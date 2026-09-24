/// Ziel eines Deep Links aus einer Nachricht (Glocke, später auch Push:
/// dieselbe Zeichenkette im Feld `deepLink` bzw. in den FCM-Daten `link`).
///
/// Format: App-Pfad wie "/greek/vocabulary" oder eine https-URL.
/// Neues Ziel → Konstante hier und in [paths] ergänzen sowie den Screen in
/// `widgets/deep_link_navigator.dart` eintragen.
class AppDeepLink {
  final String path;

  const AppDeepLink._(this.path);

  static const String perikopen = "/perikopen";
  static const String greek = "/greek";
  static const String greekVocabulary = "/greek/vocabulary";
  static const String greekGrammar = "/greek/grammar";
  static const String latin = "/latin";
  static const String latinVocabulary = "/latin/vocabulary";
  static const String calendar = "/calendar";
  static const String hymns = "/hymns";
  static const String confessions = "/confessions";
  static const String settings = "/settings";
  static const String notificationSettings = "/settings/notifications";
  static const String account = "/account";

  /// Alle bekannten App-Pfade.
  static const Set<String> paths = {
    perikopen,
    greek,
    greekVocabulary,
    greekGrammar,
    latin,
    latinVocabulary,
    calendar,
    hymns,
    confessions,
    settings,
    notificationSettings,
    account,
  };

  /// Liefert null für leere, unbekannte oder unsichere Links.
  static AppDeepLink? parse(String? raw) {
    final link = raw?.trim();

    if (link == null || link.isEmpty) return null;

    if (link.startsWith("/")) {
      final path = link.length > 1 && link.endsWith("/")
          ? link.substring(0, link.length - 1)
          : link;

      return paths.contains(path) ? AppDeepLink._(path) : null;
    }

    final uri = Uri.tryParse(link);

    if (uri != null && uri.scheme == "https" && uri.host.isNotEmpty) {
      return AppDeepLink._(link);
    }

    return null;
  }

  bool get isExternal => !path.startsWith("/");
}
