# -*- coding: utf-8 -*-
"""Ergänzt ``assets/prayers.json`` um liturgische Stücke und Gebete aus dem
„Kirchenbuch für Evangelisch-Lutherische Gemeinden“ (Philadelphia 1877) und
ordnet alle Einträge einer Rubrik zu.

Die Texte sind aus dem Faksimile (archive.org, kirchenbuchfur00gene)
abgeschrieben: Texterkennung der Seite (ocr_pages.py), danach Wort für Wort am
Seitenbild nachgelesen. Orthographie der Ausgabe ("gieb", "thut", groß
geschriebene Anrede Gottes); Zierinitialen und Silbentrennung aufgelöst,
Rubriken (Handlungsanweisungen) weggelassen, Rollenangaben als "Pfarrer:" /
"Gemeinde:" vor die Zeile gesetzt. Der Lauf ist wiederholbar: vorhandene
Einträge mit gleicher ID werden ersetzt.
"""
import json

from common import repo

KB = ('Kirchenbuch für Evangelisch-Lutherische Gemeinden, hg. von der Allgemeinen Kirchenversammlung '
      '(General Council), Philadelphia 1877; am Faksimile geprüft (archive.org, kirchenbuchfur00gene), %s; '
      'Orthographie der Ausgabe')

# Rubrik der schon vorhandenen Einträge
CATEGORIES = {
    'vaterunser': 'grundtexte',
    'jesusgebet': 'weitere',
    'magnificat': 'lobgesaenge', 'benedictus': 'lobgesaenge', 'nunc_dimittis': 'lobgesaenge',
    'gloria_patri': 'lobgesaenge', 'gloria_in_excelsis': 'lobgesaenge', 'trishagion': 'lobgesaenge',
    'kyrie': 'gottesdienst',
    'agnus_dei': 'abendmahl', 'sanctus': 'abendmahl', 'dankkollekte_abendmahl': 'abendmahl',
    'verleih_uns_frieden': 'anliegen', 'kollekte_um_frieden': 'anliegen',
    'luthers_morgensegen': 'tageslauf', 'luthers_abendsegen': 'tageslauf',
    'tischgebet_benedicite': 'tageslauf', 'tischgebet_gratias': 'tageslauf',
}


def entry(pid, title, category, kind, tags, where, text, description, tradition='lutherisch',
          source=None, dating=None, note=None):
    version = {'language': 'de', 'status': 'original', 'source': KB % where, 'text': text}
    if note:
        version['note'] = note
    e = {'id': pid, 'title': {'de': title}, 'category': category, 'type': kind, 'tradition': tradition,
         'originalLanguage': 'de',
         'source': source or 'Lutherische Agende des 19. Jahrhunderts (Kirchenbuch, Philadelphia 1877)'}
    if dating:
        e['dating'] = dating
    e['description'] = description
    e['tags'] = tags
    e['versions'] = [version]
    return e


HG = 'Ordnung des Haupt-Gottesdienstes, S. %s'
COLLECT_SOURCE = 'Kollektengebet lutherischer Agenden (Kirchenbuch, Philadelphia 1877)'

NEW = [
    # ---------------- Liturgie: Gottesdienst ----------------
    entry('votum_und_adjutorium', 'Eingangsvotum und Adjutorium', 'gottesdienst', 'liturgisches_stueck',
          ['liturgie', 'gottesdienst', 'lutherisch', 'trinitaet'], HG % '3',
          'Pfarrer: Im Namen des Vaters und des Sohnes und des Heiligen Geistes.\nGemeinde: Amen.\n\n'
          'Pfarrer: Unsere Hilfe steht im Namen des Herrn.\nGemeinde: Der Himmel und Erde gemacht hat.\n\n'
          'Pfarrer: Ich sprach, ich will dem Herrn meine Übertretung bekennen.\n'
          'Gemeinde: Da vergabst Du mir die Missethat meiner Sünde.',
          'Eröffnung des Gottesdienstes im Namen des dreieinigen Gottes mit den Wechselversen aus '
          'Psalm 124,8 und Psalm 32,5.',
          source='Trinitarisches Votum (Matthäus 28,19) mit Psalm 124,8 und Psalm 32,5; Eröffnung des '
                 'lutherischen Hauptgottesdienstes'),
    entry('suendenbekenntnis_gottesdienst', 'Sündenbekenntnis im Gottesdienst (Offene Schuld)', 'gottesdienst',
          'gebet', ['liturgie', 'gottesdienst', 'busse', 'beichte', 'lutherisch'], HG % '4',
          'Pfarrer: Ich armer sündiger Mensch bekenne Gott dem Allmächtigen,\nmeinem Schöpfer und Erlöser,\n'
          'daß ich nicht allein gesündigt habe mit Gedanken, Worten oder Werken,\n'
          'sondern auch in Sünden empfangen und geboren bin,\n'
          'also daß alle meine Natur und Wesen vor Seiner Gerechtigkeit sträflich und verdammlich ist.\n'
          'Darum fliehe ich zu Seiner grundlosen Barmherzigkeit, such und bitt um Gnade.\n'
          'Herr, sei gnädig mir armen Sünder.\n\n'
          'Gemeinde: Der barmherzige Gott wolle Sich unser erbarmen\nund uns unsre Sünde verzeihen\n'
          'und den Heiligen Geist geben,\ndaß wir durch Ihn Seinen göttlichen Willen vollbringen\n'
          'und das ewige Leben empfangen. Amen.',
          'Gemeinsames Sündenbekenntnis zu Beginn des Hauptgottesdienstes mit der Bitte der Gemeinde um '
          'Erbarmen.'),
    entry('gnadenzusage_gottesdienst', 'Absolution im Gottesdienst (Gnadenzusage)', 'gottesdienst',
          'liturgisches_stueck', ['liturgie', 'gottesdienst', 'beichte', 'lutherisch'], HG % '4',
          'Der allmächtige, barmherzige Gott hat Sich unser erbarmt,\n'
          'Seinen einigen Sohn für unsere Sünde in den Tod gegeben\nund um Seinetwillen uns verziehen,\n'
          'auch allen denen, die an Seinen heiligen Namen glauben,\nMacht gegeben, Gottes Kinder zu werden,\n'
          'und den Heiligen Geist verheißen.\nWer da glaubet und getauft wird, der wird selig werden.\n'
          'Das verleihe Gott uns allen.\nAmen.',
          'Zuspruch der Vergebung nach dem Sündenbekenntnis; die Gemeinde antwortet mit „Amen“.'),
    entry('salutatio', 'Salutatio (Der Herr sei mit euch)', 'gottesdienst', 'liturgisches_stueck',
          ['liturgie', 'gottesdienst', 'altkirchlich', 'lutherisch'], HG % '6',
          'Pfarrer: Der Herr sei mit Euch.\nGemeinde: Und mit deinem Geiste.\nPfarrer: Lasset uns beten.',
          'Wechselgruß vor dem Kollektengebet.', tradition='altkirchlich',
          source='Altkirchlicher liturgischer Gruß (vgl. Rut 2,4; 2. Timotheus 4,22)'),
    entry('kanzelsegen', 'Kanzelsegen (Der Friede Gottes)', 'gottesdienst', 'segen',
          ['liturgie', 'gottesdienst', 'segen', 'biblisch', 'frieden'], HG % '9',
          'Der Friede Gottes, welcher höher ist, denn alle Vernunft,\n'
          'bewahre eure Herzen und Sinne in Christo Jesu zum ewigen Leben.\nAmen.',
          'Votum nach der Predigt.', tradition='biblisch', source='Philipper 4,7 in liturgischer Fassung'),
    entry('offertorium', 'Offertorium: Schaffe in mir, Gott, ein reines Herze', 'gottesdienst',
          'biblisches_gebet', ['liturgie', 'gottesdienst', 'biblisch', 'busse'], HG % '10',
          'Schaffe in mir, Gott, ein reines Herze\nund gieb mir einen neuen gewissen Geist.\n'
          'Verwirf mich nicht von Deinem Angesicht,\nund nimm Deinen Heiligen Geist nicht von mir.\n'
          'Tröste mich wieder mit Deiner Hilfe,\nund er, der freudige Geist, enthalte mich.\n'
          'Wasche mich wohl von meiner Missethat,\nund reinige mich von meiner Sünde.',
          'Gesang nach der Predigt, während die Gaben gesammelt werden (erste der drei Formen des '
          'Kirchenbuchs).', tradition='biblisch', source='Psalm 51,12–14 und 4'),
    entry('allgemeines_kirchengebet', 'Das allgemeine Kirchengebet', 'gottesdienst', 'gebet',
          ['liturgie', 'gottesdienst', 'fuerbitte', 'kirche', 'obrigkeit', 'not', 'lutherisch'],
          HG % '10–12',
          'Allmächtiger, barmherziger, ewiger Gott und Vater unseres Herrn Jesu Christi, ein Herr Himmels und '
          'der Erden, wir bitten Dich herzlich, Du wollest Deine heilige Kirche mit ihren Dienern, Wächtern '
          'und Hirten durch Deinen Heiligen Geist regieren, auf daß sie bei der rechtschaffenen Weide Deines '
          'allmächtigen und ewigen Wortes erhalten werden, dadurch der Glaube an Dich gestärket und die Liebe '
          'gegen alle Menschen in uns erwachse und zunehme.\nGemeinde: Erhöre uns, lieber Herre Gott.\n\n'
          'Wollest auch der weltlichen Obrigkeit, insonderheit den Beamten unseres Volkes Gnade und Einigkeit '
          'verleihen, das Land nach Deinem göttlichen Willen und Wohlgefallen zu regieren, auf daß die '
          'Gerechtigkeit gefördert, die Bosheit verhindert und gestraft werde, damit wir in stiller Ruhe und '
          'gutem Frieden, wie Christen gebührt, unser Leben vollstrecken mögen.\n'
          'Gemeinde: Erhöre uns, lieber Herre Gott.\n\n'
          'Gieb auch, daß unsere Feinde und Widersacher ablassen und sich mit uns friedlich und sanftmütig zu '
          'leben begeben wollen.\nGemeinde: Erhöre uns, lieber Herre Gott.\n\n'
          'Alle die, so in Trübsal, Armut, Krankheit, Kindesbanden, Todesnöten und anderer Anfechtung sind, '
          'auch die, so um Deines heiligen Namens und der Wahrheit willen angefochten, gefangen sind oder '
          'sonst Verfolgung leiden: tröst sie, o Gott, mit Deinem Heiligen Geist, daß sie solches alles für '
          'Deinen väterlichen Willen aufnehmen und erkennen.\nGemeinde: Erhöre uns, lieber Herre Gott.\n\n'
          'Und ob wir zwar mit unsern Sünden Deinen gerechten Zorn und allerlei Strafen wohl verdient haben; '
          'so bitten wir doch, o treuer, barmherziger Vater, von Grund unserer Seelen, daß Du nicht gedenken '
          'wollest der Sünden unserer Jugend, noch aller unserer Übertretung, sondern vielmehr eingedenk '
          'bleiben Deiner grundlosen Güte, Gnade und Barmherzigkeit und uns mit allerlei schweren Plagen des '
          'Leibes und der Seele verschonen. Behüte uns gnädig vor fremder, verderblicher Lehre, vor Krieg und '
          'Blutvergießen, vor Pestilenz und schädlicher Seuche an Menschen und Vieh, vor Feuers- und '
          'Wassersnot, vor Hagel und Ungewitter, vor Mißwachs und teurer Zeit, vor allem Herzeleid und '
          'sonderlich vor unleidlicher hoher Anfechtung der Seelen und einem bösen schnellen Tod. Hilf '
          'allenthalben aus aller Not und sei ein Heiland aller Menschen, sonderlich Deiner Gläubigen.\n'
          'Gemeinde: Behüte uns, lieber Herre Gott,\nErhöre uns, lieber Herre Gott.\n\n'
          'Wollest uns auch alle Früchte der Erde zur leiblichen Notdurft gehörig, mit fruchtbarem Wachstum '
          'geraten und gedeihen lassen; auch christliche Kinderzucht, alle ehrliche Nahrung und Hantierung zu '
          'Wasser und zu Lande, alle edlen Künste und Wissenschaften mit Deinem göttlichen Segen krönen.\n'
          'Gemeinde: Erhöre uns, lieber Herre Gott.\n\n'
          'Solches und alles, dafür Du ewiger Gott gebeten sein willst, verleihe uns gnädiglich durch das '
          'bittere Leiden und Sterben Christi Jesu, Deines einigen Sohnes, unsres geliebten Herrn und '
          'Heilandes, welcher mit Dir und dem Heiligen Geiste lebet und regieret, gleicher Gott, hochgelobet '
          'in Ewigkeit.',
          'Das große Fürbittgebet des Hauptgottesdienstes: für die Kirche und ihre Diener, die Obrigkeit, die '
          'Feinde, die Notleidenden, um Bewahrung und um das tägliche Brot. An der vorgesehenen Stelle werden '
          'die besonderen Fürbitten eingefügt; es folgt das Vaterunser.'),
    entry('benedicamus', 'Dankversikel und Benedicamus', 'gottesdienst', 'liturgisches_stueck',
          ['liturgie', 'gottesdienst', 'danksagung', 'lobpreis', 'lutherisch'], HG % '20',
          'Pfarrer: Danket dem Herrn, denn Er ist freundlich. Hallelujah.\n'
          'Gemeinde: Und Seine Güte währet ewiglich. Hallelujah.\n\n'
          'Pfarrer: Laßt uns benedeien den Herren.\nGemeinde: Gott sei ewiglich Dank.',
          'Wechselverse vor dem Dankgebet (Psalm 118,1) und vor dem Segen.',
          source='Psalm 118,1 und altkirchliches „Benedicamus Domino“'),
    entry('aaronitischer_segen', 'Der aaronitische Segen', 'gottesdienst', 'segen',
          ['liturgie', 'gottesdienst', 'segen', 'biblisch', 'frieden'], HG % '20',
          'Der Herr segne dich und behüte dich.\n'
          'Der Herr lasse Sein Angesicht leuchten über dir und sei dir gnädig.\n'
          'Der Herr erhebe Sein Angesicht auf dich und gebe dir Frieden.\nAmen.',
          'Schlusssegen des lutherischen Gottesdienstes, von Luther in der Deutschen Messe (1526) eingeführt.',
          tradition='biblisch', source='4. Mose 6,24–26'),

    # ---------------- Liturgie: Abendmahl ----------------
    entry('praefation', 'Präfation (Sursum corda und gemeine Präfation)', 'abendmahl', 'liturgisches_stueck',
          ['liturgie', 'abendmahl', 'altkirchlich', 'lobpreis', 'danksagung'], HG % '13',
          'Pfarrer: Der Herr sei mit Euch.\nGemeinde: Und mit deinem Geiste.\n'
          'Pfarrer: Die Herzen in die Höhe.\nGemeinde: Erheben wir zum Herrn.\n'
          'Pfarrer: Lasset uns danksagen dem Herrn, unserm Gotte.\nGemeinde: Das ist würdig und recht.\n\n'
          'Pfarrer: Wahrhaft würdig und recht, billig und heilsam ists,\n'
          'daß wir Dir, heiliger Herr, allmächtiger Vater, ewiger Gott,\n'
          'allezeit und allenthalben danksagen durch Christum, unsern Herrn,\n'
          'durch welchen Deine Majestät loben die Engel,\nanbeten die Herrschaften,\nfürchten die Mächte,\n'
          'die Himmel und aller Himmel Kräfte samt den seligen Seraphim mit einhelligem Jubel preisen.\n'
          'Mit ihnen laß auch unsre Stimmen uns vereinen und anbetend zu Dir sprechen:',
          'Eröffnung der Abendmahlsfeier; die Präfation mündet in das Sanctus. In den Festzeiten treten '
          'besondere Präfationen an ihre Stelle.', tradition='altkirchlich',
          source='Altkirchlicher Eröffnungsdialog und Praefatio communis der abendländischen Messe, deutsch'),
    entry('einsetzungsworte', 'Die Einsetzungsworte des Abendmahls', 'abendmahl', 'liturgisches_stueck',
          ['liturgie', 'abendmahl', 'biblisch', 'lutherisch', 'katechismus'], HG % '18',
          'Unser Herr Jesus Christus, in der Nacht da Er verraten ward,\nnahm Er das Brot,\n'
          'dankte und brachs und gabs Seinen Jüngern, und sprach:\n'
          'Nehmet hin und esset, das ist Mein Leib, der für euch gegeben wird.\n'
          'Solches thut zu Meinem Gedächtnis.\n\n'
          'Desselben gleichen nahm Er auch den Kelch nach dem Abendmahl,\n'
          'dankte und gab ihnen den und sprach:\nNehmet hin und trinket alle daraus;\n'
          'dieser Kelch ist das Neue Testament in Meinem Blut,\n'
          'das für euch vergossen wird zur Vergebung der Sünden.\n'
          'Solches thut so oft ihrs trinket, zu Meinem Gedächtnis.',
          'Die Stiftungsworte Christi in der aus den vier Berichten zusammengefügten Fassung, wie sie auch '
          'Luthers Kleiner Katechismus bietet.', tradition='biblisch',
          source='Matthäus 26,26–28; Markus 14,22–24; Lukas 22,19–20; 1. Korinther 11,23–25'),
    entry('friedensgruss', 'Friedensgruß (Pax Domini)', 'abendmahl', 'liturgisches_stueck',
          ['liturgie', 'abendmahl', 'frieden', 'altkirchlich'], HG % '18',
          'Pfarrer: Der Friede des Herrn sei mit euch allen.\nGemeinde: Amen.',
          'Gruß nach dem Agnus Dei, vor der Austeilung.', tradition='altkirchlich',
          source='Altkirchlicher Friedensgruß der Messe („Pax Domini sit semper vobiscum“), deutsch'),
    entry('austeilungsworte', 'Austeilungsworte und Entlassung', 'abendmahl', 'liturgisches_stueck',
          ['liturgie', 'abendmahl', 'lutherisch', 'segen'], HG % '19',
          'Nimm hin und iß, das ist der Leib Christi, der für dich gegeben ist.\n\n'
          'Nimm hin und trink, das ist das Blut des Neuen Testaments, das für deine Sünde vergossen ist.\n\n'
          'Der Leib unsres Herrn Jesu Christi und Sein teures Blut\n'
          'stärke und erhalte euch im wahren Glauben zum ewigen Leben.\nAmen.',
          'Spendeworte bei Brot und Kelch und das Entlasswort an die Kommunikanten.'),

    # ---------------- Liturgie: Taufe ----------------
    entry('sintflutgebet', 'Luthers Sintflutgebet', 'taufe', 'gebet',
          ['liturgie', 'taufe', 'luther', 'lutherisch'], 'Ordnung der heiligen Taufe, S. 201',
          'Allmächtiger, ewiger Gott, der Du hast durch die Sündflut, nach Deinem gestrengen Gericht, die '
          'ungläubige Welt verdammt, und den gläubigen Noah selbacht, nach Deiner großen Barmherzigkeit '
          'erhalten;\nund den verstockten Pharaoh mit all den Seinen im roten Meer ersäuft und Dein Volk '
          'Israel trocken durchhin geführet, damit dies Bad Deiner heiligen Taufe zukünftig bezeichnet;\n'
          'und durch die Taufe Deines lieben Kindes, unseres Herrn Jesu Christi, den Jordan und alle Wasser '
          'zur seligen Sündflut und reichlicher Abwaschung der Sünden geheiliget und eingesetzt:\n'
          'wir bitten durch dieselbe Deine grundlose Barmherzigkeit, Du wollest dieses Kind gnädiglich '
          'ansehen, und mit rechtem Glauben im Geist beseligen, daß durch diese heilsame Sündflut an ihm '
          'ersaufe und untergehe alles, was ihm von Adam angeboren ist und es selbst dazu gethan hat;\n'
          'und es, aus der Ungläubigen Zahl gesondert, in der heiligen Arche der Christenheit trocken und '
          'sicher behalten, allezeit brünstig im Geiste, fröhlich in Hoffnung, Deinem Namen diene,\n'
          'auf daß es mit allen Gläubigen Deiner Verheißung ewiges Leben zu erlangen würdig werde:\n'
          'durch Jesum Christum, unsern Herrn. Amen.',
          'Taufgebet aus Luthers Taufbüchlein (1523/1526), das Sintflut und Durchzug durchs Schilfmeer als '
          'Vorbilder der Taufe deutet.', dating='1523',
          source='Martin Luther, Taufbüchlein (1523, überarbeitet 1526); hier in der Fassung der Agende',
          note='Agendenfassung; nicht am Erstdruck des Taufbüchleins geprüft. Im Druck steht „erlangeu“ '
               '(Druckfehler für „erlangen“).'),
    entry('tauffragen', 'Tauffragen: Absage und Glaubensbekenntnis', 'taufe', 'liturgisches_stueck',
          ['liturgie', 'taufe', 'lutherisch', 'altkirchlich'], 'Ordnung der heiligen Taufe, S. 202–203',
          'Entsagest du dem Teufel, und allen seinen Werken, und allem seinem Wesen?\nJa, ich entsage.\n\n'
          'Glaubest du an Gott, den Vater allmächtigen, Schöpfer Himmels und der Erden?\nJa, ich glaube.\n\n'
          'Glaubest du an Jesum Christum, Seinen einigen Sohn, unsern Herrn;\n'
          'der empfangen ist von dem Heiligen Geist, geboren von der Jungfrau Maria;\n'
          'gelitten unter Pontio Pilato, gekreuziget, gestorben und begraben;\nniedergefahren zur Höllen;\n'
          'am dritten Tage wieder auferstanden von den Toten;\n'
          'aufgefahren gen Himmel, sitzend zur Rechten Gottes, des allmächtigen Vaters;\n'
          'von dannen Er kommen wird zu richten die Lebendigen und die Toten?\nJa, ich glaube.\n\n'
          'Glaubest du an den Heiligen Geist;\nEine heilige christliche Kirche, die Gemeine der Heiligen;\n'
          'Vergebung der Sünden;\nAuferstehung des Fleisches, und ein ewiges Leben?\nJa, ich glaube.\n\n'
          'Willst du auf diesen christlichen Glauben getauft werden?\nJa, ich will.',
          'Die Fragen an den Täufling (bei Kindern beantwortet von den Paten): Absage an den Teufel und '
          'Bekenntnis des Glaubens nach den drei Artikeln.',
          source='Altkirchliche Tauffragen (Abrenuntiatio und Glaubensfragen) nach Luthers Taufbüchlein'),
    entry('taufformel_und_taufsegen', 'Taufformel und Segen nach der Taufe', 'taufe', 'liturgisches_stueck',
          ['liturgie', 'taufe', 'segen', 'lutherisch', 'trinitaet'], 'Ordnung der heiligen Taufe, S. 203',
          'Ich taufe dich im Namen des Vaters, und des Sohnes, und des Heiligen Geistes.\n\n'
          'Der allmächtige Gott, und Vater unseres Herrn Jesu Christi,\n'
          'der dich wiedergeboren hat durch\'s Wasser und den Heiligen Geist,\n'
          'und hat dir alle deine Sünde vergeben,\nder stärke dich mit Seiner Gnade zum ewigen Leben. Amen.\n\n'
          'Friede sei mit dir. Amen.',
          'Die Taufformel nach Matthäus 28,19 und das Segenswort unter Handauflegung aus Luthers '
          'Taufbüchlein.',
          source='Matthäus 28,19; Martin Luther, Taufbüchlein (1526)'),
    entry('dankgebet_nach_der_taufe', 'Dankgebet nach der Taufe', 'taufe', 'gebet',
          ['liturgie', 'taufe', 'danksagung', 'lutherisch'], 'Ordnung der heiligen Taufe, S. 203',
          'Allmächtiger, barmherziger Gott und Vater,\n'
          'wir sagen Dir Lob und Dank, daß Du Deine Kirche gnädiglich erhältst und mehrest,\n'
          'und diesem Kind verliehen hast, daß es, durch die heilige Taufe wiedergeboren und Deinem lieben '
          'Sohn, unsrem Herrn und einigen Heiland Jesu Christo, eingeleibt, Dein Kind und Erbe Deiner '
          'himmlischen Güter worden ist.\n'
          'Wir bitten Dich demütiglich, daß Du dies Kind, so nunmehr Dein Kind worden ist, bei der '
          'empfangenen Gutthat gnädiglich bewahren wollest,\n'
          'damit es nach allem Deinem Wohlgefallen zu Lob und Preis Deines heiligen Namens, treulich und '
          'gottselig auferzogen werde,\n'
          'und endlich das versprochene Erbteil im Himmel mit allen Heiligen empfahe,\n'
          'durch Jesum Christum. Amen.',
          'Dank für die empfangene Taufe und Bitte um Bewahrung des Kindes in der Taufgnade.'),

    # ---------------- Liturgie: Beichte ----------------
    entry('beichtfragen', 'Beichtfragen der öffentlichen Beichte', 'beichte', 'liturgisches_stueck',
          ['liturgie', 'beichte', 'busse', 'lutherisch'], 'Ordnung der Beichte und Absolution, S. 220–221',
          'Ich frage euch nun vor dem Angesicht des allwissenden Gottes:\n\n'
          '1. Ob ihr auch wahrhaftig erkennet, bekennet und darüber euch von Herzen betrübet, daß ihr nicht '
          'nur aus eurer natürlichen Geburt Sünder seid, sondern daß ihr auch wirklich mit Unterlassung des '
          'Guten und Ausübung manches Bösen in Gedanken, Begierden, Worten und Werken den Herrn, euren Gott '
          'und Wohlthäter, gar vielfältig betrübt und beleidigt habt; demnach wohl wert wäret, daß euch Gott '
          'von Seinem Angesicht verstieße und ewiglich verwürfe? — So saget: Ja.\nGemeinde: Ja.\n\n'
          '2. Glaubet ihr auch von Herzen, daß Jesus Christus kommen sei in die Welt, die Sünder selig zu '
          'machen, und daß alle, die an Seinen Namen glauben, Vergebung der Sünden empfahen sollen? Habt ihr '
          'demnach ein sehnliches Verlangen, durch Christum von euren Sünden los zu werden, und stehet ihr in '
          'der Zuversicht, daß euch euer himmlischer Vater um Jesu Christi willen gnädig sein, eure Sünden '
          'vergeben und euch von aller Unreinigkeit reinigen und heiligen wolle? — So saget: Ja.\n'
          'Gemeinde: Ja.\n\n'
          '3. Begehret ihr auch die heilige Absolution, daß euch der Diener der Kirche an Christi Statt '
          'Vergebung aller eurer Sünden sprechen soll, und glaubet ihr, daß diese Absolution im Himmel gelte '
          'und vor Gott kräftig sei? — So saget: Ja.\nGemeinde: Ja.\n\n'
          '4. Habet ihr auch den festen Vorsatz gefaßt, von nun an dem Heiligen Geist gehorsam zu sein, also '
          'daß ihr künftig die Sünde hassen und lassen, vor Gottes Angesicht zu wandeln euch bestreben, euer '
          'Leben wirklich bessern und täglich frömmer werden wollet? — So saget: Ja.\nGemeinde: Ja.',
          'Die vier Fragen an die Gemeinde vor der Beichte: Erkenntnis der Sünde, Glaube an Christus, '
          'Verlangen nach der Absolution, Vorsatz der Besserung.'),
    entry('allgemeine_beichte', 'Allgemeine Beichte', 'beichte', 'gebet',
          ['liturgie', 'beichte', 'busse', 'lutherisch'], 'Ordnung der Beichte und Absolution, S. 221',
          'Ich armer Sünder bekenne mich Gott, meinem himmlischen Vater,\n'
          'daß ich leider schwer und mannigfaltig gesündigt habe,\n'
          'nicht allein mit äußerlichen, groben Sünden,\n'
          'sondern viel mehr mit innerlicher, angeborner Blindheit, Unglauben, Zweifelung, Kleinmütigkeit, '
          'Ungeduld, Hoffart, bösen Lüsten, Geiz, heimlichem Neid, Haß und Mißgunst, auch andern bösen '
          'Tücken,\nwie das mein Herr und Gott an mir erkennt\n'
          'und ich leider so vollkommen nicht erkennen kann.\n'
          'Nun aber reuen sie mich und sind mir leid\n'
          'und begehre von Herzen Gnade von Gott durch Seinen Sohn Jesum Christum.',
          'Das Beichtgebet, das die Gemeinde kniend mit dem Pfarrer spricht.'),
    entry('absolution', 'Absolution (Lossprechung)', 'beichte', 'liturgisches_stueck',
          ['liturgie', 'beichte', 'lutherisch', 'trinitaet'], 'Ordnung der Beichte und Absolution, S. 221',
          'Der allmächtige Gott hat sich euer erbarmt\n'
          'und durch das Verdienst des allerheiligsten Leidens, Sterbens und Auferstehens unseres Herrn Jesu '
          'Christi, Seines geliebten Sohnes,\nvergiebt Er euch alle eure Sünde,\n'
          'und ich, als ein berufener Diener der christlichen Kirche,\n'
          'aus dem Befehl unsres Herrn Jesu Christi,\nverkündige euch solche Vergebung aller eurer Sünden,\n'
          'im Namen des Vaters, und des Sohnes, und des Heiligen Geistes. Amen.',
          'Die Lossprechung nach der allgemeinen Beichte, gesprochen im Auftrag Christi (Johannes 20,23).'),
    entry('beichtgebet_einzelbeichte', 'Sündenbekenntnis der Einzelbeichte', 'beichte', 'gebet',
          ['liturgie', 'beichte', 'busse', 'lutherisch'], 'Ordnung der Beichte und Absolution, S. 217',
          'Ich armer, sündiger Mensch bekenne vor Gott, meinem Schöpfer und Erlöser,\n'
          'daß ich viel gesündigt habe, nicht allein mit Gedanken, Worten und Werken,\n'
          'sondern daß ich auch in Sünden empfangen und geboren bin.\n'
          'Ich habe aber Zuflucht zu Seiner grundlosen Barmherzigkeit,\n'
          'suche und begehre Gnade um des Herrn Jesu Christi willen.\nHerr sei gnädig mir armen Sünder.\n'
          'Ich will mit Gottes Hilfe mein Leben gerne bessern.',
          'Kurze Form des Sündenbekenntnisses für die Privatbeichte („Eine andere Form des '
          'Sündenbekenntnisses“).'),

    # ---------------- Kirchenjahr ----------------
    entry('kollekte_advent', 'Kollekte zum ersten Advent', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'altkirchlich', 'christusgebet'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 31',
          'Erwecke Deine Gewalt, wir bitten Dich, o Herr, und komm:\n'
          'auf daß wir aus aller Not und Gefahr unsrer Sünden,\nso Du uns beschirmest, mögen errettet\n'
          'und, so Du uns frei machst, ewig selig werden,\n'
          'der Du mit dem Vater und dem Heiligen Geiste lebest und regierest in Ewigkeit.',
          'Tagesgebet des ersten Adventssonntags („Excita, quaesumus, Domine, potentiam tuam et veni“).',
          source='Altkirchliche Adventskollekte der abendländischen Messe, deutsch'),
    entry('kollekte_weihnachten', 'Kollekte zum Christfest', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'altkirchlich', 'bitte'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 38',
          'Allmächtiger Gott, wir bitten Dich, verleihe,\n'
          'daß die neue Geburt Deines eingebornen Sohns im Fleisch uns erlöse,\n'
          'welche die alte Dienstbarkeit unterm Joch der Sünde gefangen hält;\n'
          'durch denselben unsern Herrn Jesum Christum,\n'
          'welcher mit Dir und dem Heiligen Geiste lebet und regieret wahrer Gott von Ewigkeit zu Ewigkeit.',
          'Tagesgebet am heiligen Christfest.',
          source='Altkirchliche Weihnachtskollekte der abendländischen Messe, deutsch'),
    entry('kollekte_epiphanias', 'Kollekte zum Erscheinungsfest (Epiphanias)', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'altkirchlich', 'bitte'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 46',
          'Allmächtiger, ewiger Gott, himmlischer Vater,\n'
          'der Du auf diesen heutigen Tag Deinen eingebornen Sohn Jesum Christum den Heiden durch Erscheinung '
          'und Leitung des Sternes offenbaret hast:\n'
          'verleihe uns gnädiglich, die wir Dich jetzt im Glauben erkennen,\n'
          'daß wir zum Anschauen Deiner herrlichen Klarheit gelangen mögen;\n'
          'durch denselbigen unsern Herrn Jesum Christum, Deinen Sohn,\n'
          'welcher mit Dir und dem Heiligen Geiste lebet und regieret wahrer Gott von Ewigkeit zu Ewigkeit.',
          'Tagesgebet am Epiphaniasfest.',
          source='Altkirchliche Epiphaniaskollekte der abendländischen Messe, deutsch'),
    entry('kollekte_karfreitag', 'Kollekte zum Karfreitag', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'lutherisch', 'christusgebet'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 77',
          'Barmherziger, ewiger Gott,\nder Du Deines einigen Sohnes nicht verschonet hast,\n'
          'sondern für uns alle dahingegeben, daß Er unsre Sünd am Kreuze tragen sollte;\n'
          'verleihe uns, daß unser Herz in solchem Glauben nimmermehr erschrecke noch verzage;\n'
          'durch denselbigen unsern Herrn Jesum Christum, Deinen Sohn,\n'
          'welcher mit Dir und dem Heiligen Geiste lebet und regieret in Ewigkeit.',
          'Zweite der drei Karfreitagskollekten des Kirchenbuchs.',
          source=COLLECT_SOURCE),
    entry('kollekte_ostern', 'Kollekte zum Osterfest', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'altkirchlich', 'bitte'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 79',
          'Allmächtiger Gott,\n'
          'der Du am heutigen Tage durch Deinen eingebornen Sohn den Tod überwunden\n'
          'und uns den Eingang zum ewigen Leben eröffnet hast:\n'
          'wir bitten Dich, wecke in uns die Begierde zur seligen Ewigkeit\n'
          'und hilf uns dieselbe auch erlangen;\n'
          'durch denselbigen unsern Herrn Jesum Christum, Deinen Sohn,\n'
          'welcher mit Dir und dem Heiligen Geiste lebet und regieret wahrer Gott von Ewigkeit zu Ewigkeit.',
          'Tagesgebet am heiligen Osterfest.',
          source='Altkirchliche Osterkollekte der abendländischen Messe, deutsch'),
    entry('kollekte_himmelfahrt', 'Kollekte zum Himmelfahrtstag', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'altkirchlich', 'bitte'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 91',
          'Allmächtiger Gott, wir bitten Dich, verleihe uns,\n'
          'die wir glauben, daß Dein einiger Sohn, unser Heiland, sei heute gen Himmel gefahren:\n'
          'daß auch wir mit Ihm in einem himmlischen Wesen wandeln;\n'
          'welcher mit Dir und dem Heiligen Geiste lebet und regieret wahrer Gott von Ewigkeit zu Ewigkeit.',
          'Tagesgebet am Himmelfahrtstage.',
          source='Altkirchliche Himmelfahrtskollekte der abendländischen Messe, deutsch'),
    entry('kollekte_pfingsten', 'Kollekte zum Pfingstfest', 'kirchenjahr', 'kollekte',
          ['kirchenjahr', 'liturgie', 'altkirchlich', 'heiliger_geist'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 95',
          'Herr Gott, lieber Vater,\n'
          'der Du an diesem Tage Deiner Gläubigen Herzen durch Deinen Heiligen Geist erleuchtet und gelehret '
          'hast:\ngieb uns, daß wir auch durch denselbigen Geist rechten Verstand haben\n'
          'und zu aller Zeit Seines Trostes und Kraft uns freuen:\n'
          'durch unsern Herrn Jesum Christum, Deinen Sohn,\n'
          'welcher mit Dir und dem Heiligen Geiste lebet und regieret wahrer Gott von Ewigkeit zu Ewigkeit.',
          'Tagesgebet am heiligen Pfingstfest, in Luthers Verdeutschung der altkirchlichen Kollekte.',
          source='Altkirchliche Pfingstkollekte („Deus, qui hodierna die“), deutsch'),
    entry('kollekte_trinitatis', 'Kollekte zum Fest der heiligen Dreieinigkeit (Trinitatis)', 'kirchenjahr',
          'kollekte', ['kirchenjahr', 'liturgie', 'altkirchlich', 'trinitaet', 'glaube'],
          'Introiten, Kollekten, Episteln und Evangelien, S. 99',
          'O allmächtiger, ewiger Gott,\n'
          'der Du uns Deinen Dienern aus Gnaden gegeben hast,\n'
          'im Bekenntnis des wahren Glaubens die Herrlichkeit der ewigen Dreifaltigkeit zu erkennen\n'
          'und die Einigkeit göttlicher Gewalt und Majestät anzubeten:\n'
          'wir bitten Dich, verleihe, daß wir durch Beständigkeit solches Glaubens allezeit befestiget werden '
          'in aller Widerwärtigkeit;\nder Du lebest und regierest, wahrer Gott von Ewigkeit zu Ewigkeit.',
          'Tagesgebet am Trinitatisfest.',
          source='Altkirchliche Trinitatiskollekte der abendländischen Messe, deutsch'),
]


def collect(pid, title, number, page, tags, text, description, category='anliegen'):
    return entry(pid, title, category, 'kollekte', tags,
                 'Allgemeine und besondere Kollekten, Nr. %s, S. %s' % (number, page), text, description,
                 source=COLLECT_SOURCE)


NEW += [
    # ---------------- Morgen, Abend, Arbeit ----------------
    collect('kollekte_am_morgen', 'Kollekte am Morgen', 59, 172, ['morgen', 'bitte', 'lutherisch'],
            'O Herr, allmächtiger Gott,\nder Du uns bis zum Anfang dieses Tages hast kommen lassen:\n'
            'hilf uns heute durch Deine Kraft,\ndaß wir an diesem Tage in keine Sünde willigen,\n'
            'sondern unser Sinnen, Thun und Reden dahin richten,\ndaß wir Dir gefallen und Deinen Willen thun;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Kurzes Morgengebet um Bewahrung vor Sünde am beginnenden Tag.', category='tageslauf'),
    collect('kollekte_am_abend', 'Kollekte am Abend', 61, 172, ['abend', 'bitte', 'lutherisch'],
            'Erleucht unsre Finsternis, wir bitten Dich, Herr,\n'
            'und nach Deiner großen Barmherzigkeit behüt uns diese Nacht vor allem Schaden und Gefahr;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Kurzes Abendgebet um Schutz in der Nacht („Illumina, quaesumus, Domine, tenebras nostras“).',
            category='tageslauf'),
    collect('kollekte_berufsarbeit', 'Gebet um Segen zur Berufsarbeit', 60, 172,
            ['arbeit', 'bitte', 'lutherisch'],
            'Allmächtiger Gott und Vater,\nohne dessen Hilfe und Segen alle Mühe und Arbeit umsonst ist:\n'
            'siehe an Deine Güte und unsre Dürftigkeit\nund segne den Schweiß unseres Angesichts,\n'
            'daß wir Deine Güte erfahren und preisen\n'
            'und in Deinem Namen und Vertrauen unsern Beruf in Geduld fröhlich verrichten;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Gebet für Beruf und tägliche Arbeit.', category='tageslauf'),

    # ---------------- Gebete in besonderen Anliegen ----------------
    collect('kollekte_fuer_die_kirche', 'Gebet für die Kirche', 13, 160,
            ['kirche', 'fuerbitte', 'lutherisch', 'wort_gottes'],
            'Allmächtiger Herre Gott, wir bitten Dich,\ngieb Deiner Gemeine Deinen Geist und göttliche Weisheit,\n'
            'daß Dein Wort unter uns laufe und wachse\nund mit aller Freudigkeit, wie sichs gebühret, gepredigt\n'
            'und Deine heilige christliche Gemeine dadurch gebessert werde,\n'
            'auf daß wir mit beständigem Glauben Dir dienen\n'
            'und im Bekenntnis Deines Namens bis an das Ende verharren;\n'
            'durch unsern Herrn Jesum Christum, Deinen Sohn,\n'
            'welcher mit Dir und dem Heiligen Geiste lebet und regieret in Ewigkeit. Amen.',
            'Bitte um den Heiligen Geist für die Gemeinde und um den Lauf des Wortes Gottes.'),
    collect('kollekte_fuer_pfarrer_und_gemeinden', 'Gebet für Pfarrer und Gemeinden', 23, 162,
            ['kirche', 'fuerbitte', 'altkirchlich', 'lutherisch'],
            'Allmächtiger, ewiger Gott, der Du allein große Wunder thust:\n'
            'gieß aus den Geist Deiner heilsamen Gnade über Deine Diener\n'
            'und die Gemeinden, die ihnen befohlen sind,\n'
            'und damit sie Dir in der Wahrheit wohlgefällig seien,\n'
            'so tränke sie allzeit mit dem Tau Deines Segens;\ndurch unsern Herrn Jesum Christum. Amen.',
            'Fürbitte für die Diener der Kirche und die ihnen anvertrauten Gemeinden („Omnipotens sempiterne '
            'Deus, qui facis mirabilia magna solus“).'),
    collect('kollekte_um_prediger', 'Gebet um treue Prediger des Wortes', 24, 162,
            ['kirche', 'fuerbitte', 'wort_gottes', 'lutherisch'],
            'O allmächtiger, gütiger Gott und Vater unsers Herrn Jesu Christi,\n'
            'der uns ernstlich befohlen hast, daß wir Dich um Arbeiter in Deine Ernte bitten sollen:\n'
            'wir bitten Deine grundlose Barmherzigkeit,\n'
            'Du wollest uns rechtschaffene Lehrer und Diener Deines göttlichen Worts zuschicken\n'
            'und denselben Dein heilsames Wort in ihr Herz und Mund geben,\n'
            'daß sie Deinen Befehl treulich ausrichten\n'
            'und nichts predigen, das Deinem heiligen Wort entgegen sei,\n'
            'auf daß wir durch Dein himmlisch, ewig Wort ermahnet, gelehrt, gespeist, getröstet und gestärkt '
            'werden\nund thun, was Dir gefällig und uns fruchtbarlich ist;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Bitte um Arbeiter in Gottes Ernte (Matthäus 9,38) und um treue Verkündigung.'),
    collect('kollekte_mission', 'Gebet für die Heiden (um Ausbreitung des Evangeliums)', 30, 164,
            ['mission', 'fuerbitte', 'altkirchlich', 'lutherisch'],
            'Allmächtiger, ewiger Gott,\nder Du nicht willst der Sünder Tod,\n'
            'sondern daß sie sich bekehren und leben:\nnimm gnädiglich an unser Gebet für die Heiden\n'
            'und errette sie von ihrer greulichen Abgötterei\nund versammle sie zu Deiner heiligen Kirche\n'
            'zu Lob und Preis Deines göttlichen Namens;\ndurch unsern Herrn Jesum Christum. Amen.',
            'Missionsgebet der alten Kirche aus den Karfreitagsfürbitten, in der Sprache der Agende von 1877 '
            '(„Für die Heiden“).'),
    collect('kollekte_fuer_die_obrigkeit', 'Gebet für die Obrigkeit', 32, '164–165',
            ['obrigkeit', 'fuerbitte', 'frieden', 'lutherisch'],
            'Barmherziger, himmlischer Vater,\nin welches Hand besteht aller Menschen Gewalt und Obrigkeit,\n'
            'von Dir gesetzt zur Straf der Bösen und Wohlfahrt der Frommen,\n'
            'in welches Hand auch stehen alle Recht und Gesetz aller Reich auf Erden;\n'
            'wir bitten Dich, siehe gnädiglich auf Deine Diener, unsre Landes-Obrigkeit und alle, die Gewalt '
            'haben,\ndamit sie das weltlich Schwert, ihnen von Dir befohlen, nach Deinem Befehl führen mögen,\n'
            'erleuchte und erhalte sie bei Deinem göttlichen Namen,\n'
            'gieb ihnen Weisheit und Verstand und ein friedlich Regiment,\n'
            'auf daß wir in Frieden, Ruhe und Einigkeit samt ihnen Deinen göttlichen Namen heiligen und '
            'preisen mögen;\ndurch unsern Herrn Jesum Christum. Amen.',
            'Fürbitte für Regierung und alle, die Verantwortung tragen (vgl. 1. Timotheus 2,1–2).'),
    collect('kollekte_fuer_eltern_und_haus', 'Gebet für Eltern und Hausstand', 33, 165,
            ['familie', 'fuerbitte', 'lutherisch'],
            'Allmächtiger, ewiger Gott, wir bitten Dich,\n'
            'Du wollest allen christlichen Regenten und Hausvätern und Eltern gnädiglich verleihen,\n'
            'daß sie mit guten Exempeln ihren Unterthanen, Gesinde und Kindern vorgehen,\n'
            'sie weder mit Worten noch mit Werken ärgern,\n'
            'sondern in der Zucht und Vermahnung zu Dir auferziehen mögen,\n'
            'und daß sie auch durch Deine Gnade in christlichem, gottseligem Gehorsam folgen mögen;\n'
            'der Du lebest und regierest, wahrer Gott, immer und ewiglich. Amen.',
            'Gebet für alle, denen andere anvertraut sind, besonders für Eltern und ihre Kinder („Für Eltern '
            'und Herren“).'),
    collect('kollekte_fuer_eheleute', 'Gebet für Eheleute', 34, 165, ['familie', 'fuerbitte', 'lutherisch'],
            'Herr Gott, himmlischer Vater, wir bitten Dich,\nDu wollest allen Eheleuten verleihen,\n'
            'daß sie in Frieden und Einigkeit gottselig leben und Dir dienen mögen,\n'
            'ihre Kinder nach Deinem Willen erziehen,\nDu wollest alle ihre Nahrung segnen\n'
            'und in allem Unglück, Kreuz und Anfechtungen sie trösten;\n'
            'durch Jesum Christum unsern Herrn. Amen.',
            'Gebet für Ehe und Familie.'),
    collect('kollekte_fuer_die_jugend', 'Gebet für die Jugend', 22, 162,
            ['familie', 'fuerbitte', 'lutherisch'],
            'Allmächtiger, ewiger Gott,\n'
            'dieweil Dein Wille nicht ist, daß jemand aus diesen Geringsten verloren werde,\n'
            'sondern hast Deinen einigen Sohn gesandt, das Verlorne selig zu machen,\n'
            'und durch Desselben Mund befohlen, wir sollen die Kinder zu Dir bringen, denn solcher sei das '
            'Himmelreich:\nwir bitten Dich herzlich,\n'
            'Du wollest diese unsre Jugend mit Deinem Heiligen Geist segnen und regieren,\n'
            'daß sie in Deinem Wort heilig wachsen und zunehmen,\n'
            'und durch den Schutz Deiner Engel wider alle Fährlichkeit behüten und bewahren;\n'
            'um Jesu Christi, Deines lieben Sohnes, unsres Herrn willen. Amen.',
            'Fürbitte für Kinder und junge Menschen.'),
    collect('kollekte_in_kreuz_und_truebsal', 'Gebet in Kreuz und Trübsal', 41, 167,
            ['not', 'fuerbitte', 'lutherisch'],
            'O allmächtiger, ewiger Gott,\nein Trost der Traurigen und Stärke der Schwachen,\n'
            'laß vor Dein Angesicht gnädiglich kommen die Bitt aller derer,\n'
            'so in Kümmernis und Anfechtung zu Dir seufzen und schreien,\n'
            'daß männiglich merke und empfinde Deine Hilfe und Beistand in Zeit der Not;\n'
            'durch Jesum Christum Deinen Sohn, unsern Herrn. Amen.',
            'Gebet für alle, die in Not, Kummer und Anfechtung sind.'),
    collect('kollekte_trost_im_leid', 'Gebet um Trost im Leid', 46, 168, ['not', 'sterben', 'lutherisch'],
            'Ach Herr, getreuer Gott und Vater,\nder Du züchtigest alle, die Du lieb hast,\n'
            'auf daß sie nicht samt der gottlosen Welt verdammet werden:\n'
            'wir bitten Dein treues Vaterherz,\n'
            'Du wollest uns in unsrem Kreuz mit Deinem Geist und Worte trösten,\n'
            'daß wir das kleine Stündlein dieses Elends in Geduld überwinden\n'
            'und feste glauben und hoffen,\n'
            'Du werdest unser Leid und Traurigkeit bald in ewige Freude und Herrlichkeit verwandeln;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Gebet für Leidtragende und Trauernde um Geduld und um die Hoffnung der ewigen Freude.'),
    collect('kollekte_fuer_kranke', 'Gebet für Kranke', 47, 168, ['krankheit', 'fuerbitte', 'lutherisch'],
            'Allmächtiger, ewiger Gott,\nein Heiland aller, die an Dich glauben,\n'
            'hör unsre Bitt für Deine kranken Knechte,\n'
            'für welche wir zu Deiner Barmherzigkeit um Hilfe flehen,\n'
            'auf daß sie wiedergenesen\nund in Deiner Gemeinde mit Wort und Werk Dir danken mögen;\n'
            'durch unsern Herrn Jesum Christum, Deinen Sohn. Amen.',
            'Fürbitte für die Kranken („Omnipotens sempiterne Deus, salus aeterna credentium“).'),
    collect('kollekte_danksagung', 'Dankgebet', 57, 171, ['danksagung', 'lobpreis', 'lutherisch'],
            'Herr Gott, himmlischer Vater,\n'
            'von dem wir ohn Unterlaß allerlei Gutes ganz überflüssig empfahen\n'
            'und täglich vor allem Übel gnädiglich behütet werden:\n'
            'wir bitten Dich, gieb uns durch Deinen Geist\n'
            'solches alles mit ganzem Herzen in rechtem Glauben zu erkennen,\n'
            'auf daß wir Deiner milden Güte und Barmherzigkeit hier und dort ewiglich danken und Dich loben;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Dank für Gottes tägliche Wohltaten und Bewahrung.'),
    collect('kollekte_um_gottes_wort', 'Gebet um das rechte Hören des göttlichen Wortes', 63, 173,
            ['wort_gottes', 'bitte', 'lutherisch'],
            'Wir danken Dir, Herr Gott, himmlischer Vater, von Grund unsers Herzens,\n'
            'daß Du uns Dein heiliges Evangelium gegeben\nund Dein väterliches Herz hast erkennen lassen:\n'
            'wir bitten Deine grundlose Barmherzigkeit,\n'
            'Du wollest solch seliges Licht Deines Worts uns gnädiglich erhalten\n'
            'und durch Deinen Heiligen Geist unsre Herzen leiten und führen,\n'
            'daß wir nimmermehr davon abweichen,\nsondern fest daran halten und endlich dadurch selig werden;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Dank für das Evangelium und Bitte, bei Gottes Wort erhalten zu werden; geeignet auch vor dem '
            'Gottesdienst.'),
    collect('kollekte_um_den_heiligen_geist', 'Gebet um den Heiligen Geist', 3, 157,
            ['heiliger_geist', 'bitte', 'lutherisch'],
            'Allmächtiger Gott,\nder Du uns befohlen hast, daß wir um den Heiligen Geist bitten sollen:\n'
            'wir bitten Dich von Herzen,\ngieb uns durch Christum, unsern Mittler, den Heiligen Geist,\n'
            'der Gottes Wort in unsern Herzen kräftig mache,\n'
            'uns in alle Wahrheit leite, lehre, erleuchte, regiere, tröste und heilige zum ewigen Leben;\n'
            'durch denselbigen Deinen Sohn, Jesum Christum, unsern Herrn. Amen.',
            'Bitte um den Heiligen Geist, um Erkenntnis der Wahrheit und geistliche Erneuerung.'),
    collect('kollekte_um_erleuchtung', 'Gebet um die Leitung des Heiligen Geistes', 64, 173,
            ['heiliger_geist', 'bitte', 'altkirchlich', 'lutherisch'],
            'Wir bitten Dich, Herr,\nlaß den Tröster, der von Dir ausgeht, unsre Sinnen erleuchten\n'
            'und uns, wie Dein Sohn verheißen, in alle Wahrheit leiten;\n'
            'durch denselbigen, unsern Herrn Jesum Christum. Amen.',
            'Kurze Bitte um Weisheit und Erkenntnis durch den Heiligen Geist (vgl. Johannes 16,13).'),
    collect('kollekte_um_ein_bussfertiges_herz', 'Gebet um ein bußfertiges Herz', 65, 173,
            ['busse', 'bitte', 'lutherisch'],
            'Herr Gott, himmlischer Vater, wir bitten Dich,\n'
            'Du wollest durch Deinen Heiligen Geist uns also leiten und führen,\n'
            'daß wir unsrer Sünde nicht geringer achten und sicher werden,\n'
            'sondern in steter Buße stehn und uns von Tag zu Tag bessern,\n'
            'und dabei allein uns dessen trösten,\n'
            'daß Du um Deines Sohnes willen uns gnädig sein, alle Sünde vergeben und selig machen wollest;\n'
            'durch denselbigen unsern Herrn Jesum Christum. Amen.',
            'Bußgebet um tägliche Umkehr und um den Trost der Vergebung.'),
    collect('kollekte_um_vergebung', 'Gebet um Vergebung der Sünden', 66, 173,
            ['busse', 'bitte', 'frieden', 'altkirchlich'],
            'Erhöre Herr, wir bitten Dich, unser Gebet und Flehen\n'
            'und verschon unsrer Missethat, die wir Dir bekennen,\n'
            'auf daß Du nach Deiner milden Güte uns beides schenkest, Vergebung und Frieden;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Kurze Bitte um Vergebung und Frieden („Exaudi, quaesumus, Domine, supplicum preces“).'),
    collect('kollekte_um_festen_glauben', 'Gebet um festen Glauben', 77, 176,
            ['glaube', 'bitte', 'lutherisch', 'sterben'],
            'Herr Gott, himmlischer Vater,\n'
            'der Du aus sonderlicher Liebe und Barmherzigkeit Deinen Sohn für uns hast Mensch werden und am '
            'Kreuze sterben lassen:\ngieb Deinen Heiligen Geist in unsere Herzen,\n'
            'daß wir all unser Vertrauen auf Ihn setzen\n'
            'und durch Ihn Vergebung unsrer Sünde und ewiges Leben mit ungezweifeltem Herzen glauben\n'
            'und an unserm letzten Ende fest dabei bleiben;\n'
            'durch denselbigen unsern Herrn Jesum Christum. Amen.',
            'Bitte um Bewahrung im Glauben bis ans Ende.'),
    collect('kollekte_um_ein_selig_ende', 'Gebet um ein seliges Ende', 85, 178,
            ['sterben', 'bitte', 'lutherisch'],
            'Allmächtiger Gott, wir bitten Deine milde Güte,\n'
            'Du wollest uns Deine Diener mit Deiner Gnade stärken,\n'
            'daß uns an unsrem letzten Ende der böse Feind nicht übermöge,\n'
            'sondern wir in Deiner Engel Geleite eingehen zum ewigen Leben;\n'
            'durch unsern Herrn Jesum Christum. Amen.',
            'Bitte um Beistand in der Sterbestunde.'),
]


def decalogue():
    """Die Zehn Gebote in der Fassung des Kleinen Katechismus: Wortlaut der
    Gebote aus dem (am Faksimile geprüften) ersten Hauptstück, ohne Auslegung."""
    import re
    confessions = json.load(open(repo('assets', 'confessions.json'), encoding='utf-8'))
    sc = next(c for c in confessions if c['id'] == 'kleiner_katechismus')
    part = next(s for s in sc['sections'] if s['id'] == 'hauptstueck_1')
    heading = {'de': r'^Das .+ Gebot\.$', 'la': r'^[IVX]+\. Praeceptum\.$', 'en': r'^The .+ Commandment\.$'}
    versions = []
    for lang in ('de', 'la', 'en'):
        blocks = []
        for para in part['texts'][lang].split('\n\n'):
            lines = para.split('\n')
            if re.match(heading[lang], lines[0]) and len(lines) > 1:
                blocks.append(lines[0] + '\n' + lines[1])
        assert len(blocks) == 10, (lang, len(blocks))
        v = {'language': lang, 'status': 'original' if lang == 'de' else 'translation'}
        if lang != 'de':
            v['translatedFrom'] = 'de'
        v['source'] = ('Kleiner Katechismus, erstes Hauptstück (Wortlaut der Gebote ohne Auslegung), nach der '
                       'Concordia Triglotta (St. Louis: Concordia Publishing House, 1921); Text wie unter den '
                       'Bekenntnissen, dort am Faksimile des Drucks geprüft')
        v['text'] = '\n\n'.join(blocks)
        versions.append(v)
    return {
        'id': 'zehn_gebote',
        'title': {'de': 'Die Zehn Gebote', 'la': 'Decem Praecepta', 'en': 'The Ten Commandments'},
        'category': 'grundtexte', 'type': 'katechismusstueck', 'tradition': 'lutherisch',
        'author': 'Martin Luther', 'originalLanguage': 'de',
        'source': '2. Mose 20,2–17 und 5. Mose 5,6–21 in der Kurzfassung und Zählung von Luthers Kleinem '
                  'Katechismus (1529)',
        'dating': '1529',
        'description': 'Der Dekalog, wie ihn Luthers Kleiner Katechismus zum Auswendiglernen bietet. Die '
                       'Auslegungen („Was ist das?“) stehen unter den Bekenntnissen im Kleinen Katechismus.',
        'tags': ['biblisch', 'katechismus', 'luther', 'lutherisch'],
        'versions': versions,
    }


def main():
    NEW.insert(0, decalogue())
    path = repo('assets', 'prayers.json')
    prayers = json.load(open(path, encoding='utf-8'))
    new_ids = {e['id'] for e in NEW}
    assert len(new_ids) == len(NEW), 'doppelte ID'
    kept = []
    for p in prayers:
        if p['id'] in new_ids:
            continue
        if p['id'] in CATEGORIES:
            # "category" direkt nach "tradition" einsortieren
            q = {}
            for k, v in p.items():
                if k == 'category':
                    continue
                q[k] = v
                if k == 'tradition':
                    q['category'] = CATEGORIES[p['id']]
            p = q
        kept.append(p)
    out = kept + NEW
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, ensure_ascii=False, indent=4)
    print(len(kept), 'vorhandene +', len(NEW), 'neue Einträge')


if __name__ == '__main__':
    main()
