// Definisce il "contratto" che ogni modello di profilo utente deve rispettare.
// In questo modo, le funzioni helper possono lavorare con qualsiasi tipo di utente.
abstract class IUserProfile {
  String? get photoUrl;
  String? get emailPrincipale;
}
