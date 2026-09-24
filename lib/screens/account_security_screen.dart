import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';
import '../utils/phone_number_utils.dart';
import '../widgets/sign_out_confirmation.dart';
import 'email_verification_screen.dart';
import 'mfa_challenge_screen.dart';
import 'mfa_enrollment_screen.dart';
import 'totp_enrollment_screen.dart';

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

  Future<void> _openTotpEnrollment() async {
    final enrolled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TotpEnrollmentScreen()),
    );

    if (enrolled == true) {
      await _loadFactors();
    }
  }

  Future<void> _unenroll(MultiFactorInfo factor) async {
    final isLastFactor = mfaFactors.length <= 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("${_factorTypeLabel(factor)} entfernen"),
        content: Text(
          isLastFactor
              ? "Das ist dein einziger zweiter Faktor. Wenn du ihn entfernst, "
                    "ist die Zwei-Faktor-Authentifizierung deaktiviert und für "
                    "den Login nur noch die erste Anmeldemethode nötig."
              : "Soll dieser zweite Faktor wirklich entfernt werden? Deine "
                    "anderen zweiten Faktoren bleiben aktiv.",
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

      // Firebase verlangt zum Entfernen eine kürzliche Anmeldung. Statt nur
      // den Fehler zu zeigen: erneut anmelden (inkl. zweitem Faktor) und das
      // Entfernen dann wiederholen.
      if (e.code == "requires-recent-login" && await _reauthenticate()) {
        await _retryUnenroll(factor);
        return;
      }

      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _retryUnenroll(MultiFactorInfo factor) async {
    try {
      await authService.unenrollMfaFactor(factor);
      await _loadFactors();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  /// Erneute Anmeldung per Passwort bzw. Google. Hat das Konto einen zweiten
  /// Faktor, wird anschließend dessen Bestätigung verlangt. Liefert true,
  /// wenn die erneute Anmeldung vollständig abgeschlossen ist.
  Future<bool> _reauthenticate() async {
    if (!authService.isEmailPasswordUser && !authService.isGoogleUser) {
      return false;
    }

    final result = await showDialog<_ReauthResult>(
      context: context,
      builder: (_) => const _ReauthDialog(),
    );

    if (!mounted || result == null) return false;

    final resolver = result.mfaResolver;
    if (resolver != null) {
      return resolveReauthMfaChallenge(context, resolver);
    }

    return result.success;
  }

  void _showError(FirebaseAuthException e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(describeAuthError(e))));
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
                      "Schütze dein Konto zusätzlich mit einer SMS-Bestätigung "
                      "oder einer Authenticator-App.",
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
                      subtitle: Text(_factorTypeLabel(factor)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _unenroll(factor),
                      ),
                    ),
                    const Divider(height: 1),
                  ],

                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text("Telefonnummer (SMS) hinzufügen"),
                  onTap: _openEnrollment,
                ),

                if (!loadingFactors && !_hasTotpFactor) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: const Text("Authenticator-App einrichten"),
                    subtitle: const Text(
                      "Code aus einer App wie Google Authenticator",
                    ),
                    onTap: _openTotpEnrollment,
                  ),
                ],
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

  bool get _hasTotpFactor =>
      mfaFactors.any((factor) => factor is TotpMultiFactorInfo);

  String _factorTypeLabel(MultiFactorInfo factor) {
    if (factor is PhoneMultiFactorInfo) return "Telefon (SMS)";
    if (factor is TotpMultiFactorInfo) return "Authenticator-App";
    return "Zweiter Faktor";
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

/// Ergebnis von [_ReauthDialog]: entweder erfolgreich angemeldet oder
/// Firebase verlangt noch den zweiten Faktor ([mfaResolver]).
class _ReauthResult {
  final bool success;
  final MultiFactorResolver? mfaResolver;

  const _ReauthResult.success() : success = true, mfaResolver = null;

  const _ReauthResult.mfaRequired(MultiFactorResolver resolver)
    : success = false,
      mfaResolver = resolver;
}

/// Fragt vor einer Sicherheitsaktion die erneute Anmeldung ab. Die Google-
/// Anmeldung startet direkt aus dem Button-Tap, damit der Browser das Popup
/// nicht blockiert.
class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog();

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final authService = AuthService();
  final passwordController = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() reauth) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await reauth();
      if (!mounted) return;
      Navigator.of(context).pop(const _ReauthResult.success());
    } on FirebaseAuthMultiFactorException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(_ReauthResult.mfaRequired(e.resolver));
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

  void _submitPassword() {
    final password = passwordController.text;
    if (password.isEmpty) {
      setState(() {
        error = "Bitte gib dein aktuelles Passwort ein.";
      });
      return;
    }

    _run(() => authService.reauthenticateWithPassword(password));
  }

  @override
  Widget build(BuildContext context) {
    final usePassword = authService.isEmailPasswordUser;

    return AlertDialog(
      title: const Text("Erneute Anmeldung erforderlich"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Aus Sicherheitsgründen musst du dich erneut bestätigen, bevor "
            "der Faktor entfernt werden kann.",
          ),
          if (usePassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => loading ? null : _submitPassword(),
              decoration: const InputDecoration(
                labelText: "Aktuelles Passwort",
              ),
            ),
          ],
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
          onPressed: loading
              ? null
              : usePassword
              ? _submitPassword
              : () => _run(authService.reauthenticateWithGoogle),
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(usePassword ? "Bestätigen" : "Mit Google bestätigen"),
        ),
      ],
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
      _closeWithSuccess();
    } on FirebaseAuthMultiFactorException catch (e) {
      // Konto mit zweitem Faktor: erst diesen bestätigen, dann das Passwort
      // setzen (die Reauthentifizierung ist damit abgeschlossen).
      if (!mounted) return;
      final resolved = await resolveReauthMfaChallenge(context, e.resolver);
      if (!mounted || !resolved) return;

      try {
        await authService.updatePassword(newPassword);
        if (!mounted) return;
        _closeWithSuccess();
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() {
          error = describeAuthError(e);
        });
      }
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

  void _closeWithSuccess() {
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Passwort wurde geändert")),
    );
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
