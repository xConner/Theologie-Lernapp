import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/confession.dart';

class ConfessionService {
  static const String assetPath = 'assets/confessions.json';

  /// Standardmäßig das App-Bundle; Tests können ein eigenes Bundle übergeben.
  final AssetBundle bundle;

  ConfessionService({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<List<Confession>> loadConfessions() async {
    final String jsonString = await bundle.loadString(assetPath);

    final List<dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((item) => Confession.fromJson(item)).toList();
  }
}
