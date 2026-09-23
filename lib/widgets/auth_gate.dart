import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/email_verification_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        if (user == null) {
          return const LoginScreen();
        }

        final hasPasswordProvider = user.providerData.any(
          (info) => info.providerId == "password",
        );

        if (hasPasswordProvider && !user.emailVerified) {
          return const EmailVerificationScreen();
        }

        return const HomeScreen();
      },
    );
  }
}
