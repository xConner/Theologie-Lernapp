import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greek/vocabulary/learning_card.dart';
import '../models/greek/perikope.dart';
import 'book_learning_storage.dart';
import 'local_learning_store.dart';
import 'progress_reset.dart';

/// Kontoübergreifende Operationen auf den Lernständen: Übernahme der
/// Gastdaten in ein Konto und Zurücksetzen der Lernfortschritte.
///
/// Die Firestore-Pfade entsprechen exakt denen von [LearningService] und den
/// Settings-Services; es werden keine neuen Strukturen angelegt.
class ProgressDataService {
  // Getter statt Feld: Im Gastmodus (und in Tests) wird Firestore nie berührt.
  FirebaseFirestore get db => FirebaseFirestore.instance;

  final LocalLearningStore local = LocalLearningStore.instance;

  /// Firestore-Collections mit Lernstands-/SRS-Daten unter `users/{uid}`.
  /// `grammar` enthält die Lernstände des Grammatiktrainers und ggf. ältere
  /// Grammatik-Lernstände in einem früheren Format.
  static const List<String> _progressCollections =
      LocalLearningStore.cardCollections;

  static const int _batchLimit = 400;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return db.collection("users").doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _perikopenSettingsDoc(String uid) {
    return _quizSettingsDoc(uid, "perikopen");
  }

  /// Dokumente unter `quiz_settings`, darunter die von „Bücher systematisch
  /// lernen“ und der Fortschritt in „Einführung in die Logik“
  /// ([LocalLearningStore.quizDocuments]).
  DocumentReference<Map<String, dynamic>> _quizSettingsDoc(
    String uid,
    String name,
  ) {
    return _userDoc(uid).collection("quiz_settings").doc(name);
  }

  // ==========================
  // GAST → KONTO
  // ==========================

  /// Hat das Konto bereits Lernstände oder Lerneinstellungen? Dann werden
  /// Gastdaten nicht angeboten, damit nichts überschrieben wird.
  Future<bool> accountHasLearningData(String uid) async {
    for (final collection in _progressCollections) {
      final snapshot = await _userDoc(
        uid,
      ).collection(collection).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        return true;
      }
    }

    final userData = (await _userDoc(uid).get()).data();

    if (userData != null &&
        LocalLearningStore.settingsGroups.any(userData.containsKey)) {
      return true;
    }

    if ((await _perikopenSettingsDoc(uid).get()).exists) {
      return true;
    }

    for (final name in LocalLearningStore.quizDocuments) {
      if ((await _quizSettingsDoc(uid, name).get()).exists) {
        return true;
      }
    }

    return false;
  }

  /// Überträgt die validierten lokalen Gastdaten in die bestehenden
  /// Firestore-Strukturen des Kontos und entfernt sie danach lokal.
  ///
  /// Bricht ab (StateError), wenn das Konto inzwischen eigene Daten hat.
  Future<void> transferGuestData(String uid) async {
    if (await accountHasLearningData(uid)) {
      throw StateError("account-has-data");
    }

    final writes = <void Function(WriteBatch)>[];

    for (final collection in LocalLearningStore.cardCollections) {
      // loadCards validiert die Werte (ungültige → normale Defaults).
      final cards = await local.loadCards(collection);

      for (final card in cards.values) {
        final ref = _userDoc(uid).collection(collection).doc(card.id);

        writes.add(
          (batch) =>
              batch.set(ref, card.toFirestore(), SetOptions(merge: true)),
        );
      }
    }

    final settings = <String, dynamic>{};

    for (final group in LocalLearningStore.settingsGroups) {
      final values = await local.loadSettingsGroup(group);

      if (values.isNotEmpty) {
        settings[group] = values;
      }
    }

    if (settings.isNotEmpty) {
      final ref = _userDoc(uid);
      writes.add((batch) => batch.set(ref, settings, SetOptions(merge: true)));
    }

    if (await local.hasSelectedBooks()) {
      final books = await local.loadSelectedBooks();
      final ref = _perikopenSettingsDoc(uid);
      writes.add((batch) => batch.set(ref, {"selectedBooks": books.toList()}));
    }

    // Bücher systematisch lernen (Lernstände, Präzisierungen, Pläne) und
    // Logik-Fortschritt unverändert übernehmen (gleiches Format wie in
    // Firestore).
    for (final name in LocalLearningStore.quizDocuments) {
      final doc = await local.loadQuizDocument(name);

      if (doc.isNotEmpty) {
        final ref = _quizSettingsDoc(uid, name);
        writes.add((batch) => batch.set(ref, doc, SetOptions(merge: true)));
      }
    }

    await _commitInBatches(writes);

    await local.clearGuestData();
  }

  // ==========================
  // RESET
  // ==========================

  /// Setzt alle Lernstände (stability, difficulty, lastReviewed) und den
  /// Fortschritt in „Einführung in die Logik“ zurück. uid == null → lokaler
  /// Gast-Lernstand.
  ///
  /// Karten ohne Eselsbrücke werden gelöscht (fehlende Karte = Initialwerte),
  /// Karten mit Eselsbrücke behalten nur diese. Der Lernstand von „Bücher
  /// systematisch lernen“ wird gelöscht; Verspräzisierungen, Lernpläne,
  /// Einstellungen, Konto- und sonstige Daten bleiben unberührt.
  Future<void> resetProgress(String? uid) {
    return _exclusive(() async {
      if (uid == null) {
        return local.resetProgress();
      }

      final writes = <void Function(WriteBatch)>[];

      for (final collection in _progressCollections) {
        writes.addAll(await _collectionResetWrites(uid, collection));
      }

      final books = _quizSettingsDoc(uid, LocalLearningStore.pericopeBooks);
      final logic = _quizSettingsDoc(uid, LocalLearningStore.logicCourse);
      final latinGrammar = _quizSettingsDoc(
        uid,
        LocalLearningStore.latinGrammar,
      );

      writes.add((batch) => batch.delete(books));
      writes.add((batch) => batch.delete(logic));
      writes.add((batch) => batch.delete(latinGrammar));
      writes.add(
        (batch) => batch.delete(
          _quizSettingsDoc(uid, LocalLearningStore.churchHistory),
        ),
      );

      await _commitInBatches(writes);
    });
  }

  /// Setzt nur den Lernstand eines Bereichs zurück – mit denselben Regeln
  /// wie [resetProgress] (Eselsbrücken bleiben), alle anderen Bereiche,
  /// Einstellungen und Inhalte bleiben unverändert.
  ///
  /// [ProgressArea.pericopes] umfasst das Perikopenquiz und „Bücher
  /// systematisch lernen“ (dessen Lernstand, nicht Präzisierungen/Pläne);
  /// [ProgressArea.logic] besteht nur aus einem Dokument unter
  /// `quiz_settings`.
  Future<void> resetArea(String? uid, ProgressArea area) {
    return _exclusive(() async {
      final collection = area.collection;
      final documents = area.documents;

      if (uid == null) {
        if (collection != null) await local.resetCollection(collection);

        for (final name in documents) {
          await local.removeQuizDocument(name);
        }

        return;
      }

      final writes = collection == null
          ? <void Function(WriteBatch)>[]
          : await _collectionResetWrites(uid, collection);

      for (final name in documents) {
        final ref = _quizSettingsDoc(uid, name);
        writes.add((batch) => batch.delete(ref));
      }

      await _commitInBatches(writes);
    });
  }

  /// Was das Zurücksetzen eines Bibelbuchs beträfe (ohne etwas zu ändern).
  Future<PericopeBookResetPlan> planPericopeBookReset(
    String? uid,
    String book,
    Iterable<Perikope> perikopen, {
    bool includeShared = false,
  }) async {
    final quizCards = uid == null
        ? await local.loadCards(LocalLearningStore.perikopen)
        : {
            for (final doc in (await _userDoc(
              uid,
            ).collection(LocalLearningStore.perikopen).get()).docs)
              doc.id: LearningCard.fromFirestore(doc.id, doc.data()),
          };

    final bookData = await BookLearningStorage.forUser(uid).load();

    return PericopeBookResetPlan.build(
      book: book,
      perikopen: perikopen,
      quizCards: quizCards,
      bookCards: bookData.cards,
      includeShared: includeShared,
    );
  }

  /// Setzt die Perikopenkenntnisse eines Bibelbuchs zurück (siehe
  /// [PericopeBookResetPlan]); andere Bücher bleiben unverändert, gemeinsame
  /// Karten nur mit [includeShared] nicht.
  ///
  /// In Firestore gehen alle Änderungen in möglichst einen Batch; ein Buch
  /// hat höchstens einige hundert Karten, sodass das Zurücksetzen in der
  /// Regel ganz oder gar nicht geschieht.
  Future<PericopeBookResetPlan> resetPericopeBook(
    String? uid,
    String book,
    Iterable<Perikope> perikopen, {
    bool includeShared = false,
  }) {
    return _exclusive(() async {
      final plan = await planPericopeBookReset(
        uid,
        book,
        perikopen,
        includeShared: includeShared,
      );

      if (plan.isEmpty) return plan;

      final bookEntries = <String, Object?>{
        for (final key in plan.deleteKeys) key: null,
        for (final key in plan.markerKeys)
          key: PericopeBookResetPlan.markerJson(key),
      };

      if (uid == null) {
        await local.resetCollection(
          LocalLearningStore.perikopen,
          ids: plan.resetIds.keys.toSet(),
        );

        if (bookEntries.isNotEmpty) {
          await local.mergeQuizDocument(
            LocalLearningStore.pericopeBooks,
            "cards",
            bookEntries,
          );
        }

        return plan;
      }

      final writes = <void Function(WriteBatch)>[];

      final cards = _userDoc(uid).collection(LocalLearningStore.perikopen);

      for (final entry in plan.resetIds.entries) {
        final ref = cards.doc(entry.key);
        final mnemonic = entry.value;

        if (mnemonic != null) {
          final reset = LearningCard(id: entry.key, mnemonic: mnemonic);
          writes.add((batch) => batch.set(ref, reset.toFirestore()));
        } else {
          writes.add((batch) => batch.delete(ref));
        }
      }

      if (bookEntries.isNotEmpty) {
        final ref = _quizSettingsDoc(uid, LocalLearningStore.pericopeBooks);

        if ((await ref.get()).exists) {
          // update ersetzt jeden Eintrag vollständig (set mit merge würde
          // alte Felder einer Karte in die Markierung übernehmen).
          final fields = <Object, Object?>{
            for (final entry in bookEntries.entries)
              FieldPath(["cards", entry.key]):
                  entry.value ?? FieldValue.delete(),
          };

          writes.add((batch) => batch.update(ref, fields));
        } else {
          final markers = {
            for (final entry in bookEntries.entries)
              if (entry.value != null) entry.key: entry.value,
          };

          if (markers.isNotEmpty) {
            writes.add(
              (batch) =>
                  batch.set(ref, {"cards": markers}, SetOptions(merge: true)),
            );
          }
        }
      }

      await _commitInBatches(writes);

      return plan;
    });
  }

  /// Schreibvorgänge, die die Karten einer Collection zurücksetzen.
  Future<List<void Function(WriteBatch)>> _collectionResetWrites(
    String uid,
    String collection,
  ) async {
    final writes = <void Function(WriteBatch)>[];

    final snapshot = await _userDoc(uid).collection(collection).get();

    for (final doc in snapshot.docs) {
      final mnemonic = doc.data()["mnemonic"];

      if (collection != LocalLearningStore.greekGrammar &&
          mnemonic is String &&
          mnemonic.isNotEmpty) {
        final reset = LearningCard(id: doc.id, mnemonic: mnemonic);

        writes.add((batch) => batch.set(doc.reference, reset.toFirestore()));
      } else {
        writes.add((batch) => batch.delete(doc.reference));
      }
    }

    return writes;
  }

  // Ein Zurücksetzen zur Zeit: Zwei gleichzeitige Vorgänge könnten sich
  // gegenseitig überschreiben (lesen, dann schreiben).
  static bool _running = false;

  /// Läuft gerade ein Zurücksetzen?
  static bool get isResetRunning => _running;

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_running) {
      throw StateError("progress-reset-running");
    }

    _running = true;

    try {
      return await action();
    } finally {
      _running = false;
    }
  }

  Future<void> _commitInBatches(List<void Function(WriteBatch)> writes) async {
    for (var start = 0; start < writes.length; start += _batchLimit) {
      final batch = db.batch();

      for (final write in writes.skip(start).take(_batchLimit)) {
        write(batch);
      }

      await batch.commit();
    }
  }
}
