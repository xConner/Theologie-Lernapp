import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pflichthinweis für das unsichtbare reCAPTCHA, das Firebase auf Web bei
/// Phone-/SMS-Verifizierungen automatisch rendert.
///
/// Das schwebende reCAPTCHA-Badge wird in web/index.html per CSS
/// ausgeblendet (FlutterFire räumt seine Verifier nie mit `clear()` ab, das
/// Badge bliebe sonst dauerhaft sichtbar). Laut Google ist das nur zulässig,
/// wenn stattdessen dieser Text im Nutzerfluss sichtbar ist.
class RecaptchaNotice extends StatelessWidget {
  const RecaptchaNotice({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        "Geschützt durch reCAPTCHA. Es gelten die Datenschutzerklärung "
        "(policies.google.com/privacy) und die Nutzungsbedingungen "
        "(policies.google.com/terms) von Google.",
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
