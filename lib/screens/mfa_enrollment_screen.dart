import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';
import '../utils/phone_number_utils.dart';
import '../widgets/recaptcha_notice.dart';

enum _EnrollmentStep { reauthenticate, enterPhone, enterCode }

/// Aktiviert SMS-Multi-Faktor-Authentifizierung für das aktuelle Konto.
/// Erfordert zuerst eine erneute Authentifizierung, da das Hinzufügen eines
/// zweiten Faktors eine sicherheitsrelevante Aktion ist.
class MfaEnrollmentScreen extends StatefulWidget {
  const MfaEnrollmentScreen({super.key});

  @override
  State<MfaEnrollmentScreen> createState() => _MfaEnrollmentScreenState();
}

class _MfaEnrollmentScreenState extends State<MfaEnrollmentScreen> {
  final authService = AuthService();

  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  late _EnrollmentStep step;

  bool busy = false;
  String? error;

  MultiFactorSession? session;
  String? verificationId;
  String? phoneNumberForEnrollment;

  @override
  void initState() {
    super.initState();

    if (authService.isEmailPasswordUser || authService.isGoogleUser) {
      step = _EnrollmentStep.reauthenticate;
    } else {
      // Kein bekannter Reauth-Weg vorhanden - direkt versuchen, die
      // MFA-Session zu holen. Firebase verlangt bei Bedarf ohnehin
      // "requires-recent-login" und bricht mit einer verständlichen
      // Fehlermeldung ab.
      step = _EnrollmentStep.enterPhone;
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    phoneController.dispose();
    codeController.dispose();
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
      setState(() {
        step = _EnrollmentStep.enterPhone;
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

  Future<void> _reauthenticateWithGoogle() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      await authService.reauthenticateWithGoogle();

      if (!mounted) return;
      setState(() {
        step = _EnrollmentStep.enterPhone;
      });
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

  Future<void> _sendCode() async {
    final phoneNumber = normalizePhoneNumber(phoneController.text);

    if (!isValidE164PhoneNumber(phoneNumber)) {
      setState(() {
        error =
            "Bitte gib eine gültige Telefonnummer inkl. Ländervorwahl ein, z. B. +49...";
      });
      return;
    }

    // Tastatur schließen, bevor reCAPTCHA ggf. eine Challenge einblendet:
    // Die Viewport-Änderung beim Schließen würde sie sonst auf Mobile
    // verschieben.
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final mfaSession = session ?? await authService.getMfaEnrollmentSession();
      session = mfaSession;

      await authService.startMfaPhoneEnrollment(
        phoneNumber: phoneNumber,
        session: mfaSession,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            busy = false;
            error = logAndDescribeAuthErrorForDiagnosis(
              e,
              context: "MfaEnrollment.verificationFailed",
            );
          });
        },
        codeSent: (id, _) {
          if (!mounted) return;
          setState(() {
            busy = false;
            verificationId = id;
            phoneNumberForEnrollment = phoneNumber;
            step = _EnrollmentStep.enterCode;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = logAndDescribeAuthErrorForDiagnosis(
          e,
          context: "MfaEnrollment.startMfaPhoneEnrollment",
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = logAndDescribeAuthErrorForDiagnosis(
          e,
          context: "MfaEnrollment.startMfaPhoneEnrollment.raw",
        );
      });
    }
  }

  Future<void> _confirmCode() async {
    final id = verificationId;
    if (id == null) return;

    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        error = "Bitte gib den erhaltenen Code ein.";
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await authService.enrollPhoneMfaFactor(
        verificationId: id,
        smsCode: code,
        displayName: phoneNumberForEnrollment,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Zwei-Faktor-Authentifizierung")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
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
    );
  }

  List<Widget> _buildStepChildren(BuildContext context) {
    switch (step) {
      case _EnrollmentStep.reauthenticate:
        return _reauthStep(context);
      case _EnrollmentStep.enterPhone:
        return _phoneStep(context);
      case _EnrollmentStep.enterCode:
        return _codeStep(context);
    }
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
        "Aus Sicherheitsgründen musst du dich vor der Aktivierung der "
        "Zwei-Faktor-Authentifizierung erneut bestätigen.",
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
          decoration: const InputDecoration(labelText: "Aktuelles Passwort"),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: busy ? null : _reauthenticateWithPassword,
          child: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("Bestätigen"),
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

  List<Widget> _phoneStep(BuildContext context) {
    return [
      Icon(Icons.phone_iphone_rounded, size: 40, color: AppColors.primary),
      const SizedBox(height: 12),
      Text(
        "Telefonnummer hinzufügen",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        "Diese Nummer wird künftig für die Anmeldebestätigung per SMS "
        "verwendet.",
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        decoration: const InputDecoration(
          labelText: "Telefonnummer (z. B. +49...)",
          prefixIcon: Icon(Icons.dialpad_rounded),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 14),
        Text(error!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: busy ? null : _sendCode,
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text("Code senden"),
      ),
      const RecaptchaNotice(),
    ];
  }

  List<Widget> _codeStep(BuildContext context) {
    return [
      Icon(Icons.sms_rounded, size: 40, color: AppColors.primary),
      const SizedBox(height: 12),
      Text(
        "Code bestätigen",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        "Wir haben einen Code an ${maskPhoneNumber(phoneNumberForEnrollment ?? '')} gesendet.",
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: codeController,
        keyboardType: TextInputType.number,
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        decoration: const InputDecoration(
          labelText: "SMS-Code",
          prefixIcon: Icon(Icons.pin_rounded),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 14),
        Text(error!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: busy ? null : _confirmCode,
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text("Aktivieren"),
      ),
    ];
  }
}
