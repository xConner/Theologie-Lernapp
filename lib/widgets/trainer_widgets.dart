import 'package:flutter/material.dart';

import '../services/quiz_sound_player.dart';
import '../services/quiz_sound_settings.dart';
import '../services/statistics/learning_statistics.dart';
import '../services/statistics/statistics_service.dart';
import '../services/streak/streak_track.dart';
import '../theme/app_theme.dart';
import 'settings_selection.dart';
import 'streak_widgets.dart';

/// Gemeinsame Bausteine der Trainer (Vokabeln, Grammatik, Perikopenquiz).
///
/// Hier liegt nur, was in allen Trainern identisch ist. Frageauswahl,
/// Antwortprüfung und Einstellungen bleiben Sache des jeweiligen Trainers.

/// Rahmen eines Eingabefelds nach der Auswertung: grün bzw. rot, vor der
/// Auswertung (`null`) der normale Rahmen.
OutlineInputBorder answerResultBorder(bool? correct) {
  if (correct == null) {
    return const OutlineInputBorder();
  }

  return OutlineInputBorder(
    borderSide: BorderSide(
      color: correct ? AppColors.success : AppColors.error,
      width: 2,
    ),
  );
}

/// Verbucht eine ausgewertete Antwort außerhalb des Lernstands: Sound,
/// Tagesstatistik und Streak.
///
/// Statistik und Streak zählen nur die erste Auswertung einer Frage
/// ([firstEvaluation]), der Streak nur richtige Antworten. Nichts davon
/// blockiert den Trainer oder kann ihn durch Fehler beeinflussen.
void reportTrainerAnswer(
  BuildContext context, {
  required String? uid,
  required bool correct,
  required bool firstEvaluation,
  required SoundModule sound,
  required StatisticsTrainer trainer,
  required StreakTrack track,
  required String source,
}) {
  if (correct) {
    QuizSoundPlayer.instance.playCorrect(sound);
  } else {
    QuizSoundPlayer.instance.playIncorrect(sound);
  }

  if (!firstEvaluation) {
    return;
  }

  LearningStatisticsService.instance.recordAnswer(
    uid: uid,
    trainer: trainer,
    correct: correct,
  );

  if (correct && context.mounted) {
    recordStreakAnswer(context, uid: uid, track: track, source: source);
  }
}

/// Abschnitt „Sounds“ eines Trainer-Einstellungsdialogs: Richtig- und
/// Falsch-Sound des Moduls. Die Schalter wirken sofort (lokal gespeichert).
class SoundSettingsSection extends StatelessWidget {
  final SoundModule module;

  const SoundSettingsSection({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final settings = QuizSoundSettings.instance;

    return SettingsSection(
      title: "Sounds",
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return SettingsSwitchGroup(
            children: [
              SwitchListTile(
                title: const Text("Sound bei richtiger Antwort"),
                value: settings.isCorrectSoundEnabled(module),
                onChanged: (value) {
                  settings.setCorrectSoundEnabled(module, value);
                },
              ),

              SwitchListTile(
                title: const Text("Sound bei falscher Antwort"),
                value: settings.isWrongSoundEnabled(module),
                onChanged: (value) {
                  settings.setWrongSoundEnabled(module, value);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Eigene Lernhilfe zu einer Vokabel: anzeigen, anlegen und bearbeiten.
///
/// [onSave] erhält den bereinigten Text (`null` = Lernhilfe entfernt) und
/// speichert ihn; danach wird die Bearbeitung geschlossen.
class MnemonicSection extends StatefulWidget {
  final String? mnemonic;
  final Future<void> Function(String? mnemonic) onSave;

  const MnemonicSection({
    super.key,
    required this.mnemonic,
    required this.onSave,
  });

  @override
  State<MnemonicSection> createState() => _MnemonicSectionState();
}

class _MnemonicSectionState extends State<MnemonicSection> {
  final TextEditingController _controller = TextEditingController();

  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  void _edit(String text) {
    _controller.text = text;

    setState(() {
      _editing = true;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();

    await widget.onSave(text.isEmpty ? null : text);

    if (!mounted) {
      return;
    }

    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mnemonic = widget.mnemonic;

    if (_editing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Lernhilfe",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Speichern"),
                onPressed: _save,
              ),
            ],
          ),
        ),
      );
    }

    if (mnemonic != null && mnemonic.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "Lernhilfe",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    Text(mnemonic, textAlign: TextAlign.center),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(mnemonic),
              ),
            ],
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.add),
      label: const Text("Lernhilfe hinzufügen"),
      onPressed: () => _edit(""),
    );
  }
}
