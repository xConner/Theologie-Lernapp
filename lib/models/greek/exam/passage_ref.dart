/// Stabile Identität eines Textabschnitts: Korpus, Buch, Kapitel und
/// Versbereich innerhalb des Kapitels. Gespeichert wird [id], z. B.
/// `nt:JHN.1.1-5` oder `lxx:PSA.22.1-6`.
///
/// Ein Abschnitt umfasst immer nur die genannten Verse; „bearbeitet“
/// markiert also nie mehr als den tatsächlich gestellten Text.
class PassageRef {
  final String corpusId;
  final String bookId;
  final int chapter;

  /// Versbezeichnungen wie in der Quelle ("1", "22a").
  final String firstVerse;
  final String lastVerse;

  const PassageRef({
    required this.corpusId,
    required this.bookId,
    required this.chapter,
    required this.firstVerse,
    required this.lastVerse,
  });

  String get id => "$corpusId:$bookId.$chapter.$firstVerse-$lastVerse";

  static final RegExp _pattern = RegExp(
    r'^([a-z0-9_]+):([A-Z0-9]+)\.(\d+)\.([0-9a-z]+)-([0-9a-z]+)$',
  );

  /// Liest eine gespeicherte [id]; `null` bei ungültigem Format.
  static PassageRef? tryParse(String id) {
    final m = _pattern.firstMatch(id);
    if (m == null) return null;

    return PassageRef(
      corpusId: m[1]!,
      bookId: m[2]!,
      chapter: int.parse(m[3]!),
      firstVerse: m[4]!,
      lastVerse: m[5]!,
    );
  }

  /// Ordnung einer Versbezeichnung: Zahl, dann Zusatzbuchstabe (22 < 22a).
  static (int, String) verseOrder(String label) {
    final m = RegExp(r'^(\d+)(.*)$').firstMatch(label);
    if (m == null) return (0, label);
    return (int.parse(m[1]!), m[2]!);
  }

  static int compareVerses(String a, String b) {
    final (na, sa) = verseOrder(a);
    final (nb, sb) = verseOrder(b);
    return na != nb ? na.compareTo(nb) : sa.compareTo(sb);
  }

  /// Ob sich die beiden Abschnitte in mindestens einem Vers überschneiden.
  bool overlaps(PassageRef other) {
    return corpusId == other.corpusId &&
        bookId == other.bookId &&
        chapter == other.chapter &&
        compareVerses(firstVerse, other.lastVerse) <= 0 &&
        compareVerses(other.firstVerse, lastVerse) <= 0;
  }

  /// Stellenangabe für die Anzeige ("1,1–5", "1,3").
  String get verseLabel => firstVerse == lastVerse
      ? "$chapter,$firstVerse"
      : "$chapter,$firstVerse–$lastVerse";

  @override
  bool operator ==(Object other) => other is PassageRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
