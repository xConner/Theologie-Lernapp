import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/home_screen.dart';
import '../screens/email_verification_screen.dart';
import '../screens/login_screen.dart';
import '../services/local_learning_store.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasUserState = false;
  String? _lastUid;

  // Nach einem Logout geht es in dieser Sitzung direkt in den Gastmodus
  // (statt zurück auf den Login-Screen des ersten Besuchs).
  bool _signedOutThisSession = false;

  /// Beim Wechsel zwischen Gast und Konto (Login, Registrierung, Logout)
  /// werden alle über AuthGate gepushten Routen geschlossen (z. B. Login,
  /// MFA, Einstellungen, Trainer), damit kein Screen mit dem Speicher des
  /// vorherigen Nutzers weiterläuft.
  void _handleUserChange(String? uid) {
    if (_hasUserState && _lastUid != null && uid == null) {
      _signedOutThisSession = true;
    }

    if (_hasUserState && uid != _lastUid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }

    _hasUserState = true;
    _lastUid = uid;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // userChanges() emittiert (anders als authStateChanges()) auch nach
      // user.reload(), z. B. wenn die E-Mail-Verifizierung geprüft wird.
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        _handleUserChange(user?.uid);

        // Nicht angemeldet: Beim ersten Besuch den Login-Screen mit der
        // Option "Als Gast fortfahren" zeigen; wurde in diesem Browser schon
        // als Gast gearbeitet, direkt die Startseite im Gastmodus (Lernstände
        // lokal). Der Key sorgt dafür, dass HomeScreen beim Wechsel
        // Gast ↔ Konto neu aufgebaut wird.
        if (user == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: LocalLearningStore.instance.guestModeActive,
            builder: (context, guestModeActive, _) {
              if (guestModeActive || _signedOutThisSession) {
                return const HomeScreen(key: ValueKey("guest"));
              }

              return const LoginScreen(showGuestOption: true);
            },
          );
        }

        final hasPasswordProvider = user.providerData.any(
          (info) => info.providerId == "password",
        );

        if (hasPasswordProvider && !user.emailVerified) {
          return const EmailVerificationScreen();
        }

        return HomeScreen(key: ValueKey(user.uid));
      },
    );
  }
}
