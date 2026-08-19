import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';

class LatinVocabularyLoader {
  static Future<List<LatinVocabularyEntry>> load() async {
    final jsonString = await rootBundle.loadString(
      "assets/latin_vocabulary.json",
    );

    final List<dynamic> json = jsonDecode(jsonString);

    return json.map((e) => LatinVocabularyEntry.fromJson(e)).toList();
  }
}
