import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/local_learning_store.dart';
import 'services/quiz_sound_settings.dart';
import 'services/theme_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await QuizSoundSettings.instance.load();

  await ThemeSettings.instance.load();

  // Entscheidet, ob ohne Anmeldung der Login-Screen (erster Besuch) oder
  // direkt die Gast-Startseite gezeigt wird.
  await LocalLearningStore.instance.loadGuestModeState();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Baut die App neu auf, sobald in den Einstellungen ein anderes
    // Erscheinungsbild gewählt wird. Bei „System“ folgt die MaterialApp
    // selbst der Einstellung des Betriebssystems.
    return ListenableBuilder(
      listenable: ThemeSettings.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,

        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeSettings.instance.themeMode,

        home: const AuthGate(),
      ),
    );
  }
}
