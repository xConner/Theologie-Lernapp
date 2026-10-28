import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/philosophy/reading_export.dart';
import '../../../services/philosophy/reading_user_data.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/text_file.dart';
import '../../../widgets/content_page.dart';
import 'reader_screen.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';
import 'sentence_detail.dart';

/// Eigene Stellen: Lesezeichen, Notizen und Wortliste mit Sprung in den
/// Text und Ausfuhr.
class MyPassagesView extends StatelessWidget {
  final ReadingSession session;

  const MyPassagesView({super.key, required this.session});

  Future<void> _export(BuildContext context) async {
    final content = ReadingExport.markdown(session.work!, session.user);
    if (textFilesSupported) {
      saveTextFile("physik-meine-stellen.md", content);
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("In die Zwischenablage kopiert")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final text = session.text!;
    final bookmarks = user.bookmarks;
    final notes = user.notes;
    final words = user.words.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    Widget markTile(ReadingMark m) {
      final preview = m.kind == "w"
          ? "Wort: ${m.word}"
          : sentencePreview(text, m.sentenceId);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: RefLabel(m.sentenceId.split(".").first),
        title: Text(
          m.note.isNotEmpty ? m.note : preview,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: m.note.isNotEmpty
            ? Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: m.kind == "w" ? null : greekStyle(context, scale: 0.7),
              )
            : null,
        onTap: () => openReader(context, session, sentenceId: m.sentenceId),
      );
    }

    return ContentBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Notizen, Lesezeichen und Wortliste hängen an Bekker-Stellen "
                "und gelten für jede Ausgabe.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text("Ausfuhr"),
              onPressed: () => _export(context),
            ),
          ],
        ),
        if (bookmarks.isEmpty && notes.isEmpty && words.isEmpty)
          const EmptyHint(
            "Noch nichts gemerkt. Im Leser einen Satz antippen, um ein "
            "Lesezeichen oder eine Notiz zu setzen; ein Wort antippen, um es "
            "in die Wortliste aufzunehmen.",
          ),
        if (bookmarks.isNotEmpty) ...[
          const ContentSectionTitle("Lesezeichen"),
          for (final m in bookmarks) markTile(m),
        ],
        if (notes.isNotEmpty) ...[
          const ContentSectionTitle("Notizen"),
          for (final m in notes) markTile(m),
        ],
        if (words.isNotEmpty) ...[
          const ContentSectionTitle("Wortliste"),
          for (final w in words)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                w.lemma != null && w.lemma != w.form
                    ? "${w.form}  ·  ${w.lemma}"
                    : w.form,
                style: greekStyle(context, scale: 0.85),
              ),
              subtitle: Text(w.sentenceId.split(".").first),
              onTap: () =>
                  openReader(context, session, sentenceId: w.sentenceId),
              trailing: IconButton(
                tooltip: "Aus der Wortliste entfernen",
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => session.removeWord(w.key),
              ),
            ),
        ],
      ],
    );
  }
}
