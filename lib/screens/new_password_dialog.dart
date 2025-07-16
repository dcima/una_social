// lib/screens/new_password_dialog.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import 'package:flutter_pw_validator/Resource/Strings.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/snackbar_helper.dart';

final supabase = Supabase.instance.client;

class NewPasswordDialog extends StatefulWidget {
  const NewPasswordDialog({super.key});

  @override
  State<NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<NewPasswordDialog> {
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
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || !_isPasswordStrongEnough) {
      SnackbarHelper.showErrorSnackbar(context, 'La password non soddisfa tutti i requisiti.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
          data: const {'has_set_password': true},
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      Logger('NewPasswordDialog').severe('Errore impostazione password: ${e.message}');
      SnackbarHelper.showErrorSnackbar(context, 'Errore durante l\'aggiornamento della password.');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      Logger('NewPasswordDialog').severe('Errore inatteso: $e');
      SnackbarHelper.showErrorSnackbar(context, 'Si è verificato un errore inatteso.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crea la tua Password di Accesso'),
      // **INIZIO DELLA CORREZIONE DEFINITIVA**
      content: SizedBox(
        // 1. Diamo una larghezza e un'altezza massime al contenuto del dialogo.
        //    Questo fornisce a SingleChildScrollView un'area definita in cui lavorare.
        width: 400,
        height: MediaQuery.of(context).size.height * 0.5, // Usa il 50% dell'altezza dello schermo
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('La tua password deve soddisfare i seguenti requisiti di sicurezza.'),
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
              ],
            ),
          ),
        ),
      ),
      // **FINE DELLA CORREZIONE**
      actions: [
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
        else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: _setNewPassword,
            child: const Text('Salva e Accedi'),
          ),
        ]
      ],
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
