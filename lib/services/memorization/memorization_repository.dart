import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/memorization/memorization_card.dart';
import '../learning_service.dart';
import '../local_learning_store.dart';

/// Lernstände, „Meine Texte“ und Favoriten von „Texte auswendig lernen“ für
/// einen Nutzer.
///
/// Speicherung wie bei den Trainern: angemeldet in Firestore
/// (`users/{uid}/memorization` und das Feld `memorization_settings`, damit
/// auf allen Geräten des Kontos gleich),
/// als Gast (`uid == null`) lokal über [LocalLearningStore].
///
/// Die Daten werden je Instanz einmal geladen und danach im Speicher
/// geführt; die Screens einer Sitzung teilen sich eine Instanz. Geschrieben
/// wird nur, was sich geändert hat.
///
/// Favoriten werden auch in den Menüs Gebete und Bekenntnisse gesetzt, die
/// eigene Instanzen haben. Damit alle Ansichten denselben Stand zeigen (und
/// keine ältere Instanz beim Speichern neuere Einstellungen überschreibt),
/// übernehmen alle geladenen Instanzen desselben Nutzers jede gespeicherte
/// Änderung von „Meine Texte“, Pausen und Favoriten sofort.
class MemorizationRepository extends ChangeNotifier {
  final String? uid;

  final LearningService _learning;

  MemorizationRepository(this.uid, {LearningService? learning})
    : _learning = learning ?? LearningService() {
    _instances.add(WeakReference(this));
  }

  static final List<WeakReference<MemorizationRepository>> _instances = [];

  /// Für Widget-Tests: ersetzt [forCurrentUser].
  @visibleForTesting
  static MemorizationRepository? debugOverride;

  /// Neue Instanz für den angemeldeten Nutzer bzw. den Gast.
  factory MemorizationRepository.forCurrentUser() {
    return debugOverride ??
        MemorizationRepository(FirebaseAuth.instance.currentUser?.uid);
  }

  static const String _group = "memorization_settings";

  // Getter statt Feld: Im Gastmodus (und in Tests) wird Firestore nie berührt.
  DocumentReference<Map<String, dynamic>> get _userDoc {
    return FirebaseFirestore.instance.collection("users").doc(uid);
  }

  /// Lernstand je Abschnitts-ID; fehlende Einträge sind neue Abschnitte.
  Map<String, MemorizationCard> cards = {};

  final List<String> _texts = [];
  final Set<String> _paused = {};
  final List<String> _favorites = [];

  bool _loaded = false;

  Future<void>? _loading;

  bool get isLoaded => _loaded;

  /// IDs der Texte in „Meine Texte“, in der Reihenfolge des Hinzufügens.
  List<String> get textIds => List.unmodifiable(_texts);

  bool contains(String textId) => _texts.contains(textId);

  /// Nur aktive Texte nehmen an der automatischen Wiederholung teil.
  bool isActive(String textId) =>
      _texts.contains(textId) && !_paused.contains(textId);

  /// IDs der Favoriten in der Reihenfolge des Markierens: Werk-IDs
  /// (z. B. `prayer.vaterunser`) oder ganze Bekenntnisschriften
  /// (`confession.augsburger_konfession`), siehe `FavoriteIds`.
  List<String> get favoriteIds => List.unmodifiable(_favorites);

  bool isFavorite(String workId) => _favorites.contains(workId);

  /// Lädt Lernstände und Textauswahl (je ein Lesezugriff). Mehrfache
  /// Aufrufe teilen sich denselben Ladevorgang; nach einem Fehler kann
  /// erneut geladen werden.
  Future<void> load() {
    return _loading ??= _load().catchError((Object error) {
      _loading = null;
      throw error;
    });
  }

  Future<void> _load() async {
    // Beide Lesezugriffe laufen gleichzeitig.
    final cardsFuture = _learning.loadMemorizationCards(uid);
    final settingsFuture = _loadSettings();

    final loaded = await cardsFuture;
    final settings = await settingsFuture;

    cards = loaded;

    _texts
      ..clear()
      ..addAll(_strings(settings["texts"]));
    _paused
      ..clear()
      ..addAll(_strings(settings["paused"]));
    // Doppelte Einträge (z. B. aus einem älteren Stand) nur einmal führen.
    _favorites
      ..clear()
      ..addAll(_strings(settings["favorites"]).toSet());

    _loaded = true;

    notifyListeners();
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    if (uid == null) {
      return LocalLearningStore.instance.loadSettingsGroup(_group);
    }

    final data = (await _userDoc.get()).data();
    final group = data?[_group];

    return group is Map ? Map<String, dynamic>.from(group) : {};
  }

  static List<String> _strings(Object? value) {
    return value is List ? value.whereType<String>().toList() : [];
  }

  // ==========================
  // LERNSTÄNDE
  // ==========================

  // Speichervorgänge nacheinander ausführen: Der lokale Speicher liest,
  // ändert und schreibt die gesamte Collection.
  Future<void> _pending = Future.value();

  /// Speichert geänderte Karten (ein Schreibvorgang je Übung).
  Future<void> saveCards(List<MemorizationCard> changed) {
    if (changed.isEmpty) {
      return Future.value();
    }

    for (final card in changed) {
      cards[card.id] = card;
    }

    notifyListeners();

    final result = _pending.then(
      (_) => _learning.saveMemorizationCards(uid, changed),
    );

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }

  // ==========================
  // MEINE TEXTE
  // ==========================

  Future<void> addText(String textId) async {
    if (_texts.contains(textId)) return;

    _texts.add(textId);

    await _saveSettings();
  }

  /// Entfernt den Text aus „Meine Texte“. Der Lernstand bleibt erhalten,
  /// falls der Text später wieder aufgenommen wird.
  Future<void> removeText(String textId) async {
    if (!_texts.remove(textId)) return;

    _paused.remove(textId);

    await _saveSettings();
  }

  Future<void> setActive(String textId, bool active) async {
    final changed = active ? _paused.remove(textId) : _paused.add(textId);

    if (!changed) return;

    await _saveSettings();
  }

  // ==========================
  // FAVORITEN
  // ==========================

  /// Markiert ein Werk mit allen Sprachfassungen (oder eine ganze
  /// Bekenntnisschrift) als Favorit oder entfernt die Markierung. Lernstand, Wiederholung und „Meine Texte“ bleiben davon
  /// unberührt.
  Future<void> setFavorite(String workId, bool favorite) async {
    if (favorite == _favorites.contains(workId)) return;

    if (favorite) {
      _favorites.add(workId);
    } else {
      _favorites.remove(workId);
    }

    await _saveSettings();
  }

  Future<void> toggleFavorite(String workId) {
    return setFavorite(workId, !isFavorite(workId));
  }

  Future<void> _saveSettings() {
    notifyListeners();

    _shareSettings();

    final values = {
      "texts": List.of(_texts),
      "paused": _paused.toList(),
      "favorites": List.of(_favorites),
    };

    final result = _pending.then((_) {
      if (uid == null) {
        return LocalLearningStore.instance.saveSettingsGroup(_group, values);
      }

      return _userDoc.set({_group: values}, SetOptions(merge: true));
    });

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }

  /// Gibt die eigenen Einstellungen an die übrigen geladenen Instanzen
  /// desselben Nutzers weiter.
  void _shareSettings() {
    _instances.removeWhere((ref) => ref.target == null);

    for (final ref in List.of(_instances)) {
      final other = ref.target;

      if (other == null ||
          identical(other, this) ||
          other.uid != uid ||
          !other._loaded) {
        continue;
      }

      other._texts
        ..clear()
        ..addAll(_texts);
      other._paused
        ..clear()
        ..addAll(_paused);
      other._favorites
        ..clear()
        ..addAll(_favorites);

      other.notifyListeners();
    }
  }
}
