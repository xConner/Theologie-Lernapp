import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/greek_vocabulary_entry.dart';

class GreekVocabularyLoader {
  static Future<List<GreekVocabularyEntry>> load() async {
    final jsonString = await rootBundle.loadString(
      "assets/greek_vocabulary.json",
    );

    final List<dynamic> json = jsonDecode(jsonString);

    return json.map((e) => GreekVocabularyEntry.fromJson(e)).toList();
  }
}
