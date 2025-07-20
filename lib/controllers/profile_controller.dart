// lib/controllers/profile_controller.dart
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';

// La classe deve chiamarsi ProfileController e estendere GetxController
class ProfileController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Usiamo le variabili reattive di GetX con .obs
  final RxBool hasAcceptedRelationships = false.obs;
  final RxBool isLoading = false.obs;

  // Questo è il metodo che useremo nel router
  Future<void> checkUserRelationships() async {
    // Se l'utente non è loggato, esci subito
    if (_supabase.auth.currentUser == null) {
      hasAcceptedRelationships.value = false;
      return;
    }

    isLoading.value = true;
    try {
      // Usiamo la sintassi corretta per ottenere il conteggio
      final count = await _supabase
          .from('relationships')
          .count(CountOption.exact) // Questo è il modo giusto
          .eq('status', 'accepted')
          .or('user_one_id.eq.${_supabase.auth.currentUser!.id},user_two_id.eq.${_supabase.auth.currentUser!.id}');

      // Aggiorniamo il valore della variabile reattiva
      hasAcceptedRelationships.value = count > 0;

      logInfo("[ProfileController] Controllo relazioni: ${hasAcceptedRelationships.value} ($count trovate)");
    } catch (e, stackTrace) {
      logError("[ProfileController] Errore durante il controllo delle relazioni:", e, stackTrace);
      hasAcceptedRelationships.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  // Metodo per resettare lo stato al logout
  void reset() {
    hasAcceptedRelationships.value = false;
  }
}
