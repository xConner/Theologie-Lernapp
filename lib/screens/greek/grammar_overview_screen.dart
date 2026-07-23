import 'package:flutter/material.dart';

import 'grammar_topics/article_screen.dart';
import 'grammar_topics/declinations_screen.dart';

class GrammarOverviewScreen extends StatelessWidget {
  const GrammarOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Grammatikübersicht")),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ArticleScreen(),
                        ),
                      );
                    },

                    child: const Text("Bestimmter Artikel"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeclinationsScreen(),
                        ),
                      );
                    },

                    child: const Text("Deklinationen"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
