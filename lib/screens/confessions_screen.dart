import 'package:flutter/material.dart';

import '../models/confession.dart';
import '../services/confession_service.dart';
import 'confession_detail_screen.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';

class ConfessionsScreen extends StatefulWidget {
  /// Ermöglicht Widget-Tests mit eigenem Asset-Bundle.
  final ConfessionService? service;

  const ConfessionsScreen({super.key, this.service});

  @override
  State<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends State<ConfessionsScreen> {
  late final ConfessionService service =
      widget.service ?? ConfessionService();

  List<Confession> confessions = [];

  bool loading = true;

  bool failed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await service.loadConfessions();

      if (!mounted) return;

      setState(() {
        confessions = data;
        failed = false;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        failed = true;
        loading = false;
      });
    }
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
        appBar: AppBar(
          title: const Text("Bekenntnisse"),
actions: const [
            InfoButton(module: AppModules.confessions),
            SettingsButton(),
          ],
        ),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (failed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Bekenntnisse"),
actions: const [
            InfoButton(module: AppModules.confessions),
            SettingsButton(),
          ],
        ),

        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Die Bekenntnisse konnten nicht geladen werden.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final altkirchlich = getByCategory("altkirchliche_symbole");

    final lutherisch = getByCategory("lutherische_symbole");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bekenntnisse"),
actions: const [
          InfoButton(module: AppModules.confessions),
          SettingsButton(),
        ],
      ),

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
