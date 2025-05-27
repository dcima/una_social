// lib/helpers/logger_helper.dart
import 'package:flutter/foundation.dart'; // Per kReleaseMode
import 'package:logging/logging.dart';

// Crea un logger globale per l'app (puoi anche creare logger specifici per modulo)
final AppLogger appLogger = AppLogger();

class AppLogger {
  static final Logger _logger = Logger('UnaSocialApp'); // Dai un nome al tuo logger

  // Singleton pattern per una facile accessibilità, anche se non strettamente necessario
  // con una variabile globale 'appLogger'.
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() {
    return _instance;
  }
  AppLogger._internal() {
    _setupLogger();
  }

  void _setupLogger() {
    Logger.root.level = Level.ALL; // Cattura tutti i livelli di log

    Logger.root.onRecord.listen((record) {
      if (!kReleaseMode) {
        // Mostra i log solo se NON siamo in modalità release
        // Puoi personalizzare il formato del log qui
        // Questo è un formato di esempio: [LIVELLO] [ORA] [LOGGER_NAME]: MESSAGGIO
        // [ERRORE SE PRESENTE] [STACKTRACE SE PRESENTE]
        debugPrint('[${record.level.name}] ${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')}:${record.time.second.toString().padLeft(2, '0')}.${record.time.millisecond.toString().padLeft(3, '0')} '
            '${record.loggerName}: ${record.message}');
        if (record.error != null) {
          debugPrint('  ERROR: ${record.error}');
        }
        if (record.stackTrace != null) {
          // Stampa lo stack trace in modo più leggibile, se presente e significativo
          // Potresti volerlo stampare solo per livelli SEVERE o SHOUT
          if (record.level >= Level.SEVERE) {
            debugPrint('  STACKTRACE:\n${record.stackTrace}');
          }
        }
      }
    });
  }

  // Metodi di logging comodi
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.finer(message, error, stackTrace); // Finer è un buon livello per debug dettagliato
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace); // Severe è per errori seri
  }

  void shout(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.shout(message, error, stackTrace); // Per errori molto critici
  }
}

// Funzione globale per un accesso ancora più semplice (opzionale)
void logDebug(String message, [Object? error, StackTrace? stackTrace]) => appLogger.debug(message, error, stackTrace);
void logInfo(String message, [Object? error, StackTrace? stackTrace]) => appLogger.info(message, error, stackTrace);
void logWarning(String message, [Object? error, StackTrace? stackTrace]) => appLogger.warning(message, error, stackTrace);
void logError(String message, [Object? error, StackTrace? stackTrace]) => appLogger.error(message, error, stackTrace);
