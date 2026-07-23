import 'package:flutter/material.dart';

import '../models/confession.dart';
import '../services/confession_service.dart';

class ConfessionDetailScreen extends StatefulWidget {
  final Confession confession;

  const ConfessionDetailScreen({super.key, required this.confession});

  @override
  State<ConfessionDetailScreen> createState() => _ConfessionDetailScreenState();
}

class _ConfessionDetailScreenState extends State<ConfessionDetailScreen> {
  final ConfessionService service = ConfessionService();

  late Confession confession;

  late String selectedLanguage;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    confession = widget.confession;
    selectedLanguage = confession.languages.first;
  }

  // Wird bei Hot Reload automatisch ausgeführt
  @override
  void reassemble() {
    super.reassemble();

    reloadConfession();
  }

  Future<void> reloadConfession() async {
    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final confessions = await service.loadConfessions();

      final updated = confessions.firstWhere((c) => c.id == confession.id);

      setState(() {
        confession = updated;

        if (!confession.languages.contains(selectedLanguage)) {
          selectedLanguage = confession.languages.first;
        }

        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });

      debugPrint("Fehler beim Reload: $e");
    }
  }

  String languageName(String code) {
    switch (code) {
      case "de":
        return "Deutsch";

      case "en":
        return "Englisch";

      case "la":
        return "Latein";

      case "gr":
        return "Griechisch";

      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          confession.title[selectedLanguage] ??
              confession.title["de"] ??
              confession.id,
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: reloadConfession,
          ),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              if (loading) const LinearProgressIndicator(),

              Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      confession.title[selectedLanguage] ??
                          confession.title["de"] ??
                          confession.id,

                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 16),

                    DropdownButton<String>(
                      value: selectedLanguage,

                      items: confession.languages
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(languageName(lang)),
                            ),
                          )
                          .toList(),

                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedLanguage = value;
                        });
                      },
                    ),

                    const Divider(height: 32),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),

                  child: SelectableText(
                    confession.sections[0].texts[selectedLanguage] ?? "",

                    style: const TextStyle(fontSize: 18, height: 1.5),

                    selectionControls: MaterialTextSelectionControls(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
