import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/notification_settings_screen.dart';
import 'package:theologie_lernapp/services/notifications/notification_preferences.dart';
import 'package:theologie_lernapp/services/notifications/push_platform.dart';
import 'package:theologie_lernapp/services/notifications/push_service.dart';
import 'package:theologie_lernapp/services/notifications/push_token_registry.dart';

const subscriptionA = PushSubscriptionInfo(
  endpoint: "https://fcm.googleapis.com/fcm/send/a",
  p256dh: "key-a",
  auth: "auth-a",
);

const subscriptionB = PushSubscriptionInfo(
  endpoint: "https://fcm.googleapis.com/fcm/send/b",
  p256dh: "key-b",
  auth: "auth-b",
);

class FakePlatform implements PushPlatform {
  @override
  PushSupport support = PushSupport.supported;

  @override
  PushPermission permission = PushPermission.notAsked;

  @override
  PushDevice device = PushDevice.desktop;

  @override
  String? timeZone = "Europe/Berlin";

  /// Antwort des Nutzers auf die Berechtigungsabfrage.
  PushPermission answer = PushPermission.granted;

  PushSubscriptionInfo? subscription;
  PushSubscriptionInfo next = subscriptionA;

  int permissionRequests = 0;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    return permission = answer;
  }

  @override
  Future<PushSubscriptionInfo?> currentSubscription(String publicKey) async {
    return permission == PushPermission.granted ? subscription : null;
  }

  @override
  Future<PushSubscriptionInfo> subscribe(String publicKey) async {
    return subscription = next;
  }

  @override
  Future<void> unsubscribe() async => subscription = null;

  @override
  String? takeLaunchLink() => null;

  @override
  Stream<String> get links => const Stream.empty();
}

class FakeRegistry extends PushTokenRegistry {
  /// uid → Abonnement-ID → Adresse.
  final Map<String, Map<String, String>> devices = {};

  int writes = 0;

  @override
  Future<void> register(
    String uid,
    PushSubscriptionInfo subscription, {
    required String platform,
  }) async {
    writes++;
    devices.putIfAbsent(uid, () => {})[subscription.id] = subscription.endpoint;
  }

  @override
  Future<void> unregister(String uid, String id) async {
    devices[uid]?.remove(id);
  }

  @override
  Future<bool> hasDevices(String uid) async {
    return devices[uid]?.isNotEmpty ?? false;
  }
}

class FakePreferences extends NotificationPreferencesService {
  NotificationPreferences stored;

  final List<NotificationPreferences> saved = [];

  FakePreferences([this.stored = NotificationPreferences.defaults]);

  @override
  Future<NotificationPreferences> load(String uid) async => stored;

  @override
  Future<void> save(String uid, NotificationPreferences preferences) async {
    stored = preferences;
    saved.add(preferences);
  }
}

void main() {
  late FakePlatform platform;
  late FakeRegistry registry;
  late FakePreferences preferences;
  late DateTime now;

  PushService service({String publicKey = "server-key"}) {
    return PushService(
      platform: platform,
      registry: registry,
      preferences: preferences,
      publicKey: publicKey,
      clock: () => now,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    platform = FakePlatform();
    registry = FakeRegistry();
    preferences = FakePreferences();
    now = DateTime(2026, 10, 10, 12);
  });

  group("PushService", () {
    test("Zustand je Gerät", () async {
      expect(await service().deviceState("u1"), PushDeviceState.off);

      expect(
        await service(publicKey: " ").deviceState("u1"),
        PushDeviceState.notConfigured,
      );

      platform.permission = PushPermission.denied;
      expect(await service().deviceState("u1"), PushDeviceState.blocked);

      platform.support = PushSupport.needsHomeScreen;
      expect(
        await service().deviceState("u1"),
        PushDeviceState.needsHomeScreen,
      );

      platform.support = PushSupport.unsupported;
      expect(await service().deviceState("u1"), PushDeviceState.unsupported);

      // Nichts davon hat nach einer Berechtigung gefragt.
      expect(platform.permissionRequests, 0);
    });

    test(
      "Einschalten fragt die Berechtigung an und meldet das Gerät an",
      () async {
        final push = service();

        expect(await push.enable("u1"), PushDeviceState.on);

        expect(platform.permissionRequests, 1);
        expect(registry.devices["u1"], {"key-a": subscriptionA.endpoint});
        expect(await push.deviceState("u1"), PushDeviceState.on);

        // Für ein anderes Konto gilt das Abonnement nicht.
        expect(await push.deviceState("u2"), PushDeviceState.off);
      },
    );

    test("abgelehnte Berechtigung meldet nichts an", () async {
      platform.answer = PushPermission.denied;

      expect(await service().enable("u1"), PushDeviceState.blocked);
      expect(registry.devices, isEmpty);
      expect(platform.subscription, isNull);
    });

    test("ohne Unterstützung wird nie gefragt", () async {
      platform.support = PushSupport.needsHomeScreen;

      expect(await service().enable("u1"), PushDeviceState.needsHomeScreen);
      expect(platform.permissionRequests, 0);
    });

    test("Ausschalten beendet das Abonnement; andere Geräte bleiben", () async {
      final push = service();

      await push.enable("u1");
      registry.devices["u1"]!["anderes-geraet"] = "https://example.org";

      expect(await push.disable("u1"), isTrue);
      expect(platform.subscription, isNull);
      expect(registry.devices["u1"], {"anderes-geraet": "https://example.org"});

      registry.devices["u1"]!.clear();
      await push.enable("u1");

      expect(await push.disable("u1"), isFalse);
    });

    test("Abmelden entfernt das Gerät des Kontos", () async {
      final push = service();

      await push.enable("u1");
      await push.signOut("u1");

      expect(registry.devices["u1"], isEmpty);
      expect(platform.subscription, isNull);

      // Gäste und Geräte ohne Push: nichts zu tun, kein Fehler.
      await push.signOut(null);
    });

    test("Start: entzogene Berechtigung räumt das Gerät ab", () async {
      final push = service();

      await push.enable("u1");
      platform.permission = PushPermission.denied;

      await push.sync("u1");

      expect(registry.devices["u1"], isEmpty);
      expect(await push.deviceState("u1"), PushDeviceState.blocked);
      expect(platform.permissionRequests, 1, reason: "sync fragt nie nach");
    });

    test("Start: erneuertes Abonnement ersetzt das alte", () async {
      final push = service();

      await push.enable("u1");
      platform.subscription = subscriptionB;

      await push.sync("u1");

      expect(registry.devices["u1"], {"key-b": subscriptionB.endpoint});
      expect(await push.deviceState("u1"), PushDeviceState.on);
    });

    test("Start: fremdes Abonnement wird nicht übernommen", () async {
      final push = service();

      await push.enable("u1");
      await push.sync("u2");

      expect(platform.subscription, isNull);
      expect(registry.devices["u1"], isEmpty);
      expect(registry.devices["u2"], isNull);
    });

    test("Start: Abonnement wird nur selten aufgefrischt", () async {
      final push = service();

      await push.enable("u1");
      expect(registry.writes, 1);

      now = DateTime(2026, 10, 12, 12);
      await push.sync("u1");
      expect(registry.writes, 1);

      now = DateTime(2026, 10, 18, 12);
      await push.sync("u1");
      expect(registry.writes, 2);
    });

    test("Start: neue Zeitzone speichert die Einstellungen neu", () async {
      preferences.stored = const NotificationPreferences(pushEnabled: true);

      final push = service();

      await push.enable("u1");
      await push.sync("u1");
      expect(preferences.saved, hasLength(1));

      await push.sync("u1");
      expect(preferences.saved, hasLength(1), reason: "Zeitzone unverändert");

      platform.timeZone = "America/New_York";
      await push.sync("u1");
      expect(preferences.saved, hasLength(2));
    });
  });

  group("Einstellungen", () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            uid: "u1",
            service: preferences,
            push: service(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    SwitchListTile tile(WidgetTester tester, String title) {
      return tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, title),
      );
    }

    testWidgets("öffnen fragt nicht nach der Berechtigung", (tester) async {
      await open(tester);

      expect(platform.permissionRequests, 0);
      expect(tile(tester, "Push auf diesem Gerät").value, isFalse);
      expect(tile(tester, "Bibellese").onChanged, isNull);
    });

    testWidgets("einschalten, Kategorie und Ausschalten", (tester) async {
      await open(tester);

      await tester.tap(find.text("Push auf diesem Gerät"));
      await tester.pumpAndSettle();

      expect(platform.permissionRequests, 1);
      expect(preferences.stored.pushEnabled, isTrue);
      expect(tile(tester, "Push auf diesem Gerät").value, isTrue);
      expect(find.text("Testbenachrichtigung senden"), findsOneWidget);

      await tester.tap(find.text("Bibelleseplan"));
      await tester.pumpAndSettle();

      expect(preferences.stored.readingPlan, isFalse);
      expect(preferences.stored.bibleReading, isTrue);

      await tester.tap(find.text("Push auf diesem Gerät"));
      await tester.pumpAndSettle();

      expect(preferences.stored.pushEnabled, isFalse);
      expect(registry.devices["u1"], isEmpty);
    });

    testWidgets("abgelehnte Berechtigung lässt Push aus", (tester) async {
      platform.answer = PushPermission.denied;

      await open(tester);

      await tester.tap(find.text("Push auf diesem Gerät"));
      await tester.pumpAndSettle();

      expect(preferences.stored.pushEnabled, isFalse);
      expect(tile(tester, "Push auf diesem Gerät").onChanged, isNull);
      expect(find.textContaining("gesperrt"), findsOneWidget);
      expect(find.text("Berechtigung verwalten"), findsOneWidget);
    });

    testWidgets("iPhone ohne Home-Bildschirm: Hinweis statt Schalter", (
      tester,
    ) async {
      platform.support = PushSupport.needsHomeScreen;

      await open(tester);

      expect(find.textContaining("Zum Home-Bildschirm"), findsOneWidget);
      expect(tile(tester, "Push auf diesem Gerät").onChanged, isNull);
    });

    testWidgets("nicht unterstützter Browser", (tester) async {
      platform.support = PushSupport.unsupported;

      await open(tester);

      expect(
        find.textContaining("unterstützt keine Push-Benachrichtigungen"),
        findsOneWidget,
      );
      expect(find.text("Berechtigung verwalten"), findsNothing);
    });
  });
}
