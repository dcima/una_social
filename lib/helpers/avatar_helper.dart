// lib/helpers/avatar_helper.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/personale.dart'; // Assicurati che il percorso sia corretto

class AvatarHelper {
  static const String _bucketName = 'una-bucket';

  /// Genera un URL visualizzabile per l'avatar di un utente.
  ///
  /// Segue una logica a priorità per determinare il percorso dell'immagine:
  /// 1. Se `user.photoUrl` è già un URL pubblico, lo restituisce.
  /// 2. Se `user.photoUrl` contiene un percorso, lo usa per generare un URL firmato.
  /// 3. Se `user.photoUrl` è vuoto, costruisce un percorso di default usando
  ///    `ente` e `id` del [user] e genera un URL firmato.
  /// 4. Se [user] è nullo ma viene fornito un [email], prova a generare un
  ///    URL per un utente "esterno".
  ///
  /// Restituisce `null` se non è possibile determinare un percorso valido.
  static Future<String?> getDisplayAvatarUrl({
    required Personale? user,
    String? email, // Email principale, utile come fallback se `user` è nullo
  }) async {
    final supabase = Supabase.instance.client;
    final String? photoUrl = user?.photoUrl;

    // Priorità 1: È già un URL pubblico e valido.
    if (photoUrl != null && photoUrl.startsWith('http')) {
      return photoUrl;
    }

    String? imagePath;

    // Priorità 2: Il campo photoUrl contiene un percorso.
    if (photoUrl != null && photoUrl.isNotEmpty) {
      imagePath = photoUrl;
    }
    // Priorità 3: Il campo è vuoto, costruiamo il percorso dal profilo Personale.
    else if (user != null && user.ente.isNotEmpty && user.id > 0) {
      imagePath = 'personale/foto/${user.ente}_${user.id}.jpg';
    }
    // Priorità 4: Fallback sull'email per utenti esterni.
    else if (email != null && email.isNotEmpty) {
      final emailFileName = email.replaceAll(RegExp(r'[^\w.@-]'), '_');
      imagePath = 'esterni/foto/$emailFileName.jpg';
    }

    appLogger.info("imagePath: $imagePath");

    // Se non siamo riusciti a determinare un percorso, non possiamo fare nulla.
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // Tentativo finale: creare un URL firmato per il percorso trovato.
    try {
      return await supabase.storage.from(_bucketName).createSignedUrl(imagePath, 3600); // URL valido per 1 ora
    } catch (e) {
      // Questo errore è normale se il file non esiste, quindi non lo trattiamo come critico.
      appLogger.info('AvatarHelper: Impossibile ottenere l\'URL per "$imagePath". Errore: $e');
      return null;
    }
  }
}
