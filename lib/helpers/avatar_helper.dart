import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/i_user_profile.dart'; // <-- Usa la nuova interfaccia
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarHelper {
  static final _supabase = Supabase.instance.client;
  static const String _bucketName = 'una-bucket';

  // --- FUNZIONE UNIVERSALE ---
  // Ora accetta qualsiasi oggetto che implementi IUserProfile.
  static Future<String?> getDisplayAvatarUrl({
    required IUserProfile? user,
    String? email, // L'email di fallback
  }) async {
    // 1. Prova a usare il photo_url dal modello
    final photoPath = user?.photoUrl;
    if (photoPath != null && photoPath.isNotEmpty) {
      // Se è già un URL completo, restituiscilo
      if (photoPath.startsWith('http')) {
        return photoPath;
      }
      // Altrimenti, crea l'URL firmato da Supabase
      try {
        final url = await _supabase.storage.from(_bucketName).createSignedUrl(photoPath, 60); // URL valido per 60 secondi
        return url;
      } catch (e) {
        AppLogger().error("Errore nel creare l'URL firmato per $photoPath: $e");
        // Se fallisce, procedi al fallback
      }
    }

    // 2. Fallback: prova a usare Gravatar con l'email
    if (email != null && email.isNotEmpty) {
      // Potresti implementare qui la logica per Gravatar o un altro servizio di avatar
      // Per ora, lo lasciamo come placeholder.
      return null;
    }

    // 3. Se tutto fallisce, non c'è nessuna immagine
    return null;
  }
}
