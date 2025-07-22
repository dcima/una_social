// lib/src/features/import_contacts/presentation/import_contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:una_social/app_router.dart';

class ImportContactsScreen extends StatelessWidget {
  const ImportContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trova i tuoi Amici'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Per iniziare, connettiti con qualcuno!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.school_outlined),
                  label: const Text("Importa Colleghi dall'Università"),
                  onPressed: () {
                    // PUNTO 2: Qui viene richiamata la nuova schermata
                    // che a sua volta eseguirà 'get-colleagues'
                    context.goNamed(AppRoute.colleghi.name);
                  },
                  style: _buttonStyle(theme),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.contact_phone_outlined),
                  label: const Text('Invita dalla Rubrica del Telefono'),
                  onPressed: () {
                    // Logica per invitare da rubrica telefono
                  },
                  style: _buttonStyle(theme),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Invita tramite Email'),
                  onPressed: () {
                    // Logica per invitare via email
                  },
                  style: _buttonStyle(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stile centralizzato per i pulsanti
  ButtonStyle _buttonStyle(ThemeData theme) {
    return FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: theme.textTheme.titleMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
