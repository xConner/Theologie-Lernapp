class BibleInputValidator {
  static final RegExp _chapter = RegExp(r'^[A-Za-zÄÖÜäöü]{1,10}\s\d{1,3}$');

  static final RegExp _verse = RegExp(
    r'^[A-Za-zÄÖÜäöü]{1,10}\s\d{1,3},\d{1,3}(-\d{1,3})?$',
  );

  static String normalize(String input) {
    return input
        .trim()
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isValid(String input, String precision) {
    final v = normalize(input);
    if (v.isEmpty) return false;

    if (precision == "chapter") {
      return _chapter.hasMatch(v);
    }

    return _verse.hasMatch(v);
  }

  static String hint(String precision) {
    return precision == "chapter" ? "z.B. Mk 15" : "z.B. Mk 15,1–15";
  }

  static String hintText(String input, String precision) {
    final v = input.trim();

    if (v.isEmpty) {
      return precision == "chapter" ? "z.B. Mk 15" : "z.B. Mk 15,1–15";
    }

    return precision == "chapter" ? "Format: Mk 15" : "Format: Mk 15,1–15";
  }
}
