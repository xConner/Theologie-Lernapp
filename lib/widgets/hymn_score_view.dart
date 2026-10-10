import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hymn_score.dart';

/// Breite, bis zu der ein Notenbild mitwächst. Die Bilder sind für schmale
/// Bildschirme umbrochen; breiter gezogen würden die Noten nur riesig.
const double _maxScoreWidth = 520;

/// Schrift des Textes in den Notenbildern (siehe `pubspec.yaml`); auch die
/// weiteren Strophen unter den Noten stehen in ihr.
const String scoreTextFont = "Tinos";

/// Notenbilder eines Liedes mit Quellenangabe.
///
/// Ein Bild zeigt die Melodie und – wie im Gesangbuch – die erste Strophe
/// Silbe für Silbe unter den Noten. Wo die Silben den Tönen noch nicht
/// gesichert zugeordnet sind, zeigt es die Melodie allein; ein Hinweis sagt
/// das, und der Text folgt wie gewohnt darunter.
///
/// Die Bilder sind einfarbig und werden in der Textfarbe des Themes
/// eingefärbt, damit sie im hellen wie im dunklen Design lesbar sind. Ein
/// Tipp öffnet das Bild zum Vergrößern. Lässt sich ein Bild nicht laden,
/// erscheint an seiner Stelle ein kurzer Hinweis.
class HymnScoreView extends StatelessWidget {
  final List<HymnScore> scores;

  /// Ob das Lied in der App einen Text hat (sonst entfällt der Hinweis auf
  /// die fehlende Unterlegung).
  final bool hasLyrics;

  const HymnScoreView({super.key, required this.scores, this.hasLyrics = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final score in scores)
          _ScoreItem(
            // Der Schlüssel bindet Bild und Zustand an die Melodie.
            key: ValueKey("hymn_score_${score.id}"),
            score: score,
            showLabel: scores.length > 1,
            showUnderlayHint: hasLyrics && !score.hasUnderlay,
          ),
      ],
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final HymnScore score;
  final bool showLabel;
  final bool showUnderlayHint;

  const _ScoreItem({
    super.key,
    required this.score,
    required this.showLabel,
    required this.showUnderlayHint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(score.label, style: theme.textTheme.titleSmall),
            ),

          Semantics(
            label: score.hasUnderlay
                ? "Noten mit Text der ersten Strophe: ${score.label}"
                : "Noten der Melodie: ${score.label}",
            button: true,
            // Kein InkWell: Dessen Hover- und Druckfarbe legte sich als
            // Schleier über das ganze Notenblatt.
            child: MouseRegion(
              cursor: SystemMouseCursors.zoomIn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HymnScoreZoomScreen(score)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxScoreWidth),
                  child: ScoreImage(score: score),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          if (showUnderlayHint)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                "Melodie ohne unterlegten Text – die Silben sind diesen "
                "Noten noch nicht zugeordnet.",
                key: const Key("hymn_score_no_underlay"),
                style: secondary,
              ),
            ),

          _SourceLine(score: score, style: secondary),
        ],
      ),
    );
  }
}

/// Das eingefärbte Notenbild in voller verfügbarer Breite.
///
/// Die Datei wird hier selbst aus dem Bundle gelesen, damit eine fehlende
/// oder unlesbare Datei als Hinweis endet und nicht als unbehandelter Fehler.
class ScoreImage extends StatefulWidget {
  final HymnScore score;

  const ScoreImage({super.key, required this.score});

  @override
  State<ScoreImage> createState() => _ScoreImageState();
}

class _ScoreImageState extends State<ScoreImage> {
  Future<String>? svg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    svg ??= load();
  }

  @override
  void didUpdateWidget(ScoreImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.score.asset != widget.score.asset) svg = load();
  }

  Future<String> load() {
    return DefaultAssetBundle.of(context).loadString(widget.score.asset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final error = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        "Die Noten konnten nicht geladen werden.",
        key: const Key("hymn_score_error"),
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
    );

    return FutureBuilder<String>(
      future: svg,
      builder: (context, snapshot) {
        if (snapshot.hasError) return error;

        final data = snapshot.data;

        if (data == null) return const SizedBox(height: 48);

        // Die Höhe ergibt sich aus der Breite; flutter_svg braucht dafür
        // eine feste Breite statt „so breit wie möglich“.
        return LayoutBuilder(
          builder: (context, constraints) => SvgPicture.string(
            data,
            width: constraints.maxWidth,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topLeft,
            colorFilter: ColorFilter.mode(
              theme.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
            placeholderBuilder: (_) => const SizedBox(height: 48),
            errorBuilder: (context, _, _) => error,
          ),
        );
      },
    );
  }
}

class _SourceLine extends StatelessWidget {
  final HymnScore score;
  final TextStyle? style;

  const _SourceLine({required this.score, required this.style});

  @override
  Widget build(BuildContext context) {
    final source = score.source;
    final parts = [
      if (source.author.isNotEmpty) "Vorlage: ${source.author}",
      if (source.name.isNotEmpty || source.license.isNotEmpty)
        [source.name, source.license].where((p) => p.isNotEmpty).join(", "),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    final text = Text(parts.join(" · "), style: style);
    final uri = Uri.tryParse(source.url);

    if (source.url.isEmpty || uri == null) return text;

    return InkWell(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: text,
    );
  }
}

/// Einzelnes Notenbild zum Vergrößern und Verschieben.
class HymnScoreZoomScreen extends StatelessWidget {
  final HymnScore score;

  const HymnScoreZoomScreen(this.score, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(score.label)),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        constrained: false,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ScoreImage(score: score),
          ),
        ),
      ),
    );
  }
}
