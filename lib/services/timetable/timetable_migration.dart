import '../../models/timetable/timetable_entry.dart';
import 'timetable_store.dart';

/// Ergebnis einer Übernahme des Gast-Stundenplans.
class TimetableMigrationResult {
  /// Neu ins Konto geschriebene Einträge.
  final int copied;

  /// Lokal vorhandene Einträge, die das Konto schon hatte (nicht verändert).
  final int alreadyPresent;

  /// Lokal gelöschte Einträge (nach bestätigter Übernahme).
  final int removedLocally;

  /// Unlesbare lokale Einträge: nicht übernommen und nicht gelöscht.
  final int invalid;

  const TimetableMigrationResult({
    this.copied = 0,
    this.alreadyPresent = 0,
    this.removedLocally = 0,
    this.invalid = 0,
  });

  bool get nothingToDo =>
      copied == 0 && alreadyPresent == 0 && removedLocally == 0;
}

/// Übernimmt den lokal gespeicherten Gast-Stundenplan nach der Anmeldung in
/// das Konto (`users/{uid}/timetable`).
///
/// * Zusammenführung über die stabile Dokumentkennung ([timetableDocId]):
///   keine Duplikate; Einträge, die das Konto schon hat, bleiben unverändert.
/// * Lokale Einträge werden erst gelöscht, wenn der Server sie bestätigt hat
///   – und nur genau diese. Ein Abbruch oder Netzwerkfehler lässt die lokalen
///   Daten unangetastet; ein erneuter Lauf setzt dort fort (idempotent).
/// * Gleichzeitige Läufe für dasselbe Konto (z. B. wiederholte Anmeldung)
///   teilen sich einen Durchlauf.
class TimetableGuestMigration {
  final TimetableBackend local;
  final TimetableBackend account;

  TimetableGuestMigration({required this.local, required this.account});

  factory TimetableGuestMigration.forUser(String uid) =>
      TimetableGuestMigration(
        local: LocalTimetableBackend(),
        account: FirestoreTimetableBackend(uid),
      );

  static final Map<String, Future<TimetableMigrationResult>> _running = {};

  /// Wie [run], aber höchstens ein gleichzeitiger Lauf je [key] (z. B. uid).
  Future<TimetableMigrationResult> runOnce(String key) {
    final existing = _running[key];
    if (existing != null) return existing;
    // Block statt Pfeil: `remove` gäbe sonst genau dieses Future zurück, und
    // whenComplete würde auf sich selbst warten.
    final task = run().whenComplete(() {
      _running.remove(key);
    });
    _running[key] = task;
    return task;
  }

  Future<TimetableMigrationResult> run() async {
    final stored = await local.read();
    if (stored.isEmpty) return const TimetableMigrationResult();

    // Über das Datenmodell normalisieren: nur bekannte Felder, gültige
    // Kennung – sonst lehnen die Firestore-Regeln den Eintrag ab.
    final guest = <String, TimetableEntry>{};
    for (final e in stored.entries) {
      final entry = TimetableEntry.tryFromMap(e.value);
      if (entry != null && timetableDocId(entry.courseId) == e.key) {
        guest[e.key] = entry;
      }
    }
    final invalid = stored.length - guest.length;

    final existing = await account.read();
    var copied = 0;
    for (final entry in guest.entries) {
      if (existing.containsKey(entry.key)) continue;
      await account.put(entry.key, entry.value.toMap());
      copied++;
    }

    // Bestätigung vom Server: nur, was dort sicher angekommen ist, wird
    // lokal entfernt.
    final confirmed = await account.read(confirmed: true);
    var removed = 0;
    for (final id in guest.keys) {
      if (confirmed.containsKey(id)) {
        await local.delete(id);
        removed++;
      }
    }

    return TimetableMigrationResult(
      copied: copied,
      alreadyPresent: guest.length - copied,
      removedLocally: removed,
      invalid: invalid,
    );
  }
}
