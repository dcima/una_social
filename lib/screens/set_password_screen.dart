// lib/screens/set_password_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/snackbar_helper.dart';

final supabase = Supabase.instance.client;

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Non servono più _email e _token qui

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) return;

    // L'utente è già autenticato in questo punto, grazie al link di invito.
    // Dobbiamo solo aggiornare i suoi dati.
    if (supabase.auth.currentUser == null) {
      Logger('SetPasswordScreen').severe('Tentativo di impostare la password senza un utente loggato.');
      SnackbarHelper.showErrorSnackbar(context, 'Sessione non valida. Riprova il login.');
      context.go('/login');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Aggiorna l'utente attualmente loggato con la nuova password
      // e imposta il flag nei metadati per completare la registrazione.
      await supabase.auth.updateUser(
        UserAttributes(
          password: _passwordController.text.trim(),
          data: const {'has_set_password': true}, // Fondamentale per il redirect globale
        ),
      );

      Logger('SetPasswordScreen').info('Password impostata e registrazione completata per: ${supabase.auth.currentUser!.email}');
      SnackbarHelper.showSuccessSnackbar(context, 'Benvenuto! Registrazione completata con successo.');

      // Reindirizza l'utente alla schermata di benvenuto
      context.go('/home');
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
                    'Crea la tua password di accesso',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nuova Password'),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'La password deve avere almeno 6 caratteri';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _setNewPassword,
                    child: _isLoading ? const CircularProgressIndicator() : const Text('Salva e Accedi'),
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
