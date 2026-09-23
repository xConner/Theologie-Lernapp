import 'package:firebase_app_check/firebase_app_check.dart';

/// Firebase App Check – vorbereitet, aber bewusst NICHT aktiv.
///
/// Diese Klasse wird aktuell aus main.dart NICHT aufgerufen. App Check
/// schützt Firestore/Auth-Backends vor Missbrauch durch nicht-echte Clients,
/// braucht dafür aber echte Site-Keys aus der Firebase Console:
///   - Web: reCAPTCHA v3 (oder Enterprise) Site-Key
///   - Android: Play Integrity (kein Setup nötig, aber App muss in der
///     Console für Play Integrity registriert sein)
///   - iOS: App Attest / DeviceCheck
///
/// Ohne diese Schritte UND ohne dass "Enforce" in der Console aktiviert ist,
/// hat das Aufrufen von [activate] keine schädliche Wirkung (App Check ist
/// erst dann verpflichtend, wenn die Regeln/Backends es explizit verlangen).
/// Sobald echte Keys vorhanden sind: den TODO-Platzhalter unten ersetzen und
/// `await AppCheckService.activate();` in main.dart nach Firebase.initializeApp
/// aufrufen.
class AppCheckService {
  AppCheckService._();

  static Future<void> activate() async {
    await FirebaseAppCheck.instance.activate(
      // TODO: echten reCAPTCHA v3 Site-Key aus der Firebase Console eintragen.
      providerWeb: ReCaptchaV3Provider(
        '6LeKmMstAAAAAL_0WLhnGsVgtoNLvXz1WhC9uBQ-',
      ),
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestProvider(),
    );
  }
}
