import 'package:flutter/material.dart';
import 'services/google_sheets_loader.dart';
import 'quiz/quiz_screen.dart';
import '../models/perikope.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perikopen")),

      body: FutureBuilder<List<Perikope>>(
        future: loadPerikopen(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;

          return Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(perikopen: data),
                    ),
                  );
                },
                child: const Text("Quiz starten"),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final p = data[i];

                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text(
                        p.occurrences
                            .map((o) => "${o.book} ${o.ref}")
                            .join(" | "),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
