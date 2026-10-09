import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../info/app_info.dart';
import '../theme/app_theme.dart';
import '../widgets/info_report.dart';
import '../widgets/legal_links.dart';

/// Allgemeine Informationen zur App: Projekt, KI-Unterstützung, Inhalte und
/// Quellen, gespeicherte Daten, Fehler melden. Erreichbar über die
/// Einstellungen und über jedes Info-Blatt.
///
/// Wie in `AppModules` gilt: nur belegte Angaben, keine rechtlichen
/// Zusicherungen.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _section(BuildContext context, String heading, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Über die App")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(AppInfo.name, style: textTheme.headlineSmall),

              const SizedBox(height: 4),

              Text(
                "Version ${AppInfo.version} · In Entwicklung",
                style: textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              _section(context, "Über das Projekt", [
                _paragraph(
                  "Eine kostenlose, quelloffene Lernapp für Theologie und "
                  "Bibelkunde: Perikopenquiz, Bibel in mehreren "
                  "Übersetzungen, Altgriechisch und Latein, Texte auswendig "
                  "lernen, dazu Bekenntnisse, Gebete, liturgischer Kalender "
                  "und Gesangbuch zum Nachschlagen.",
                ),
                _paragraph(
                  "Die App befindet sich in Entwicklung. Der Quellcode ist "
                  "öffentlich auf GitHub einsehbar; Fragen, Ideen und "
                  "Mitarbeit besprechen wir auf Discord.",
                ),
                TextButton.icon(
                  icon: const Icon(Icons.discord, size: 18),
                  label: const Text("Community auf Discord"),
                  onPressed: () => launchUrl(
                    Uri.parse(AppInfo.discordUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text("GitHub Repository"),
                  onPressed: () => launchUrl(
                    Uri.parse(AppInfo.repositoryUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ]),

              _section(context, "KI-Unterstützung", [
                _paragraph(
                  "Der Quellcode dieser App wurde zu großen Teilen mit "
                  "Unterstützung von KI-Werkzeugen entwickelt.",
                ),
                _paragraph(
                  "Auch Inhalte können mit KI-Unterstützung zusammengestellt "
                  "oder aufbereitet worden sein. Für welche Datensätze das "
                  "im Einzelnen gilt, ist bisher nicht dokumentiert; wo es "
                  "bekannt ist, steht es beim jeweiligen Bereich.",
                ),
                _paragraph(
                  "Die App unterscheidet zwischen der Quelle eines Inhalts "
                  "und seiner Aufbereitung: KI gilt nicht als Quelle. Wo die "
                  "Herkunft eines Datensatzes nicht dokumentiert ist, wird "
                  "das offen angegeben.",
                ),
              ]),

              _section(context, "Inhalte und Quellen", [
                _paragraph(
                  "Die meisten Inhalte sind als Datensätze fest in der App "
                  "hinterlegt. Der Griechisch-Grammatiktrainer ruft Formen "
                  "zusätzlich beim Üben von Wiktionary ab. Details zu jedem "
                  "Bereich:",
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final module in AppModules.all)
                        ListTile(
                          dense: true,
                          title: Text(module.title),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showModuleInfo(
                            context,
                            module,
                            showAboutLink: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ]),

              _section(context, "Grenzen", [
                _paragraph(
                  "Inhalte und Funktionen können Fehler enthalten – sowohl "
                  "in den Daten als auch in der Auswertung von Antworten. "
                  "Die App ersetzt weder Lehrbuch noch Textausgabe.",
                ),
              ]),

              _section(context, "Technik", [
                _paragraph(
                  "Die App ist mit Flutter entwickelt. Anmeldung und "
                  "Synchronisierung laufen über Firebase (Authentication und "
                  "Cloud Firestore). Ein Backend unter theologie.app ruft "
                  "für den Grammatiktrainer Flexionstabellen von Wiktionary "
                  "ab.",
                ),
              ]),

              _section(context, "Gespeicherte Daten", [
                _paragraph(
                  "Ohne Konto (Gastmodus) werden Lernstände und "
                  "Einstellungen nur lokal in diesem Browser gespeichert.",
                ),
                _paragraph(
                  "Mit Konto werden Lernstände, Einstellungen, Statistiken "
                  "und eigene Merkhilfen in Firebase gespeichert und deinem "
                  "Konto zugeordnet.",
                ),
                _paragraph(
                  "Der Grammatiktrainer überträgt beim Abruf einer Form das "
                  "Wort und die gewünschte Form an das Backend der App.",
                ),
              ]),

              _section(context, "Fehler melden", [
                _paragraph(
                  "Wenn dir ein falscher Inhalt, eine falsche Quelle oder "
                  "ein technischer Fehler auffällt, kannst du das direkt "
                  "melden – hier allgemein oder über „Fehler melden“ im "
                  "jeweiligen Bereich; dann wird der angezeigte Eintrag "
                  "gleich mit übermittelt.",
                ),
                _paragraph(
                  "Eine Meldung enthält Kategorie, Beschreibung, Bereich, "
                  "gegebenenfalls den angezeigten Eintrag sowie App-Version "
                  "und Plattform. Name, E-Mail-Adresse und Konto werden "
                  "nicht übertragen.",
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text("Fehler melden"),
                  onPressed: () => showReportDialog(context),
                ),
              ]),

              _section(context, "Bildnachweis", [
                _paragraph(
                  "Lutherrose auf der Startseite: Datei „Lutherrose.svg“ von "
                  "Wikimedia-Commons-Nutzer „Jed“, Lizenz CC BY-SA 3.0. "
                  "Unverändert als PNG übernommen.",
                ),
              ]),

              _section(context, "Rechtliches", [
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text("Impressum"),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => LegalLinks.open(LegalLinks.impressumPage),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text("Datenschutz"),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => LegalLinks.open(LegalLinks.privacyPage),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text("Open-Source-Lizenzen"),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: AppInfo.name,
                          applicationVersion: AppInfo.version,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
