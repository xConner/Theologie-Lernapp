import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../services/hymn_service.dart';
import 'hymn_detail_screen.dart';

class HymnScreen extends StatefulWidget {
  const HymnScreen({super.key});

  @override
  State<HymnScreen> createState() => _HymnScreenState();
}

class _HymnScreenState extends State<HymnScreen> {
  final HymnService service = HymnService();

  List<Hymn> hymns = [];

  List<Hymn> filtered = [];

  bool loading = true;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    load();
  }

  Future<void> load() async {
    final data = await service.loadHymns();

    setState(() {
      hymns = data;

      filtered = data;

      loading = false;
    });
  }

  void search(String value) {
    final query = value.toLowerCase();

    setState(() {
      filtered = hymns.where((hymn) {
        final tags = hymn.tags.map((tag) => tag.toLowerCase()).join(" ");

        final bibleReferences = hymn.bibleReferences
            .map((ref) => ref.toLowerCase())
            .join(" ");

        return hymn.id.toString().contains(query) ||
            hymn.title.toLowerCase().contains(query) ||
            hymn.author.toLowerCase().contains(query) ||
            tags.contains(query) ||
            bibleReferences.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gesangbuch")),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),

                  child: TextField(
                    controller: searchController,

                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),

                      hintText:
                          "Suche nach Nummer, Titel, Autor, Tags oder Bibelstellen",

                      border: OutlineInputBorder(),
                    ),

                    onChanged: search,
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,

                    itemBuilder: (context, index) {
                      final hymn = filtered[index];

                      return ListTile(
                        leading: CircleAvatar(child: Text(hymn.id.toString())),

                        title: Text(hymn.title),

                        subtitle: Text(hymn.author),

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => HymnDetailScreen(hymn: hymn),
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
