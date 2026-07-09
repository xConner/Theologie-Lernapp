import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message;
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> register() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message;
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> openGithub() async {
    final uri = Uri.parse("https://github.com/xConner/Theologie-Lernapp");

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                onChanged: (_) {
                  if (error != null) {
                    setState(() {
                      error = null;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: "Email"),
              ),

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
                decoration: const InputDecoration(labelText: "Passwort"),
              ),

              const SizedBox(height: 12),

              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: loading ? null : login,
                child: const Text("Login"),
              ),

              TextButton(
                onPressed: loading ? null : register,
                child: const Text("Registrieren"),
              ),

              const SizedBox(height: 30),

              const Text(
                "In Entwicklung",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              TextButton(
                onPressed: openGithub,
                child: const Text("GitHub Repository"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
