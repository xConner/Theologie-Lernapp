import 'package:flutter/material.dart';

import '../services/quiz_sound_player.dart';
import '../services/quiz_sound_settings.dart';

/// Lautsprecher-Icon für die AppBar eines Trainers/Quiz: zeigt die aktuelle
/// Lautstärke an und öffnet per Tap ein Popup mit einem stufenlosen Regler
/// für die (für alle Trainer gemeinsame) Sound-Lautstärke.
class SoundVolumeButton extends StatelessWidget {
  const SoundVolumeButton({super.key});

  IconData _icon(double volume) {
    if (volume <= 0) {
      return Icons.volume_off;
    }

    if (volume < 0.5) {
      return Icons.volume_down;
    }

    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final settings = QuizSoundSettings.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return PopupMenuButton<void>(
          icon: Icon(_icon(settings.volume)),
          tooltip: "Lautstärke der Sounds",
          itemBuilder: (context) => [
            PopupMenuItem<void>(
              enabled: false,
              child: _VolumePopupContent(settings: settings),
            ),
          ],
        );
      },
    );
  }
}

class _VolumePopupContent extends StatefulWidget {
  final QuizSoundSettings settings;

  const _VolumePopupContent({required this.settings});

  @override
  State<_VolumePopupContent> createState() => _VolumePopupContentState();
}

class _VolumePopupContentState extends State<_VolumePopupContent> {
  late double _volume = widget.settings.volume;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          Icon(_volume <= 0 ? Icons.volume_off : Icons.volume_up),

          Expanded(
            child: Slider(
              value: _volume,
              min: 0,
              max: 1,
              label: "${(_volume * 100).round()}%",
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });

                widget.settings.setVolume(value);
              },
              onChangeEnd: (value) {
                QuizSoundPlayer.instance.previewVolume();
              },
            ),
          ),
        ],
      ),
    );
  }
}
