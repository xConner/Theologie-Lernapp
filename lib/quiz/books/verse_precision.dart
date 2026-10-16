import '../../models/greek/perikope.dart';
import '../pericope_reference.dart';
import 'book_catalog.dart';

/// Persönliche, versgenaue Präzisierung einer Perikope („Mk 1“ → „Mk 1,14-20“).
///
/// Sie gilt nur für den Nutzer, der sie anlegt, und ändert die globale
/// Perikopenliste nicht: gespeichert wird sie getrennt unter dem
/// [BookPericope.key] der Perikope (siehe `BookLearningStorage`). Ohne
/// Präzisierung gilt die Genauigkeit der Liste.
class VersePrecision {
  final int startChapter;
  final int startVerse;
  final int endChapter;
  final int endVerse;

  const VersePrecision({
    required this.startChapter,
    required this.startVerse,
    required this.endChapter,
    required this.endVerse,
  });

  /// Liest gespeicherte Werte; unvollständige oder unsinnige Daten ergeben
  /// `null` (die Perikope gilt dann als nicht präzisiert).
  static VersePrecision? fromJson(Object? raw) {
    if (raw is! Map) return null;

    int? read(String key) {
      final value = raw[key];
      return value is num && value.isFinite ? value.toInt() : null;
    }

    final sc = read("startChapter");
    final sv = read("startVerse");
    final ec = read("endChapter");
    final ev = read("endVerse");

    if (sc == null || sv == null || ec == null || ev == null) return null;

    if (sc < 1 || sv < 1 || ec < sc || ev < 1) return null;
    if (ec == sc && ev < sv) return null;

    return VersePrecision(
      startChapter: sc,
      startVerse: sv,
      endChapter: ec,
      endVerse: ev,
    );
  }

  Map<String, dynamic> toJson() => {
    "startChapter": startChapter,
    "startVerse": startVerse,
    "endChapter": endChapter,
    "endVerse": endVerse,
  };

  @override
  bool operator ==(Object other) =>
      other is VersePrecision &&
      other.startChapter == startChapter &&
      other.startVerse == startVerse &&
      other.endChapter == endChapter &&
      other.endVerse == endVerse;

  @override
  int get hashCode =>
      Object.hash(startChapter, startVerse, endChapter, endVerse);
}

/// Die Stelle, die beim systematischen Lernen für eine Perikope gilt.
class ExpectedReference {
  final PericopeReference reference;

  /// Aus einer persönlichen Präzisierung (statt aus der Perikopenliste).
  final bool personal;

  const ExpectedReference(this.reference, {required this.personal});

  /// Versgenau – global oder persönlich.
  bool get versePrecise => reference.startVerse != null;

  String get text => reference.text;

  /// Die maßgebliche Stelle: die persönliche Präzisierung, sonst die
  /// Perikopenliste in ihrer hinterlegten Genauigkeit (meist kapitelgenau).
  factory ExpectedReference.of(Perikope p, VersePrecision? precision) {
    if (precision != null) {
      return ExpectedReference(
        PericopeReference(
          book: p.book,
          startChapter: precision.startChapter,
          startVerse: precision.startVerse,
          endChapter: precision.endChapter,
          endVerse: precision.endVerse,
        ),
        personal: true,
      );
    }

    return ExpectedReference(PericopeReference.of(p), personal: false);
  }
}

/// Prüft eine Präzisierung gegen die Perikope und – soweit bekannt – gegen
/// die Verszahlen der Bibelausgaben.
class VersePrecisionValidator {
  VersePrecisionValidator._();

  /// Fehlermeldung oder `null`, wenn die Präzisierung gültig ist.
  ///
  /// Die Kapitel müssen innerhalb der Kapitel der Perikope liegen: Aus
  /// „Mk 1“ kann „Mk 1,14-20“ werden, aber nicht „Mk 2,1-12“.
  ///
  /// [verseCount] liefert die Verszahl eines Kapitels (deutsche Zählung)
  /// oder `null`, wenn sie unbekannt ist; dann wird nur die Form geprüft.
  static String? validate(
    Perikope p,
    VersePrecision precision, {
    int? Function(int chapter)? verseCount,
  }) {
    final sc = precision.startChapter;
    final ec = precision.endChapter;

    if (sc < p.startChapter || ec > p.endChapter || ec < sc) {
      final chapters = p.startChapter == p.endChapter
          ? "Kapitel ${p.startChapter}"
          : "Kapitel ${p.startChapter}–${p.endChapter}";

      return "Die Verse müssen in $chapters liegen.";
    }

    if (precision.startVerse < 1 || precision.endVerse < 1) {
      return "Verse beginnen bei 1.";
    }

    if (sc == ec && precision.endVerse < precision.startVerse) {
      return "Der Endvers liegt vor dem Anfangsvers.";
    }

    final startMax = verseCount?.call(sc);

    if (startMax != null && startMax > 0 && precision.startVerse > startMax) {
      return "Kapitel $sc hat nur $startMax Verse.";
    }

    final endMax = verseCount?.call(ec);

    if (endMax != null && endMax > 0 && precision.endVerse > endMax) {
      return "Kapitel $ec hat nur $endMax Verse.";
    }

    return null;
  }

  /// Vorschlag für den Bearbeiten-Dialog: die Anfangs- und Endverse, die die
  /// Perikopenliste zu der Perikope führt (auch wenn sie nur kapitelgenau
  /// abgefragt wird). Es ist nur ein Startwert, keine Vorgabe.
  static VersePrecision? suggestionOf(Perikope p) {
    return VersePrecision.fromJson({
      "startChapter": p.startChapter,
      "startVerse": p.startVerse,
      "endChapter": p.endChapter,
      "endVerse": p.endVerse,
    });
  }
}
