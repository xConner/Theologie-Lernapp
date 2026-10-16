import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../models/hymnal.dart';
import '../services/hymnal_service.dart';
import 'hymn_detail_screen.dart';
import '../widgets/hymnal_widgets.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';

/// Lieder einer Sammlung mit Suche, standardmäßig der Stammteil des
/// Evangelischen Gesangbuchs. Die Suche ist dieselbe wie in der globalen
/// Suche ([HymnalLibrary.index]), nur auf die Sammlung begrenzt.
class HymnScreen extends StatefulWidget {
  final String hymnalId;

  /// Nur für Tests oder zum Weiterreichen bereits geladener Sammlungen.
  final Future<HymnalLibrary> Function()? loadLibrary;

  const HymnScreen({super.key, this.hymnalId = 'eg', this.loadLibrary});

  @override
  State<HymnScreen> createState() => _HymnScreenState();
}

class _HymnScreenState extends State<HymnScreen> {
  HymnalLibrary? library;

  List<Hymn> hymns = [];

  List<Hymn> filtered = [];

  /// Fundstellen im Liedtext je Lied.
  Map<String, String?> snippets = {};

  bool loading = true;

  final TextEditingController searchController = TextEditingController();

  Hymnal? get hymnal => library?.hymnal(widget.hymnalId);

  bool get failed => library?.failed.contains(widget.hymnalId) ?? true;

  @override
  void initState() {
    super.initState();

    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    HymnalLibrary? data;
    try {
      data = await (widget.loadLibrary ?? HymnalService.shared)();
    } catch (_) {
      data = null;
    }

    if (!mounted) return;

    setState(() {
      library = data;

      hymns = data?.hymnsOf(widget.hymnalId) ?? const [];

      filtered = hymns;

      loading = false;
    });
  }

  void search(String value) {
    final index = library?.index;
    if (index == null) return;

    if (value.trim().isEmpty) {
      setState(() {
        filtered = hymns;
        snippets = {};
      });
      return;
    }

    final hits = index.search(
      value,
      where: (hymn) => hymn.collectionId == widget.hymnalId,
    );

    setState(() {
      filtered = [for (final hit in hits) hit.hymn];
      snippets = {for (final hit in hits) hit.hymn.key: hit.snippet};
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = hymnal;
    final isCore = current?.part == HymnalPart.core;

    return Scaffold(
      appBar: AppBar(
        title: Text(current == null || isCore ? "Gesangbuch" : current.title),
        actions: const [
          InfoButton(module: AppModules.hymns),
          SettingsButton(),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : current == null || (failed && current.asset != null)
          ? const Center(
              key: Key("hymn_list_error"),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Die Lieder konnten nicht geladen werden.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                if (hymns.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),

                    child: TextField(
                      controller: searchController,

                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),

                        hintText: isCore
                            ? "Suche nach Nummer, Titel, Text, Autor, Tags "
                                  "oder Bibelstellen"
                            : "Suche in ${current.label}",

                        border: const OutlineInputBorder(),
                      ),

                      onChanged: search,
                    ),
                  ),

                if (filtered.isEmpty && searchController.text.isNotEmpty)
                  const Padding(
                    key: Key("hymn_list_no_results"),
                    padding: EdgeInsets.all(16),
                    child: Text("Keine Lieder gefunden."),
                  ),

                Expanded(
                  child: ListView.builder(
                    // Bei Teilsammlungen stehen Stand und Quellen über der
                    // Liste.
                    itemCount: filtered.length + (isCore ? 0 : 1),

                    itemBuilder: (context, index) {
                      if (!isCore) {
                        if (index == 0) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: hymns.isEmpty ? 12 : 0,
                            ),
                            child: HymnalInfoCard(
                              hymnal: current,
                              hymns: hymns,
                            ),
                          );
                        }
                        index--;
                      }

                      final hymn = filtered[index];

                      return HymnTile(
                        hymn: hymn,
                        snippet: snippets[hymn.key],
                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => HymnDetailScreen(
                                hymn: hymn,
                                library: library,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
