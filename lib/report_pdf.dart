// Raport PDF dla lekarza / dietetyka: dane osoby, kalorie i makro dzień po dniu, trawienie, objawy,
// podejrzane składniki, leki i suplementy, waga, wiatry. Bez zdjęć – lekko i do wydruku.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'calc.dart';
import 'extras.dart';
import 'gas.dart';
import 'models.dart';

class ReportInput {
  final Person person;
  final List<Meal> meals;
  final List<GutEntry> gut;
  final List<MedEntry> meds;
  final List<Drink> drinks;
  final List<WeightEntry> weights;
  final GasSeries gas;
  final String from, to;
  final bool mealList; // pełna lista posiłków
  const ReportInput({
    required this.person,
    required this.meals,
    required this.gut,
    required this.meds,
    required this.drinks,
    required this.weights,
    required this.gas,
    required this.from,
    required this.to,
    this.mealList = true,
  });
}

String _d(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
}

Future<Uint8List> buildReport(ReportInput r) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final accent = PdfColor.fromInt(0xFF2E7650);
  final grey = PdfColor.fromInt(0xFF6E625A);

  bool inRange(String d) => d.compareTo(r.from) >= 0 && d.compareTo(r.to) <= 0;
  final meals = r.meals.where((m) => inRange(m.date)).toList()..sort((a, b) => a.ts.compareTo(b.ts));
  final gut = r.gut.where((g) => inRange(g.date)).toList()..sort((a, b) => a.ts.compareTo(b.ts));
  final meds = r.meds.where((m) => inRange(m.date)).toList();
  final days = <String>[];
  for (var d = r.from; d.compareTo(r.to) <= 0; d = shiftDay(d, 1)) {
    days.add(d);
  }
  final goal = goalOf(r.person);

  pw.Widget h(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)));
  pw.Widget p(String t, {PdfColor? color, double size = 9.5}) => pw.Text(t, style: pw.TextStyle(fontSize: size, color: color));
  pw.Widget table(List<String> head, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths}) => pw.TableHelper.fromTextArray(
        headers: head,
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFE6DC)),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        columnWidths: widths,
        border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFD9CFC5), width: 0.5),
      );

  // --- kalorie dzień po dniu
  final dayRows = <List<String>>[];
  final sleep = r.gas.sleepHours;
  for (final d in days) {
    final ms = meals.where((m) => m.date == d).toList();
    final gs = gut.where((g) => g.date == d);
    if (ms.isEmpty && gs.isEmpty) continue;
    final t = dayTotal(ms, d);
    final mi = Micro.ofItems(ms.expand((m) => m.items));
    final w = eatingWindow(ms, d);
    final score = gutDayScore(gs);
    final ff = [r.gas.day(d), r.gas.nightAfter(d)].whereType<int>();
    final dr = drinksOn(d, r.drinks, ms);
    dayRows.add([
      _d(d),
      ms.isEmpty ? '–' : '${t.kcal.round()}',
      ms.isEmpty ? '–' : '${t.p.round()}/${t.c.round()}/${t.f.round()}',
      mi.coverage >= 0.5 ? mi.fiber.toStringAsFixed(0) : '–',
      w == null ? '–' : '${hm(w.first)}–${hm(w.last)}',
      dr.waterMl > 0 ? '${(dr.waterMl / 1000).toStringAsFixed(1)} l' : '–',
      score == null ? '–' : '$score/5',
      ff.isEmpty ? '–' : '${ff.fold<int>(0, (a, b) => a + b)}',
      sleep[d] == null ? '–' : '${sleep[d]!.toStringAsFixed(1)} h',
    ]);
  }

  // --- objawy i podejrzani
  final freq = gutFrequency(gut);
  final assoc = gutAssociations(gut, r.meals.where((m) => m.date.compareTo(shiftDay(r.from, -2)) >= 0 && m.date.compareTo(r.to) <= 0).toList());
  final react = reactionAssociations(meals);
  final wt = WeightTrend(r.weights);
  final wIn = r.weights.where((w) => inRange(w.date)).toList();
  final ch = wt.weeklyChange(days: days.length.clamp(14, 120), until: r.to);
  final kcalDays = [for (final d in days) if (meals.any((m) => m.date == d)) dayTotal(meals, d).kcal];

  final doc = pw.Document(title: 'Dziennik talerza – ${r.person.name}', author: 'Dziennik talerza');
  doc.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
    footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Dziennik talerza · strona ${c.pageNumber}/${c.pagesCount}', style: pw.TextStyle(fontSize: 8, color: grey))),
    build: (c) => [
      pw.Text('Dziennik żywienia i trawienia', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      p('${r.person.name} · ${_d(r.from)} – ${_d(r.to)} · wygenerowano ${_d(todayIso())}', color: grey, size: 10),
      pw.SizedBox(height: 4),
      p('Dane: ${personLine(r.person)}'),
      p('Wpisy prowadzone samodzielnie w aplikacji; wartości kaloryczne są szacunkowe (tabele, bazy produktów, rozpoznawanie zdjęć).',
          color: grey, size: 8.5),
      h('Podsumowanie'),
      p('Dni z wpisami posiłków: ${kcalDays.length} z ${days.length}. Średnio ${avg(kcalDays).round()} kcal dziennie (cel orientacyjny $goal kcal).'),
      p('Wpisy o trawieniu: ${gut.length}, w tym ze złym samopoczuciem: ${gut.where(gutBad).length}. Oceny po posiłkach: ${meals.where((m) => m.reactions.isNotEmpty).length}.'),
      if (wIn.isNotEmpty)
        p('Waga: ${wIn.first.kg.toStringAsFixed(1)} kg (${_d(wIn.first.date)}) → ${wIn.last.kg.toStringAsFixed(1)} kg (${_d(wIn.last.date)})'
            '${ch != null ? ', trend ${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(2)} kg/tydz.' : ''}'),
      if (r.gas.any) p('Wiatry: ${r.gas.outcomeLabel.isEmpty ? 'z aplikacji Kreska / Rytm Snu' : 'Kreska (dzień) + Rytm Snu (noc)'}.'),
      h('Dzień po dniu'),
      if (dayRows.isEmpty) p('Brak wpisów w tym okresie.') else
        table(['Dzień', 'kcal', 'B/W/T g', 'Błonnik g', 'Okno jedzenia', 'Woda', 'Trawienie', 'Wiatry', 'Sen'], dayRows),
      if (freq.isNotEmpty) ...[
        h('Objawy trawienne'),
        table(['Objaw', 'Ile razy', 'Średnie nasilenie (1–3)'], [for (final f in freq) [f.$1, '${f.$2}', f.$3.toStringAsFixed(1)]]),
      ],
      if (assoc.rows.isNotEmpty) ...[
        h('Składniki częściej przed złym samopoczuciem'),
        p('W oknie 6–30 h przed wpisem. Odsetek złych wpisów ogółem: ${(assoc.base * 100).round()}%. Korelacja, nie diagnoza.', color: grey, size: 8.5),
        pw.SizedBox(height: 4),
        table(['Składnik', 'Przed złym wpisem', 'Wszystkich wystąpień', 'Odsetek'],
            [for (final a in assoc.rows) [a.ingredient, '${a.hits}', '${a.total}', '${(a.rate * 100).round()}%${assoc.flagged(a) ? ' !' : ''}']]),
      ],
      if (react.any((s) => s.rows.isNotEmpty)) ...[
        h('Objawy po posiłkach'),
        for (final s in react)
          if (s.rows.isNotEmpty) p('${s.symptom} (${s.meals}×): ${s.rows.map((a) => '${a.ingredient} ${a.hits}/${a.total}').join(', ')}'),
      ],
      if (meds.isNotEmpty) ...[
        h('Leki i suplementy'),
        table(['Data', 'Godz.', 'Rodzaj', 'Nazwa', 'Dawka'], [for (final m in meds) [_d(m.date), m.time, m.kind, m.name, m.dose]]),
      ],
      if (gut.isNotEmpty) ...[
        h('Wpisy o trawieniu'),
        table(
          ['Data', 'Kiedy', 'Komfort', 'Bristol', 'Objawy', 'Notatka'],
          [
            for (final g in gut)
              [
                _d(g.date),
                g.when,
                g.comfort > 0 ? '${g.comfort}/5' : '–',
                g.bristol > 0 ? '${g.bristol}' : '–',
                g.symptoms.map((s) => '${s.name} (${severityNames[s.sev]})').join(', '),
                g.note,
              ]
          ],
          widths: {4: const pw.FlexColumnWidth(3), 5: const pw.FlexColumnWidth(3)},
        ),
      ],
      if (r.mealList && meals.isNotEmpty) ...[
        h('Posiłki'),
        table(
          ['Data', 'Godz.', 'Posiłek', 'Składniki', 'kcal', 'Reakcja'],
          [
            for (final m in meals)
              [
                _d(m.date),
                m.time,
                m.name.isNotEmpty ? m.name : m.type,
                m.items.map((i) => '${i.name} ${i.grams.round()} g').join(', '),
                '${m.total.kcal.round()}',
                m.reactions.map((x) => [if (x.energy > 0) 'energia ${x.energy}/5', ...x.symptoms].join(', ')).where((s) => s.isNotEmpty).join('; '),
              ]
          ],
          widths: {3: const pw.FlexColumnWidth(4), 5: const pw.FlexColumnWidth(2)},
        ),
      ],
    ],
  ));
  return doc.save();
}

Future<File> saveReport(ReportInput r) async {
  final bytes = await buildReport(r);
  final dir = await getTemporaryDirectory();
  final safe = r.person.name.replaceAll(RegExp(r'[^\wąćęłńóśźżĄĆĘŁŃÓŚŹŻ-]+'), '_');
  final f = File('${dir.path}/dziennik-$safe-${r.from}_${r.to}.pdf');
  await f.writeAsBytes(bytes, flush: true);
  return f;
}
