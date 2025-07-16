// lib/screens/login_screen.dart
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'dart:math';
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
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isEmailValidForRegistration = false;
  bool _isAwaitingVerification = false;

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {});

    _emailController.addListener(_validateEmailForRegistration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocusNode.requestFocus();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AuthHelper.lastLogoutReason == LogoutReason.invalidRefreshToken) {
        SnackbarHelper.showErrorSnackbar(context, 'La tua sessione è scaduta. Effettua nuovamente il login.');
        AuthHelper.clearLastLogoutReason();
      }
    });

    if (mounted && AuthHelper.lastUsedEmail != null) {
      _emailController.text = AuthHelper.lastUsedEmail!;
      _passwordFocusNode.requestFocus();
      AuthHelper.clearLastUsedEmail();
    }
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    _emailController.removeListener(_validateEmailForRegistration);
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _validateEmailForRegistration() {
    // RegExp per una validazione email più robusta
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    final bool isValid = emailRegExp.hasMatch(_emailController.text);
    if (isValid != _isEmailValidForRegistration) {
      if (mounted) setState(() => _isEmailValidForRegistration = isValid);
    }
  }

  Future<void> _signInWithPassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      AuthHelper.clearLastLogoutReason();
    } on AuthException catch (e) {
      Logger('LoginScreen').severe('Errore Login: ${e.message}');
      SnackbarHelper.showErrorSnackbar(context, 'Credenziali non valide o utente non trovato.');
    } catch (e) {
      Logger('LoginScreen').severe('Errore inatteso: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Si è verificato un errore inatteso.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // **MODIFICATO:** La registrazione non apre più un dialogo
  Future<void> _handleRegistration() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Genera una password temporanea sicura
    final tempPassword = _generateSecureRandomPassword();

    try {
      final response = await supabase.functions.invoke(
        'register-user',
        method: HttpMethod.post,
        body: {'email': _emailController.text.trim(), 'password': tempPassword},
      );

      if (!mounted) return;

      if (response.status == 200) {
        setState(() => _isAwaitingVerification = true);
        SnackbarHelper.showSuccessSnackbar(context, 'Controlla la tua email per il codice di verifica.');
        _otpFocusNode.requestFocus();
      } else {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? 'Errore sconosciuto dal server.';
        SnackbarHelper.showErrorSnackbar(context, 'Errore ${response.status}: $errorMessage');
      }
    } on FunctionException catch (e) {
      if (!mounted) return;
      final details = e.details is Map ? (e.details as Map)['error'] ?? e.details : e.details;
      Logger('LoginScreen').severe('FunctionException in _registerUser: $details');
      SnackbarHelper.showErrorSnackbar(context, 'Errore di comunicazione: $details');
    } catch (e) {
      if (!mounted) return;
      Logger('LoginScreen').severe('Errore inatteso in _registerUser: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Si è verificato un errore inatteso.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateSecureRandomPassword({int length = 12}) {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: _otpController.text.trim(),
        email: _emailController.text.trim(),
      );

      // **INIZIO DELLA MODIFICA**
      // Se la verifica ha successo e abbiamo una sessione, non mostriamo più un dialogo.
      // Invece, navighiamo alla pagina dedicata per impostare la password.
      if (response.session != null && mounted) {
        // GoRouter ora gestirà il redirect alla pagina /set-password
        // perché l'utente è loggato ma non ha ancora il flag 'has_set_password'.
        // Non è nemmeno necessario un context.go() esplicito, il refresh del router farà il suo lavoro.
        // Lasciamo questo setState per sicurezza, anche se il redirect avverrà subito dopo.
        setState(() {
          _isAwaitingVerification = false;
        });
      } else {
        SnackbarHelper.showErrorSnackbar(context, 'Verifica fallita. Controlla il codice e riprova.');
      }
      // **FINE DELLA MODIFICA**
    } on AuthException catch (e) {
      Logger('LoginScreen').severe('Errore verifica OTP: ${e.message}');
      SnackbarHelper.showErrorSnackbar(context, 'Codice non valido o scaduto.');
    } catch (e) {
      Logger('LoginScreen').severe('Errore inatteso in _verifyOtp: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Si è verificato un errore inatteso.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Una Social')),
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
                  Text(
                    _isAwaitingVerification ? 'Verifica il tuo Account' : 'Accedi o Registrati',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    readOnly: _isAwaitingVerification,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Inserisci un\'email';
                      final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                      if (!emailRegExp.hasMatch(value)) return 'Inserisci un\'email valida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  if (!_isAwaitingVerification)
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _isPasswordObscured,
                      decoration: InputDecoration(
                        labelText: 'Password (se già registrato)',
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordObscured ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _signInWithPassword(),
                    ),
                  if (_isAwaitingVerification) ...[
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      decoration: const InputDecoration(labelText: 'Codice di Verifica (dall\'email)'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _verifyOtp(),
                      validator: (value) {
                        if (value == null || value.length < 6) return 'Inserisci il codice a 6 cifre';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_isAwaitingVerification)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verifica Account'),
                    )
                  else
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
                              onPressed: _isLoading ? null : _handleRegistration,
                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary),
                              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Nuovo Utente'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 25),
                  if (!_isAwaitingVerification)
                    TextButton(
                      onPressed: () => SnackbarHelper.showInfoSnackbar(context, 'Funzionalità non ancora implementata.'),
                      child: const Text('Password dimenticata?'),
                    ),
                  if (_isAwaitingVerification)
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() => _isAwaitingVerification = false),
                      child: const Text('Annulla verifica'),
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
