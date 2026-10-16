import 'package:flutter/material.dart';

import '../../../models/greek/perikope.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_outline.dart';
import '../../../services/bible/bible_books.dart';
import '../../../services/bible/bible_repository.dart';
import '../../../services/book_learning_storage.dart';
import '../../../services/learning_service.dart';
import '../../../services/settings_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_access.dart';
import 'book_detail_screen.dart';
import 'book_settings.dart';
import 'book_widgets.dart';
import 'review_overview_screen.dart';

/// Einstieg „Bücher systematisch lernen“: Wiederholungen, Lernpläne und alle
/// Bücher mit ihrem Fortschritt. Ergänzt das Endlos-Quiz, ersetzt es nicht.
class BooksOverviewScreen extends StatefulWidget {
  final List<Perikope> perikopen;

  // null = Gastmodus (lokale Speicherung).
  final String? uid;

  // Nur für Tests ersetzbar; standardmäßig die echten Dienste.
  final BookLearningStorage? storage;
  final LearningService? learningService;
  final SettingsService? settingsService;
  final BibleRepository? bibleRepository;
  final BookOutlines? outlines;
  final DateTime Function()? clock;

  const BooksOverviewScreen({
    super.key,
    required this.perikopen,
    required this.uid,
    this.storage,
    this.learningService,
    this.settingsService,
    this.bibleRepository,
    this.outlines,
    this.clock,
  });

  @override
  State<BooksOverviewScreen> createState() => _BooksOverviewScreenState();
}

class _BooksOverviewScreenState extends State<BooksOverviewScreen> {
  BookLearningController? controller;

  Object? error;

  final TextEditingController search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loaded = await BookLearningController.load(
        perikopen: widget.perikopen,
        uid: widget.uid,
        storage: widget.storage,
        learningService: widget.learningService,
        settingsService: widget.settingsService,
        bibleRepository: widget.bibleRepository,
        outlines: widget.outlines,
        clock: widget.clock,
      );

      if (!mounted) return;

      setState(() => controller = loaded);
    } catch (e) {
      if (!mounted) return;

      setState(() => error = e);
    }
  }

  void _openBook(String book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(controller: controller!, book: book),
      ),
    );
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewOverviewScreen(controller: controller!),
      ),
    );
  }

  bool _matchesSearch(String book) {
    final query = BibleBooks.nameKey(search.text);

    if (query.isEmpty) return true;

    return BibleBooks.nameKey(book).contains(query) ||
        BibleBooks.nameKey(bookName(book)).contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bücher systematisch lernen"),
        actions: [
          if (controller != null)
            BookLearningSettingsButton(controller: controller!)
          else
            const SettingsButton(),
        ],
      ),
      body: c == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Die Lernstände konnten nicht geladen werden.",
                        textAlign: TextAlign.center,
                      ),
                    ),
            )
          : ListenableBuilder(
              listenable: c,
              builder: (context, _) => _buildContent(context, c),
            ),
    );
  }

  Widget _buildContent(BuildContext context, BookLearningController c) {
    final state = c.state;

    final books = c.catalog.books;

    final dueTotal = state.progressOf(c.catalog.all).due;

    final planned = [
      for (final b in books)
        if (state.planOf(b) != null) b,
    ];

    final visible = books.where(_matchesSearch).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          "Lerne die Perikopen ganzer Bücher Schritt für Schritt. Das "
          "Endlos-Quiz bleibt unverändert daneben bestehen.",
          style: TextStyle(color: context.colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const ValueKey("open-reviews"),
            leading: Icon(Icons.schedule_rounded, color: context.colors.accent),
            title: const Text("Wiederholungen"),
            subtitle: Text(
              dueTotal == 0
                  ? "Gerade ist nichts fällig"
                  : "$dueTotal jetzt fällig – auch buchübergreifend",
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openReviews,
          ),
        ),
        if (planned.isNotEmpty) ...[
          const SectionTitle("Meine Lernpläne"),
          for (final b in planned) _bookTile(context, c, b, showPlan: true),
        ],
        const SectionTitle("Alle Bücher"),
        TextField(
          key: const ValueKey("book-search"),
          controller: search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: "Buch suchen, z. B. Markus",
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Kein Buch gefunden.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        for (final b in visible) _bookTile(context, c, b),
      ],
    );
  }

  Widget _bookTile(
    BuildContext context,
    BookLearningController c,
    String book, {
    bool showPlan = false,
  }) {
    final progress = c.state.progressOf(c.catalog.pericopesOf(book));

    final plan = c.state.planOf(book);

    return Card(
      key: ValueKey("${showPlan ? "plan" : "book"}-$book"),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => _openBook(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bookName(book),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  if (showPlan && plan != null)
                    StatusPill(
                      label: plan.paused ? "pausiert" : "aktiv",
                      color: plan.paused
                          ? context.colors.textSecondary
                          : context.colors.primary,
                    ),
                  if (progress.due > 0) ...[
                    const SizedBox(width: 6),
                    StatusPill(
                      label: "${progress.due} fällig",
                      color: context.colors.accent,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                bookSummary(c, book),
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 8),
              LearningProgressBar(progress: progress, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
