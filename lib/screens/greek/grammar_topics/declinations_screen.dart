import 'package:flutter/material.dart';

import '../../../widgets/grammar_overview_widgets.dart';

class DeclinationsScreen extends StatelessWidget {
  const DeclinationsScreen({super.key});

  static Widget _form(String stem, String article, String ending) {
    return GrammarCell.ending(stem, ending, article: article);
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Deklinationen",
      children: [
        GrammarSection(
          title: "o-Deklination",
          child: GrammarTable(
            headerRows: const {0, 5},
            rows: [
              const [
                GrammarCell.header("Singular"),
                GrammarCell.header("Maskulinum"),
                GrammarCell.header("Neutrum"),
              ],
              [
                const GrammarCell.label("Nom."),
                _form("λόγ", "ὁ", "ος"),
                _form("δένδρ", "τὸ", "ον"),
              ],
              [
                const GrammarCell.label("Gen."),
                _form("λόγ", "τοῦ", "ου"),
                _form("δένδρ", "τοῦ", "ου"),
              ],
              [
                const GrammarCell.label("Dat."),
                _form("λόγ", "τῷ", "ῳ"),
                _form("δένδρ", "τῷ", "ῳ"),
              ],
              [
                const GrammarCell.label("Akk."),
                _form("λόγ", "τὸν", "ον"),
                _form("δένδρ", "τὸ", "ον"),
              ],
              const [GrammarCell.header("Plural")],
              [
                const GrammarCell.label("Nom."),
                _form("λόγ", "οἱ", "οι"),
                _form("δένδρ", "τὰ", "α"),
              ],
              [
                const GrammarCell.label("Gen."),
                _form("λόγ", "τῶν", "ων"),
                _form("δένδρ", "τῶν", "ων"),
              ],
              [
                const GrammarCell.label("Dat."),
                _form("λόγ", "τοῖς", "οις"),
                _form("δένδρ", "τοῖς", "οις"),
              ],
              [
                const GrammarCell.label("Akk."),
                _form("λόγ", "τοὺς", "ους"),
                _form("δένδρ", "τὰ", "α"),
              ],
            ],
          ),
        ),

        GrammarSection(
          title: "a-Deklination",
          child: GrammarTable(
            headerRows: const {0, 5},
            rows: [
              const [
                GrammarCell.header("Singular"),
                GrammarCell.header("-η"),
                GrammarCell.header("-α (Stamm endet auf ε, ι, ρ)"),
              ],
              [
                const GrammarCell.label("Nom."),
                _form("ἀρχ", "ἡ", "ή"),
                _form("καρδί", "ἡ", "α"),
              ],
              [
                const GrammarCell.label("Gen."),
                _form("ἀρχ", "τῆς", "ῆς"),
                _form("καρδί", "τῆς", "ας"),
              ],
              [
                const GrammarCell.label("Dat."),
                _form("ἀρχ", "τῇ", "ῇ"),
                _form("καρδί", "τῇ", "ᾳ"),
              ],
              [
                const GrammarCell.label("Akk."),
                _form("ἀρχ", "τὴν", "ήν"),
                _form("καρδί", "τὴν", "αν"),
              ],
              const [GrammarCell.header("Plural")],
              [
                const GrammarCell.label("Nom."),
                _form("ἀρχ", "αἱ", "αί"),
                _form("καρδί", "αἱ", "αι"),
              ],
              [
                const GrammarCell.label("Gen."),
                _form("ἀρχ", "τῶν", "ῶν"),
                _form("καρδί", "τῶν", "ῶν"),
              ],
              [
                const GrammarCell.label("Dat."),
                _form("ἀρχ", "ταῖς", "αῖς"),
                _form("καρδί", "ταῖς", "αις"),
              ],
              [
                const GrammarCell.label("Akk."),
                _form("ἀρχ", "τὰς", "άς"),
                _form("καρδί", "τὰς", "ας"),
              ],
            ],
          ),
        ),

        GrammarSection(
          title: "3./Konsonantische Deklination",
          child: GrammarTable(
            headerRows: const {0, 5},
            rows: [
              const [GrammarCell.header("Singular")],
              [const GrammarCell.label("Nom."), _form("παῖ", "ὁ", "ς")],
              [const GrammarCell.label("Gen."), _form("παιδ", "τοῦ", "ός")],
              [const GrammarCell.label("Dat."), _form("παιδ", "τῷ", "ί")],
              [const GrammarCell.label("Akk."), _form("παῖδ", "τὸν", "α")],
              const [GrammarCell.header("Plural")],
              [const GrammarCell.label("Nom."), _form("παῖδ", "οἱ", "ες")],
              [const GrammarCell.label("Gen."), _form("παίδ", "τῶν", "ων")],
              [const GrammarCell.label("Dat."), _form("παι", "τοῖς", "σί")],
              [const GrammarCell.label("Akk."), _form("παῖδ", "τοὺς", "ας")],
            ],
          ),
        ),
      ],
    );
  }
}
