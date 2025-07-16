// lib/screens/set_password_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/snackbar_helper.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import 'package:flutter_pw_validator/Resource/Strings.dart';

final supabase = Supabase.instance.client;

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _checkPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordStrongEnough = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (mounted) {
        _formKey.currentState?.validate();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _checkPasswordController.dispose();
    super.dispose();
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate() || !_isPasswordStrongEnough) {
      SnackbarHelper.showErrorSnackbar(context, 'La password non soddisfa tutti i requisiti.');
      return;
    }

    if (supabase.auth.currentUser == null) {
      Logger('SetPasswordScreen').severe('Tentativo di impostare la password senza un utente loggato.');
      SnackbarHelper.showErrorSnackbar(context, 'Sessione non valida. Riprova il login.');
      context.go('/login');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: _passwordController.text.trim(),
          data: const {'has_set_password': true},
        ),
      );

      Logger('SetPasswordScreen').info('Password impostata per: ${supabase.auth.currentUser!.email}');
      SnackbarHelper.showSuccessSnackbar(context, 'Benvenuto! Registrazione completata.');
    } catch (e) {
      Logger('SetPasswordScreen').severe('Errore durante l\'aggiornamento della password: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Errore: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completa la Registrazione')),
      // **INIZIO DELLA NUOVA STRUTTURA DI LAYOUT**
      body: SingleChildScrollView(
        // 1. Il SingleChildScrollView è il widget principale, permette lo scroll verticale.
        child: Align(
          // 2. Align centra il suo figlio orizzontalmente nella larghezza disponibile.
          //    Non tenta di centrare verticalmente, evitando conflitti.
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // 3. Limita la larghezza massima del form per una buona leggibilità su schermi grandi.
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              // 4. Aggiunge spazio attorno al form.
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Crea la tua password di accesso',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FlutterPwValidator(
                      controller: _passwordController,
                      minLength: 6,
                      uppercaseCharCount: 1,
                      lowercaseCharCount: 1,
                      numericCharCount: 1,
                      specialCharCount: 1,
                      width: 400,
                      height: 150,
                      strings: ItalianPasswordValidatorStrings(),
                      onSuccess: () {
                        if (mounted) setState(() => _isPasswordStrongEnough = true);
                      },
                      onFail: () {
                        if (mounted) setState(() => _isPasswordStrongEnough = false);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _checkPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Conferma Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Le password non coincidono';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _isLoading ? null : _setNewPassword,
                      child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salva e Accedi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // **FINE DELLA NUOVA STRUTTURA DI LAYOUT**
    );
  }
}

class ItalianPasswordValidatorStrings extends FlutterPwValidatorStrings {
  @override
  String get atLeast => 'Almeno - caratteri';
  @override
  String get normalLetters => '- lettere minuscole';
  @override
  String get uppercaseLetters => '- lettere maiuscole';
  @override
  String get numericCharacters => '- caratteri numerici';
  @override
  String get specialCharacters => '- caratteri speciali';
}
