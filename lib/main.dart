import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),

        cardTheme: const CardThemeData(
          color: Color.fromARGB(255, 133, 133, 133),
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 6),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),

      home: const AuthGate(),
    );
  }
}
