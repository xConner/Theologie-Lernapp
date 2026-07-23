import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hymn.dart';

class HymnService {
  Future<List<Hymn>> loadHymns() async {
    final String jsonString = await rootBundle.loadString(
      'assets/eg_lieder.json',
    );

    final List<dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((e) => Hymn.fromJson(e)).toList();
  }
}
