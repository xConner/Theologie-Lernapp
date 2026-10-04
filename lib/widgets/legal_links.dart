import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../info/app_info.dart';

/// Impressum und Datenschutzhinweise. Beide liegen als statische Seiten in
/// `web/` und werden mit der Web-App ausgeliefert, damit sie auch ohne
/// JavaScript und ohne Anmeldung erreichbar sind.
class LegalLinks {
  LegalLinks._();

  static const String impressumPage = "impressum.html";
  static const String privacyPage = "datenschutz.html";

  /// Im Browser relativ zur aktuellen Seite (funktioniert auch lokal und auf
  /// Vorschau-Deployments), in nativen Apps auf der öffentlichen Website.
  static Uri resolve(String page) {
    return kIsWeb
        ? Uri.base.resolve(page)
        : Uri.parse(AppInfo.websiteUrl).resolve(page);
  }

  static Future<void> open(String page) {
    return launchUrl(resolve(page), mode: LaunchMode.externalApplication);
  }
}
