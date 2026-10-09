import 'push_platform_stub.dart'
    if (dart.library.js_interop) 'push_platform_web.dart'
    as implementation;

/// Kann dieses Gerät Push-Benachrichtigungen empfangen?
enum PushSupport {
  supported,

  /// iPhone/iPad im Browser: Web-Push gibt es dort nur für Web-Apps, die
  /// zum Home-Bildschirm hinzugefügt wurden (ab iOS/iPadOS 16.4).
  needsHomeScreen,

  unsupported,
}

/// Berechtigung des Browsers bzw. Systems für Benachrichtigungen.
enum PushPermission { notAsked, granted, denied }

/// Geräteart, nur für die Hinweise zur Verwaltung der Berechtigung.
enum PushDevice { ios, android, desktop }

/// Push-Abonnement dieses Browsers (Web Push): Adresse beim Push-Dienst des
/// Browserherstellers und die Schlüssel, mit denen der Server Nachrichten
/// für genau dieses Gerät verschlüsselt.
class PushSubscriptionInfo {
  final String endpoint;
  final String p256dh;
  final String auth;

  const PushSubscriptionInfo({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  /// Dokument-ID unter `users/{uid}/push_tokens`: der öffentliche Schlüssel
  /// des Abonnements (base64url, je Abonnement eindeutig).
  String get id => p256dh;
}

/// Zugriff auf die Push-Funktionen der Plattform. Im Browser über die
/// Web-APIs; überall sonst gibt es (noch) keinen Push.
abstract class PushPlatform {
  factory PushPlatform() = implementation.PlatformPush;

  PushSupport get support;

  PushPermission get permission;

  PushDevice get device;

  /// IANA-Zeitzone des Geräts, z. B. "Europe/Berlin".
  String? get timeZone;

  /// Fragt die Berechtigung an. Muss direkt aus einer Nutzeraktion heraus
  /// aufgerufen werden.
  Future<PushPermission> requestPermission();

  /// Das bestehende Abonnement dieses Browsers für [publicKey], falls es
  /// eines gibt.
  Future<PushSubscriptionInfo?> currentSubscription(String publicKey);

  /// Registriert den Service Worker und abonniert Push mit dem öffentlichen
  /// VAPID-Schlüssel [publicKey].
  Future<PushSubscriptionInfo> subscribe(String publicKey);

  Future<void> unsubscribe();

  /// Link, mit dem die App aus einer Benachrichtigung gestartet wurde
  /// (`?open=…`); wird dabei aus der Adresse entfernt.
  String? takeLaunchLink();

  /// Links aus Benachrichtigungen, die bei laufender App angetippt wurden.
  Stream<String> get links;
}
