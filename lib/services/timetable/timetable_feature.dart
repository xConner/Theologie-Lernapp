import 'package:flutter/foundation.dart';

/// Stundenplan-Vorschau. Bis zur Klärung der Nutzungsrechte an UnivIS-Daten
/// arbeitet die Funktion nur mit SYNTHETISCHEN Testdaten. Damit Nutzerinnen
/// und Nutzer der veröffentlichten App keine erfundenen Veranstaltungen für
/// echte halten, erscheint der Menüpunkt nur in Entwicklungs-Builds oder
/// ausdrücklich freigeschaltet:
///
///   flutter run --dart-define=TIMETABLE_PREVIEW=true
///   flutter build web --dart-define=TIMETABLE_PREVIEW=true
const bool timetablePreviewEnabled =
    kDebugMode || bool.fromEnvironment("TIMETABLE_PREVIEW");
