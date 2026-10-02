import 'package:flutter/foundation.dart';

import '../../info/app_info.dart';
import '../../info/module_info.dart';

/// Art der Meldung. Aktuell gibt es nur Fehlermeldungen („hier ist etwas
/// falsch“); [feedback] („ich habe eine Idee“) ist für später vorgesehen und
/// wird von UI und Firestore-Regeln noch nicht angenommen.
enum ReportKind { report, feedback }

enum ReportCategory {
  bug("bug", "Technischer Fehler"),
  content("content", "Falscher Inhalt"),
  reference("reference", "Falsche Bibelstelle"),
  translation("translation", "Falsche Übersetzung oder Form"),
  source("source", "Quelle falsch oder fehlt"),
  display("display", "Darstellung"),
  other("other", "Sonstiges");

  /// Gespeicherter Wert (siehe firestore.rules).
  final String id;
  final String label;

  const ReportCategory(this.id, this.label);
}

/// Wo eine Meldung ausgelöst wurde: der Bereich und – falls vorhanden – der
/// gerade angezeigte Inhalt.
///
/// [details] enthält nur, was für die Fehlersuche nötig ist (z. B. Eintrags-ID,
/// abgefragte Form, Eingabe). Keine Kontodaten, keine eigenen Merkhilfen.
class ReportContext {
  final ModuleInfo module;
  final Map<String, String> details;

  const ReportContext({required this.module, this.details = const {}});

  static const int _maxValueLength = 300;

  /// Kontext als Zeilen „Schlüssel: Wert“, auf [Report.maxContextLength]
  /// begrenzt. Leere Werte entfallen.
  String get text {
    final lines = <String>[];

    for (final entry in details.entries) {
      var value = entry.value.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (value.isEmpty) continue;

      if (value.length > _maxValueLength) {
        value = "${value.substring(0, _maxValueLength)}…";
      }

      lines.add("${entry.key}: $value");
    }

    final text = lines.join("\n");

    return text.length > Report.maxContextLength
        ? text.substring(0, Report.maxContextLength)
        : text;
  }
}

/// Eine Nutzermeldung. Enthält bewusst keine Angaben zur Person (keine UID,
/// E-Mail-Adresse, kein Name).
class Report {
  static const int minDescriptionLength = 3;
  static const int maxDescriptionLength = 2000;
  static const int maxContextLength = 1500;

  final ReportKind kind;
  final ReportCategory category;
  final String description;
  final ReportContext context;

  const Report({
    this.kind = ReportKind.report,
    required this.category,
    required this.description,
    required this.context,
  });

  /// Betriebssystem-Familie, kein Gerätemodell und keine Browserkennung.
  static String get platform {
    final os = defaultTargetPlatform.name;

    return kIsWeb ? "web ($os)" : os;
  }

  /// Felder des Firestore-Dokuments (ohne Zeitstempel). Muss zu
  /// `isValidReport` in firestore.rules passen.
  Map<String, Object> toMap() {
    return {
      "kind": kind.name,
      "category": category.id,
      "description": description.trim(),
      "area": context.module.id,
      "areaTitle": context.module.title,
      "context": context.text,
      "appVersion": AppInfo.version,
      "platform": platform,
    };
  }

  /// Dieselben Angaben als Text, z. B. zum Kopieren, wenn das Senden
  /// fehlschlägt.
  String toPlainText() {
    final contextText = context.text;

    return [
      "App: ${AppInfo.name}",
      "Version: ${AppInfo.version}",
      "Plattform: $platform",
      "Bereich: ${context.module.title}",
      "Kategorie: ${category.label}",
      if (contextText.isNotEmpty) contextText,
      "",
      "Beschreibung:",
      description.trim(),
    ].join("\n");
  }
}
