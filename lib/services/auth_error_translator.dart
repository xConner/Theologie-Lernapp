import 'package:firebase_auth/firebase_auth.dart';

/// Übersetzt Firebase-Auth-Fehler in verständliche deutsche Meldungen,
/// damit Nutzer nie einen rohen Firebase-Fehlercode zu sehen bekommen.
String describeAuthError(Object error) {
  if (error is! FirebaseAuthException) {
    return "Etwas ist schiefgelaufen. Bitte versuche es erneut.";
  }

  switch (error.code) {
    case "email-already-in-use":
      return "Diese E-Mail-Adresse ist bereits registriert.";

    case "invalid-email":
      return "Diese E-Mail-Adresse ist ungültig.";

    case "user-not-found":
    case "wrong-password":
    case "invalid-credential":
    case "invalid-login-credentials":
      return "E-Mail oder Passwort ist falsch.";

    case "user-disabled":
      return "Dieses Konto wurde deaktiviert.";

    case "weak-password":
      return "Das Passwort ist zu schwach. Bitte wähle ein stärkeres Passwort.";

    case "too-many-requests":
      return "Zu viele Versuche. Bitte warte einen Moment und versuche es erneut.";

    case "network-request-failed":
      return "Netzwerkfehler. Bitte prüfe deine Internetverbindung.";

    case "requires-recent-login":
      return "Diese Aktion erfordert eine erneute Anmeldung aus Sicherheitsgründen.";

    case "operation-not-allowed":
      return "Diese Anmeldemethode ist derzeit nicht verfügbar.";

    case "popup-closed-by-user":
    case "canceled":
    case "cancelled-popup-request":
    case "web-context-cancelled":
      return "Anmeldung wurde abgebrochen.";

    case "account-exists-with-different-credential":
      return "Für diese E-Mail-Adresse existiert bereits ein Konto mit einer anderen Anmeldemethode.";

    default:
      return error.message ?? "Etwas ist schiefgelaufen. Bitte versuche es erneut.";
  }
}

/// True, wenn der Fehler auf einen bewussten Nutzerabbruch (z. B. Google-
/// Anmeldefenster geschlossen) zurückgeht und keine Fehlermeldung braucht.
bool isAuthCancellation(Object error) {
  if (error is! FirebaseAuthException) return false;

  const cancellationCodes = {
    "popup-closed-by-user",
    "canceled",
    "cancelled-popup-request",
    "web-context-cancelled",
  };

  return cancellationCodes.contains(error.code);
}
