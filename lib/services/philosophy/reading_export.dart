import '../../models/philosophy/reading_work.dart';
import 'reading_user_data.dart';

/// Ausfuhr der eigenen Notizen, Lesezeichen und der Wortliste als
/// Markdown. Enthalten sind nur Stellenangaben und eigene Texte, nie der
/// Text der Ausgabe – die Datei darf deshalb weitergegeben werden.
class ReadingExport {
  static String markdown(
    ReadingWork work,
    ReadingUserState user, {
    DateTime? now,
  }) {
    final date = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    final out = StringBuffer()
      ..writeln("# ${work.displayTitle} – Meine Stellen")
      ..writeln()
      ..writeln("Stand: $date. Stellen nach ${work.citation}.")
      ..writeln();

    final marks = user.marks.values.toList()
      ..sort((a, b) => _order(a.sentenceId).compareTo(_order(b.sentenceId)));

    final bookmarks = [for (final m in marks) if (m.bookmark) m];
    if (bookmarks.isNotEmpty) {
      out
        ..writeln("## Lesezeichen")
        ..writeln();
      for (final m in bookmarks) {
        out.writeln("- ${_label(m)}");
      }
      out.writeln();
    }

    final notes = [for (final m in marks) if (m.note.trim().isNotEmpty) m];
    if (notes.isNotEmpty) {
      out
        ..writeln("## Notizen")
        ..writeln();
      for (final m in notes) {
        out.writeln("- **${_label(m)}**: ${m.note.trim().replaceAll("\n", "\n  ")}");
      }
      out.writeln();
    }

    if (user.words.isNotEmpty) {
      out
        ..writeln("## Wortliste")
        ..writeln();
      final words = user.words.values.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final w in words) {
        final lemma = w.lemma == null || w.lemma == w.form ? "" : " (${w.lemma})";
        out.writeln("- ${w.form}$lemma – ${_ref(w.sentenceId)}");
      }
      out.writeln();
    }

    if (bookmarks.isEmpty && notes.isEmpty && user.words.isEmpty) {
      out.writeln("Noch keine Lesezeichen, Notizen oder Wörter.");
    }
    return out.toString();
  }

  /// Bekker-Stelle aus einer Satzkennung („184a10.2“ → „184a10“).
  static String _ref(String sentenceId) => sentenceId.split(".").first;

  static String _label(ReadingMark m) => switch (m.kind) {
    "w" => "${_ref(m.sentenceId)}, Wort „${m.word}“",
    "u" => "Abschnitt ${_ref(m.sentenceId)}",
    _ => _ref(m.sentenceId),
  };

  static int _order(String sentenceId) {
    final match = RegExp(r'^(\d+)([ab])(\d+)').firstMatch(sentenceId);
    if (match == null) return 0;
    return int.parse(match[1]!) * 200 +
        (match[2] == "a" ? 0 : 100) +
        int.parse(match[3]!);
  }
}
