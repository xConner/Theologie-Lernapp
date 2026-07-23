import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/confession.dart';

class ConfessionService {
  Future<List<Confession>> loadConfessions() async {
    final response = await http.get(
      Uri.parse("http://localhost:8000/confessions.json"),
    );

    final jsonData = json.decode(response.body);

    return jsonData
        .map<Confession>((item) => Confession.fromJson(item))
        .toList();
  }
}
