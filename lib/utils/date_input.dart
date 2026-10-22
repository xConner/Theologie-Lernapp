/// Datum als „TT.MM.JJJJ“ anzeigen und eingeben (Lernpläne).
String formatDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, "0");

  return "${two(date.day)}.${two(date.month)}.${date.year}";
}

/// Liest „TT.MM.JJJJ“ (auch „T.M.JJJJ“); sonst `null`.
DateTime? parseDate(String input) {
  final match = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
  ).firstMatch(input.trim());

  if (match == null) return null;

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);

  final date = DateTime(year, month, day);

  // 31.02. o. ä. ablehnen.
  if (date.day != day || date.month != month || date.year != year) {
    return null;
  }

  return date;
}
