import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';
import '../utils/phone_number_utils.dart';
import '../widgets/recaptcha_notice.dart';

/// Wird während des Logins angezeigt, wenn Firebase eine
/// [FirebaseAuthMultiFactorException] wirft, weil für das Konto SMS-MFA
/// aktiviert ist. Erst nach erfolgreicher Code-Eingabe ist der Login
/// abgeschlossen (Firebase führt vorher keinen Sign-in durch).
class MfaChallengeScreen extends StatefulWidget {
  final MultiFactorResolver resolver;

  const MfaChallengeScreen({super.key, required this.resolver});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final authService = AuthService();
  final codeController = TextEditingController();

  late PhoneMultiFactorInfo? selectedHint;

  bool sendingCode = false;
  bool verifying = false;
  bool codeSent = false;
  String? verificationId;
  String? error;

  @override
  void initState() {
    super.initState();

    final phoneHints = widget.resolver.hints.whereType<PhoneMultiFactorInfo>();
    selectedHint = phoneHints.isNotEmpty ? phoneHints.first : null;

    if (selectedHint != null) {
      _sendCode();
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final hint = selectedHint;
    if (hint == null) return;

    setState(() {
      sendingCode = true;
      error = null;
    });

    try {
      await authService.startMfaSignInChallenge(
        resolver: widget.resolver,
        hint: hint,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            sendingCode = false;
            error = logAndDescribeAuthErrorForDiagnosis(
              e,
              context: "MfaChallenge.verificationFailed",
            );
          });
        },
        codeSent: (id, _) {
          if (!mounted) return;
          setState(() {
            sendingCode = false;
            codeSent = true;
            verificationId = id;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        sendingCode = false;
        error = logAndDescribeAuthErrorForDiagnosis(
          e,
          context: "MfaChallenge.startMfaSignInChallenge",
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        sendingCode = false;
        error = logAndDescribeAuthErrorForDiagnosis(
          e,
          context: "MfaChallenge.startMfaSignInChallenge.raw",
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
      verifying = true;
      error = null;
    });

    try {
      await authService.resolveMfaSignIn(
        resolver: widget.resolver,
        verificationId: id,
        smsCode: code,
      );

      if (!mounted) return;
      // AuthGate zeigt nach erfolgreichem Sign-in automatisch den HomeScreen;
      // dieser Screen und der LoginScreen wurden darüber gepusht und müssen
      // weg. popUntil ist idempotent, falls AuthGate schon aufgeräumt hat.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = selectedHint;
    final busy = sendingCode || verifying;

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
                  children: [
                    Icon(
                      Icons.sms_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Code bestätigen",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 12),

                    if (hint == null)
                      const Text(
                        "Für dieses Konto ist kein unterstützter zweiter "
                        "Faktor hinterlegt.",
                        textAlign: TextAlign.center,
                      )
                    else
                      Text(
                        codeSent
                            ? "Wir haben einen Code an ${maskPhoneNumber(hint.phoneNumber)} gesendet."
                            : "Code wird an ${maskPhoneNumber(hint.phoneNumber)} gesendet...",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),

                    if (codeSent) ...[
                      const SizedBox(height: 20),

                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          if (error != null) {
                            setState(() {
                              error = null;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: "SMS-Code",
                          prefixIcon: Icon(Icons.pin_rounded),
                        ),
                      ),
                    ],

                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],

                    const SizedBox(height: 20),

                    if (codeSent)
                      ElevatedButton(
                        onPressed: busy ? null : _confirmCode,
                        child: verifying
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Bestätigen"),
                      )
                    else if (sendingCode)
                      const Center(child: CircularProgressIndicator()),

                    if (codeSent) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: busy ? null : _sendCode,
                        child: const Text("Code erneut senden"),
                      ),
                    ],

                    const RecaptchaNotice(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
