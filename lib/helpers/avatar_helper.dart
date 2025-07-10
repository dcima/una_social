// lib/helpers/avatar_helper.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/esterni.dart';
import 'package:una_social/models/i_user_profile.dart';
import 'package:una_social/models/personale.dart';

class AvatarHelper {
  static final _supabase = Supabase.instance.client;
  static const String _bucketName = 'una-bucket';

  /// ASYNCHRONOUSLY generates a temporary, signed URL for an avatar from a private bucket.
  ///
  /// This is now an async function because `createSignedUrl` is async.
  static Future<String?> getDisplayAvatarUrl({
    required IUserProfile? user,
    required User? authUser,
  }) async {
    if (authUser == null) {
      return null;
    }

    String? finalPath;

    // 1. Check for a direct photo_url (highest priority)
    final String? photoPath = user?.photoUrl?.trim();
    if (photoPath != null && photoPath.isNotEmpty) {
      if (photoPath.startsWith('http')) {
        logInfo('[AvatarHelper] Using direct public URL from photo_url: $photoPath');
        return photoPath;
      }
      finalPath = photoPath;
    } else {
      // 2. If photo_url is empty, apply fallback logic
      if (user is Personale) {
        final personale = user;
        final filename = '${personale.ente}_${personale.id}.jpg';
        finalPath = 'personale/foto/$filename';
      } else if (user is Esterni) {
        if (user.emailPrincipale != null && user.emailPrincipale!.isNotEmpty) {
          final filename = '${user.emailPrincipale}.jpg';
          finalPath = 'esterni/foto/$filename';
        }
      } else if (user == null) {
        // Handle newly registered Esterni user not yet in DB
        final email = authUser.email;
        if (email != null && email.isNotEmpty) {
          final filename = '$email.jpg';
          finalPath = 'esterni/foto/$filename';
        }
      }
    }

    // 3. If we have a path, create a temporary signed URL for it.
    if (finalPath != null && finalPath.isNotEmpty) {
      logInfo('[AvatarHelper] Attempting to create signed URL for path: $finalPath');
      try {
        // Create a URL valid for 1 hour (3600 seconds) as requested.
        final signedUrl = await _supabase.storage.from(_bucketName).createSignedUrl(finalPath, 3600);
        logInfo('[AvatarHelper] Successfully created signed URL.');
        return signedUrl;
      } catch (e) {
        // This error usually means the file does not exist or access is denied.
        logError('[AvatarHelper] Failed to create signed URL for "$finalPath". Error: $e');
        return null;
      }
    }

    // 4. If all checks fail, return null.
    logInfo('[AvatarHelper] No valid photo path found. Returning null.');
    return null;
  }
}
