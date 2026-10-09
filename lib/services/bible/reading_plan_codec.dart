import 'dart:convert';

import '../../models/bible/bible_translation.dart';
import '../../models/bible/reading_plan.dart';

/// Eine Plandatei ist ungültig; [problems] nennt jede Ursache verständlich.
class ReadingPlanFormatException implements Exception {
  final List<String> problems;

  const ReadingPlanFormatException(this.problems);

  @override
  String toString() => problems.join("\n");
}

/// Liest und schreibt Lesepläne im JSON-Format von theologie.app
/// (`docs/reading-plans.md`). Integrierte und eigene Pläne verwenden
/// dasselbe Format.
class ReadingPlanCodec {
  ReadingPlanCodec._();

  static const String format = "theologie.app/reading-plan";
  static const int formatVersion = 1;

  static const int maxFileLength = 500000;
  static const int maxDays = 1500;
  static const int maxReadingsPerDay = 30;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 1000;

  /// So viele Probleme werden höchstens einzeln genannt.
  static const int _maxProblems = 12;

  static final RegExp idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{1,62}$');

  /// Liest eine Plandatei. Mit [translations] wird jede Lesung daran geprüft,
  /// ob es sie in mindestens einer Ausgabe gibt.
  ///
  /// Wirft [ReadingPlanFormatException] mit allen gefundenen Problemen.
  static ReadingPlan decode(
    String source, {
    List<BibleTranslation>? translations,
    bool builtIn = false,
  }) {
    if (source.trim().isEmpty) {
      throw const ReadingPlanFormatException(["Die Datei ist leer."]);
    }

    if (source.length > maxFileLength) {
      throw const ReadingPlanFormatException([
        "Die Datei ist zu groß (höchstens 500 000 Zeichen).",
      ]);
    }

    Object? json;

    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw ReadingPlanFormatException([
        "Die Datei ist kein gültiges JSON: ${e.message}",
      ]);
    }

    if (json is! Map) {
      throw const ReadingPlanFormatException([
        "Erwartet wird ein JSON-Objekt mit den Feldern „id“, „name“ und "
            "„days“.",
      ]);
    }

    return fromJson(
      Map<String, dynamic>.from(json),
      translations: translations,
      builtIn: builtIn,
    );
  }

  static ReadingPlan fromJson(
    Map<String, dynamic> json, {
    List<BibleTranslation>? translations,
    bool builtIn = false,
  }) {
    final problems = <String>[];
    var hidden = 0;

    void problem(String text) {
      if (problems.length < _maxProblems) {
        problems.add(text);
      } else {
        hidden++;
      }
    }

    final version = json["formatVersion"];

    if (version != null && version != formatVersion) {
      problem(
        "Die Formatversion „$version“ wird nicht unterstützt (erwartet: "
        "$formatVersion).",
      );
    }

    final declared = json["format"];

    if (declared != null && declared != format) {
      problem("Unbekanntes Format „$declared“ (erwartet: „$format“).");
    }

    String? text(String field, {required int max, bool required = false}) {
      final value = json[field];

      if (value == null) {
        if (required) problem("Das Feld „$field“ fehlt.");

        return null;
      }

      if (value is! String) {
        problem("Das Feld „$field“ muss ein Text sein.");

        return null;
      }

      final trimmed = value.trim();

      if (trimmed.isEmpty) {
        if (required) problem("Das Feld „$field“ ist leer.");

        return null;
      }

      if (trimmed.length > max) {
        problem("Das Feld „$field“ ist zu lang (höchstens $max Zeichen).");

        return null;
      }

      return trimmed;
    }

    final id = text("id", max: 63, required: true);

    if (id != null && !idPattern.hasMatch(id)) {
      problem(
        "Die Kennung „$id“ ist ungültig: erlaubt sind 2–63 Zeichen aus "
        "Kleinbuchstaben, Ziffern, Punkt, Binde- und Unterstrich.",
      );
    }

    final name = text("name", max: maxNameLength, required: true);
    final description = text("description", max: maxDescriptionLength);
    final language = text("language", max: 12);
    final category = text("category", max: 40);
    final license = text("license", max: 300);

    ReadingPlanDifficulty? difficulty;

    final rawDifficulty = json["difficulty"];

    if (rawDifficulty != null) {
      difficulty = ReadingPlanDifficulty.parse(rawDifficulty);

      if (difficulty == null) {
        problem(
          "Unbekannter Schwierigkeitsgrad „$rawDifficulty“ (möglich: "
          "${ReadingPlanDifficulty.values.map((d) => d.name).join(", ")}).",
        );
      }
    }

    String? sourceName, sourceUrl, sourceNote;

    final source = json["source"];

    if (source is String) {
      sourceName = source.trim();
    } else if (source is Map) {
      String? part(String key) {
        final value = source[key];

        return value is String && value.trim().isNotEmpty ? value.trim() : null;
      }

      sourceName = part("name");
      sourceUrl = part("url");
      sourceNote = part("note");
    } else if (source != null) {
      problem("Das Feld „source“ muss ein Text oder ein Objekt sein.");
    }

    final days = <ReadingPlanDay>[];

    final rawDays = json["days"];

    if (rawDays is! List) {
      problem(
        rawDays == null
            ? "Das Feld „days“ fehlt."
            : "Das Feld „days“ muss eine Liste der Tage sein.",
      );
    } else if (rawDays.isEmpty) {
      problem("Der Plan enthält keine Tage.");
    } else if (rawDays.length > maxDays) {
      problem("Der Plan hat zu viele Tage (höchstens $maxDays).");
    } else {
      for (var i = 0; i < rawDays.length; i++) {
        final number = i + 1;
        final rawDay = rawDays[i];

        Object? rawReadings = rawDay;
        String? title;

        if (rawDay is Map) {
          rawReadings = rawDay["readings"];

          final rawTitle = rawDay["title"];

          if (rawTitle is String && rawTitle.trim().isNotEmpty) {
            title = rawTitle.trim();
          }
        }

        if (rawReadings is! List) {
          problem(
            "Tag $number: erwartet wird eine Liste von Lesungen oder ein "
            "Objekt mit dem Feld „readings“.",
          );
          continue;
        }

        if (rawReadings.isEmpty) {
          problem("Tag $number enthält keine Lesung.");
          continue;
        }

        if (rawReadings.length > maxReadingsPerDay) {
          problem(
            "Tag $number hat zu viele Lesungen (höchstens "
            "$maxReadingsPerDay).",
          );
          continue;
        }

        final readings = <PlanReading>[];

        for (final raw in rawReadings) {
          final reading = raw is String ? PlanReading.parse(raw) : null;

          if (reading == null) {
            problem(
              "Tag $number: „$raw“ ist keine gültige Stellenangabe "
              "(Beispiele: „GEN 1-3“, „JHN 3:16-21“, „JOL“).",
            );
            continue;
          }

          if (readings.contains(reading)) {
            problem("Tag $number: „${reading.key}“ steht doppelt.");
            continue;
          }

          final invalid = translations == null
              ? null
              : reading.problemIn(translations);

          if (invalid != null) {
            problem("Tag $number, „${reading.key}“: $invalid");
            continue;
          }

          readings.add(reading);
        }

        days.add(ReadingPlanDay(readings: readings, title: title));
      }
    }

    if (problems.isNotEmpty) {
      throw ReadingPlanFormatException([
        ...problems,
        if (hidden > 0) "… und $hidden weitere Probleme.",
      ]);
    }

    return ReadingPlan(
      id: id!,
      name: name!,
      description: description ?? "",
      language: language ?? "de",
      category: category,
      difficulty: difficulty,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      sourceNote: sourceNote,
      license: license,
      days: days,
      builtIn: builtIn,
    );
  }

  static Map<String, dynamic> toJson(ReadingPlan plan) {
    final source = {
      "name": ?plan.sourceName,
      "url": ?plan.sourceUrl,
      "note": ?plan.sourceNote,
    };

    return {
      "format": format,
      "formatVersion": formatVersion,
      "id": plan.id,
      "name": plan.name,
      if (plan.description.isNotEmpty) "description": plan.description,
      "language": plan.language,
      "category": ?plan.category,
      "difficulty": ?plan.difficulty?.name,
      if (source.isNotEmpty) "source": source,
      "license": ?plan.license,
      "days": [
        for (final day in plan.days)
          if (day.title == null)
            [for (final reading in day.readings) reading.key]
          else
            {
              "title": day.title,
              "readings": [for (final reading in day.readings) reading.key],
            },
      ],
    };
  }

  /// Der Plan als Datei: eingerückt, ein Tag je Zeile.
  static String encode(ReadingPlan plan) {
    final json = toJson(plan);
    final days = json.remove("days") as List;

    final head = const JsonEncoder.withIndent("  ").convert(json);

    final buffer = StringBuffer(head.substring(0, head.length - 2))
      ..write(',\n  "days": [\n');

    for (var i = 0; i < days.length; i++) {
      buffer
        ..write("    ")
        ..write(jsonEncode(days[i]))
        ..write(i == days.length - 1 ? "\n" : ",\n");
    }

    buffer.write("  ]\n}\n");

    return buffer.toString();
  }
}
