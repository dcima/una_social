import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService extends ChangeNotifier {
  final SupabaseClient _supabase;

  ProfileService(this._supabase);

  bool _hasCheckedRelationships = false;
  bool _hasAcceptedRelationships = false;

  // Getter pubblico per la UI e il router
  bool get hasAcceptedRelationships => _hasAcceptedRelationships;

  // Controlla se l'utente ha relazioni.
  // Questo metodo viene chiamato dopo il login e ogni volta che una relazione cambia.
  Future<void> checkUserRelationships() async {
    if (_supabase.auth.currentUser == null) return;

    try {
      final response = await _supabase.from('relationships').select('user_one_id').eq('status', 'accepted').or('user_one_id.eq.${_supabase.auth.currentUser!.id},user_two_id.eq.${_supabase.auth.currentUser!.id}');

      _hasAcceptedRelationships = response.isNotEmpty;
    } catch (e) {
      // In caso di errore, assumiamo che non ci siano contatti per sicurezza.
      _hasAcceptedRelationships = false;
    } finally {
      _hasCheckedRelationships = true;
      // Notifica i listener (come il router) che lo stato è cambiato.
      notifyListeners();
    }
  }

  void reset() {
    _hasCheckedRelationships = false;
    _hasAcceptedRelationships = false;
  }
}
