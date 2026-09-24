import 'package:flutter/foundation.dart';
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

    case "invalid-phone-number":
      return "Diese Telefonnummer ist ungültig. Bitte im Format +49... eingeben.";

    case "missing-phone-number":
      return "Bitte gib eine Telefonnummer ein.";

    case "invalid-verification-code":
      return "Der eingegebene Code ist falsch.";

    case "invalid-verification-id":
    case "missing-verification-id":
    case "missing-verification-code":
      return "Die Code-Anfrage ist abgelaufen. Bitte fordere einen neuen Code an.";

    case "code-expired":
      return "Der Code ist abgelaufen. Bitte fordere einen neuen Code an.";

    case "quota-exceeded":
      return "Das SMS-Kontingent ist derzeit ausgeschöpft. Bitte versuche es später erneut.";

    case "captcha-check-failed":
      return "Die Sicherheitsprüfung ist fehlgeschlagen. Bitte lade die Seite neu und versuche es erneut.";

    case "recaptcha-timeout":
      return "Die Telefonbestätigung konnte nicht gestartet werden. Bitte versuche es in einem anderen Browser (z. B. Chrome, Firefox oder Safari).";

    case "totp-challenge-timeout":
      return "Die Einrichtung ist abgelaufen. Bitte starte die Einrichtung der Authenticator-App erneut.";

    case "unverified-email":
      return "Bitte bestätige zuerst deine E-Mail-Adresse, bevor du die Zwei-Faktor-Authentifizierung einrichtest.";

    case "second-factor-already-in-use":
      return "Diese Telefonnummer ist bereits als zweiter Faktor hinterlegt.";

    case "maximum-second-factor-count-exceeded":
      return "Es sind bereits die maximal zulässigen Faktoren hinterlegt.";

    case "unsupported-first-factor":
      return "Für diese Anmeldemethode ist keine Zwei-Faktor-Authentifizierung möglich.";

    case "multi-factor-auth-required":
      return "Für dieses Konto ist eine Zwei-Faktor-Bestätigung erforderlich.";

    default:
      return error.message ?? "Etwas ist schiefgelaufen. Bitte versuche es erneut.";
  }
}

/// Nur zur Diagnose (Phone-Auth/MFA-Fehleranalyse): loggt den vollständigen
/// FirebaseAuthException.code + message in die Browser-/Debug-Konsole und
/// gibt einen kurzen Diagnosetext zurück, der zusätzlich in der UI angezeigt
/// werden kann, solange wir die reCAPTCHA-Fehlerursache eingrenzen.
/// Verändert keine reCAPTCHA-/App-Check-Konfiguration.
String logAndDescribeAuthErrorForDiagnosis(Object error, {String? context}) {
  final label = context != null ? "[$context] " : "";

  if (error is FirebaseAuthException) {
    debugPrint(
      "${label}FirebaseAuthException: code='${error.code}' "
      "message='${error.message}'",
    );
    return "${describeAuthError(error)}\n\n(Debug: code=${error.code})";
  }

  debugPrint("${label}Nicht-Firebase-Fehler: ${error.runtimeType}: $error");
  return "Etwas ist schiefgelaufen. Bitte versuche es erneut.\n\n"
      "(Debug: ${error.runtimeType})";
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
