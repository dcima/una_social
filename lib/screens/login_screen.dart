// lib/screens/login_screen.dart
// ignore_for_file: avoid_print, deprecated_member_use, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Per FilteringTextInputFormatter
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/auth_helper.dart'; // Importa l'helper
import 'package:una_social/helpers/snackbar_helper.dart'; // Per la Snackbar

final supabase = Supabase.instance.client;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isPasswordObscured = true;

  // FocusNodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      // La logica di redirect è gestita da GoRouter globalmente
    });

    // Mostra un messaggio se il logout è avvenuto per sessione invalida
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AuthHelper.lastLogoutReason == LogoutReason.invalidRefreshToken) {
        SnackbarHelper.showErrorSnackbar(
          context,
          'La tua sessione è scaduta o non è più valida. Effettua nuovamente il login.',
          duration: const Duration(seconds: 5), // Durata più lunga per dare tempo di leggere
        );
        AuthHelper.clearLastLogoutReason(); // Pulisci la ragione dopo aver mostrato il messaggio
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _authStateSubscription?.cancel();
    // Dispose FocusNodes
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // Nasconde la tastiera
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      // La validazione del form mostrerà i messaggi di errore nei TextFormField
      //print("Form validation failed for Email/Password sign in.");
      return;
    }
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Se il login ha successo, GoRouter gestirà il redirect.
      // Pulisci qualsiasi ragione di logout precedente, dato che l'utente sta tentando un nuovo login.
      AuthHelper.clearLastLogoutReason();
    } on AuthException catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, 'Errore Login: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, 'Errore inatteso: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtpInvite() async {
    // Nasconde la tastiera
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    // Validazione preliminare, anche se il validator del form per OTP fa già qualcosa
    if (email.isEmpty) {
      _formKey.currentState?.validate(); // Forza la validazione dell'email se vuota
      SnackbarHelper.showErrorSnackbar(context, 'Inserisci un\'email per verificare il codice.');
      return;
    } else if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]{2,}$").hasMatch(email)) {
      _formKey.currentState?.validate(); // Forza la validazione dell'email se non valida
      SnackbarHelper.showErrorSnackbar(context, 'Inserisci un\'email valida per verificare il codice.');
      return;
    }

    if (otp.isEmpty || otp.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(otp)) {
      _formKey.currentState?.validate(); // Forza la validazione del campo OTP
      SnackbarHelper.showErrorSnackbar(context, 'Inserisci un codice di invito valido (6 cifre).');
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.invite,
      );
      if (mounted) {
        SnackbarHelper.showSuccessSnackbar(context, 'Invito verificato con successo! Verrai reindirizzato.');
      }
      // Se la verifica ha successo, GoRouter gestirà il redirect.
      AuthHelper.clearLastLogoutReason();
    } on AuthException catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, 'Errore Verifica Codice: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, 'Errore inatteso durante la verifica: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              autovalidateMode: AutovalidateMode.onUserInteraction, // <-- MODIFICA CHIAVE
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Accedi',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci un\'email';
                      }
                      // Regex semplice per il formato email. Per una validazione RFC completa, la regex è molto più complessa.
                      // Questa copre la maggior parte dei casi comuni: qualcosa@qualcosa.dominio
                      final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]{2,}$");
                      if (!emailRegex.hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
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
                        icon: Icon(_isPasswordObscured ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).primaryColorDark.withOpacity(0.6)),
                        tooltip: _isPasswordObscured ? 'Mostra password' : 'Nascondi password',
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _signIn();
                      }
                    },
                    validator: (value) {
                      // Se il campo OTP è compilato, la password non è strettamente obbligatoria
                      // per questo validator, dato che l'utente potrebbe voler usare l'OTP.
                      // La logica in _signIn() si occuperà di richiederla se necessario.
                      if (_otpController.text.trim().isEmpty) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci la password';
                        }
                        if (value.length < 6) {
                          return 'La password deve avere almeno 6 caratteri';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accedi'),
                  ),
                  const SizedBox(height: 25),
                  const Row(
                    children: <Widget>[
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text("Oppure"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Hai ricevuto un codice di invito via email?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Codice Invito (6 cifre)',
                        counterText: "",
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _verifyOtpInvite();
                        }
                      },
                      validator: (value) {
                        // Questo validator si attiva solo se l'utente inserisce qualcosa nel campo OTP.
                        // Non è obbligatorio se il campo è lasciato vuoto (perché l'utente potrebbe usare email/password).
                        if (value != null && value.isNotEmpty) {
                          if (value.length != 6) {
                            return 'Il codice deve essere di 6 cifre.';
                          }
                          if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                            return 'Il codice deve contenere solo cifre.';
                          }
                        }
                        return null;
                      }),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _verifyOtpInvite,
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verifica Codice Invito'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nota: Cliccando il link di invito nell\'email, verrai autenticato automaticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
