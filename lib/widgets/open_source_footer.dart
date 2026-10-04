import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../info/app_info.dart';
import '../theme/app_theme.dart';

/// Hinweis am Ende der Startseite, dass die App Open Source ist, mit Link
/// zum Repository.
class OpenSourceFooter extends StatelessWidget {
  const OpenSourceFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),

        Text(
          "Open Source",
          textAlign: TextAlign.center,
          style: textTheme.titleSmall,
        ),

        const SizedBox(height: 4),

        Text(
          "Theologie lernen – gemeinsam weiterentwickeln. Der Quellcode ist "
          "öffentlich: ansehen, verbessern, mitentwickeln.",
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(AppInfo.repositoryUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const GithubIcon(),
          label: const Text("Auf GitHub ansehen"),
        ),
      ],
    );
  }
}

/// GitHub-Logo als Vektorgrafik. Größe und Farbe folgen wie bei [Icon] dem
/// umgebenden [IconTheme], sofern nicht angegeben.
class GithubIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const GithubIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24;

    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _GithubIconPainter(
          color ?? iconTheme.color ?? context.colors.primary,
        ),
      ),
    );
  }
}

class _GithubIconPainter extends CustomPainter {
  final Color color;

  const _GithubIconPainter(this.color);

  // Pfad des GitHub-Logos in einem 16×16-Raster.
  static final Path _mark = Path()
    ..moveTo(8, 0)
    ..cubicTo(3.58, 0, 0, 3.58, 0, 8)
    ..relativeCubicTo(0, 3.54, 2.29, 6.53, 5.47, 7.59)
    ..relativeCubicTo(0.4, 0.07, 0.55, -0.17, 0.55, -0.38)
    ..relativeCubicTo(0, -0.19, -0.01, -0.82, -0.01, -1.49)
    ..relativeCubicTo(-2.01, 0.37, -2.53, -0.49, -2.69, -0.94)
    ..relativeCubicTo(-0.09, -0.23, -0.48, -0.94, -0.82, -1.13)
    ..relativeCubicTo(-0.28, -0.15, -0.68, -0.52, -0.01, -0.53)
    ..relativeCubicTo(0.63, -0.01, 1.08, 0.58, 1.23, 0.82)
    ..relativeCubicTo(0.72, 1.21, 1.87, 0.87, 2.33, 0.66)
    ..relativeCubicTo(0.07, -0.52, 0.28, -0.87, 0.51, -1.07)
    ..relativeCubicTo(-1.78, -0.2, -3.64, -0.89, -3.64, -3.95)
    ..relativeCubicTo(0, -0.87, 0.31, -1.59, 0.82, -2.15)
    ..relativeCubicTo(-0.08, -0.2, -0.36, -1.02, 0.08, -2.12)
    ..relativeCubicTo(0, 0, 0.67, -0.21, 2.2, 0.82)
    ..relativeCubicTo(0.64, -0.18, 1.32, -0.27, 2, -0.27)
    ..relativeCubicTo(0.68, 0, 1.36, 0.09, 2, 0.27)
    ..relativeCubicTo(1.53, -1.04, 2.2, -0.82, 2.2, -0.82)
    ..relativeCubicTo(0.44, 1.1, 0.16, 1.92, 0.08, 2.12)
    ..relativeCubicTo(0.51, 0.56, 0.82, 1.27, 0.82, 2.15)
    ..relativeCubicTo(0, 3.07, -1.87, 3.75, -3.65, 3.95)
    ..relativeCubicTo(0.29, 0.25, 0.54, 0.73, 0.54, 1.48)
    ..relativeCubicTo(0, 1.07, -0.01, 1.93, -0.01, 2.2)
    ..relativeCubicTo(0, 0.21, 0.15, 0.46, 0.55, 0.38)
    ..arcToPoint(
      const Offset(16, 8),
      radius: const Radius.circular(8.013),
      clockwise: false,
    )
    ..relativeCubicTo(0, -4.42, -3.58, -8, -8, -8)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    canvas.drawPath(_mark, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GithubIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
