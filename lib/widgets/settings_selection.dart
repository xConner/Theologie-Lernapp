import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gemeinsame Auswahl-Bausteine der Trainer. Je Art der Auswahl gibt es genau
/// eine Darstellung, damit sie überall gleich gelesen wird:
///
/// * Mehrfachauswahl → [MultiSelectSection]: Chips mit Häkchen, Zähler und
///   „Alle auswählen“.
/// * Einzelauswahl aus wenigen Optionen → [SingleSelectChips].
/// * An/Aus → `SwitchListTile` in einer [SettingsSwitchGroup].

/// Abschnitt eines Einstellungsdialogs: Überschrift, optionaler Hinweis und
/// optionale Aktion rechts neben der Überschrift.
class SettingsSection extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget? action;
  final Widget child;

  const SettingsSection({
    super.key,
    required this.title,
    this.hint,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap statt Row: Auf sehr schmalen Dialogen rutscht die Aktion
          // unter die Überschrift, statt überzulaufen.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),

          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                hint!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),

          child,
        ],
      ),
    );
  }
}

/// Auswählbarer Chip im App-Design. Ausgewählt = gefüllt in der Hauptfarbe,
/// nicht ausgewählt = gedeckt wie ein leeres Eingabefeld.
///
/// [showCheckmark] kennzeichnet Mehrfachauswahl. Mit [correct] wird ein
/// ausgewählter Chip nach der Auswertung grün bzw. rot dargestellt.
/// `onSelected == null` sperrt den Chip, der Zustand bleibt erkennbar.
class SelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool showCheckmark;
  final bool? correct;

  const SelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.showCheckmark = true,
    this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Color border;

    if (selected) {
      background = correct == null
          ? AppColors.primary
          : correct!
          ? AppColors.success
          : AppColors.error;
      foreground = Colors.white;
      border = background;
    } else {
      background = AppColors.surfaceMuted;
      foreground = onSelected == null
          ? AppColors.textSecondary
          : AppColors.textPrimary;
      border = AppColors.divider;
    }

    // Mindestbreite, damit auch kurze Bezeichnungen wie „m“ gut treffbar sind.
    final labelWidget = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 24),
      child: Text(label, textAlign: TextAlign.center),
    );

    final color = WidgetStatePropertyAll<Color>(background);

    final labelStyle = TextStyle(
      color: foreground,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    final side = BorderSide(color: border);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    );

    if (showCheckmark) {
      return FilterChip(
        label: labelWidget,
        selected: selected,
        onSelected: onSelected,
        checkmarkColor: foreground,
        color: color,
        labelStyle: labelStyle,
        side: side,
        shape: shape,
      );
    }

    return ChoiceChip(
      label: labelWidget,
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      color: color,
      labelStyle: labelStyle,
      side: side,
      shape: shape,
    );
  }
}

/// Zeile unter einer Mehrfachauswahl: Anzahl der ausgewählten Optionen oder,
/// wenn nichts ausgewählt ist, der Fehlerhinweis [emptyError].
class SelectionStatus extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final String emptyError;

  const SelectionStatus({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.emptyError,
  });

  @override
  Widget build(BuildContext context) {
    final empty = selectedCount == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Text(
        empty ? emptyError : "$selectedCount von $totalCount ausgewählt",
        style: TextStyle(
          color: empty ? AppColors.error : AppColors.textSecondary,
          fontWeight: empty ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}

/// Mehrfachauswahl als Abschnitt: alle Optionen sind direkt sichtbar, die
/// ausgewählten hervorgehoben und mit Häkchen versehen.
class MultiSelectSection<T> extends StatelessWidget {
  final String title;
  final String? hint;
  final List<T> options;
  final bool Function(T option) isSelected;
  final String Function(T option) labelOf;
  final void Function(T option, bool selected) onChanged;

  /// Wählt alle Optionen aus bzw. ab (wenn bereits alle ausgewählt sind).
  final VoidCallback onToggleAll;

  final String emptyError;

  const MultiSelectSection({
    super.key,
    required this.title,
    this.hint,
    required this.options,
    required this.isSelected,
    required this.labelOf,
    required this.onChanged,
    required this.onToggleAll,
    required this.emptyError,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = options.where(isSelected).length;
    final allSelected = selectedCount == options.length;

    return SettingsSection(
      title: title,
      hint: hint,
      action: TextButton(
        onPressed: onToggleAll,
        child: Text(allSelected ? "Alle abwählen" : "Alle auswählen"),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final option in options)
                SelectionChip(
                  label: labelOf(option),
                  selected: isSelected(option),
                  onSelected: (value) => onChanged(option, value),
                ),
            ],
          ),

          SelectionStatus(
            selectedCount: selectedCount,
            totalCount: options.length,
            emptyError: emptyError,
          ),
        ],
      ),
    );
  }
}

/// Einzelauswahl aus wenigen Optionen: alle Optionen sind direkt antippbar,
/// genau eine ist ausgewählt. `onChanged == null` sperrt die Auswahl.
///
/// [correct] färbt Beschriftung und ausgewählten Chip nach der Auswertung.
class SingleSelectChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool? correct;

  const SingleSelectChips({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final resultColor = correct == null
        ? null
        : correct!
        ? AppColors.success
        : AppColors.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: resultColor ?? AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (resultColor != null) ...[
              const SizedBox(width: 4),
              Icon(
                correct! ? Icons.check_rounded : Icons.close_rounded,
                size: 16,
                color: resultColor,
              ),
            ],
          ],
        ),

        Wrap(
          spacing: 8,
          children: [
            for (final option in options)
              SelectionChip(
                label: option,
                selected: option == value,
                showCheckmark: false,
                correct: option == value ? correct : null,
                onSelected: onChanged == null
                    ? null
                    : (_) => onChanged!(option),
              ),
          ],
        ),
      ],
    );
  }
}

/// Gruppe von An/Aus-Einstellungen (`SwitchListTile`) in einer Karte, wie in
/// den Benachrichtigungseinstellungen.
class SettingsSwitchGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsSwitchGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}
