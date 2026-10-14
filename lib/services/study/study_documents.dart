import 'dart:convert';

import 'package:flutter/services.dart';

// Offizielle Studienunterlagen der Theologischen Fakultät der CAU Kiel.
// Die Metadaten stehen zentral in assets/study/documents.json und verweisen
// nur auf die Originalquellen (keine Kopien). Prüfung der Links:
// .github/workflows/study-documents.yml (tool/study_documents/).

/// Wie verlässlich die Gültigkeit feststeht.
enum DocumentStatus {
  /// Die offizielle Fundstelle führt das Dokument als geltend bzw. aktuell.
  current("Aktuell"),

  /// Es gibt eine neuere Fassung für denselben Studiengang.
  older("Ältere Fassung"),

  /// Nicht sicher feststellbar – bitte an der Originalquelle prüfen.
  unclear("Gültigkeit prüfen");

  final String label;
  const DocumentStatus(this.label);

  static DocumentStatus fromName(Object? name) => DocumentStatus.values
      .firstWhere((s) => s.name == name, orElse: () => DocumentStatus.unclear);
}

class StudyDocument {
  final String id;
  final String title;
  final String? officialTitle;
  final String description;
  final List<String> programs;
  final String publisher;
  final Uri url;
  final Uri? sourcePage;

  /// PDF oder Informationsseite.
  final bool isPdf;
  final DocumentStatus status;
  final String? version;
  final String validity;

  const StudyDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.programs,
    required this.publisher,
    required this.url,
    required this.status,
    required this.validity,
    this.officialTitle,
    this.sourcePage,
    this.isPdf = true,
    this.version,
  });

  static StudyDocument? tryFromJson(Map<String, dynamic> json) {
    final id = json["id"];
    final title = json["title"];
    final url = Uri.tryParse("${json["url"] ?? ""}");
    if (id is! String ||
        title is! String ||
        url == null ||
        !isOfficialUrl(url)) {
      return null;
    }
    final source = Uri.tryParse("${json["sourcePage"] ?? ""}");
    return StudyDocument(
      id: id,
      title: title,
      officialTitle: json["officialTitle"] is String
          ? json["officialTitle"] as String
          : null,
      description: json["description"] is String
          ? json["description"] as String
          : "",
      programs: [
        if (json["programs"] is List)
          for (final p in json["programs"] as List)
            if (p is String) p,
      ],
      publisher: json["publisher"] is String ? json["publisher"] as String : "",
      url: url,
      sourcePage: source != null && isOfficialUrl(source) ? source : null,
      isPdf: json["format"] != "page",
      status: DocumentStatus.fromName(json["status"]),
      version: json["version"] is String ? json["version"] as String : null,
      validity: json["validity"] is String ? json["validity"] as String : "",
    );
  }
}

class DocumentGroup {
  final String id;
  final String title;
  final List<StudyDocument> documents;

  const DocumentGroup(this.id, this.title, this.documents);
}

class StudyDocuments {
  /// Studiengang-Kürzel → Bezeichnung.
  final Map<String, String> programs;
  final List<DocumentGroup> groups;
  final String checkedAt;
  final String notice;

  const StudyDocuments({
    required this.programs,
    required this.groups,
    required this.checkedAt,
    required this.notice,
  });

  static const String asset = "assets/study/documents.json";

  factory StudyDocuments.fromJson(Map<String, dynamic> json) {
    final programs = <String, String>{
      if (json["programs"] is Map)
        for (final e in (json["programs"] as Map).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
    };
    return StudyDocuments(
      programs: programs,
      checkedAt: json["checkedAt"] is String ? json["checkedAt"] as String : "",
      notice: json["notice"] is String ? json["notice"] as String : "",
      groups: [
        if (json["groups"] is List)
          for (final g in json["groups"] as List)
            if (g is Map && g["id"] is String && g["title"] is String)
              DocumentGroup(g["id"] as String, g["title"] as String, [
                if (g["documents"] is List)
                  for (final d in g["documents"] as List)
                    if (d is Map)
                      ?StudyDocument.tryFromJson(Map<String, dynamic>.from(d)),
              ]),
      ],
    );
  }

  static Future<StudyDocuments> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    return StudyDocuments.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  /// Dokumente eines Studiengangs (bzw. alle mit [program] == null).
  /// Übergreifende Ordnungen (alle Studiengänge, alle BA/MA, Zwei-Fächer)
  /// gehören zu den Studiengängen, für die sie gelten.
  List<DocumentGroup> filtered({String? program, bool includeOlder = true}) => [
    for (final g in groups)
      DocumentGroup(g.id, g.title, [
        for (final d in g.documents)
          if ((includeOlder || d.status != DocumentStatus.older) &&
              (program == null || appliesTo(d, program)))
            d,
      ]),
  ];

  static bool appliesTo(StudyDocument d, String program) {
    if (d.programs.contains(program) || d.programs.contains("alle")) {
      return true;
    }
    // Übergreifende CAU-Ordnungen: Bachelor-/Masterstudiengänge bzw. die
    // Zwei-Fächer-Studiengänge (Lehramt).
    if (d.programs.contains("bama") &&
        (program == "lehramt" || program == "ma-re")) {
      return true;
    }
    return d.programs.contains("zwei-faecher") && program == "lehramt";
  }
}

/// Nur Originalquellen: CAU Kiel und Nordkirche, nur HTTPS.
bool isOfficialUrl(Uri url) {
  if (url.scheme != "https") return false;
  final host = url.host.toLowerCase();
  return host == "uni-kiel.de" ||
      host.endsWith(".uni-kiel.de") ||
      host == "nordkirche.de" ||
      host.endsWith(".nordkirche.de") ||
      host == "www.kirchenrecht-nordkirche.de";
}
