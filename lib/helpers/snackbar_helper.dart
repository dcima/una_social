// lib/helpers/snackbar_helper.dart
import 'package:flutter/material.dart';

class SnackbarHelper {
  // Rende il costruttore privato per impedire l'istanziazione.
  // Questa classe conterrà solo metodi statici.
  SnackbarHelper._();

  static void showSuccessSnackbar(BuildContext context, String message) {
    _showSnackbar(context, message, backgroundColor: Colors.green, icon: Icons.check_circle_outline);
  }

  static void showErrorSnackbar(BuildContext context, String message) {
    _showSnackbar(context, message, backgroundColor: Colors.redAccent, icon: Icons.error_outline);
  }

  static void showInfoSnackbar(BuildContext context, String message) {
    _showSnackbar(context, message, backgroundColor: Colors.blueAccent, icon: Icons.info_outline);
  }

  static void showWarningSnackbar(BuildContext context, String message) {
    _showSnackbar(context, message, backgroundColor: Colors.orangeAccent, icon: Icons.warning_amber_outlined);
  }

  // Metodo privato generico per mostrare la snackbar
  static void _showSnackbar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 4), // Durata di default
    SnackBarBehavior behavior = SnackBarBehavior.floating, // Comportamento di default
  }) {
    // Controlla se il context è ancora valido e se il widget è montato.
    // Questo è particolarmente utile se chiamato da callback asincroni.
    // Tuttavia, è responsabilità del chiamante assicurarsi che il context sia
    // appropriato per mostrare una SnackBar (cioè, deve avere uno ScaffoldMessenger ancestor).
    // Per una maggiore robustezza, il chiamante dovrebbe idealmente controllare `mounted`
    // se sta chiamando da uno StatefulWidget.

    // Rimuoviamo il controllo 'mounted' da qui, poiché questa classe helper non ha uno stato 'mounted'.
    // Il chiamante (es. uno StatefulWidget) dovrebbe preoccuparsi di chiamare questo metodo
    // solo quando il suo context è valido.

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 20),
            if (icon != null) const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: behavior,
        // Potresti aggiungere altre personalizzazioni qui, come action:
        // action: SnackBarAction(
        //   label: 'OK',
        //   onPressed: () {
        //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
        //   },
        // ),
      ),
    );
  }

  // Se vuoi un metodo per nascondere la snackbar corrente
  static void hideCurrentSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // Se vuoi rimuovere tutte le snackbar in coda
  static void clearSnackbars(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
