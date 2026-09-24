import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';

enum _TotpStep { reauthenticate, loadingSecret, scanAndVerify, done }

/// Richtet eine Authenticator-App (TOTP) als zweiten Faktor ein.
///
/// Im Gegensatz zur SMS-Variante ([MfaEnrollmentScreen]) wird hier weder
/// verifyPhoneNumber() noch reCAPTCHA benötigt. Das Secret erzeugt Firebase,
/// es lebt nur im State dieses Screens und wird nirgends gespeichert oder
/// geloggt. Der QR-Code enthält die standardisierte otpauth://-URL, die
/// jede übliche Authenticator-App lesen kann.
class TotpEnrollmentScreen extends StatefulWidget {
  const TotpEnrollmentScreen({super.key});

  @override
  State<TotpEnrollmentScreen> createState() => _TotpEnrollmentScreenState();
}

class _TotpEnrollmentScreenState extends State<TotpEnrollmentScreen> {
  static const String _issuer = "Theologie Lernapp";

  final authService = AuthService();

  final passwordController = TextEditingController();
  final codeController = TextEditingController();

  late _TotpStep step;

  bool busy = false;
  String? error;

  TotpSecret? secret;
  String? qrCodeUrl;

  @override
  void initState() {
    super.initState();

    if (authService.isEmailPasswordUser || authService.isGoogleUser) {
      step = _TotpStep.reauthenticate;
    } else {
      // Wie bei der SMS-Einrichtung: ohne bekannten Reauth-Weg direkt
      // versuchen; Firebase meldet ggf. "requires-recent-login".
      step = _TotpStep.loadingSecret;
      _generateSecret();
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    codeController.dispose();
    secret = null;
    qrCodeUrl = null;
    super.dispose();
  }

  Future<void> _reauthenticateWithPassword() async {
    final password = passwordController.text;

    if (password.isEmpty) {
      setState(() {
        error = "Bitte gib dein aktuelles Passwort ein.";
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await authService.reauthenticateWithPassword(password);
      if (!mounted) return;
      await _generateSecret();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _reauthenticateWithGoogle() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      await authService.reauthenticateWithGoogle();
      if (!mounted) return;
      await _generateSecret();
    } on FirebaseAuthException catch (e) {
      if (!mounted || isAuthCancellation(e)) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _generateSecret() async {
    setState(() {
      step = _TotpStep.loadingSecret;
      error = null;
      secret = null;
      qrCodeUrl = null;
      codeController.clear();
    });

    try {
      final newSecret = await authService.generateTotpSecret();
      final url = await newSecret.generateQrCodeUrl(
        accountName: FirebaseAuth.instance.currentUser?.email ?? "Konto",
        issuer: _issuer,
      );

      if (!mounted) return;
      setState(() {
        secret = newSecret;
        qrCodeUrl = url;
        step = _TotpStep.scanAndVerify;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
        step = _canReauthenticate
            ? _TotpStep.reauthenticate
            : _TotpStep.scanAndVerify;
      });
    }
  }

  bool get _canReauthenticate =>
      authService.isEmailPasswordUser || authService.isGoogleUser;

  Future<void> _verifyCode() async {
    final currentSecret = secret;
    if (currentSecret == null) return;

    final code = codeController.text.replaceAll(RegExp(r"\s"), "");
    if (code.isEmpty) {
      setState(() {
        error = "Bitte gib den Code aus deiner Authenticator-App ein.";
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await authService.enrollTotpMfaFactor(
        secret: currentSecret,
        oneTimePassword: code,
        displayName: "Authenticator-App",
      );

      if (!mounted) return;
      setState(() {
        step = _TotpStep.done;
        secret = null;
        qrCodeUrl = null;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _copySecret() async {
    final key = secret?.secretKey;
    if (key == null) return;

    await Clipboard.setData(ClipboardData(text: key));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Schlüssel kopiert")));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: step != _TotpStep.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step == _TotpStep.done) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Authenticator-App")),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildStepChildren(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStepChildren(BuildContext context) {
    switch (step) {
      case _TotpStep.reauthenticate:
        return _reauthStep(context);
      case _TotpStep.loadingSecret:
        return const [
          SizedBox(height: 12),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 12),
        ];
      case _TotpStep.scanAndVerify:
        return _scanStep(context);
      case _TotpStep.done:
        return _doneStep(context);
    }
  }

  Widget _busyIndicator() {
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }

  List<Widget> _reauthStep(BuildContext context) {
    return [
      Icon(Icons.lock_person_rounded, size: 40, color: AppColors.primary),
      const SizedBox(height: 12),
      Text(
        "Erneute Anmeldung erforderlich",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        "Aus Sicherheitsgründen musst du dich vor dem Einrichten der "
        "Authenticator-App erneut bestätigen.",
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),

      if (authService.isEmailPasswordUser) ...[
        TextField(
          controller: passwordController,
          obscureText: true,
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
          onSubmitted: (_) => busy ? null : _reauthenticateWithPassword(),
          decoration: const InputDecoration(labelText: "Aktuelles Passwort"),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: busy ? null : _reauthenticateWithPassword,
          child: busy ? _busyIndicator() : const Text("Bestätigen"),
        ),
      ] else if (authService.isGoogleUser) ...[
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: busy ? null : _reauthenticateWithGoogle,
          icon: const Icon(Icons.g_mobiledata_rounded),
          label: const Text("Mit Google bestätigen"),
        ),
      ],
    ];
  }

  List<Widget> _scanStep(BuildContext context) {
    final url = qrCodeUrl;
    final key = secret?.secretKey;
    final codeLength = secret?.codeLength ?? 6;

    if (url == null || key == null) {
      // Secret konnte nicht erzeugt werden (Fehler wird angezeigt).
      return [
        Icon(Icons.qr_code_2_rounded, size: 40, color: AppColors.primary),
        const SizedBox(height: 12),
        if (error != null)
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: busy ? null : _generateSecret,
          child: const Text("Erneut versuchen"),
        ),
      ];
    }

    return [
      Text(
        "1. QR-Code scannen",
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        "Scanne den Code mit deiner Authenticator-App, z. B. Google "
        "Authenticator, Microsoft Authenticator oder 1Password.",
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: url,
            size: 200,
            backgroundColor: Colors.white,
            semanticsLabel: "QR-Code für die Authenticator-App",
          ),
        ),
      ),
      const SizedBox(height: 12),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text("QR-Code lässt sich nicht scannen?"),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Gib diesen Schlüssel in deiner Authenticator-App manuell ein "
              "(Kontotyp: zeitbasiert).",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _groupKey(key),
                    style: const TextStyle(
                      fontFamily: "monospace",
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Schlüssel kopieren",
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: _copySecret,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text("2. Code eingeben", style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(
        controller: codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: codeLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        onSubmitted: (_) => busy ? null : _verifyCode(),
        decoration: InputDecoration(
          labelText: "$codeLength-stelliger Code aus der App",
          prefixIcon: const Icon(Icons.pin_rounded),
          counterText: "",
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(error!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: busy ? null : _verifyCode,
        child: busy ? _busyIndicator() : const Text("Aktivieren"),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: busy ? null : _generateSecret,
        child: const Text("Neuen QR-Code erzeugen"),
      ),
    ];
  }

  List<Widget> _doneStep(BuildContext context) {
    return [
      const Icon(
        Icons.verified_user_rounded,
        size: 48,
        color: AppColors.success,
      ),
      const SizedBox(height: 12),
      Text(
        "Authenticator-App eingerichtet",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        "Bei der nächsten Anmeldung wirst du nach dem Code aus deiner "
        "Authenticator-App gefragt.",
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text("Fertig"),
      ),
    ];
  }

  /// Gruppiert den Base32-Schlüssel in 4er-Blöcke, damit er sich leichter
  /// abtippen lässt. Authenticator-Apps ignorieren die Leerzeichen.
  static String _groupKey(String key) {
    final buffer = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(" ");
      buffer.write(key[i]);
    }
    return buffer.toString();
  }
}
