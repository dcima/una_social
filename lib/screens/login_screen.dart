// lib/screens/login_screen.dart
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/auth_helper.dart';
import 'package:una_social/helpers/snackbar_helper.dart';

final supabase = Supabase.instance.client;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isEmailValidForRegistration = false; // Stato per la visibilità del pulsante di registrazione

  final _passwordFocusNode = FocusNode();

  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Il redirect è gestito globalmente da GoRouter
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {});

    // Aggiungi un listener al controller dell'email per aggiornare la UI
    _emailController.addListener(_validateEmailForRegistration);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AuthHelper.lastLogoutReason == LogoutReason.invalidRefreshToken) {
        SnackbarHelper.showErrorSnackbar(
          context,
          'La tua sessione è scaduta. Effettua nuovamente il login.',
          duration: const Duration(seconds: 5),
        );
        AuthHelper.clearLastLogoutReason();
      }
    });

    // 2. Aggiungi la logica per pre-compilare l'email e spostare il focus
    if (mounted && AuthHelper.lastUsedEmail != null) {
      _emailController.text = AuthHelper.lastUsedEmail!;
      _passwordFocusNode.requestFocus(); // Sposta il cursore sulla password
      AuthHelper.clearLastUsedEmail(); // Pulisci per non riutilizzarla involontariamente
    }
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _emailController.removeListener(_validateEmailForRegistration); // Rimuovi il listener
    _emailController.dispose();
    _passwordController.dispose();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  /// Controlla se l'email inserita è valida per mostrare il pulsante di registrazione
  void _validateEmailForRegistration() {
    // Semplice validazione: deve contenere '@' e avere almeno 3 caratteri (es. a@b)
    final bool isValid = _emailController.text.contains('@') && _emailController.text.length > 2;
    // Aggiorna lo stato solo se il valore di validità è cambiato per evitare rebuild non necessari
    if (isValid != _isEmailValidForRegistration) {
      if (mounted) {
        setState(() {
          _isEmailValidForRegistration = isValid;
        });
      }
    }
  }

  /// Login standard con email e password
  Future<void> _signInWithPassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final emailToSignIn = _emailController.text.trim();
    final passwordToSignIn = _passwordController.text.trim();

    Logger('LoginScreen').info('--- TENTATIVO DI LOGIN ---');
    Logger('LoginScreen').info('Email inviata: [$emailToSignIn]');
    Logger('LoginScreen').info('Password inviata: [$passwordToSignIn]');

    try {
      await supabase.auth.signInWithPassword(
        email: emailToSignIn,
        password: passwordToSignIn,
      );
      AuthHelper.clearLastLogoutReason();
      // GoRouter gestirà il redirect alla home
    } on AuthException catch (e) {
      Logger('LoginScreen').severe('Errore Login: ${e.message}');
      SnackbarHelper.showErrorSnackbar(context, 'Credenziali non valide o utente non trovato.');
    } catch (e) {
      Logger('LoginScreen').severe('Errore inatteso: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Si è verificato un errore inatteso.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Registra un nuovo utente chiamando una Edge Function.
  /// Restituisce `true` in caso di successo, `false` altrimenti.
  /// La gestione degli errori (con Snackbar) avviene qui.
  Future<bool> _registerUser(BuildContext context, String email, String password) async {
    try {
      final response = await supabase.functions.invoke(
        'register-user',
        method: HttpMethod.post,
        body: {
          'email': email.trim(),
          'password': password.trim(),
        },
      );

      if (!mounted) return false;

      if (response.status == 200) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData.containsKey('error')) {
          SnackbarHelper.showErrorSnackbar(context, '${responseData['error']}');
          return false;
        } else {
          // Successo! La funzione è stata eseguita e non ha restituito un errore logico.
          return true;
        }
      } else {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? 'Errore sconosciuto dal server.';
        SnackbarHelper.showErrorSnackbar(context, 'Errore ${response.status}: $errorMessage');
        return false;
      }
    } on FunctionException catch (e) {
      if (!mounted) return false;
      final details = e.details is Map ? (e.details as Map)['error'] ?? e.details : e.details;
      Logger('LoginScreen').severe('FunctionException in _registerUser: $details');
      SnackbarHelper.showErrorSnackbar(context, 'Errore di comunicazione: $details');
      return false;
    } catch (e) {
      if (!mounted) return false;
      Logger('LoginScreen').severe('Errore inatteso in _registerUser: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Si è verificato un errore inatteso.');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Una Social')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Accedi', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || !value.contains('@')) return 'Inserisci un\'email valida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _isPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _isLoading ? null : _signInWithPassword(),
                    validator: (value) {
                      if (value == null || value.length < 6) return 'La password deve avere almeno 6 caratteri';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signInWithPassword,
                          child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accedi'),
                        ),
                      ),
                      if (_isEmailValidForRegistration) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final String currentEmail = _emailController.text;
                              final String currentPassword = _passwordController.text;
                              final bool isPasswordValid = currentPassword.length >= 6;

                              // Mostra il dialogo e attende un risultato (la password, se la registrazione ha successo)
                              final newPassword = await showDialog<String?>(
                                context: context,
                                builder: (BuildContext context) {
                                  return RegisterDialog(
                                    emailController: _emailController,
                                    initialPassword: isPasswordValid ? currentPassword : null,
                                    onRegister: (email, password) => _registerUser(context, email, password),
                                  );
                                },
                              );

                              // Se il dialogo ha restituito una password (registrazione avvenuta con successo)
                              if (newPassword != null && mounted) {
                                setState(() {
                                  // Imposta la password restituita dal dialogo nel campo della form di login
                                  _emailController.text = currentEmail;
                                  _passwordController.text = newPassword;
                                });
                                // Notifica l'utente di procedere con il login
                                SnackbarHelper.showSuccessSnackbar(
                                  context,
                                  'Registrazione effettuata, premi \'Accedi\' per entrare',
                                  duration: const Duration(seconds: 10),
                                );
                              }
                            },
                            child: const Text('Nuovo Utente'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 25),
                  TextButton(
                    onPressed: () {
                      SnackbarHelper.showInfoSnackbar(context, 'Funzionalità di recupero password non ancora implementata.');
                    },
                    child: const Text('Password dimenticata?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterDialog extends StatefulWidget {
  final TextEditingController emailController;
  // La callback ora restituisce un Future<bool> per indicare il successo
  final Future<bool> Function(String, String) onRegister;
  final String? initialPassword;

  const RegisterDialog({
    super.key,
    required this.emailController,
    required this.onRegister,
    this.initialPassword,
  });

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _passwordController = TextEditingController();
  final _checkPasswordController = TextEditingController();
  final _dialogFormKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true;
  bool _isCheckPasswordObscured = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _checkPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_dialogFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Esegue la registrazione e attende il risultato booleano
    final bool success = await widget.onRegister(
      widget.emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Se la registrazione ha successo, chiude il dialogo e restituisce la password usata
      Navigator.of(context).pop(_passwordController.text);
    } else {
      // Se la registrazione fallisce, ferma l'indicatore di caricamento.
      // L'errore è già stato mostrato tramite Snackbar da _registerUser.
      // Il dialogo rimane aperto per permettere all'utente di correggere.
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Registra un Nuovo Utente'),
      contentPadding: const EdgeInsets.all(24.0),
      children: [
        Form(
          key: _dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _passwordController,
                obscureText: _isPasswordObscured,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) return 'La password deve avere almeno 6 caratteri';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _checkPasswordController,
                obscureText: _isCheckPasswordObscured,
                decoration: InputDecoration(
                  labelText: 'Conferma Password',
                  suffixIcon: IconButton(
                    icon: Icon(_isCheckPasswordObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isCheckPasswordObscured = !_isCheckPasswordObscured),
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) return 'Le password non coincidono';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleRegister,
                      child: const Text('Registrati'),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
