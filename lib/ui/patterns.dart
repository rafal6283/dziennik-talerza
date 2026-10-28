import 'package:flutter/material.dart';

import '../ai.dart';
import '../calc.dart';
import '../gas.dart';
import '../main.dart';
import 'charts.dart';
import 'format.dart';

class PatternsTab extends StatefulWidget {
  const PatternsTab({super.key});
  @override
  State<PatternsTab> createState() => _PatternsTabState();
}

class _PatternsTabState extends State<PatternsTab> {
  final _ai = <String, String>{}; // analiza per osoba (do końca sesji)
  bool busy = false;
  String? err;

  Future<void> _analyze() async {
    final p = app.active;
    final since = shiftDay(todayIso(), -30);
    if (app.meals.where((m) => m.date.compareTo(since) >= 0).length < 5) {
      setState(() => err = 'Za mało danych. Zapisz co najmniej 5 posiłków (najlepiej z oceną samopoczucia).');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final t = await Ai.analyze(p, app.meals, app.gut, gas: app.gasSeries);
      setState(() => _ai[p.id] = t);
    } on AiError catch (e) {
      setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meals = app.meals, gut = app.gut;
    final today = todayIso();
    final goal = app.goal;
    Widget muted(String t) => Text(t, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13));
    Widget title(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)));
    Widget assocRow(String name, double frac, String right, Color color, {bool flag = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(flex: 5, child: Text(flag ? '$name ⚑' : name, style: TextStyle(fontWeight: flag ? FontWeight.w700 : FontWeight.w400))),
            Expanded(flex: 3, child: Meter(frac, color)),
            SizedBox(width: 92, child: Text(right, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontFeatures: tabular))),
          ]),
        );

    // --- trawienie ---
    final gut30 = gut.where((g) => g.date.compareTo(shiftDay(today, -30)) >= 0).toList();
    final freq = gutFrequency(gut30);
    final ga = gutAssociations(gut, meals);
    final ra = reactionAssociations(meals);
    final rated = meals.where((m) => m.reactions.isNotEmpty).length;
    final en = energyByType(meals);
    final gs = app.gasSeries;
    final gasA = gasAssociations(meals, gs);

    return ListView(padding: const EdgeInsets.only(top: 6, bottom: 32), children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title('Kalorie dzień po dniu'),
          KcalChart(meals: meals, goal: goal, today: today),
          const SizedBox(height: 6),
          muted('Zielona linia to cel tej osoby: $goal kcal. Dotknij słupka albo przesuń palcem, żeby zobaczyć dzień.'),
        ]),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title('Trawienie · ostatnie 14 dni'),
          Builder(builder: (_) {
            final ds = [for (var i = 13; i >= 0; i--) shiftDay(today, -i)];
            return GutStrip(
              days: ds,
              scores: [for (final d in ds) gutDayScore(gut.where((g) => g.date == d))],
              counts: [for (final d in ds) gut.where((g) => g.date == d).length],
            );
          }),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (final l in [(5, 'dobrze'), (3, 'tak sobie'), (1, 'źle'), (0, 'brak wpisu')])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Palette.comfort(context, l.$1), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                muted(l.$2),
              ]),
          ]),
          const SizedBox(height: 14),
          if (freq.isEmpty)
            muted(gut30.isEmpty ? 'Brak wpisów o trawieniu z ostatnich 30 dni.' : 'W ostatnich 30 dniach bez objawów trawiennych.')
          else ...[
            Text('Objawy w ostatnich 30 dniach · ${gut30.length} wpisów', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final f in freq) assocRow(f.$1, f.$2 / freq.first.$2, '${f.$2}× · ${severityLabel(f.$3)}', Palette.bad(context)),
          ],
        ]),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title('Co jadłeś przed gorszym trawieniem'),
          muted('Dla każdego wpisu liczą się posiłki zaznaczone jako podejrzane, a bez zaznaczenia wszystko z 30 godzin przed nim. '
              'Procent to odsetek takich okien, po których trawienie było złe (komfort 1–2 albo objaw średni lub silny).'),
          const SizedBox(height: 10),
          if (ga.windows < 4)
            muted('Potrzeba co najmniej 4 wpisów o trawieniu z zapisanymi posiłkami przed nimi. Masz: ${ga.windows}.')
          else if (ga.bad == 0)
            muted('Żaden wpis nie wskazuje na złe trawienie.')
          else ...[
            Text('Złe trawienie w ${(ga.base * 100).round()}% wpisów (${ga.bad} z ${ga.windows}).', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (ga.rows.isEmpty) muted('Żaden składnik nie pojawił się jeszcze przed złym trawieniem co najmniej 2 razy.'),
            for (final r in ga.rows) assocRow(r.ingredient, r.rate, '${(r.rate * 100).round()}% (${r.hits}/${r.total})', Palette.bad(context), flag: ga.flagged(r)),
            if (ga.rows.any(ga.flagged)) Padding(padding: const EdgeInsets.only(top: 6), child: muted('⚑ wyraźnie częściej niż przeciętnie, przy co najmniej 3 wystąpieniach.')),
          ],
        ]),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title('Objawy zaraz po posiłkach'),
          if (rated < 3)
            muted('Oceń samopoczucie po co najmniej 3 posiłkach („Jak się czujesz po?”). Masz ocenionych: $rated.')
          else if (ra.isEmpty)
            muted('Po ocenionych posiłkach nie zanotowałeś objawów.')
          else
            for (final s in ra) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Row(children: [Chip2(s.symptom, color: Palette.bad(context)), const SizedBox(width: 8), muted('po ${s.meals} z $rated ocenionych posiłków')]),
              ),
              if (s.rows.isEmpty) muted('Żaden składnik nie powtórzył się jeszcze 2 razy.'),
              for (final r in s.rows) assocRow(r.ingredient, r.rate, '${(r.rate * 100).round()}% (${r.hits}/${r.total})', Palette.bad(context)),
            ],
        ]),
      ),
      if (gs.any)
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Wiatry'),
            muted([
              if (gs.kreska != null) 'Kreska: licznik „${gs.kreska!.label}” (w ciągu dnia)',
              if (gs.night != null) 'Rytm Snu (w nocy)',
            ].join(' · ')),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final ds = [for (var i = 13; i >= 0; i--) shiftDay(today, -i)];
              return GasBars(
                days: ds,
                day: [for (final d in ds) gs.day(d)],
                night: [for (final d in ds) gs.nightAfter(d)],
                dayColor: Palette.amber(context),
                nightColor: cs.tertiary,
              );
            }),
            Wrap(spacing: 12, children: [
              if (gs.kreska != null)
                Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: Palette.amber(context)), const SizedBox(width: 4), muted('dzień')]),
              if (gs.night != null)
                Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: cs.tertiary), const SizedBox(width: 4), muted('noc po tym dniu')]),
            ]),
            const SizedBox(height: 14),
            Text('Po czym więcej wiatrów', style: const TextStyle(fontWeight: FontWeight.w600)),
            muted('Średnia liczba wiatrów (${gs.outcomeLabel}) po dniach, w które jadłeś dany składnik, wobec średniej ze wszystkich dni.'),
            const SizedBox(height: 6),
            if (gasA.days < 5)
              muted('Potrzeba co najmniej 5 dni z posiłkami i danymi o wiatrach. Masz: ${gasA.days}.')
            else ...[
              Text('Średnio ${gasA.base.toStringAsFixed(1).replaceAll('.', ',')} po dniu (${gasA.days} dni).', style: const TextStyle(fontWeight: FontWeight.w600)),
              for (final r in gasA.rows)
                assocRow(r.ingredient, (gasA.ratio(r) / 2).clamp(0, 1).toDouble(),
                    '${r.avg.toStringAsFixed(1).replaceAll('.', ',')} · ${r.days} dni', gasA.flagged(r) ? Palette.bad(context) : Palette.amber(context),
                    flag: gasA.flagged(r)),
              if (gasA.rows.any(gasA.flagged)) Padding(padding: const EdgeInsets.only(top: 6), child: muted('⚑ co najmniej 30% więcej niż średnio, przy co najmniej 3 dniach.')),
            ],
          ]),
        ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title('Energia po jedzeniu'),
          if (en.fold<int>(0, (a, e) => a + e.$3) < 3)
            muted('Oceniaj energię po posiłkach, a tu zobaczysz, po czym masz jej najwięcej i najmniej.')
          else
            for (final e in en) assocRow(e.$1, e.$2 / 5, '${e.$2.toStringAsFixed(1).replaceAll('.', ',')}/5 · ${e.$3}×', Palette.good(context)),
        ]),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('Analiza AI'),
          muted('AI przejrzy posiłki i wpisy (model na telefonie: 14 dni, Claude: 30 dni), uwzględniając wiek, płeć, wagę, aktywność i uwagi z profilu. To obserwacje, nie diagnoza.'),
          const SizedBox(height: 12),
          FutureBuilder<bool>(
            future: Ai.enabled(),
            builder: (_, s) => s.data == false
                ? muted('Analiza wymaga darmowego modelu na telefonie albo klucza Claude (Ustawienia → Rozpoznawanie AI).')
                : Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: busy ? null : _analyze,
                      icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                      label: Text(busy ? 'AI czyta dziennik…' : 'Przeanalizuj wzorce: ${app.active.name}'),
                    ),
                  ),
          ),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: cs.error))),
          if (_ai[app.active.id] != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(_ai[app.active.id]!, style: const TextStyle(height: 1.5, fontSize: 14.5)),
            ),
        ]),
      ),
    ]);
  }
}

String severityLabel(double avgSev) => severityNamesSafe(avgSev.round());
String severityNamesSafe(int i) => const ['', 'lekki', 'średni', 'silny'][i.clamp(1, 3)];
