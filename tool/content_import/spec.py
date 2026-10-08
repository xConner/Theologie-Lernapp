# -*- coding: utf-8 -*-
"""Abschnittsplan des Konkordienbuchs.

Je Abschnitt: (id, (Titel de, la, en) | None, Anker de, Anker la, Anker en).
Ein Anker ist ein regulärer Ausdruck auf einen Textblock der jeweiligen Quelle;
der Abschnitt reicht bis zum nächsten Anker. '+' vor dem Ausdruck: der
Ankerblock gehört zum Text. id None = Bereich wird übersprungen (Titelblätter,
Unterschriftenlisten, bereits anderweitig vorhandene Texte). Titel None = der
Abschnitt besteht schon in assets/confessions.json und behält seinen Titel.
"""
R = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII',
     'XVIII', 'XIX', 'XX', 'XXI', 'XXII', 'XXIII', 'XXIV', 'XXV', 'XXVI', 'XXVII', 'XXVIII']


def P(n):
    return r'^@@PAGE ' + n + '$'


BOOKS = []


def book(cid, title, secs, en_pages):
    BOOKS.append(dict(id=cid, title=title, sections=secs, en_pages=en_pages))


# ---------- Vorrede zum Konkordienbuch ----------
book('konkordienbuch_vorrede',
     dict(de='Vorrede zum Konkordienbuch', la='Praefatio Libri Concordiae', en='Preface to the Book of Concord'),
     [('full', ('Gesamter Text', 'Textus Integer', 'Complete Text'), r'^Vorrede$', r'^PRAEFATIO$', P('preface')),
      (None, None, r'^Die Drei Hauptsymbola', r'^TRIA SYMBOLA', None)],
     [('preface',)])

# ---------- Augsburgische Konfession ----------
ca_de = ['Von Gott', 'Von der Erbsünde', 'Von dem Sohne Gottes', 'Von der Rechtfertigung', 'Vom Predigtamt',
         'Vom neuen Gehorsam', 'Von der Kirche', 'Was die Kirche sei', 'Von der Taufe', 'Vom heiligen Abendmahl',
         'Von der Beichte', 'Von der Buße', 'Vom Gebrauch der Sakramente', 'Vom Kirchenregiment',
         'Von Kirchenordnungen', 'Von der Polizei und weltlichem Regiment',
         'Von der Wiederkunft Christi zum Gericht', 'Vom freien Willen', 'Über die Ursache der Sünde',
         'Vom Glauben und guten Werken', 'Vom Dienst der Heiligen',
         'Von beider Gestalt des Sakraments', 'Vom Ehestand der Priester', 'Von der Messe', 'Von der Beichte',
         'Vom Unterschied der Speise', 'Von Klostergelübden', 'Von der Bischöfe Gewalt']
ca_la22 = ['De Utraque Specie', 'De Coniugio Sacerdotum', 'De Missa', 'De Confessione', 'De Discrimine Ciborum',
           'De Votis Monachorum', 'De Potestate Ecclesiastica']
ca_en22 = ['Of Both Kinds in the Sacrament', 'Of the Marriage of Priests', 'Of the Mass', 'Of Confession',
           'Of the Distinction of Meats', 'Of Monastic Vows', 'Of Ecclesiastical Power']
ca_pages = ['of-god', 'original-sin', 'son-of-god', 'of-justification', 'of-the-ministry', 'of-new-obedience',
            'of-the-church', 'what-the-church-is', 'of-baptism', 'of-the-lords-supper', 'of-confession',
            'of-repentance', 'use-of-the-sacraments', 'of-ecclesiastical-order', 'of-ecclesiastical-usages',
            'of-civil-affairs', 'of-christs-return-to-judgment', 'of-free-will', 'cause-of-sin', 'of-good-works',
            'of-worship-of-saints', 'of-both-kinds-in-the-sacrament', 'of-marriage-of-priests', 'of-the-mass',
            'of-confession-xxv', 'of-the-distinction-of-meats', 'of-monastic-vows', 'of-ecclesiastical-power']
secs = [('vorrede', ('Vorrede an Kaiser Karl V.', 'Praefatio ad Caesarem Carolum V.',
                     'Preface to the Emperor Charles V'),
         r'^Vorrede\.$', r'^Praefatio ad Caesarem', P('augsburg-confession__preface'))]
for i in range(28):
    n = R[i]
    la = r'^Art\. %s\. ' % n if i < 21 else r'^%s\. %s' % (R[i - 21], ca_la22[i - 21])
    t = None if i < 21 else ('Artikel %s: %s' % (n, ca_de[i]), 'Articulus %s: %s' % (n, ca_la22[i - 21]),
                             'Article %s: %s' % (n, ca_en22[i - 21]))
    secs.append(('art_%d' % (i + 1), t, r'^Der %s\. Artikel\.' % n, la, P('augsburg-confession__' + ca_pages[i])))
secs.append(('beschluss', ('Beschluss', 'Epilogus', 'Conclusion'), r'^Schluss\.$', r'^Epilogus\.$',
             P('augsburg-confession__conclusion')))
secs.append((None, None, r'^Apologia der Konfession', r'^Confessionis Augustanae\.$', None))
book('augsburger_konfession', None, secs,
     [('augsburg-confession__preface',)] + [('augsburg-confession__' + p,) for p in ca_pages]
     + [('augsburg-confession__conclusion',)])

# ---------- Apologie ----------
ap = [  # id, de, la, en, Anker de, Anker la, Seite en
    ('vorrede', 'Vorrede: Philipp Melanchthon dem Leser', 'Praefatio: Philippus Melanchthon Lectori',
     'Preface: Philip Melanchthon to the Reader', r'^Philippus Melanchthon dem Leser',
     r'^Philippus Melanchthon Lectori', 'melanchthon-greetings'),
    ('art_1', 'Artikel I: Von Gott', 'Articulus I: De Deo', 'Article I: Of God',
     r'^Artikel I\. Von Gott', r'^Art\. I\. De Deo', 'of-god'),
    ('art_2', 'Artikel II (I): Von der Erbsünde', 'Articulus II (I): De Peccato Originali',
     'Article II (I): Of Original Sin', r'^Artikel II\. \(I\.\)', r'^Art\. II \(I\.\)', 'of-original-sin'),
    ('art_3', 'Artikel III: Von Christo', 'Articulus III: De Christo', 'Article III: Of Christ',
     r'^Artikel III\. Von Christo', r'^Art\. III\. De Christo', 'of-christ'),
    ('art_4', 'Artikel IV (II): Wie man vor Gott fromm und gerecht wird', 'Articulus IV (II): De Iustificatione',
     'Article IV (II): Of Justification', r'^Artikel IV\. \(II\.\)', r'^Art\. IV\. \(II\.\)', 'of-justification'),
    ('art_4_liebe', 'Artikel IV (III): Von der Liebe und Erfüllung des Gesetzes',
     'Articulus IV (III): De Dilectione et Impletione Legis',
     'Article IV (III): Of Love and the Fulfilling of the Law', r'^\(Art\. III\.\) Von der Liebe',
     r'^\(Art\. III\) De Dilectione', 'of-love-and-fulfilling-the-law'),
    ('art_7_8', 'Artikel VII und VIII (IV): Von der Kirche', 'Articulus VII et VIII (IV): De Ecclesia',
     'Articles VII and VIII (IV): Of the Church', r'^Art\. VII und VIII', r'^Art\. VII\. VIII\.', 'of-the-church'),
    ('art_9', None, None, None, r'^Artikel IX\. Von der Taufe', r'^\[Art\. IX\.', 'of-baptism'),
    ('art_10', 'Artikel X: Vom heiligen Abendmahl', 'Articulus X: De Sacra Coena',
     'Article X: Of the Holy Supper', r'^\[Artikel X\.', r'^\[Art\. X\.', 'of-the-holy-supper'),
    ('art_11', 'Artikel XI: Von der Beichte', 'Articulus XI: De Confessione', 'Article XI: Of Confession',
     r'^\[Artikel XI\.', r'^\[Art\. XI\.', 'of-confession'),
    ('art_12', 'Artikel XII (V): Von der Buße', 'Articulus XII (V): De Poenitentia',
     'Article XII (V): Of Repentance', r'^Artikel XII\. \(V\.\)', r'^Art\. XII\. \(V\.\)', 'of-repentance'),
    ('art_12_beichte', 'Artikel XII (VI): Von der Beichte und Genugtuung',
     'Articulus XII (VI): De Confessione et Satisfactione', 'Article XII (VI): Of Confession and Satisfaction',
     r'^\(Artikel VI\.\)', r'^\(Art\. VI\.\)', 'of-confession-and-satisfaction'),
    ('art_13', 'Artikel XIII (VII): Von den Sakramenten und ihrem rechten Gebrauch',
     'Articulus XIII (VII): De Numero et Usu Sacramentorum',
     'Article XIII (VII): Of the Number and Use of the Sacraments', r'^Artikel XIII\.', r'^Art\. XIII\.',
     'of-the-number-and-use-of-sacraments'),
    ('art_14', 'Artikel XIV: Vom Kirchenregiment', 'Articulus XIV: De Ordine Ecclesiastico',
     'Article XIV: Of Ecclesiastical Order', r'^Artikel XIV\.', r'^Art\. XIV\.', 'of-ecclesiastical-order'),
    ('art_15', 'Artikel XV (VIII): Von den menschlichen Satzungen in der Kirche',
     'Articulus XV (VIII): De Traditionibus Humanis in Ecclesia',
     'Article XV (VIII): Of Human Traditions in the Church', r'^Artikel XV\.', r'^Art\. XV\.',
     'of-human-traditions-in-the-church'),
    ('art_16', 'Artikel XVI: Vom weltlichen Regiment', 'Articulus XVI: De Ordine Politico',
     'Article XVI: Of Political Order', r'^Artikel XVI\.', r'^Art\. XVI\.', 'of-political-order'),
    ('art_17', 'Artikel XVII: Von der Wiederkunft Christi zum Gericht',
     'Articulus XVII: De Christi Reditu ad Iudicium', "Article XVII: Of Christ's Return to Judgment",
     r'^Artikel XVII\.', r'^Art\. XVII\.', 'of-christs-return-to-judgment'),
    ('art_18', 'Artikel XVIII: Vom freien Willen', 'Articulus XVIII: De Libero Arbitrio',
     'Article XVIII: Of Free Will', r'^Artikel XVIII\.', r'^Art\. XVIII\.', 'of-free-will'),
    ('art_19', 'Artikel XIX: Von der Ursache der Sünde', 'Articulus XIX: De Causa Peccati',
     'Article XIX: Of the Cause of Sin', r'^Artikel XIX\.', r'^Art\. XIX\.', 'of-the-cause-of-sin'),
    ('art_20', 'Artikel XX: Von guten Werken', 'Articulus XX: De Bonis Operibus', 'Article XX: Of Good Works',
     r'^Artikel XX\.', r'^Art\. XX\.? De Bonis', 'of-good-works'),
    ('art_21', 'Artikel XXI (IX): Vom Anrufen der Heiligen', 'Articulus XXI (IX): De Invocatione Sanctorum',
     'Article XXI (IX): Of the Invocation of Saints', r'^Artikel XXI\.', r'^Art\. XXI\.',
     'of-the-invocation-of-saints'),
    ('art_22', 'Artikel XXII (X): Von beiderlei Gestalt im Abendmahl',
     'Articulus XXII (X): De Utraque Specie Coenae Domini', "Article XXII (X): Of Both Kinds in the Lord's Supper",
     r'^Artikel XXII\.', r'^Art\. XXII\.', 'of-both-kinds-in-the-lords-supper'),
    ('art_23', 'Artikel XXIII (XI): Von der Priesterehe', 'Articulus XXIII (XI): De Coniugio Sacerdotum',
     'Article XXIII (XI): Of the Marriage of Priests', r'^Artikel XXIII\.', r'^Art\. XXIII\.',
     'of-marriage-of-priests'),
    ('art_24', 'Artikel XXIV (XII): Von der Messe', 'Articulus XXIV (XII): De Missa',
     'Article XXIV (XII): Of the Mass', r'^Artikel XXIV\.', r'^Art\. XXIV\.', 'of-the-mass'),
    ('art_27', 'Artikel XXVII (XIII): Von den Klostergelübden', 'Articulus XXVII (XIII): De Votis Monasticis',
     'Article XXVII (XIII): Of Monastic Vows', r'^Artikel XXVII\.', r'^Art\. XXVII\.', 'of-monastic-vows'),
    ('art_28', 'Artikel XXVIII (XIV): Von der Kirchengewalt', 'Articulus XXVIII (XIV): De Potestate Ecclesiastica',
     'Article XXVIII (XIV): Of Ecclesiastical Power', r'^Artikel XXVIII\.', r'^Art\. XXVIII\.',
     'of-ecclesiastical-power'),
]
secs = [(a[0], None if a[1] is None else (a[1], a[2], a[3]), a[4], a[5], P('defense__' + a[6])) for a in ap]
secs.append((None, None, r'Die Schmalkaldischen Artikel', r'ARTICULI SMALCALDICI', None))
book('apologie', dict(de='Apologie der Augsburgischen Konfession', la='Apologia Confessionis Augustanae',
                      en='Apology of the Augsburg Confession'), secs, [('defense__' + a[6],) for a in ap])

# ---------- Schmalkaldische Artikel ----------
sa3 = [('Von der Sünde', 'De Peccato', 'Of Sin'), ('Vom Gesetz', 'De Lege', 'Of the Law'),
       ('Von der Buße', 'De Poenitentia', 'Of Repentance'), ('Vom Evangelium', 'De Evangelio', 'Of the Gospel'),
       ('Von der Taufe', 'De Baptismo', 'Of Baptism'),
       ('Vom Sakrament des Altars', 'De Sacramento Altaris', 'Of the Sacrament of the Altar'),
       ('Von den Schlüsseln', 'De Clavibus', 'Of the Keys'), ('Von der Beichte', 'De Confessione', 'Of Confession'),
       ('Vom Bann', 'De Excommunicatione', 'Of Excommunication'),
       ('Von der Weihe und Vokation', 'De Initiatione, Ordine et Vocatione', 'Of Ordination and the Call'),
       ('Von der Priesterehe', 'De Coniugio Sacerdotum', 'Of the Marriage of Priests'),
       ('Von der Kirche', 'De Ecclesia', 'Of the Church'),
       ('Wie man vor Gott gerecht wird, und von guten Werken',
        'Quomodo coram Deo Homo Iustificetur, et de Bonis Operibus',
        'How One is Justified before God, and of Good Works'),
       ('Von Klostergelübden', 'De Votis Monasticis', 'Of Monastic Vows'),
       ('Von Menschensatzungen', 'De Humanis Traditionibus', 'Of Human Traditions')]
sa3_de = [r'^Das dritte Teil der Artikel', r'^II\. Vom Gesetz', r'^III\. Von der Busse', r'^IV\. Vom Evangelium',
          r'^V\. Von der Taufe', r'^VI\. Von Sakrament', r'^VII\. Von \[den\] Schl', r'^VIII\. Von der Beichte',
          r'^IX\. Vom Bann', r'^X\. Von der Weihe', r'^XI\. Von der Priesterehe', r'^XII\. Von der Kirche',
          r'^XIII\. Wie man', r'^XIV\. Von Kloster', r'^XV\. Von Menschensatzungen']
sa3_la = [r'^TERTIA PARS', r'^II\. De Lege', r'^III\. De Poenitentia', r'^IV\. De Evangelio', r'^V\. De Baptismo',
          r'^VI\. De Sacramento Altaris', r'^VII\. De Clavibus', r'^VIII\. De Confessione',
          r'^IX\. De Excommunicatione', r'^X\. De Initiatione', r'^XI\. De Coniugio', r'^XII\. De Ecclesia',
          r'^XIII\. Quomodo', r'^XIV\. De Votis', r'^XV\. De Humanis']
secs = [
    ('vorrede', ('Vorrede D. Martin Luthers', 'Praefatio D. Martini Lutheri', 'Preface of Dr. Martin Luther'),
     r'^Vorrede Doktor Martin Luthers', r'^Praefatio D\. Martini Lutheri', P('smalcald-articles')),
    ('teil_1', ('Teil I: Von den hohen Artikeln der göttlichen Majestät',
                'Pars I: De summis articulis divinae Maiestatis',
                'Part I: Of the Sublime Articles concerning the Divine Majesty'),
     r'^Das erste Teil', r'^PRIMA PARS', P('smalcald-articles__i__divine-majesty')),
    ('teil_2_art_1', ('Teil II, Artikel I: Der Hauptartikel', 'Pars II, Articulus I: Articulus principalis',
                      'Part II, Article I: The First and Chief Article'),
     r'^Das andere Teil', r'^SECUNDA PARS', P('smalcald-articles__ii__office-and-work-of-jesus')),
    ('teil_2_art_2', ('Teil II, Artikel II: Von der Messe', 'Pars II, Articulus II: De Missa',
                      'Part II, Article II: Of the Mass'),
     r'^Der II\. Artikel\. Von der Messe', r'+^II\. Articulus de Missa', r'^Article II - Of the Mass'),
    ('teil_2_art_3', ('Teil II, Artikel III: Von Stiften und Klöstern',
                      'Pars II, Articulus III: De Collegiis Canonicorum, Cathedralibus et Monasteriis',
                      'Part II, Article III: Of Chapters and Cloisters'),
     r'^Der III\. Artikel\. Von Stiften', r'^III\. Articulus\. De Collegiis', r'^Article III - Of Chapters'),
    ('teil_2_art_4', ('Teil II, Artikel IV: Vom Papsttum', 'Pars II, Articulus IV: De Papatu',
                      'Part II, Article IV: Of the Papacy'),
     r'^Der IV\. Artikel\. Vom Papsttum', r'+^IV\. Articulus de Papatu', r'^Article IV - Of the Papacy')]
for i in range(15):
    en = P('smalcald-articles__iii__part-iii') if i == 0 else r'^Article %s - ' % R[i]
    secs.append(('teil_3_art_%d' % (i + 1),
                 tuple('%s, %s %s: %s' % (a, b, R[i], t) for a, b, t in
                       zip(('Teil III', 'Pars III', 'Part III'), ('Artikel', 'Articulus', 'Article'), sa3[i])),
                 sa3_de[i], sa3_la[i], en))
secs.append((None, None, r'^\(Signatures of Luther', r'^\d+\] Martinus Luther D\. subscripsit',
             P('smalcald-articles__signatories')))
book('schmalkaldische_artikel', dict(de='Schmalkaldische Artikel', la='Articuli Smalcaldici', en='Smalcald Articles'),
     secs, [('smalcald-articles', None, r'^Part I'), ('smalcald-articles__i__divine-majesty',),
            ('smalcald-articles__ii__office-and-work-of-jesus',), ('smalcald-articles__iii__part-iii',),
            ('smalcald-articles__signatories',)])

# ---------- Traktat ----------
book('traktat', dict(de='Traktat von der Gewalt und Obrigkeit des Papstes',
                     la='Tractatus de Potestate et Primatu Papae',
                     en='Treatise on the Power and Primacy of the Pope'),
     [('papst', ('Von der Gewalt und Obrigkeit des Papstes', 'De Potestate et Primatu Papae',
                 'Of the Power and Primacy of the Pope'),
       r'^Von der Gewalt und Oberkeit des Papsts', r'^DE POTESTATE ET PRIMATU PAPAE',
       P('power-and-primacy__treatise-compiled-at-smalcald')),
      ('bischoefe', ('Von der Bischöfe Gewalt und Jurisdiktion', 'De Potestate et Iurisdictione Episcoporum',
                     'Of the Power and Jurisdiction of Bishops'),
       r'^Von der Bischöfe Gewalt und Jurisdiktion', r'^De Potestate et Iurisdictione Episcoporum',
       P('power-and-primacy__power-and-jurisdiction-of-bishops')),
      (None, None, r'^Verzeichnis der Doktoren', r'^DOCTORES ET CONCIONATORES', P('power-and-primacy__signatories'))],
     [('power-and-primacy__treatise-compiled-at-smalcald',),
      ('power-and-primacy__power-and-jurisdiction-of-bishops',), ('power-and-primacy__signatories',)])

# ---------- Kleiner Katechismus ----------
book('kleiner_katechismus', None,
     [('vorrede', ('Vorrede D. Martin Luthers', 'Praefatio D. Martini Lutheri', 'Preface of Dr. Martin Luther'),
       r'^Vorrede D\. Martini Lutheri', r'^Praefatio D\. Martini Lutheri', P('small-catechism__preface')),
      ('hauptstueck_1', None, r'^I\. Die zehn Gebote', r'^I\. DECEM PRAECEPTA',
       P('small-catechism__ten-commandments')),
      ('hauptstueck_2', None, r'^II\. Der Glaube', r'^II\. SYMBOLUM', P('small-catechism__the-creed')),
      ('hauptstueck_3', None, r'^III\. Das Vaterunser', r'^III\. ORATIO DOMINICA',
       P('small-catechism__the-lords-prayer')),
      ('hauptstueck_4', None, r'^IV\. Das Sakrament der heiligen Taufe', r'^IV\. SACRAMENTUM BAPTISMI',
       P('small-catechism__the-sacrament-of-holy-baptism')),
      ('hauptstueck_5', None, r'lehren beichten', r'^V\. DE CONFESSIONE',
       P('small-catechism__how-christians-confess')),
      ('hauptstueck_6', None, r'^VI\. Das Sakrament des Altars', r'^VI\. SACRAMENTUM ALTARIS',
       P('small-catechism__the-sacrament-of-the-altar')),
      ('gebete', ('Anhang I: Morgen- und Abendsegen, Benedicite und Gratias',
                  'Appendix I: Benedictiones et Preces', 'Appendix I: Daily Prayers'),
       r'^\[Anhang I\.\]', r'^\[Appendix I\.\]', P('small-catechism__daily-prayers')),
      ('haustafel', ('Anhang II: Die Haustafel', 'Appendix II: Tabula Oeconomica', 'Appendix II: Table of Duties'),
       r'^\[Anhang II\.\]', r'^\[Appendix II\.\]', P('small-catechism__table-of-duties')),
      (None, None, r'^Der Grosse Katechismus', r'^CATECHISMUS MAIOR', None)],
     [('small-catechism__preface',), ('small-catechism__ten-commandments',), ('small-catechism__the-creed',),
      ('small-catechism__the-lords-prayer',), ('small-catechism__the-sacrament-of-holy-baptism',),
      ('small-catechism__how-christians-confess',), ('small-catechism__the-sacrament-of-the-altar',),
      ('small-catechism__daily-prayers',), ('small-catechism__table-of-duties',)])

# ---------- Großer Katechismus ----------
ordde = ['erste', 'zweite', 'dritte', 'vierte', 'fünfte', 'sechste', 'siebente', 'achte']
orden = ['First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth', 'Seventh', 'Eighth']
secs = [('vorrede', ('Vorrede D. Martin Luthers', 'Praefatio D. Martini Lutheri', 'Preface of Dr. Martin Luther'),
         r'^D\. Martin Luther\.$', r'^D\. Martini Lutheri\.$', P('large-catechism')),
        ('kurze_vorrede', ('Kurze Vorrede', 'Brevis Praefatio', 'Short Preface'),
         r'^Kurze Vorrede', r'^DOCT\. MART\. LUTHERI BREVIS', P('large-catechism__preface')),
        ('gebot_1', ('Das erste Gebot', 'Praeceptum I', 'The First Commandment'),
         r'^\[Das erste Teil\.\]', r'^\[Prima Pars\.\]', P('large-catechism__ten-commandments'))]
for i in range(1, 8):
    secs.append(('gebot_%d' % (i + 1),
                 ('Das %s Gebot' % ordde[i], 'Praeceptum %s' % R[i], 'The %s Commandment' % orden[i]),
                 r'+^Das %s Gebot\.$' % ordde[i], r'+^Praeceptum %s\.?$' % R[i],
                 r'+^The %s Commandment\.$' % orden[i]))
secs += [
    ('gebot_9_10', ('Das neunte und zehnte Gebot', 'Praeceptum IX et X', 'The Ninth and Tenth Commandments'),
     r'+^Das neunte und zehnte Gebot', r'+^Praeceptum IX\. et X\.', r'+^The Ninth and Tenth Commandments'),
    ('beschluss_gebote', ('Beschluss der zehn Gebote', 'Conclusio Decalogi', 'Conclusion of the Ten Commandments'),
     r'^Beschluss der zehn Gebote', r'^Conclusio Decalogi', r'^Conclusion of the Ten Commandments'),
    ('glaube', ('Der Glaube: Einleitung', 'Symbolum Fidei: Introductio', 'The Creed: Introduction'),
     r'^Das zweite Teil\.$', r'^Secunda Pars Catechismi', P('large-catechism__apostles-creed')),
    ('glaube_art_1', ('Der Glaube: Der erste Artikel', 'Symbolum Fidei: Articulus I', 'The Creed: Article I'),
     r'^Der erste Artikel\.$', r'^Articulus I\.$', r'^Article I\.$'),
    ('glaube_art_2', ('Der Glaube: Der zweite Artikel', 'Symbolum Fidei: Articulus II', 'The Creed: Article II'),
     r'^Der zweite Artikel\.$', r'^Articulus II\.$', r'^Article II\.$'),
    ('glaube_art_3', ('Der Glaube: Der dritte Artikel', 'Symbolum Fidei: Articulus III', 'The Creed: Article III'),
     r'^Der dritte Artikel\.$', r'^Articulus III\.$', r'^Article III\.$'),
    ('vaterunser', ('Das Vaterunser: Einleitung', 'Oratio Dominica: Introductio',
                    "The Lord's Prayer: Introduction"),
     r'^Das dritte Teil, vom Gebet', r'^Tertia Catechismi Pars', P('large-catechism__lords-prayer'))]
bde = ['Die erste Bitte', 'Die zweite Bitte', 'Die dritte Bitte', 'Die vierte Bitte', 'Die fünfte Bitte',
       'Die sechste Bitte', 'Die siebente und letzte Bitte']
bla = ['Prima Precatio', 'Secunda Precatio', 'Tertia Petitio', 'Quarta Petitio', 'Quinta Petitio', 'Sexta Petitio',
       'Ultima Petitio']
blat = ['Prima Petitio', 'Secunda Petitio', 'Tertia Petitio', 'Quarta Petitio', 'Quinta Petitio', 'Sexta Petitio',
        'Ultima Petitio']
for i in range(7):
    secs.append(('bitte_%d' % (i + 1),
                 ('Das Vaterunser: ' + bde[i], 'Oratio Dominica: ' + blat[i],
                  "The Lord's Prayer: The %s Petition" % orden[i]),
                 r'^' + bde[i], r'^' + bla[i], r'^The %s Petition' % orden[i]))
secs += [
    ('taufe', ('Von der Taufe', 'De Baptismo', 'Of Baptism'),
     r'^Das vierte Teil\.$', r'^Quarta Pars Catechismi', P('large-catechism__holy-baptism')),
    ('kindertaufe', ('Von der Kindertaufe', 'De Puerorum Baptismo', 'Of Infant Baptism'),
     r'^Von der Kindertaufe', r'^\[DE PUERORUM BAPTISMO', r'^Of Infant Baptism'),
    ('abendmahl', ('Von dem Sakrament des Altars', 'De Sacramento Altaris', 'Of the Sacrament of the Altar'),
     r'^\[Das fünfte Teil\.\]', r'^\[Quinta Pars\.\]', P('large-catechism__sacrament-of-the-altar')),
    (None, None, r'^Die Konkordienformel\.$', r'^FORMULA CONCORDIAE', None)]
book('grosser_katechismus', dict(de='Der Große Katechismus', la='Catechismus Maior', en='The Large Catechism'), secs,
     [('large-catechism', r'A Christian, Profitable', r'^Short Preface'), ('large-catechism__preface',),
      ('large-catechism__ten-commandments',), ('large-catechism__apostles-creed',),
      ('large-catechism__lords-prayer',), ('large-catechism__holy-baptism',),
      ('large-catechism__sacrament-of-the-altar',)])

# ---------- Konkordienformel ----------
fc = [('Von der Erbsünde', 'De Peccato Originis', 'Of Original Sin'),
      ('Vom freien Willen', 'De Libero Arbitrio', 'Of Free Will'),
      ('Von der Gerechtigkeit des Glaubens vor Gott', 'De Iustitia Fidei coram Deo',
       'Of the Righteousness of Faith before God'),
      ('Von guten Werken', 'De Bonis Operibus', 'Of Good Works'),
      ('Vom Gesetz und Evangelium', 'De Lege et Evangelio', 'Of the Law and the Gospel'),
      ('Vom dritten Brauch des Gesetzes', 'De Tertio Usu Legis', 'Of the Third Use of the Law'),
      ('Vom heiligen Abendmahl', 'De Coena Domini', "Of the Lord's Supper"),
      ('Von der Person Christi', 'De Persona Christi', 'Of the Person of Christ'),
      ('Von der Höllenfahrt Christi', 'De Descensu Christi ad Inferos', 'Of the Descent of Christ to Hell'),
      ('Von Kirchengebräuchen, so man Adiaphora oder Mitteldinge nennt',
       'De Ceremoniis Ecclesiasticis, quae vulgo Adiaphora vocantur', 'Of Church Rites which are Called Adiaphora'),
      ('Von der ewigen Vorsehung und Wahl Gottes', 'De Aeterna Praedestinatione et Electione Dei',
       "Of God's Eternal Foreknowledge and Election"),
      ('Von andern Rotten und Sekten', 'De Aliis Haeresibus et Sectis', 'Of Other Factions and Sects')]
fc_de = [r'^I\. Von der Erbsünde', r'^II\. Vom freien Willen', r'^III\. Von der Gerechtigkeit',
         r'^IV\. Von guten Werken', r'^V\. Vom Gesetz', r'^VI\. Vom dritten Brauch', r'^VII\. Vom heiligen Abendmahl',
         r'^VIII\. Von der Person', r'^IX\. Von der Höllenfahrt', r'^X\. Von Kirchengebräuchen',
         r'^XI\. Von der ewigen', r'^\[?XII\.\]? Von andern Rotten']
fc_la = [r'^I\. DE PECCATO ORIGINIS', r'^II\. DE LIBERO ARBITRIO', r'^III\. DE IUSTITIA FIDEI',
         r'^IV\. DE BONIS OPERIBUS', r'^V\. DE LEGE ET EVANGELIO', r'^VI\. DE TERTIO USU LEGIS',
         r'^VII\. DE COENA DOMINI', r'^VIII\. DE PERSONA CHRISTI', r'^IX\. DE DESCENSU', r'^X\. DE CEREMONIIS',
         r'^XI\. DE AETERNA', r'^XII\. DE ALIIS']
ep_pages = ['original-sin', 'free-will', 'righteousness-of-faith', 'good-works', 'law-and-gospel',
            'third-use-of-the-law', 'the-lords-supper', 'person-of-christ', 'descent-of-christ-into-hell',
            'church-rites', 'election', 'other-sects']
sd_pages = ['original-sin', 'free-will', 'righteousness-of-faith', 'good-works', 'law-and-gospel',
            'third-use-of-the-law', 'the-holy-supper', 'person-of-christ', 'christs-descent-into-hell',
            'church-rites-adiaphora', 'election', 'other-sects']
secs = [('regel_und_richtschnur', None, r'^Von dem summarischen Begriff, Regel und Richtschnur',
         r'^DE COMPENDIARIA REGULA ATQUE NORMA', P('epitome__rule-and-norm'))]
for i in range(12):
    secs.append(('art_%d' % (i + 1),
                 tuple('%s %s: %s' % (a, R[i], t) for a, t in zip(('Artikel', 'Articulus', 'Article'), fc[i])),
                 fc_de[i], fc_la[i], P('epitome__' + ep_pages[i])))
secs.append((None, None, r'^\[Zweiter Teil\.\]', r'^\(FORMULA CONCORDIAE SOLIDA DECLARATIO\)', None))
book('konkordienformel_epitome', dict(de='Konkordienformel: Epitome', la='Formula Concordiae: Epitome',
                                      en='Formula of Concord: Epitome'), secs,
     [('epitome__rule-and-norm',)] + [('epitome__' + p,) for p in ep_pages])
secs = [('vorrede', ('Vorrede', 'Praefatio', 'Preface'),
         r'^Mit Kurfl\. Gn zu Sachsen Befreiung\. Dresden Anno', r'^REPETITIO ET DECLARATIO',
         P('solid-declaration__preface')),
        ('regel_und_richtschnur', ('Von dem summarischen Begriff, Grund, Regel und Richtschnur',
                                   'De compendiaria doctrinae forma, fundamento, norma atque regula',
                                   'Of the Summary Content, Foundation, Rule, and Standard'),
         r'^Von dem summarischen Begriff, Grund, Regel', r'^DE COMPENDIARIA DOCTRINAE FORMA',
         P('solid-declaration__rule-and-norm'))]
for i in range(12):
    secs.append(('art_%d' % (i + 1),
                 tuple('%s %s: %s' % (a, R[i], t) for a, t in zip(('Artikel', 'Articulus', 'Article'), fc[i])),
                 fc_de[i], fc_la[i], P('solid-declaration__' + sd_pages[i])))
book('konkordienformel_solida_declaratio',
     dict(de='Konkordienformel: Solida Declaratio', la='Formula Concordiae: Solida Declaratio',
          en='Formula of Concord: Solid Declaration'), secs,
     [('solid-declaration__preface',), ('solid-declaration__rule-and-norm',)]
     + [('solid-declaration__' + p,) for p in sd_pages])
