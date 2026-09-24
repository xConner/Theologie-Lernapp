import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/services/notifications/app_notification.dart';
import 'package:theologie_lernapp/services/notifications/notification_preferences.dart';
import 'package:theologie_lernapp/services/notifications/notification_read_state.dart';
import 'package:theologie_lernapp/services/notifications/notification_repository.dart';
import 'package:theologie_lernapp/services/notifications/notification_service.dart';
import 'package:theologie_lernapp/widgets/notification_style.dart';

AppNotification note(
  String id,
  DateTime createdAt, {
  NotificationCategory category = NotificationCategory.content,
  NotificationScope scope = NotificationScope.global,
  DateTime? expiresAt,
}) {
  return AppNotification(
    id: id,
    scope: scope,
    category: category,
    title: "Titel $id",
    body: "",
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
}

class FakeRepository implements NotificationRepository {
  final global = StreamController<List<AppNotification>>();
  final personal = StreamController<List<AppNotification>>();
  final readState = StreamController<NotificationReadState>();
  final List<NotificationReadState> saved = [];

  @override
  Stream<List<AppNotification>> watchGlobal() => global.stream;

  @override
  Stream<List<AppNotification>> watchPersonal() => personal.stream;

  @override
  Stream<NotificationReadState> watchReadState() => readState.stream;

  @override
  Future<void> saveReadState(NotificationReadState state) async {
    saved.add(state);
  }
}

void main() {
  final day1 = DateTime.utc(2026, 9, 20, 8);
  final day2 = DateTime.utc(2026, 9, 21, 8);
  final day3 = DateTime.utc(2026, 9, 22, 8);

  group("AppNotification.tryParse", () {
    test("liest gültige Nachricht", () {
      final n = AppNotification.tryParse("a", {
        "category": "content",
        "title": " Neue griechische Vokabeln ",
        "body": "40 neue Vokabeln hinzugefügt.",
        "createdAt": day1,
        "deepLink": "/greek/vocabulary",
        "priority": "high",
        "channels": {"push": true},
      }, scope: NotificationScope.global)!;

      expect(n.title, "Neue griechische Vokabeln");
      expect(n.category, NotificationCategory.content);
      expect(n.priority, NotificationPriority.high);
      expect(n.channels.inApp, isTrue);
      expect(n.channels.push, isTrue);
      expect(n.channels.email, isFalse);
      expect(n.key, "g:a");
    });

    test("verwirft unvollständige oder unbekannte Daten", () {
      AppNotification? parse(Map<String, dynamic> data) =>
          AppNotification.tryParse("x", data, scope: NotificationScope.global);

      expect(parse({"category": "content", "title": "T"}), isNull);
      expect(
        parse({"category": "streak", "title": "T", "createdAt": day1}),
        isNull,
      );
      expect(
        parse({"category": "system", "title": " ", "createdAt": day1}),
        isNull,
      );
    });

    test("Account-Nachrichten nur persönlich", () {
      final data = {"category": "account", "title": "T", "createdAt": day1};

      expect(
        AppNotification.tryParse("x", data, scope: NotificationScope.global),
        isNull,
      );
      expect(
        AppNotification.tryParse("x", data, scope: NotificationScope.personal),
        isNotNull,
      );
    });

    test("Ablauf und inApp-Kanal bestimmen Sichtbarkeit", () {
      final n = note("a", day1, expiresAt: day2);

      expect(n.isVisible(day1), isTrue);
      expect(n.isVisible(day2), isFalse);

      final pushOnly = AppNotification.tryParse("b", {
        "category": "system",
        "title": "T",
        "createdAt": day1,
        "channels": {"inApp": false, "push": true},
      }, scope: NotificationScope.global)!;

      expect(pushOnly.isVisible(day1), isFalse);
    });
  });

  group("NotificationReadState", () {
    test("markAllRead setzt Marke auf neueste angezeigte Nachricht", () {
      final a = note("a", day1);
      final b = note("b", day2);
      final later = note("c", day3);

      final state = NotificationReadState.empty.markRead(a, day2).markAllRead([
        a,
        b,
      ]);

      expect(state.readUpTo, day2);
      expect(state.isRead(a), isTrue);
      expect(state.isRead(b), isTrue);
      expect(state.isRead(later), isFalse);
      // Von der Marke abgedeckte Einzelmarkierung entfernt.
      expect(state.readKeys, isEmpty);
    });

    test("markRead einzeln und Begrenzung der Einzelmarkierungen", () {
      var state = NotificationReadState.empty;

      for (var i = 0; i < NotificationReadState.maxReadKeys + 5; i++) {
        state = state.markRead(
          note("n$i", day1),
          day1.add(Duration(minutes: i)),
        );
      }

      expect(state.readKeys.length, NotificationReadState.maxReadKeys);
      expect(state.readKeys.containsKey("g:n0"), isFalse);
      expect(state.isRead(note("n104", day1)), isTrue);
    });

    test("union übernimmt die jeweils weitere Marke und alle Schlüssel", () {
      final a = NotificationReadState(readUpTo: day1, readKeys: {"g:x": day1});
      final b = NotificationReadState(readUpTo: day2, readKeys: {"u:y": day2});

      final merged = a.union(b);

      expect(merged.readUpTo, day2);
      expect(merged.readKeys.keys, containsAll(["g:x", "u:y"]));
    });

    test("toMap/fromMap", () {
      final state = NotificationReadState(
        readUpTo: day2,
        readKeys: {"u:a": day3},
      );

      final restored = NotificationReadState.fromMap(state.toMap());

      expect(restored.readUpTo, day2);
      expect(restored.readKeys["u:a"], day3);
      expect(NotificationReadState.fromMap("kaputt").readUpTo, isNull);
    });
  });

  group("NotificationService", () {
    late Map<String?, FakeRepository> repos;
    late NotificationService service;

    setUp(() {
      repos = {};
      service = NotificationService(
        repositoryFor: (uid) => repos.putIfAbsent(uid, FakeRepository.new),
        clock: () => day3,
      );
    });

    tearDown(() => service.detach());

    test("zählt ungelesene erst, wenn der Lesestatus geladen ist", () async {
      service.attach("u1");
      final repo = repos["u1"]!;

      repo.global.add([note("a", day1), note("b", day2)]);
      repo.personal.add([
        note(
          "sec",
          day2,
          category: NotificationCategory.account,
          scope: NotificationScope.personal,
        ),
      ]);
      await pumpEventQueue();

      expect(service.unreadCount, 0);
      expect(service.loaded, isFalse);

      repo.readState.add(NotificationReadState(readUpTo: day1));
      await pumpEventQueue();

      expect(service.loaded, isTrue);
      expect(service.notifications.map((n) => n.key).toSet(), {
        "g:a",
        "g:b",
        "u:sec",
      });
      expect(service.notifications.last.key, "g:a");
      expect(service.unreadCount, 2);
    });

    test("abgelaufene Nachrichten erhöhen den Badge nicht", () async {
      service.attach("u1");
      final repo = repos["u1"]!;

      repo.global.add([note("old", day1, expiresAt: day2), note("b", day2)]);
      repo.readState.add(NotificationReadState.empty);
      await pumpEventQueue();

      expect(service.notifications.map((n) => n.id), ["b"]);
      expect(service.unreadCount, 1);
    });

    test("markAllRead speichert und setzt Badge zurück", () async {
      service.attach("u1");
      final repo = repos["u1"]!;

      repo.global.add([note("a", day1), note("b", day2)]);
      repo.readState.add(NotificationReadState.empty);
      await pumpEventQueue();

      await service.markAllRead();

      expect(service.unreadCount, 0);
      expect(repo.saved.single.readUpTo, day2);

      // Älterer Server-Stand setzt den Lesestatus nicht zurück.
      repo.readState.add(NotificationReadState.empty);
      await pumpEventQueue();
      expect(service.unreadCount, 0);

      // Neue Nachricht danach ist ungelesen.
      repo.global.add([note("a", day1), note("b", day2), note("c", day3)]);
      await pumpEventQueue();
      expect(service.unreadCount, 1);
    });

    test("Nutzerwechsel verwirft Ereignisse des alten Nutzers", () async {
      service.attach("u1");
      final old = repos["u1"]!;

      service.attach("u2");
      final current = repos["u2"]!;

      old.global.add([note("fremd", day1)]);
      old.readState.add(NotificationReadState.empty);
      current.global.add([note("eigen", day2)]);
      current.readState.add(NotificationReadState.empty);
      await pumpEventQueue();

      expect(service.notifications.map((n) => n.id), ["eigen"]);
    });

    test("ohne geladenen Lesestatus wird nichts gespeichert", () async {
      service.attach(null);
      final repo = repos[null]!;

      repo.global.add([note("a", day1)]);
      await pumpEventQueue();

      await service.markAllRead();

      expect(repo.saved, isEmpty);
    });
  });

  group("Badge & Datum", () {
    test("Badge-Beschriftung", () {
      expect(notificationBadgeLabel(0), isNull);
      expect(notificationBadgeLabel(1), "1");
      expect(notificationBadgeLabel(9), "9");
      expect(notificationBadgeLabel(10), "9+");
    });

    test("Datumsanzeige", () {
      final now = DateTime(2026, 9, 25, 15); // Freitag

      expect(
        formatNotificationDate(DateTime(2026, 9, 25, 9, 5), now),
        "Heute, 09:05",
      );
      expect(
        formatNotificationDate(DateTime(2026, 9, 24, 18, 30), now),
        "Gestern, 18:30",
      );
      expect(
        formatNotificationDate(DateTime(2026, 9, 22, 12), now),
        "Dienstag",
      );
      expect(
        formatNotificationDate(DateTime(2026, 8, 3, 12), now),
        "03.08.2026",
      );
    });
  });

  group("AppDeepLink.parse", () {
    test("bekannte App-Pfade", () {
      expect(AppDeepLink.parse("/greek/vocabulary")?.path, "/greek/vocabulary");
      expect(AppDeepLink.parse(" /perikopen/ ")?.path, "/perikopen");
      expect(AppDeepLink.parse("/greek/grammar")?.isExternal, isFalse);
    });

    test("unbekannte oder unsichere Links werden abgelehnt", () {
      expect(AppDeepLink.parse(null), isNull);
      expect(AppDeepLink.parse(""), isNull);
      expect(AppDeepLink.parse("/gibt-es-nicht"), isNull);
      expect(AppDeepLink.parse("http://example.org"), isNull);
      expect(AppDeepLink.parse("javascript:alert(1)"), isNull);
    });

    test("https-Links sind extern", () {
      expect(
        AppDeepLink.parse("https://theologie.app/neu")?.isExternal,
        isTrue,
      );
    });
  });

  group("NotificationPreferences", () {
    test("Defaults: Push und E-Mail sind Opt-in", () {
      final prefs = NotificationPreferences.fromMap(null);

      expect(prefs.pushEnabled, isFalse);
      expect(prefs.emailAnnouncements, isFalse);
      expect(prefs.streakReminders, isTrue);
      expect(prefs.systemMessages, isTrue);
      expect(prefs.newContent, isFalse);
    });

    test("toMap/fromMap und ungültige Werte", () {
      const prefs = NotificationPreferences(
        pushEnabled: true,
        newContent: true,
        emailAnnouncements: true,
      );

      expect(NotificationPreferences.fromMap(prefs.toMap()), prefs);

      final broken = NotificationPreferences.fromMap({
        "push": {"enabled": "ja", "streakReminders": false},
        "email": 3,
      });

      expect(broken.pushEnabled, isFalse);
      expect(broken.streakReminders, isFalse);
      expect(broken.emailAnnouncements, isFalse);
    });

    test("keine Einstellungen für Lernerinnerungen", () {
      final keys = <String>{};

      void collect(Map<String, dynamic> map) {
        for (final entry in map.entries) {
          keys.add(entry.key.toLowerCase());
          if (entry.value is Map<String, dynamic>) collect(entry.value);
        }
      }

      collect(NotificationPreferences.defaults.toMap());

      expect(
        keys.any(
          (k) =>
              k.contains("learn") || k.contains("review") || k.contains("due"),
        ),
        isFalse,
      );
    });
  });
}
