import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final authService = AuthService();

  bool sending = false;
  bool checking = false;
  String? info;
  String? error;

  Future<void> _resendEmail() async {
    setState(() {
      sending = true;
      error = null;
      info = null;
    });

    try {
      await authService.sendEmailVerification();

      if (!mounted) return;
      setState(() {
        info = "Bestätigungs-Mail wurde erneut gesendet.";
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      checking = true;
      error = null;
      info = null;
    });

    try {
      await authService.reloadCurrentUser();

      if (!mounted) return;

      if (!authService.isEmailVerified) {
        setState(() {
          error =
              "Die E-Mail wurde noch nicht bestätigt. Bitte prüfe dein Postfach.";
        });
      }
      // Bei Erfolg baut AuthGate automatisch auf HomeScreen um, da
      // FirebaseAuth.userChanges() nach reload() erneut feuert.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          checking = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";
    final busy = sending || checking;

    return Scaffold(
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
                      Icons.mark_email_unread_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "E-Mail bestätigen",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Wir haben eine Bestätigungs-Mail an $email gesendet. "
                      "Bitte bestätige deine E-Mail-Adresse, um fortzufahren.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    if (info != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        info!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.success),
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

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: busy ? null : _checkVerified,
                      child: checking
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Ich habe meine E-Mail bestätigt"),
                    ),

                    const SizedBox(height: 4),

                    TextButton(
                      onPressed: busy ? null : _resendEmail,
                      child: Text(
                        sending
                            ? "Wird gesendet..."
                            : "Bestätigungs-Mail erneut senden",
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 6),

                    TextButton(
                      onPressed: busy ? null : _signOut,
                      child: const Text("Abmelden"),
                    ),
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
