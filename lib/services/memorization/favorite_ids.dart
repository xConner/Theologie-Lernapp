import '../../models/confession.dart';
import '../../models/prayer.dart';

/// Stabile IDs der Favoriten – gemeinsam für „Texte auswendig lernen“ und
/// die Menüs Gebete und Bekenntnisse, damit es nur einen Favoritenbestand
/// gibt. Titel oder Positionen dienen nie als Schlüssel.
///
///   * Gebet: Werk-ID des Lerntextes, z. B. `prayer.vaterunser`.
///   * Bekenntnis mit einem Abschnitt: ebenfalls die Werk-ID,
///     z. B. `confession.apostolicum.full`.
///   * Bekenntnisschrift mit mehreren Abschnitten als Ganzes:
///     `confession.augsburger_konfession`; ihre Artikel sind eigene Werke
///     (`confession.augsburger_konfession.art_4`).
class FavoriteIds {
  const FavoriteIds._();

  static String prayer(Prayer prayer) => "prayer.${prayer.id}";

  static String confessionSection(
    Confession confession,
    ConfessionSection section,
  ) => "confession.${confession.id}.${section.id}";

  /// Bekenntnisschrift als Ganzes (nur bei mehreren Abschnitten).
  static String confessionGroup(Confession confession) =>
      "confession.${confession.id}";

  /// Eintrag eines Bekenntnisses im Menü Bekenntnisse.
  static String confession(Confession confession) =>
      confession.sections.length == 1
      ? confessionSection(confession, confession.sections.first)
      : confessionGroup(confession);
}
