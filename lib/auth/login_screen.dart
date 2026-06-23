import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool stayLoggedIn = true;

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e);
    } catch (_) {
      _showMessage("Unbekannter Fehler");
    }
  }

  Future<void> register() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e);
    } catch (_) {
      _showMessage("Unbekannter Fehler");
    }
  }

  void _showError(FirebaseAuthException e) {
    String msg;

    switch (e.code) {
      case 'user-not-found':
        msg = "Kein Benutzer mit dieser E-Mail gefunden.";
        break;
      case 'wrong-password':
        msg = "Falsches Passwort.";
        break;
      case 'invalid-email':
        msg = "Ungültige E-Mail-Adresse.";
        break;
      case 'email-already-in-use':
        msg = "Diese E-Mail ist bereits registriert.";
        break;
      case 'weak-password':
        msg = "Passwort ist zu schwach.";
        break;
      case 'network-request-failed':
        msg = "Netzwerkfehler. Prüfe deine Verbindung.";
        break;
      default:
        msg = "Login fehlgeschlagen: ${e.message}";
    }

    _showMessage(msg);
  }

  void _showMessage(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Passwort"),
            ),

            const SizedBox(height: 10),

            // ✅ Feature 2: "Angemeldet bleiben"
            Row(
              children: [
                Checkbox(
                  value: stayLoggedIn,
                  onChanged: (value) {
                    setState(() {
                      stayLoggedIn = value ?? true;
                    });
                  },
                ),
                const Text("Angemeldet bleiben"),
              ],
            ),

            const SizedBox(height: 10),

            ElevatedButton(onPressed: login, child: const Text("Login")),

            ElevatedButton(
              onPressed: register,
              child: const Text("Registrieren"),
            ),
          ],
        ),
      ),
    );
  }
}
