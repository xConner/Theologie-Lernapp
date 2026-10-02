import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'report.dart';

/// Übertragungsweg für Meldungen. Die Oberfläche kennt nur diese
/// Schnittstelle; ein anderer Weg (z. B. eigenes Backend) lässt sich über
/// [ReportService.sender] einsetzen, ohne das Formular anzupassen.
abstract class ReportSender {
  Future<void> send(Report report);
}

/// Legt Meldungen als neues Dokument in der Collection `reports` ab.
///
/// Die Firestore-Regeln erlauben dort ausschließlich das Anlegen gültiger
/// Dokumente – kein Lesen, Ändern oder Löschen. Nutzerdaten unter `users/`
/// sind davon nicht berührt.
class FirestoreReportSender implements ReportSender {
  static const Duration _timeout = Duration(seconds: 15);

  @override
  Future<void> send(Report report) {
    return FirebaseFirestore.instance
        .collection("reports")
        .add({...report.toMap(), "createdAt": FieldValue.serverTimestamp()})
        .timeout(_timeout);
  }
}

/// Meldungen werden zu schnell hintereinander gesendet.
class ReportThrottledException implements Exception {
  final Duration retryAfter;

  const ReportThrottledException(this.retryAfter);
}

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  /// Nur für Tests bzw. einen späteren anderen Übertragungsweg ersetzen.
  static ReportSender sender = FirestoreReportSender();

  /// Mindestabstand zwischen zwei Meldungen. Bremst versehentliches
  /// Mehrfachsenden; kein Ersatz für eine serverseitige Begrenzung.
  static const Duration cooldown = Duration(seconds: 30);

  DateTime? _lastSent;

  Future<void> submit(Report report) async {
    final last = _lastSent;

    if (last != null) {
      final elapsed = DateTime.now().difference(last);

      if (elapsed < cooldown) {
        throw ReportThrottledException(cooldown - elapsed);
      }
    }

    await sender.send(report);

    _lastSent = DateTime.now();
  }

  /// Nur für Tests.
  void resetCooldown() => _lastSent = null;
}
