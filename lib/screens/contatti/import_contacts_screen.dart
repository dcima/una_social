// lib/src/features/import_contacts/presentation/import_contacts_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/app_router.dart'; // Importa AppRouter

class ImportContactsScreen extends StatefulWidget {
  // Cambia a StatefulWidget
  const ImportContactsScreen({super.key});

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  final AuthController authController = Get.find<AuthController>();
  // Rimosso l'istanza di UiController da qui, non è più necessaria per initState.
  // Se fosse necessaria per altri scopi nel build, andrebbe mantenuta.

  @override
  void initState() {
    super.initState();
    // Rimosso: uiController.updateBreadcrumbs(UiController.buildBreadcrumbsFromPath('/app/import-contacts'));
    // L'aggiornamento dei breadcrumbs è gestito centralmente dal ShellRoute in app_router.dart
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Rimuovi Scaffold e AppBar, saranno forniti da HomeScreen
    return Center(
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
              Visibility(
                visible: authController.isPersonale,
                child: const SizedBox(height: 32),
              ),
              Visibility(
                visible: authController.isPersonale,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.school_outlined),
                  key: const Key('import_university_colleghi_button'),
                  label: const Text("Importa Colleghi dall'Università"),
                  onPressed: () {
                    context.goNamed(AppRoute.colleghi.name);
                  },
                  style: _buttonStyle(theme),
                ),
              ),
              Visibility(
                visible: (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? false : true,
                child: const SizedBox(height: 16),
              ),
              Visibility(
                visible: (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? false : true,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.contact_phone_outlined),
                  key: const Key('import_phone_contacts_button'),
                  label: const Text('Invita dalla Rubrica del Telefono'),
                  onPressed: () {
                    // Logica per invitare da rubrica telefono
                  },
                  style: _buttonStyle(theme),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.email_outlined),
                key: const Key('import_csv_contacts_button'),
                label: const Text('Importa contatti CSV'),
                onPressed: () {
                  // Logica per importare contatti CSV
                },
                style: _buttonStyle(theme),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.email_outlined),
                key: const Key('import_email_contacts_button'),
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
