/// Ziel eines Deep Links aus einer Nachricht (Glocke und Push: dieselbe
/// Zeichenkette im Feld `deepLink` bzw. im Feld `link` einer Push-Nachricht).
///
/// Format: App-Pfad wie "/greek/vocabulary" oder eine https-URL.
/// Neues Ziel → Konstante hier und in [paths] ergänzen sowie den Screen in
/// `widgets/deep_link_navigator.dart` eintragen.
class AppDeepLink {
  final String path;

  const AppDeepLink._(this.path);

  /// Startseite (schließt alle geöffneten Bereiche).
  static const String home = "/";
  static const String perikopen = "/perikopen";
  static const String greek = "/greek";
  static const String greekVocabulary = "/greek/vocabulary";
  static const String greekGrammar = "/greek/grammar";
  static const String latin = "/latin";
  static const String latinVocabulary = "/latin/vocabulary";
  static const String calendar = "/calendar";
  static const String hymns = "/hymns";
  static const String confessions = "/confessions";
  static const String prayers = "/prayers";
  static const String memorize = "/memorize";
  static const String bible = "/bible";

  /// Ein begonnener Leseplan: `/bible/plan/<Plan-ID>`.
  static const String biblePlanPrefix = "/bible/plan/";
  static const String settings = "/settings";
  static const String notificationSettings = "/settings/notifications";
  static const String account = "/account";

  /// Alle bekannten App-Pfade.
  static const Set<String> paths = {
    home,
    perikopen,
    greek,
    greekVocabulary,
    greekGrammar,
    latin,
    latinVocabulary,
    calendar,
    hymns,
    confessions,
    prayers,
    memorize,
    bible,
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

      if (path.startsWith(biblePlanPrefix)) {
        return _planId.hasMatch(path.substring(biblePlanPrefix.length))
            ? AppDeepLink._(path)
            : null;
      }

      return paths.contains(path) ? AppDeepLink._(path) : null;
    }

    final uri = Uri.tryParse(link);

    if (uri != null && uri.scheme == "https" && uri.host.isNotEmpty) {
      return AppDeepLink._(link);
    }

    return null;
  }

  // Wie `ReadingPlanCodec.idPattern`.
  static final RegExp _planId = RegExp(r'^[a-z0-9][a-z0-9._-]{1,62}$');

  bool get isExternal => !path.startsWith("/");

  /// Plan-ID eines Leseplan-Links, sonst null.
  String? get planId {
    return path.startsWith(biblePlanPrefix)
        ? path.substring(biblePlanPrefix.length)
        : null;
  }
}
