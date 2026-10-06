import 'package:flutter/material.dart';

import '../services/streak/streak_service.dart';
import '../services/streak/streak_state.dart';
import '../services/streak/streak_track.dart';
import '../theme/app_theme.dart';

String formatStreakDays(int days) => days == 1 ? "1 Tag" : "$days Tage";

/// Meldet eine von der bestehenden Trainerlogik als richtig bewertete
/// Antwort an den [StreakService] und zeigt beim Erreichen des Tagesziels
/// eine kurze Erfolgsmeldung. Blockiert den Trainer nicht.
void recordStreakAnswer(
  BuildContext context, {
  required String? uid,
  required StreakTrack track,
  required String source,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);

  StreakService.instance
      .recordCorrectAnswer(uid: uid, track: track, source: source)
      .then((update) {
        if (update == null || !update.goalReachedNow || messenger == null) {
          return;
        }

        messenger.showSnackBar(streakSnackBar(track, update));
      }, onError: (_) {});
}

SnackBar streakSnackBar(StreakTrack track, StreakUpdate update) {
  final title = update.streakStarted
      ? "🔥 ${track.streakStartedMessage ?? "${track.label}-Streak gestartet!"}"
      : "🔥 Streak fortgeführt!";

  return SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (!update.streakStarted)
          Text("${track.label} · ${formatStreakDays(update.currentStreak)}"),
      ],
    ),
  );
}

/// Lädt die Streaks für [uid] beim ersten Anzeigen und baut bei Änderungen
/// neu auf.
class _StreakBuilder extends StatefulWidget {
  final String? uid;
  final bool refresh;
  final WidgetBuilder builder;

  const _StreakBuilder({
    required this.uid,
    required this.builder,
    this.refresh = false,
  });

  @override
  State<_StreakBuilder> createState() => _StreakBuilderState();
}

class _StreakBuilderState extends State<_StreakBuilder> {
  @override
  void initState() {
    super.initState();

    StreakService.instance.load(widget.uid, refresh: widget.refresh);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StreakService.instance,
      builder: (context, _) => widget.builder(context),
    );
  }
}

Widget _flame(BuildContext context, bool active, {double size = 20}) {
  return Icon(
    Icons.local_fire_department_rounded,
    size: size,
    color: active ? context.colors.accent : context.colors.divider,
  );
}

/// Kompakte Übersicht aller Tracks für die Startseite.
class StreakSummary extends StatelessWidget {
  final String? uid;
  final List<StreakTrack> tracks;

  const StreakSummary({
    super.key,
    required this.uid,
    this.tracks = StreakTrack.all,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _StreakBuilder(
      uid: uid,
      refresh: true,
      builder: (context) {
        // Nur bestehende Streaks anzeigen (keine "0 Tage").
        final active = [
          for (final track in tracks)
            (track, StreakService.instance.snapshotFor(uid, track)),
        ].where((entry) => entry.$2.currentStreak > 0).toList();

        if (active.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  for (final (track, s) in active)
                    Builder(
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              _flame(context, true),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  track.label,
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                              if (s.completedToday) ...[
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: context.colors.success,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                formatStreakDays(s.currentStreak),
                                style: textTheme.titleSmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ausführliche Streak-Ansicht eines Tracks (Sprach-Screen, Perikopenquiz).
class StreakDetailCard extends StatelessWidget {
  final String? uid;
  final StreakTrack track;

  /// Für Tracks, deren Tagesziel eine einzelne Lernaktivität ist (Texte
  /// auswendig lernen): erklärt, was den Tag erfüllt, statt eines Zählers.
  /// Ohne Angabe gilt der Zähler richtiger Antworten des Tracks.
  final String? todayHint;

  const StreakDetailCard({
    super.key,
    required this.uid,
    required this.track,
    this.todayHint,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );

    return _StreakBuilder(
      uid: uid,
      builder: (context) {
        final s = StreakService.instance.snapshotFor(uid, track);

        final hint = todayHint;

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _flame(context, s.currentStreak > 0, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.currentStreak > 0
                            ? "${formatStreakDays(s.currentStreak)} Streak"
                            : "Noch keine aktive Streak",
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(child: Text("Heute", style: textTheme.titleSmall)),
                    Text(
                      s.completedToday
                          ? "Tagesziel erreicht"
                          : hint != null
                          ? "Noch offen"
                          : "${s.todayCorrectAnswers}/${s.dailyGoal}",
                      style: s.completedToday
                          ? textTheme.titleSmall?.copyWith(
                              color: context.colors.success,
                            )
                          : textTheme.titleSmall,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                if (hint != null)
                  Text(
                    hint,
                    key: const Key("streak_today_hint"),
                    style: secondary,
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: s.completedToday ? 1.0 : s.todayProgress,
                      minHeight: 8,
                      backgroundColor: context.colors.surfaceMuted,
                      color: s.completedToday
                          ? context.colors.success
                          : context.colors.accent,
                    ),
                  ),

                if (s.currentStreak > 0) ...[
                  const SizedBox(height: 14),

                  Text("Deine Streak", style: textTheme.titleSmall),

                  const SizedBox(height: 4),

                  _row("Aktuell", formatStreakDays(s.currentStreak), secondary),
                  _row("Längste", formatStreakDays(s.longestStreak), secondary),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Kleiner AppBar-Button mit der aktuellen Streak; öffnet die Detailansicht.
class StreakAppBarButton extends StatelessWidget {
  final String? uid;
  final StreakTrack track;

  const StreakAppBarButton({super.key, required this.uid, required this.track});

  @override
  Widget build(BuildContext context) {
    return _StreakBuilder(
      uid: uid,
      builder: (context) {
        final s = StreakService.instance.snapshotFor(uid, track);

        return TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: StreakDetailCard(uid: uid, track: track),
              ),
            ),
          ),
          icon: _flame(context, s.currentStreak > 0),
          label: Text("${s.currentStreak}"),
        );
      },
    );
  }
}
