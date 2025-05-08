// lib/screens/login_screen.dart
// ignore_for_file: avoid_print, deprecated_member_use, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Per FilteringTextInputFormatter
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client; // Inizializza il client Supabase

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
      final session = data.session;
      if (session != null && mounted) {
        // GoRouter gestirà il redirect globale
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose(); // --- NUOVO: Dispose OTP controller ---
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // Funzione per Sign In standard con Email/Password
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      final emailValid = _emailController.text.isNotEmpty && _emailController.text.contains('@');
      final passwordValid = _passwordController.text.isNotEmpty && _passwordController.text.length >= 6;
      if (!emailValid || !passwordValid) {
        if (!_formKey.currentState!.validate()) {
          print("Form validation failed for Email/Password sign in.");
          return;
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar('Errore Login: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Errore inatteso: $e');
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
      _showErrorSnackBar('Inserisci un\'email valida per verificare il codice.');
      return;
    }
    if (otp.isEmpty || otp.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(otp)) {
      _showErrorSnackBar('Inserisci un codice di invito valido (6 cifre).');
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      // Usa verifyOTP con il tipo corretto
      await supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.invite, // Specifica che è un OTP di invito!
      );
      // Se arriva qui, la verifica ha avuto successo e l'utente è loggato.
      // GoRouter dovrebbe gestire il redirect a /home grazie a onAuthStateChange.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invito verificato con successo!'), backgroundColor: Colors.green),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar('Errore Verifica Codice: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Errore inatteso durante la verifica: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Funzione helper per mostrare errori
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Rimuovi snackbar precedenti
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // _signInWithGoogle() rimane invariato...
  Future<void> _signInWithGoogle() async {
    // ... (stesso codice di prima) ...
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
                  Text(
                    'Accedi o Registrati',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // --- Sezione Email/Password ---
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email *'), // Aggiungi * per indicare che serve sempre
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      // Validazione base email (richiesta per entrambi i flussi)
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
                      labelText: 'Password', // Non necessaria per flusso OTP
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).primaryColorDark.withOpacity(0.6)),
                        tooltip: _isPasswordObscured ? 'Mostra password' : 'Nascondi password',
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    validator: (value) {
                      // La validazione della password è richiesta SOLO se
                      // l'utente NON sta inserendo un codice OTP.
                      // Potremmo rendere la validazione condizionale, ma è più complesso.
                      // Se l'utente usa il flusso OTP, ignoreremo questo errore.
                      if (_otpController.text.isEmpty && (value == null || value.isEmpty || value.length < 6)) {
                        return 'La password deve avere almeno 6 caratteri (se non usi il codice invito)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn, // Chiama _signIn
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accedi / Registrati'),
                  ),
                  const SizedBox(height: 25),

                  // --- Separatore e Sezione Codice Invito ---
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
                      counterText: "", // Nasconde il contatore standard
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Permette solo numeri
                    maxLength: 6, // Limita a 6 caratteri
                    textAlign: TextAlign.center,
                    validator: (value) {
                      // Validazione opzionale: richiesta solo se si usa questo flusso
                      // if (_passwordController.text.isEmpty && (value == null || value.isEmpty || value.length != 6)) {
                      //   return 'Il codice deve avere 6 cifre (se non usi la password)';
                      // }
                      // Per ora non validiamo qui, la validazione avviene in _verifyOtpInvite
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, // Colore diverso per distinguerlo?
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _verifyOtpInvite, // Chiama _verifyOtpInvite
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verifica Codice Invito'),
                  ),

                  // Google Sign in e Nota finale (invariati)
                  const SizedBox(height: 25),
                  /*
                   ElevatedButton.icon( ... Google Button ...),
                   */
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
