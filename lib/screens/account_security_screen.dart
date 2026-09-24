import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';
import '../utils/phone_number_utils.dart';
import '../widgets/sign_out_confirmation.dart';
import 'email_verification_screen.dart';
import 'mfa_enrollment_screen.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final authService = AuthService();

  List<MultiFactorInfo> mfaFactors = [];
  bool loadingFactors = true;

  @override
  void initState() {
    super.initState();
    _loadFactors();
  }

  Future<void> _loadFactors() async {
    final factors = await authService.getEnrolledMfaFactors();

    if (!mounted) return;
    setState(() {
      mfaFactors = factors;
      loadingFactors = false;
    });
  }

  Future<void> _signOut() async {
    // AuthGate sitzt in der Root-Route und zeigt nach dem Abmelden den
    // Login-Screen – die darüber gepushten Routen (Einstellungen, Konto &
    // Sicherheit) müssen daher explizit entfernt werden.
    final navigator = Navigator.of(context);
    if (!await confirmSignOut(context)) return;
    await authService.signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _openEnrollment() async {
    final enrolled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MfaEnrollmentScreen()),
    );

    if (enrolled == true) {
      await _loadFactors();
    }
  }

  Future<void> _unenroll(MultiFactorInfo factor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Faktor entfernen"),
        content: const Text(
          "Soll dieser zweite Faktor wirklich entfernt werden? Danach ist "
          "für den Login nur noch die erste Anmeldemethode nötig.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Entfernen"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await authService.unenrollMfaFactor(factor);
      await _loadFactors();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeAuthError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final providerLabels = user.providerData
        .map((info) => _providerLabel(info.providerId))
        .whereType<String>()
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Konto & Sicherheit")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle("Konto"),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text("E-Mail"),
                  subtitle: Text(user.email ?? "Keine E-Mail hinterlegt"),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_rounded),
                  title: const Text("Anbieter"),
                  subtitle: Text(
                    providerLabels.isEmpty
                        ? "Unbekannt"
                        : providerLabels.join(", "),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _SectionTitle("Sicherheit"),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    user.emailVerified
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: user.emailVerified
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  title: const Text("E-Mail-Verifizierung"),
                  subtitle: Text(
                    user.emailVerified
                        ? "E-Mail-Adresse ist bestätigt"
                        : "E-Mail-Adresse ist noch nicht bestätigt",
                  ),
                  onTap: user.emailVerified
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EmailVerificationScreen(),
                            ),
                          );
                        },
                ),

                if (authService.isEmailPasswordUser) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text("Passwort ändern"),
                    onTap: () => _openChangePasswordDialog(context),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          _SectionTitle("Zwei-Faktor-Authentifizierung"),

          Card(
            child: Column(
              children: [
                if (loadingFactors)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (mfaFactors.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text("Keine Zwei-Faktor-Authentifizierung aktiv"),
                    subtitle: Text(
                      "Schütze dein Konto zusätzlich mit einer SMS-Bestätigung.",
                    ),
                  )
                else
                  for (final factor in mfaFactors) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.success,
                      ),
                      title: Text(
                        factor is PhoneMultiFactorInfo
                            ? maskPhoneNumber(factor.phoneNumber)
                            : (factor.displayName ?? "Zweiter Faktor"),
                      ),
                      subtitle: const Text("Telefon (SMS)"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _unenroll(factor),
                      ),
                    ),
                    const Divider(height: 1),
                  ],

                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text("Faktor hinzufügen"),
                  onTap: _openEnrollment,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text("Abmelden"),
          ),
        ],
      ),
    );
  }

  String? _providerLabel(String providerId) {
    switch (providerId) {
      case "password":
        return "E-Mail & Passwort";
      case "google.com":
        return "Google";
      case "phone":
        return "Telefon";
      default:
        return null;
    }
  }

  Future<void> _openChangePasswordDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final authService = AuthService();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = currentPasswordController.text;
    final newPassword = newPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      setState(() {
        error = "Bitte fülle beide Felder aus.";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwort wurde geändert")),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Passwort ändern"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Aktuelles Passwort"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Neues Passwort"),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: loading ? null : _submit,
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("Speichern"),
        ),
      ],
    );
  }
}
