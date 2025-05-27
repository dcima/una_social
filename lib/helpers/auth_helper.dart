// lib/helpers/auth_helper.dart
// ignore_for_file: avoid_print

enum LogoutReason {
  none,
  invalidRefreshToken, // Sessione scaduta o invalidata dal server
  userInitiated, // Logout esplicito dell'utente
  // Aggiungi altre ragioni se necessario
}

class AuthHelper {
  static LogoutReason _lastLogoutReason = LogoutReason.none;

  static LogoutReason get lastLogoutReason => _lastLogoutReason;

  static void setLogoutReason(LogoutReason reason) {
    //print("[AuthHelper] LogoutReason impostata a: $reason");
    _lastLogoutReason = reason;
  }

  static void clearLastLogoutReason() {
    if (_lastLogoutReason != LogoutReason.none) {
      //print("[AuthHelper] LogoutReason resettata da: $_lastLogoutReason a none.");
      _lastLogoutReason = LogoutReason.none;
    }
  }
}
