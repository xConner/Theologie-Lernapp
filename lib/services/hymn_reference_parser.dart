/// Liest die Liedangaben des liturgischen Kalenders.
///
/// Die Angaben nennen die Nummer im Evangelischen Gesangbuch, z. B.
/// „EG 200: Ich bin getauft auf deinen Namen“ oder – bei zwei Liedern –
/// „EG 262/263: Sonne der Gerechtigkeit“. Die Nummer ist zugleich die ID des
/// Liedes in der App. Lieder aus dem Ergänzungsheft („EG.E 10: …“) stehen
/// nicht im Gesangbuch der App und haben daher keine Nummer.
class HymnReferenceParser {
  HymnReferenceParser._();

  static final RegExp _numbers = RegExp(r"^EG\s+(\d+(?:\s*/\s*\d+)*)\s*:");

  /// Die Gesangbuchnummern einer Angabe; leer, wenn sie keine nennt.
  static List<int> parse(String input) {
    final match = _numbers.firstMatch(input.trim());

    if (match == null) return const [];

    return [
      for (final number in match.group(1)!.split("/")) int.parse(number.trim()),
    ];
  }
}
