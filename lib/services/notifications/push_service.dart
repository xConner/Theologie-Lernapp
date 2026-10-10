import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_preferences.dart';
import 'push_platform.dart';
import 'push_token_registry.dart';

/// Zustand von Push auf diesem Gerät (für die Einstellungen).
enum PushDeviceState {
  /// In diesem Build ist kein öffentlicher Schlüssel hinterlegt.
  notConfigured,
  unsupported,
  needsHomeScreen,

  /// Der Nutzer hat Benachrichtigungen im Browser/System abgelehnt.
  blocked,
  off,
  on,
}

/// Push-Benachrichtigungen auf diesem Gerät: Berechtigung, Abonnement beim
/// Push-Dienst des Browsers und dessen Anmeldung im Konto
/// (`PushTokenRegistry`). Was wann gesendet wird, entscheidet allein der
/// Server anhand der `NotificationPreferences` (siehe docs/notifications.md).
///
/// Nichts hiervon ist für die Lernfunktionen nötig: Fehler werden
/// abgefangen und führen nur dazu, dass Push aus bleibt.
class PushService {
  PushService({
    PushPlatform? platform,
    PushTokenRegistry? registry,
    NotificationPreferencesService? preferences,
    String publicKey = defaultPublicKey,
    DateTime Function()? clock,
  }) : _platform = platform ?? PushPlatform(),
       _registry = registry ?? PushTokenRegistry(),
       _preferences = preferences ?? NotificationPreferencesService(),
       _publicKey = publicKey.trim(),
       _clock = clock ?? DateTime.now;

  static final PushService instance = PushService();

  /// Öffentlicher VAPID-Schlüssel des Servers (kein Geheimnis; der private
  /// Schlüssel liegt nur in den Umgebungsvariablen des Servers). Beim Build
  /// mit `--dart-define=WEB_PUSH_PUBLIC_KEY=…` setzen oder hier eintragen.
  static const String defaultPublicKey = String.fromEnvironment(
    "WEB_PUSH_PUBLIC_KEY",
    defaultValue:
        "BD8wJX_IoQBouXGAd1WEaY_Yib_f85Cq5VgDxI5UvqP9P1oZkfiMoVL89AeGmYVIrtf0_4yRGk3H2euVhlBTvjs",
  );

  /// Dieses Gerät: `<uid>|<Abonnement-ID>|<Tag der letzten Anmeldung>`.
  static const String _deviceKey = "push.v1.device";

  /// Zuletzt gespeicherte Zeitzone: `<uid>|<Zeitzone>|<UTC-Abstand>`.
  static const String _zoneKey = "push.v1.zone";

  /// Nach so vielen Tagen wird das Abonnement im Konto aufgefrischt.
  static const int _refreshAfterDays = 7;

  static const Duration _timeout = Duration(seconds: 4);

  final PushPlatform _platform;
  final PushTokenRegistry _registry;
  final NotificationPreferencesService _preferences;
  final String _publicKey;
  final DateTime Function() _clock;

  PushDevice get device => _platform.device;

  bool get isBrave => _platform.isBrave;

  Stream<String> get links => _platform.links;

  String? takeLaunchLink() => _platform.takeLaunchLink();

  bool get _available {
    return _publicKey.isNotEmpty && _platform.support == PushSupport.supported;
  }

  String get _today => _clock().toIso8601String().substring(0, 10);

  String get _zone {
    return "${_platform.timeZone}|${_clock().timeZoneOffset.inMinutes}";
  }

  Future<PushDeviceState> deviceState(String uid) async {
    switch (_platform.support) {
      case PushSupport.needsHomeScreen:
        return PushDeviceState.needsHomeScreen;
      case PushSupport.unsupported:
        return PushDeviceState.unsupported;
      case PushSupport.supported:
        break;
    }

    if (_publicKey.isEmpty) return PushDeviceState.notConfigured;

    if (_platform.permission == PushPermission.denied) {
      return PushDeviceState.blocked;
    }

    try {
      final subscription = await _platform.currentSubscription(_publicKey);
      final device = await _device();

      return subscription != null &&
              device?.uid == uid &&
              device?.id == subscription.id
          ? PushDeviceState.on
          : PushDeviceState.off;
    } catch (_) {
      return PushDeviceState.off;
    }
  }

  /// Schaltet Push auf diesem Gerät ein: fragt – erst jetzt – die
  /// Berechtigung an, abonniert und meldet das Abonnement im Konto an.
  /// Muss direkt aus einer Nutzeraktion heraus aufgerufen werden.
  Future<PushDeviceState> enable(String uid) async {
    if (!_available) return deviceState(uid);

    // Zuerst und ohne vorheriges Warten: Browser erlauben die Abfrage nur
    // als unmittelbare Folge eines Klicks.
    final permission = await _platform.requestPermission();

    if (permission != PushPermission.granted) {
      return permission == PushPermission.denied
          ? PushDeviceState.blocked
          : PushDeviceState.off;
    }

    final subscription = await _platform.subscribe(_publicKey);

    await _register(uid, subscription);

    return PushDeviceState.on;
  }

  /// Schaltet Push auf diesem Gerät aus. Liefert, ob das Konto danach noch
  /// andere Geräte mit Push hat.
  Future<bool> disable(String uid) async {
    await _forget(uid);

    try {
      return await _registry.hasDevices(uid).timeout(_timeout);
    } catch (_) {
      return false;
    }
  }

  /// Vor dem Abmelden bzw. nach dem Löschen des Kontos: Dieses Gerät
  /// bekommt keine Nachrichten des Kontos mehr. Hält das Abmelden nie auf.
  Future<void> signOut(String? uid) async {
    if (uid == null || !_available) return;

    try {
      await _forget(uid);
    } catch (e) {
      debugPrint("Push konnte nicht abgemeldet werden: $e");
    }
  }

  /// Beim Start der App: hält Abonnement und Zeitzone des Kontos aktuell
  /// und räumt auf, wenn die Berechtigung entzogen wurde. Fragt nie nach
  /// einer Berechtigung.
  Future<void> sync(String uid) async {
    if (!_available) return;

    try {
      final device = await _device();
      final subscription = await _platform.currentSubscription(_publicKey);

      if (subscription == null) {
        // Berechtigung entzogen oder Abonnement verloren.
        if (device != null) await _forget(device.uid);
        return;
      }

      if (device == null || device.uid != uid) {
        // Abonnement eines anderen Kontos (z. B. Abmelden ohne Verbindung):
        // nicht stillschweigend übernehmen.
        await _forget(device?.uid);
        return;
      }

      if (device.id != subscription.id) {
        await _registry.unregister(uid, device.id);
        await _register(uid, subscription);
      } else if (_daysSince(device.day) >= _refreshAfterDays) {
        await _register(uid, subscription);
      }

      await _syncZone(uid);
    } catch (e) {
      debugPrint("Push konnte nicht abgeglichen werden: $e");
    }
  }

  /// Lässt den Server eine Testbenachrichtigung an die Geräte des Kontos
  /// senden. Liefert die Zahl der erreichten Geräte, null bei einem Fehler.
  Future<int?> sendTest() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      if (token == null) return null;

      final response = await http
          .post(
            Uri.base.resolve("api/push-test"),
            headers: {"Authorization": "Bearer $token"},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final sent = (jsonDecode(response.body) as Map)["sent"];

      return sent is int ? sent : null;
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // INTERN
  // ==========================

  Future<void> _register(String uid, PushSubscriptionInfo subscription) async {
    await _registry.register(
      uid,
      subscription,
      platform: _platform.device.name,
    );

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_deviceKey, "$uid|${subscription.id}|$_today");
  }

  /// Beendet das Abonnement dieses Browsers und meldet es im Konto ab.
  Future<void> _forget(String? uid) async {
    final device = await _device();
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_deviceKey);
    await prefs.remove(_zoneKey);

    // Das Abonnement selbst zu beenden wirkt auch ohne Verbindung: Der
    // Server erfährt beim nächsten Versand, dass es nicht mehr gilt.
    try {
      await _platform.unsubscribe().timeout(_timeout);
    } catch (e) {
      debugPrint("Push-Abonnement konnte nicht beendet werden: $e");
    }

    if (uid != null && device != null && device.uid == uid) {
      try {
        await _registry.unregister(uid, device.id).timeout(_timeout);
      } catch (e) {
        debugPrint("Push-Abonnement konnte nicht abgemeldet werden: $e");
      }
    }
  }

  /// Nach einer Reise oder Zeitumstellung: Zeitzone und nächsten
  /// Erinnerungszeitpunkt neu speichern.
  Future<void> _syncZone(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final current = "$uid|$_zone";

    if (prefs.getString(_zoneKey) == current) return;

    final preferences = await _preferences.load(uid);

    if (preferences.pushEnabled) await _preferences.save(uid, preferences);

    await prefs.setString(_zoneKey, current);
  }

  Future<({String uid, String id, String day})?> _device() async {
    final prefs = await SharedPreferences.getInstance();
    final parts = prefs.getString(_deviceKey)?.split("|");

    if (parts == null || parts.length != 3) return null;

    return (uid: parts[0], id: parts[1], day: parts[2]);
  }

  int _daysSince(String day) {
    final then = DateTime.tryParse(day);

    return then == null ? _refreshAfterDays : _clock().difference(then).inDays;
  }
}
