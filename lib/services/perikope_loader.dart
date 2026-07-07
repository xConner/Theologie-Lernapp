// lib/services/perikope_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/perikope.dart';

class PerikopeLoader {
  static Future<List<Perikope>> load() async {
    final data = await rootBundle.loadString('assets/perikopen.json');

    final List decoded = jsonDecode(data);

    return decoded.map((e) => Perikope.fromJson(e)).toList();
  }
}
