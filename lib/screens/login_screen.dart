import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../services/local_learning_store.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'mfa_challenge_screen.dart';
import 'phone_sign_in_screen.dart';

class LoginScreen extends StatefulWidget {
  /// true beim ersten Besuch (Einstieg der App): zusätzlich die Option
  /// "Als Gast fortfahren". false, wenn der Screen aus dem Gastmodus heraus
  /// geöffnet wird.
  final bool showGuestOption;

  const LoginScreen({super.key, this.showGuestOption = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await authService.signInWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthMultiFactorException catch (e) {
      if (!mounted) return;
      await _openMfaChallenge(e.resolver);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
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

  Future<void> register() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await authService.registerWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
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

  Future<void> signInWithGoogle() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await authService.signInWithGoogle();
    } on FirebaseAuthMultiFactorException catch (e) {
      if (!mounted) return;
      await _openMfaChallenge(e.resolver);
    } on FirebaseAuthException catch (e) {
      if (!mounted || isAuthCancellation(e)) return;

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

  Future<void> _openMfaChallenge(MultiFactorResolver resolver) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MfaChallengeScreen(resolver: resolver)),
    );
  }

  void continueAsGuest() {
    // AuthGate wechselt daraufhin zur Startseite im Gastmodus.
    LocalLearningStore.instance.enterGuestMode();
  }

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void openPhoneSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
    );
  }

  Future<void> openGithub() async {
    final uri = Uri.parse("https://github.com/xConner/Theologie-Lernapp");

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Aus dem Gastmodus gepusht: Zurück-Leiste; nach erfolgreicher
      // Anmeldung schließt AuthGate diese Route automatisch.
      appBar: widget.showGuestOption
          ? null
          : AppBar(title: const Text("Anmelden")),

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
                      Icons.auto_stories_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Theologie Lernapp",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 28),

                    TextField(
                      controller: emailController,
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

                    const SizedBox(height: 14),

                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      onChanged: (_) {
                        if (error != null) {
                          setState(() {
                            error = null;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Passwort",
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: loading ? null : openForgotPassword,
                        child: const Text("Passwort vergessen?"),
                      ),
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],

                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: loading ? null : login,
                      child: loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Login"),
                    ),

                    const SizedBox(height: 4),

                    TextButton(
                      onPressed: loading ? null : register,
                      child: const Text("Registrieren"),
                    ),

                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: loading ? null : signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: const Text("Mit Google anmelden"),
                    ),

                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: loading ? null : openPhoneSignIn,
                      icon: const Icon(Icons.phone_iphone_rounded),
                      label: const Text("Mit Telefonnummer anmelden"),
                    ),

                    if (widget.showGuestOption) ...[
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: loading ? null : continueAsGuest,
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text("Als Gast fortfahren"),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Ohne Konto werden deine Lernstände und Einstellungen "
                        "nur lokal in diesem Browser gespeichert und nicht "
                        "zwischen Geräten synchronisiert. Beim Löschen der "
                        "Browserdaten gehen sie verloren. Du kannst dich "
                        "später jederzeit registrieren und deine Fortschritte "
                        "übernehmen.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    const Divider(),

                    const SizedBox(height: 6),

                    Text(
                      "In Entwicklung",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),

                    TextButton(
                      onPressed: openGithub,
                      child: const Text("GitHub Repository"),
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
