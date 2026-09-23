/// Sehr einfache E.164-Prüfung (z. B. "+49 151 23456789"): Pluszeichen,
/// danach 8-15 Ziffern. Keine externe Bibliothek nötig für diesen Zweck.
bool isValidE164PhoneNumber(String input) {
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(input.trim());
}

/// Normalisiert eine Telefonnummer-Eingabe zu E.164 (entfernt Leerzeichen,
/// Klammern und Bindestriche, behält das führende "+").
String normalizePhoneNumber(String input) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// Zeigt eine Telefonnummer nur maskiert an, z. B. "+49 •••••••89".
String maskPhoneNumber(String phoneNumber) {
  if (phoneNumber.length <= 4) return phoneNumber;

  final visibleEnd = phoneNumber.substring(phoneNumber.length - 2);
  final visibleStart = phoneNumber.substring(0, 3);
  final maskedLength = phoneNumber.length - visibleStart.length - visibleEnd.length;

  return '$visibleStart${'•' * maskedLength}$visibleEnd';
}
