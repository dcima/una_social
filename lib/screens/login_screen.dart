// lib/screens/login_screen.dart
// ignore_for_file: avoid_print, deprecated_member_use, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Per FilteringTextInputFormatter
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/helpers/auth_helper.dart'; // Importa l'helper
import 'package:una_social_app/helpers/snackbar_helper.dart'; // Per la Snackbar

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
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      // La validazione del form mostrerà i messaggi di errore nei TextFormField
      print("Form validation failed for Email/Password sign in.");
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
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      SnackbarHelper.showErrorSnackbar(context, 'Inserisci un\'email valida per verificare il codice.');
      return;
    }
    if (otp.isEmpty || otp.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(otp)) {
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

  // _signInWithGoogle non è nel tuo codice, la rimuovo per brevità se non necessaria
  // Future<void> _signInWithGoogle() async { ... }

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
                  Text(
                    'Accedi',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Inserisci un\'email valida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).primaryColorDark.withOpacity(0.6)),
                        tooltip: _isPasswordObscured ? 'Mostra password' : 'Nascondi password',
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    validator: (value) {
                      if (_otpController.text.isEmpty && (value == null || value.isEmpty || value.length < 6)) {
                        return 'La password deve avere almeno 6 caratteri (se non usi il codice invito)';
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
                    decoration: const InputDecoration(
                      labelText: 'Codice Invito (6 cifre)',
                      counterText: "",
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    // Validator non strettamente necessario qui se _verifyOtpInvite fa i controlli
                  ),
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
