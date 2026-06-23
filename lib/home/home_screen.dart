import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/google_sheets_loader.dart';
import '../quiz/quiz_screen.dart';
import '../models/perikope.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bibelkunde App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      body: FutureBuilder<List<Perikope>>(
        future: loadPerikopen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Fehler beim Laden"));
          }

          final data = snapshot.data ?? [];

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Eingeloggt als: ${user?.email ?? ''}"),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: data.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(perikopen: data),
                          ),
                        );
                      },
                child: const Text("Quiz starten"),
              ),

              const SizedBox(height: 20),

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
