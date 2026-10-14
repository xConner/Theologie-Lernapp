import 'course_catalog_source.dart';

/// Der Stundenplan ist regulär verfügbar und nutzt den Veranstaltungskatalog
/// der CAU (UnivIS, über `/api/catalog`).
///
/// Synthetische Testdaten gibt es nur noch ausdrücklich für die
/// Entwicklung – nie als stiller Ersatz, wenn der echte Katalog fehlt:
///
///   flutter run --dart-define=TIMETABLE_SYNTHETIC=true
const bool timetableSyntheticMode = bool.fromEnvironment("TIMETABLE_SYNTHETIC");

CourseCatalogSource defaultCourseCatalogSource() => timetableSyntheticMode
    ? SyntheticCourseCatalogSource()
    : ApiCourseCatalogSource();
