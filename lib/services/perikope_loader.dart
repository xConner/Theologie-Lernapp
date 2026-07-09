import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/perikope.dart';

class PerikopeLoader {
  static Future<List<Perikope>> load() async {
    // 1. Default Bibliothek aus der App laden
    final data = await rootBundle.loadString('assets/perikopen.json');

    final List decoded = jsonDecode(data);

    final List<Perikope> pericopes = decoded
        .map((e) => Perikope.fromJson(e))
        .toList();

    // 2. Aktuellen Nutzer bestimmen
    final user = FirebaseAuth.instance.currentUser;

    // Kein eingeloggter Nutzer → nur Default-Bibliothek verwenden
    if (user == null) {
      return pericopes;
    }

    // 3. User Overrides laden
    final overrideDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("pericope_overrides")
        .doc("config")
        .get();

    if (!overrideDoc.exists) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pericope_overrides")
          .doc("config")
          .set({"items": [], "deleted": []});

      return pericopes;
    }

    final overrideData = overrideDoc.data();

    if (overrideData == null) {
      return pericopes;
    }

    // 4. Gelöschte Perikopen entfernen
    final deleted = List<String>.from(overrideData["deleted"] ?? []);

    pericopes.removeWhere((p) => deleted.contains(p.id));

    // 5. Überschreiben oder neue Perikopen hinzufügen
    final overrides = List<Map<String, dynamic>>.from(
      (overrideData["items"] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    for (final override in overrides) {
      final id = override["id"];

      final index = pericopes.indexWhere((p) => p.id == id);

      final replacement = Perikope.fromJson(override);

      if (index >= 0) {
        // Bestehende Default-Perikope durch Nutzer-Version ersetzen
        pericopes[index] = replacement;
      } else {
        // Neue Nutzer-Perikope hinzufügen
        pericopes.add(replacement);
      }
    }

    return pericopes;
  }
}
