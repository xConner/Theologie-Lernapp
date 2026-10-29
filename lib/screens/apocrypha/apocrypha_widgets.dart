import 'package:flutter/material.dart';

import '../../models/apocrypha/apocrypha.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/hymn_score_view.dart' show scoreTextFont;

/// Schrift je Sprache: Tinos für polytonisches Griechisch, Noto Sans für
/// Koptisch und Ge'ez; sonst die Schrift der App.
TextStyle apocryphaTextStyle(
  BuildContext context,
  String language, {
  double scale = 1,
  Color? color,
}) {
  final base = TextStyle(
    height: 1.55,
    color: color ?? context.colors.textPrimary,
    fontFamilyFallback: const [
      scoreTextFont,
      "NotoSansCoptic",
      "NotoSansEthiopic",
    ],
  );
  return switch (language) {
    "grc" => base.copyWith(fontFamily: scoreTextFont, fontSize: 18.5 * scale),
    "cop" => base.copyWith(fontFamily: "NotoSansCoptic", fontSize: 18 * scale),
    "gez" => base.copyWith(
      fontFamily: "NotoSansEthiopic",
      fontSize: 18 * scale,
      height: 1.7,
    ),
    _ => base.copyWith(fontSize: 16 * scale),
  };
}

/// Textrichtung je Sprache (Syrisch und Hebräisch von rechts).
TextDirection apocryphaTextDirection(String language) =>
    language == "syr" || language == "he"
    ? TextDirection.rtl
    : TextDirection.ltr;

Color coverageColor(BuildContext context, Coverage c) => switch (c) {
  Coverage.full => context.colors.success,
  Coverage.external => context.colors.textSecondary,
  _ => context.colors.accent,
};

Color rightsColor(BuildContext context, Rights r) =>
    r.allowsText ? context.colors.primary : context.colors.error;

/// Kennzeichnungen eines Werks in Listen.
class WorkTags extends StatelessWidget {
  final ApocryphaWork work;

  const WorkTags(this.work, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Tag(work.tradition.label),
        if (work.preservation != Preservation.complete)
          Tag(
            work.preservation.label,
            color: colors.accent,
            icon: Icons.broken_image_outlined,
          ),
        if (work.hasText)
          Tag(
            work.textLanguages.map(languageName).join(", "),
            color: colors.primary,
            icon: Icons.menu_book_rounded,
          )
        else
          const Tag("nur Verweis", icon: Icons.link),
      ],
    );
  }
}

class ApocryphaWorkTile extends StatelessWidget {
  final ApocryphaWork work;
  final VoidCallback onTap;
  final bool favorite;

  const ApocryphaWorkTile({
    super.key,
    required this.work,
    required this.onTap,
    this.favorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      key: ValueKey("apocrypha-work-${work.id}"),
      title: Row(
        children: [
          Flexible(child: Text(work.title)),
          if (favorite) ...[
            const SizedBox(width: 6),
            Icon(Icons.star_rounded, size: 16, color: colors.accent),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${work.genre} · ${work.dating.label}"),
            const SizedBox(height: 4),
            WorkTags(work),
          ],
        ),
      ),
      trailing: Icon(
        work.hasText ? Icons.menu_book_rounded : Icons.link,
        color: work.hasText ? colors.primary : colors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

/// Zeile „Bezeichnung: Wert“ in Angabenlisten.
class FactRow extends StatelessWidget {
  final String label;
  final String value;

  const FactRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
