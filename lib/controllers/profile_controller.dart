// lib/controllers/profile_controller.dart
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';

class ProfileController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  final RxBool hasAcceptedRelationships = false.obs;
  final RxBool isLoading = false.obs;

  Future<void> checkUserRelationships() async {
    if (_supabase.auth.currentUser == null) {
      hasAcceptedRelationships.value = false;
      return;
    }

    isLoading.value = true;
    try {
      // --- INIZIO SINTASSI CORRETTA ---
      // La nuova sintassi non usa FetchOptions, ma passa 'count' direttamente
      // nella chiamata a .from(). Il risultato è un PostgrestResponse.
      final response = await _supabase.from('relationships').select('user_one_id', count: CountOption.exact).eq('status', 'accepted').or('user_one_id.eq.${_supabase.auth.currentUser!.id},user_two_id.eq.${_supabase.auth.currentUser!.id}');

      // Il conteggio si trova in response.count
      final count = response.count;
      hasAcceptedRelationships.value = (count ?? 0) > 0;
      // --- FINE SINTASSI CORRETTA ---

      logInfo("[ProfileController] Controllo relazioni: ${hasAcceptedRelationships.value} ($count trovate)");
    } catch (e, stackTrace) {
      logError("[ProfileController] Errore durante il controllo delle relazioni:", e, stackTrace);
      hasAcceptedRelationships.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  void reset() {
    hasAcceptedRelationships.value = false;
  }
}
