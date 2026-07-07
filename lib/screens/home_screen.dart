import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/perikope_loader.dart';
import '../screens/quiz_screen.dart';
import '../models/perikope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Perikope>? perikopen;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPerikopen();
  }

  Future<void> _loadPerikopen() async {
    try {
      final data = await PerikopeLoader.load();

      setState(() {
        perikopen = data;
        loading = false;
      });
    } catch (_) {
      setState(() {
        perikopen = [];
        loading = false;
      });
    }
  }

  void _openQuiz() {
    final list = perikopen;

    if (list == null || list.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Keine Perikopen geladen")));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nicht eingeloggt")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(perikopen: list, uid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Start"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("In Entwicklung"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _openQuiz,
                    child: const Text("Perikopenquiz"),
                  ),
                ],
              ),
      ),
    );
  }
}
