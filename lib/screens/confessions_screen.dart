import 'package:flutter/material.dart';

import '../models/confession.dart';
import '../services/confession_service.dart';
import 'confession_detail_screen.dart';

class ConfessionsScreen extends StatefulWidget {
  const ConfessionsScreen({super.key});

  @override
  State<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends State<ConfessionsScreen> {
  final ConfessionService service = ConfessionService();

  List<Confession> confessions = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void reassemble() {
    super.reassemble();

    load();
  }

  Future<void> load() async {
    final data = await service.loadConfessions();

    setState(() {
      confessions = data;

      loading = false;
    });
  }

  List<Confession> getByCategory(String category) {
    return confessions.where((c) => c.category == category).toList();
  }

  Widget buildButton(Confession confession) {
    return Card(
      child: ListTile(
        title: Text(confession.title["de"] ?? confession.id),

        onTap: () {
          Navigator.push(
            context,

            MaterialPageRoute(
              builder: (_) => ConfessionDetailScreen(confession: confession),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Bekenntnisse")),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final altkirchlich = getByCategory("altkirchliche_symbole");

    final lutherisch = getByCategory("lutherische_symbole");

    return Scaffold(
      appBar: AppBar(title: const Text("Bekenntnisse")),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  "Altkirchliche Symbole",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                ...altkirchlich.map(buildButton),

                const SizedBox(height: 24),

                const Text(
                  "Lutherische Symbole",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                ...lutherisch.map(buildButton),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
