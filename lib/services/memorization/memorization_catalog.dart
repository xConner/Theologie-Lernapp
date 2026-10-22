import 'package:flutter/foundation.dart';

import '../../models/bible/bible_text.dart';
import '../../models/confession.dart';
import '../../models/memorization/memorization_text.dart';
import '../../models/prayer.dart';
import '../bible/bible_text_source.dart';
import '../confession_service.dart';
import '../prayer_service.dart';
import 'bible_passages.dart';
import 'favorite_ids.dart';
import 'segment_headings.dart';
import 'text_segmenter.dart';

/// Macht die vorhandenen Inhalte der App (Gebete, Bekenntnisse,
/// ausgewählte Bibelstellen aus [BiblePassage.all]) als
/// Lerntexte verfügbar. Die Daten selbst bleiben unverändert; die Abschnitte
/// werden beim Laden aus der Zeilen- und Absatzstruktur der Texte gebildet.
/// Bei einzelnen Texten (siehe [SegmentHeadings]) werden Überschriften zum
/// Titel der Abschnitte statt zur Lernaufgabe.
///
/// Eine weitere Quelle braucht nur eine Methode, die [MemorizationWork]s
/// liefert, und einen Eintrag in [load].
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
    BibleTextSource? bible,
  }) {
    // Eigene Services (Tests) umgehen den Cache.
    if (prayers != null || confessions != null || bible != null) {
      return _load(
        prayers ?? PrayerService(),
        confessions ?? ConfessionService(),
        bible ?? const AssetBibleTextSource(),
      );
    }

    return _cache ??=
        _load(
          PrayerService(),
          ConfessionService(),
          const AssetBibleTextSource(),
        ).catchError((Object error) {
          _cache = null;
          throw error;
        });
  }

  static Future<MemorizationCatalog> _load(
    PrayerService prayers,
    ConfessionService confessions,
    BibleTextSource bible,
  ) async {
    final results = await Future.wait([
      prayers.loadPrayers(),
      confessions.loadConfessions(),
      _bibleWorks(bible),
    ]);

    final prayerList = results[0] as List<Prayer>;
    final confessionList = results[1] as List<Confession>;

    return MemorizationCatalog(
      [
        for (final prayer in prayerList) fromPrayer(prayer),
        for (final confession in confessionList)
          for (final section in confession.sections)
            fromConfession(confession, section),
        ...results[2] as List<MemorizationWork>,
      ].where((work) => work.versions.isNotEmpty).toList(),
    );
  }

  MemorizationText? text(String id) => _texts[id];

  late final Map<String, MemorizationWork> _works = {
    for (final work in works) work.id: work,
  };

  MemorizationWork? workOf(MemorizationText text) => _works[text.workId];

  MemorizationWork? work(String id) => _works[id];

  /// Die Werke einer als Ganzes favorisierbaren Gruppe
  /// ([MemorizationWork.groupId]); leer für unbekannte IDs.
  List<MemorizationWork> worksInGroup(String groupId) {
    return works.where((work) => work.groupId == groupId).toList();
  }

  /// Ob [favoriteId] (Werk oder ganze Bekenntnisschrift) im Katalog
  /// vorkommt; Favoriten entfernter Texte werden nicht angezeigt.
  bool hasFavorite(String favoriteId) {
    return work(favoriteId) != null || worksInGroup(favoriteId).isNotEmpty;
  }

  // ==========================
  // GEBETE
  // ==========================

  static MemorizationWork fromPrayer(Prayer prayer) {
    final workId = FavoriteIds.prayer(prayer);

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
    final workId = FavoriteIds.confessionSection(confession, section);

    final type = confession.category == "altkirchliche_symbole"
        ? MemorizationTextType.creed
        : MemorizationTextType.confession;

    String title(String language) {
      final base =
          confession.title[language] ?? confession.title["de"] ?? confession.id;

      if (confession.sections.length < 2) return base;

      final part = section.title[language] ?? section.title["de"] ?? section.id;

      return "$base – $part";
    }

    final multiple = confession.sections.length > 1;

    return MemorizationWork(
      id: workId,
      title: title("de"),
      type: type,
      group: multiple ? (confession.title["de"] ?? confession.id) : null,
      groupId: multiple ? FavoriteIds.confessionGroup(confession) : null,
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

  // ==========================
  // BIBELTEXTE
  // ==========================

  /// Die Stellen aus [BiblePassage.all]. Fehlt ein Buch, entfallen nur
  /// dessen Stellen; Gebete und Bekenntnisse bleiben nutzbar.
  static Future<List<MemorizationWork>> _bibleWorks(
    BibleTextSource source,
  ) async {
    final bookIds = {for (final p in BiblePassage.all) p.bookId};

    final books = <String, BibleBookText>{};

    await Future.wait([
      for (final bookId in bookIds)
        source
            .loadBook(BiblePassage.translationId, bookId)
            .then((book) => books[bookId] = book)
            .catchError((Object error) {
              debugPrint("Bibelbuch $bookId nicht geladen: $error");
              return const BibleBookText("", []);
            }),
    ]);

    return [
      for (final passage in BiblePassage.all)
        if (books[passage.bookId] case final book?)
          ?fromBiblePassage(passage, book),
    ];
  }

  /// Eine Bibelstelle als Lerntext, je Vers ein Abschnitt; null, wenn ein
  /// Vers im Text fehlt. Der Wortlaut bleibt unverändert, nur Zeilenumbrüche
  /// poetischer Texte werden zu Leerzeichen.
  static MemorizationWork? fromBiblePassage(
    BiblePassage passage,
    BibleBookText book,
  ) {
    // Ein Vers, den eine Zwischenüberschrift teilt, steht in zwei Teilen.
    final verses = <int, String>{};

    for (final verse
        in book.chapter(passage.chapter)?.verses ?? <BibleVerse>[]) {
      final text = verse.text.replaceAll(RegExp(r"\s*\n\t?\s*"), " ").trim();
      verses.update(
        verse.number,
        (before) => "$before $text",
        ifAbsent: () => text,
      );
    }

    final workId = "bible.${passage.id}";
    final id = "$workId.${BiblePassage.languageCode}";

    final segments = <MemorizationSegment>[];

    for (var v = passage.fromVerse; v <= passage.toVerse; v++) {
      final verse = verses[v];
      if (verse == null) return null;

      segments.add(
        MemorizationSegment(
          id: "$id.v$v",
          text: verse,
          order: segments.length,
          title: "Vers $v",
        ),
      );
    }

    final group = passage.oldTestament
        ? "Altes Testament (${BiblePassage.edition})"
        : "Neues Testament (${BiblePassage.edition})";

    return MemorizationWork(
      id: workId,
      title: passage.title,
      type: MemorizationTextType.bible,
      group: group,
      versions: [
        MemorizationText(
          id: id,
          workId: workId,
          title: passage.title,
          workTitle: passage.title,
          languageCode: BiblePassage.languageCode,
          type: MemorizationTextType.bible,
          segments: segments,
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

        final headings = SegmentHeadings.forWork(workId);

        if (headings == null) {
          return [
            for (var i = 0; i < parts.length; i++)
              MemorizationSegment(id: "$id.s$i", text: parts[i], order: i),
          ];
        }

        // Die ID folgt der ursprünglichen Zerlegung: Abschnitte behalten
        // ihren Lernstand, auch wenn davor Überschriften entfallen.
        final titled = headings.apply(content, parts);

        return [
          for (var i = 0; i < titled.length; i++)
            MemorizationSegment(
              id: "$id.s${titled[i].index}",
              text: titled[i].text,
              order: i,
              title: titled[i].title,
            ),
        ];
      },
    );
  }
}
