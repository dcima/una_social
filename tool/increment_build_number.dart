// tool/increment_build_number.dart
import 'dart:io';

void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('Errore: pubspec.yaml non trovato!');
    exit(1);
  }

  List<String> lines = pubspecFile.readAsLinesSync();
  bool versionLineFound = false;
  bool updated = false;

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (line.startsWith('version:')) {
      versionLineFound = true;
      // Regex per trovare version: x.y.z+b o x.y.z
      RegExp versionRegex = RegExp(r'version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?');
      Match? match = versionRegex.firstMatch(line);

      if (match != null) {
        String versionCore = match.group(1)!; // x.y.z
        String? currentBuildNumberStr = match.group(2); // b (può essere null)

        int buildNumber = 0;
        if (currentBuildNumberStr != null) {
          buildNumber = int.tryParse(currentBuildNumberStr) ?? 0;
        }
        buildNumber++;

        lines[i] = 'version: $versionCore+$buildNumber';
        stdout.writeln('pubspec.yaml aggiornato: Nuova versione ${lines[i]}');
        updated = true;
        break;
      } else {
        stderr.writeln('Formato della riga "version:" non riconosciuto in pubspec.yaml.');
        stderr.writeln('Assicurati che sia nel formato "version: x.y.z" o "version: x.y.z+build".');
        exit(1);
      }
    }
  }

  if (!versionLineFound) {
    stderr.writeln('Riga "version:" non trovata in pubspec.yaml.');
    exit(1);
  }

  if (updated) {
    try {
      pubspecFile.writeAsStringSync(lines.join('\n') + (lines.isEmpty || lines.last.isEmpty ? '' : '\n'));
    } catch (e) {
      stderr.writeln('Errore durante la scrittura di pubspec.yaml: $e');
      exit(1);
    }
  } else {
    // Questo non dovrebbe accadere se versionLineFound è true e il regex matcha
    stderr.writeln('Non è stato possibile aggiornare il numero di build.');
    exit(1);
  }
}
