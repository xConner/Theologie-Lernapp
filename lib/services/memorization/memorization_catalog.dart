import '../../models/confession.dart';
import '../../models/memorization/memorization_text.dart';
import '../../models/prayer.dart';
import '../confession_service.dart';
import '../prayer_service.dart';
import 'text_segmenter.dart';

/// Macht die vorhandenen Inhalte der App (Gebete, Bekenntnisse) als
/// Lerntexte verfügbar. Die Daten selbst bleiben unverändert; die Abschnitte
/// werden beim Laden aus der Zeilen- und Absatzstruktur der Texte gebildet.
///
/// Eine weitere Quelle (z. B. Bibeltexte) braucht nur eine Methode, die
/// [MemorizationWork]s liefert, und einen Eintrag in [load].
class MemorizationCatalog {
  final List<MemorizationWork> works;

  final Map<String, MemorizationText> _texts;

  MemorizationCatalog(this.works)
    : _texts = {
        for (final work in works)
          for (final text in work.versions) text.id: text,
      };

  static const TextSegmenter _segmenter = TextSegmenter();

  static Future<MemorizationCatalog>? _cache;

  /// Lädt den Katalog einmal je App-Start aus den Assets.
  static Future<MemorizationCatalog> load({
    PrayerService? prayers,
    ConfessionService? confessions,
  }) {
    // Eigene Services (Tests) umgehen den Cache.
    if (prayers != null || confessions != null) {
      return _load(prayers ?? PrayerService(), confessions ?? ConfessionService());
    }

    return _cache ??= _load(PrayerService(), ConfessionService()).catchError((
      Object error,
    ) {
      _cache = null;
      throw error;
    });
  }

  static Future<MemorizationCatalog> _load(
    PrayerService prayers,
    ConfessionService confessions,
  ) async {
    final prayerList = await prayers.loadPrayers();
    final confessionList = await confessions.loadConfessions();

    return MemorizationCatalog([
      for (final prayer in prayerList) fromPrayer(prayer),
      for (final confession in confessionList)
        for (final section in confession.sections)
          fromConfession(confession, section),
    ].where((work) => work.versions.isNotEmpty).toList());
  }

  MemorizationText? text(String id) => _texts[id];

  late final Map<String, MemorizationWork> _works = {
    for (final work in works) work.id: work,
  };

  MemorizationWork? workOf(MemorizationText text) => _works[text.workId];

  // ==========================
  // GEBETE
  // ==========================

  static MemorizationWork fromPrayer(Prayer prayer) {
    final workId = "prayer.${prayer.id}";

    return MemorizationWork(
      id: workId,
      title: prayer.displayTitle,
      type: MemorizationTextType.prayer,
      group: PrayerCategories.label(prayer.category),
      versions: [
        for (final language in prayer.languages)
          _text(
            workId: workId,
            language: language,
            title: prayer.titleFor(language),
            workTitle: prayer.displayTitle,
            type: MemorizationTextType.prayer,
            content: prayer.versionFor(language)!.text,
          ),
      ],
    );
  }

  // ==========================
  // BEKENNTNISSE
  // ==========================

  /// Ein Abschnitt eines Bekenntnisses (bei den altkirchlichen Symbolen der
  /// ganze Text, bei der Augsburger Konfession ein Artikel) ist ein Werk.
  static MemorizationWork fromConfession(
    Confession confession,
    ConfessionSection section,
  ) {
    final workId = "confession.${confession.id}.${section.id}";

    final type = confession.category == "altkirchliche_symbole"
        ? MemorizationTextType.creed
        : MemorizationTextType.confession;

    String title(String language) {
      final base =
          confession.title[language] ?? confession.title["de"] ?? confession.id;

      if (confession.sections.length < 2) return base;

      final part =
          section.title[language] ?? section.title["de"] ?? section.id;

      return "$base – $part";
    }

    final multiple = confession.sections.length > 1;

    return MemorizationWork(
      id: workId,
      title: title("de"),
      type: type,
      group: multiple ? (confession.title["de"] ?? confession.id) : null,
      shortTitle: multiple ? (section.title["de"] ?? section.id) : null,
      versions: [
        for (final language in confession.languages)
          if ((section.texts[language] ?? "").trim().isNotEmpty)
            _text(
              workId: workId,
              language: language,
              title: title(language),
              workTitle: title("de"),
              type: type,
              content: section.texts[language]!,
            ),
      ],
    );
  }

  static MemorizationText _text({
    required String workId,
    required String language,
    required String title,
    required String workTitle,
    required MemorizationTextType type,
    required String content,
  }) {
    final id = "$workId.$language";

    // Erst beim ersten Zugriff zerlegen: der Katalog enthält das gesamte
    // Konkordienbuch, gebraucht werden meist nur wenige Texte.
    return LazyMemorizationText(
      id: id,
      workId: workId,
      title: title,
      workTitle: workTitle,
      languageCode: language,
      type: type,
      build: () {
        final parts = _segmenter.segment(content);

        return [
          for (var i = 0; i < parts.length; i++)
            MemorizationSegment(id: "$id.s$i", text: parts[i], order: i),
        ];
      },
    );
  }
}
