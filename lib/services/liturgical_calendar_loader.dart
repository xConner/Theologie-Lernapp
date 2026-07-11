import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/liturgical_day.dart';

class LiturgicalCalendarLoader {
  static Future<List<LiturgicalDay>> load() async {
    final jsonString = await rootBundle.loadString(
      "assets/liturgical_calendar_2026.json",
    );

    final List<dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((entry) => LiturgicalDay.fromJson(entry)).toList();
  }
}
