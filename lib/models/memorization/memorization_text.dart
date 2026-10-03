/// Art eines Lerntextes. Das Memorier-System ist bewusst nicht auf Gebete
/// festgelegt: [bible] und [other] sind für spätere Quellen vorbereitet.
enum MemorizationTextType { prayer, creed, confession, bible, other }

extension MemorizationTextTypeLabel on MemorizationTextType {
  String get label {
    switch (this) {
      case MemorizationTextType.prayer:
        return "Gebet";
      case MemorizationTextType.creed:
        return "Bekenntnis";
      case MemorizationTextType.confession:
        return "Bekenntnisschrift";
      case MemorizationTextType.bible:
        return "Bibeltext";
      case MemorizationTextType.other:
        return "Text";
    }
  }
}

/// Ein Abschnitt eines Lerntextes – die Einheit, auf der gelernt und
/// wiederholt wird.
class MemorizationSegment {
  /// Zugleich ID des Lernstands (`users/{uid}/memorization/{id}`).
  final String id;

  final String text;

  /// Position im Text (0-basiert).
  final int order;

  const MemorizationSegment({
    required this.id,
    required this.text,
    required this.order,
  });
}

/// Ein Text in genau einer Sprache, zerlegt in Abschnitte.
///
/// Jede Sprachfassung ist ein eigener Lerntext mit eigener [id] und damit
/// eigenem Lernstand. Der Inhalt ist statisch; der Lernstand liegt getrennt
/// davon in `MemorizationCard`.
class MemorizationText {
  /// Stabil und eindeutig, z. B. `prayer.vaterunser.de`.
  final String id;

  /// Gemeinsame Kennung aller Sprachfassungen, z. B. `prayer.vaterunser`.
  final String workId;

  /// Titel in der Sprache des Textes (sonst deutsch).
  final String title;

  /// Deutscher Titel des Werks, unter dem es in der App geführt wird.
  final String workTitle;

  final String languageCode;
  final MemorizationTextType type;
  final List<MemorizationSegment> segments;

  const MemorizationText({
    required this.id,
    required this.workId,
    required this.title,
    required this.workTitle,
    required this.languageCode,
    required this.type,
    required this.segments,
  });

  /// Lernstand des vollständigen Aufsagens.
  String get fullCardId => "$id.full";

  /// Text der Abschnitte [from] bis einschließlich [to].
  String textOf(int from, int to) {
    return [for (var i = from; i <= to; i++) segments[i].text].join("\n");
  }
}

/// Ein Werk mit seinen Sprachfassungen (z. B. Vaterunser: Deutsch, Latein).
class MemorizationWork {
  final String id;
  final String title;
  final MemorizationTextType type;
  final List<MemorizationText> versions;

  const MemorizationWork({
    required this.id,
    required this.title,
    required this.type,
    required this.versions,
  });
}
