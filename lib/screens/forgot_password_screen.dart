import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final authService = AuthService();
  final emailController = TextEditingController();

  bool loading = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        error = "Bitte gib deine E-Mail-Adresse ein.";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await authService.sendPasswordReset(email);

      if (!mounted) return;
      setState(() {
        sent = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Aus Datenschutzgründen (keine Rückschlüsse, ob eine E-Mail
      // registriert ist) wird "unbekannte E-Mail" wie ein Erfolg behandelt.
      if (e.code == "user-not-found") {
        setState(() {
          sent = true;
        });
        return;
      }

      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Passwort vergessen")),
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
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Passwort zurücksetzen",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Gib deine E-Mail-Adresse ein. Wir senden dir einen "
                      "Link zum Zurücksetzen deines Passworts.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 22),

                    if (sent) ...[
                      const Text(
                        "Falls ein Konto mit dieser E-Mail-Adresse existiert, "
                        "wurde eine E-Mail zum Zurücksetzen des Passworts "
                        "gesendet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.success),
                      ),
                    ] else ...[
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (error != null) {
                            setState(() {
                              error = null;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],

                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: loading ? null : _sendResetEmail,
                        child: loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Link senden"),
                      ),
                    ],
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
