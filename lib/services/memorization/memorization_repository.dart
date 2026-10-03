import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/memorization/memorization_card.dart';
import '../learning_service.dart';
import '../local_learning_store.dart';

/// Lernstände und „Meine Texte“ des Auswendiglernens für einen Nutzer.
///
/// Speicherung wie bei den Trainern: angemeldet in Firestore
/// (`users/{uid}/memorization` und das Feld `memorization_settings`),
/// als Gast (`uid == null`) lokal über [LocalLearningStore].
///
/// Die Daten werden je Instanz einmal geladen und danach im Speicher
/// geführt; die Screens einer Sitzung teilen sich eine Instanz. Geschrieben
/// wird nur, was sich geändert hat.
class MemorizationRepository extends ChangeNotifier {
  final String? uid;

  final LearningService _learning;

  MemorizationRepository(this.uid, {LearningService? learning})
    : _learning = learning ?? LearningService();

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

  bool _loaded = false;

  Future<void>? _loading;

  bool get isLoaded => _loaded;

  /// IDs der Texte in „Meine Texte“, in der Reihenfolge des Hinzufügens.
  List<String> get textIds => List.unmodifiable(_texts);

  bool contains(String textId) => _texts.contains(textId);

  /// Nur aktive Texte nehmen an der automatischen Wiederholung teil.
  bool isActive(String textId) =>
      _texts.contains(textId) && !_paused.contains(textId);

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

  Future<void> _saveSettings() {
    notifyListeners();

    final values = {"texts": List.of(_texts), "paused": _paused.toList()};

    final result = _pending.then((_) {
      if (uid == null) {
        return LocalLearningStore.instance.saveSettingsGroup(_group, values);
      }

      return _userDoc.set({_group: values}, SetOptions(merge: true));
    });

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }
}
