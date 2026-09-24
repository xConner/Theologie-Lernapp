import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_notification.dart';
import 'notification_read_state.dart';
import 'notification_repository.dart';

/// Zustand der In-App-Glocke für den aktuellen Nutzer (uid, null = Gast).
///
/// Die Glocke zeigt ausschließlich veröffentlichte Nachrichten (neue
/// Inhalte, System, Account, Mitteilungen). Lernstatus, Streaks und
/// Tagesziele fließen hier bewusst NICHT ein und erhöhen den Badge nie.
///
/// Nachrichten und Lesestatus werden live aus Firestore gelesen (inkl.
/// Offline-Cache). Beim Nutzerwechsel werden alle Abos beendet; Ereignisse
/// eines alten Abos werden verworfen, damit nie Nachrichten eines anderen
/// Nutzers erscheinen.
class NotificationService extends ChangeNotifier {
  NotificationService({
    NotificationRepository Function(String? uid)? repositoryFor,
    DateTime Function()? clock,
  }) : _repositoryFor = repositoryFor ?? NotificationRepository.forUser,
       _clock = clock ?? DateTime.now;

  static final NotificationService instance = NotificationService();

  final NotificationRepository Function(String? uid) _repositoryFor;
  final DateTime Function() _clock;

  bool _attached = false;
  String? _uid;
  NotificationRepository? _repository;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  List<AppNotification> _global = const [];
  List<AppNotification> _personal = const [];
  NotificationReadState _readState = NotificationReadState.empty;

  bool _globalLoaded = false;
  bool _readStateLoaded = false;

  Future<void> _saveQueue = Future.value();

  /// Sind Nachrichten und Lesestatus mindestens einmal geladen?
  bool get loaded => _globalLoaded && _readStateLoaded;

  /// Sichtbare Nachrichten (nicht abgelaufen), neueste zuerst.
  List<AppNotification> get notifications {
    final now = _clock();

    return [
      ..._global.where((n) => n.isVisible(now)),
      ..._personal.where((n) => n.isVisible(now)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Ungelesene sichtbare Nachrichten; 0, solange der Lesestatus nicht
  /// geladen ist (kein kurzes Aufblinken des Badges beim Start).
  int get unreadCount {
    if (!_readStateLoaded) return 0;

    return notifications.where((n) => !_readState.isRead(n)).length;
  }

  bool isRead(AppNotification notification) {
    return _readState.isRead(notification);
  }

  /// Beginnt, die Nachrichten für [uid] (null = Gast) zu beobachten. Ohne
  /// Wirkung, wenn bereits für diesen Nutzer aktiv.
  void attach(String? uid) {
    if (_attached && _uid == uid) return;

    _cancelSubscriptions();

    _attached = true;
    _uid = uid;
    _global = const [];
    _personal = const [];
    _readState = NotificationReadState.empty;
    _globalLoaded = false;
    _readStateLoaded = false;

    final repository = _repositoryFor(uid);
    _repository = repository;

    bool current() => identical(_repository, repository);

    _subscriptions.add(
      repository.watchGlobal().listen(
        (items) {
          if (!current()) return;
          _global = items;
          _globalLoaded = true;
          notifyListeners();
        },
        onError: (Object e) {
          if (!current()) return;
          debugPrint("Nachrichten konnten nicht geladen werden: $e");
          _globalLoaded = true;
          notifyListeners();
        },
      ),
    );

    _subscriptions.add(
      repository.watchPersonal().listen(
        (items) {
          if (!current()) return;
          _personal = items;
          notifyListeners();
        },
        onError: (Object e) {
          if (!current()) return;
          debugPrint("Persönliche Nachrichten nicht ladbar: $e");
        },
      ),
    );

    _subscriptions.add(
      repository.watchReadState().listen(
        (remote) {
          if (!current()) return;
          // Lesestatus wächst nur: lokale, noch nicht bestätigte
          // Markierungen gehen durch einen älteren Server-Stand nicht
          // verloren; Markierungen anderer Geräte werden übernommen.
          _readState = _readState.union(remote);
          _readStateLoaded = true;
          notifyListeners();
        },
        onError: (Object e) {
          if (!current()) return;
          debugPrint("Lesestatus konnte nicht geladen werden: $e");
          _readStateLoaded = true;
          notifyListeners();
        },
      ),
    );

    // Kein notifyListeners() hier: attach() wird aus initState aufgerufen;
    // neue Zuhörer lesen den (zurückgesetzten) Stand beim Aufbau.
  }

  /// Beendet die Beobachtung (z. B. für Tests).
  void detach() {
    _cancelSubscriptions();
    _attached = false;
    _repository = null;
  }

  /// Markiert alle aktuell sichtbaren Nachrichten als gelesen (beim Öffnen
  /// der Glocke).
  Future<void> markAllRead() {
    return _update(_readState.markAllRead(notifications));
  }

  /// Markiert eine einzelne Nachricht als gelesen (z. B. Öffnen über einen
  /// Deep Link außerhalb der Glocke).
  Future<void> markRead(AppNotification notification) {
    return _update(_readState.markRead(notification, _clock()));
  }

  Future<void> _update(NotificationReadState next) {
    final repository = _repository;

    if (repository == null ||
        !_readStateLoaded ||
        identical(next, _readState)) {
      return Future.value();
    }

    _readState = next;
    notifyListeners();

    // Speichervorgänge nacheinander; jeweils den dann aktuellen Stand
    // schreiben, damit ein älterer Stand nie einen neueren überschreibt.
    final result = _saveQueue.then((_) async {
      if (!identical(_repository, repository)) return;

      try {
        await repository.saveReadState(_readState);
      } catch (e) {
        debugPrint("Lesestatus konnte nicht gespeichert werden: $e");
      }
    });

    _saveQueue = result;

    return result;
  }

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    _subscriptions.clear();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
