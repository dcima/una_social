// lib/helpers/snackbar_helper.dart
import 'package:flutter/material.dart';

class SnackbarHelper {
  static void _showSnackbar(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.black,
    Duration duration = const Duration(seconds: 4), // Durata di default
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration, // Usa la durata passata
        action: action,
        behavior: SnackBarBehavior.floating, // O il tuo comportamento preferito
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showSuccessSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message,
      backgroundColor: Colors.green.shade700,
      duration: duration,
    );
  }

  static void showErrorSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4), // Durata di default per errori
  }) {
    _showSnackbar(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.error, // Usa il colore di errore del tema
      duration: duration,
    );
  }

  static void showInfoSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message,
      backgroundColor: Colors.blueGrey.shade700,
      duration: duration,
    );
  }

  static void showWarningSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _showSnackbar(
      context,
      message,
      backgroundColor: Colors.orange.shade700,
      duration: duration,
    );
  }
}
