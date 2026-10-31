import 'package:flutter/material.dart';

import '../calc.dart';
import '../fodmap.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';

String _short(String id) => groupById(id)?.name.split(' (').first ?? id;

String phaseText(Elimination e, String date) {
  final p = e.phaseOn(date);
  final out = e.forbiddenOn(date).map(_short).join(', ');
  return switch (p.stage) {
    ElimStage.before => 'Dieta eliminacyjna od ${dayLabel(e.start)}',
    ElimStage.elimination => 'Eliminacja: dzień ${p.day} z ${p.of} · bez: $out',
    ElimStage.test => 'Test: ${_short(p.group!)} – dzień ${p.day} z ${p.of}. Zjedz zwykłą porcję. Nadal bez: ${out.isEmpty ? '—' : out}',
    ElimStage.wash => 'Przerwa po teście (${_short(p.group!)}) · bez: $out',
    ElimStage.done => 'Dieta zakończona – zobacz wyniki',
  };
}

/// Dieta eliminacyjna: wybrane grupy odstawione na 2–4 tygodnie, potem wprowadzane po jednej
/// (3 dni testu + 2 dni przerwy). Wynik porównuje FF i trawienie w testach z okresem eliminacji.
class EliminationScreen extends StatefulWidget {
  const EliminationScreen({super.key});
  @override
  State<EliminationScreen> createState() => _EliminationScreenState();
}

class _EliminationScreenState extends State<EliminationScreen> {
  bool _new = false;
  final Set<String> _groups = {};
  int _days = elimDefaultDays;
  bool _tomorrow = false;

  @override
  void initState() {
    super.initState();
    final gs = app.gasSeries;
    for (final r in gasGroupAssociations(app.meals, gs)) {
      if (r.flagged) _groups.add(r.group.id);
    }
    if (_groups.isEmpty) _groups.addAll(['fruktany', 'gos', 'laktoza']);
  }

  Future<void> _start() async {
    final order = [for (final g in foodGroups) if (_groups.contains(g.id)) g.id];
    final start = _tomorrow ? shiftDay(todayIso(), 1) : todayIso();
    await app.saveElimination(Elimination(id: newId('e'), person: app.active.id, groups: order, start: start, elimDays: _days));
    setState(() => _new = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final e = app.elimination;
        return Scaffold(
          appBar: AppBar(title: const Text('Dieta eliminacyjna')),
          body: (e == null || _new) ? _setup(context) : _progress(context, e),
        );
      },
    );
  }

  Widget _setup(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assoc = {for (final r in gasGroupAssociations(app.meals, app.gasSeries)) r.group.id: r};
    final muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    final total = _days + _groups.length * (testDays + washDays);
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Panel(
        child: Text(
            'Odstaw wybrane grupy na $_days dni, potem wprowadzaj je po jednej: $testDays dni zwykłej porcji i $washDays dni przerwy. '
            'Aplikacja porówna FF (Kreska, Rytm Snu) i trawienie w dniach testu z drugą połową eliminacji i powie, '
            'która grupa Ci szkodzi. Przy chorobach przewodu pokarmowego dietę warto omówić z dietetykiem.',
            style: muted),
      ),
      const SectionTitle('Co odstawić'),
      for (final g in foodGroups)
        CheckboxListTile(
          value: _groups.contains(g.id),
          onChanged: (v) => setState(() => v == true ? _groups.add(g.id) : _groups.remove(g.id)),
          title: Text(g.name),
          subtitle: Text([
            g.examples,
            if (assoc[g.id] case final a?)
              'u Ciebie: ${a.avgWith.toStringAsFixed(1).replaceAll('.', ',')} FF po dniach z tą grupą, ${a.avgWithout.toStringAsFixed(1).replaceAll('.', ',')} bez${a.flagged ? ' ⚑' : ''}',
          ].join('\n')),
          isThreeLine: assoc.containsKey(g.id),
        ),
      const SectionTitle('Jak długo'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, children: [
          for (final d in const [14, 21, 28]) ChoiceChip(label: Text('$d dni eliminacji'), selected: _days == d, onSelected: (_) => setState(() => _days = d)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Od dziś'), selected: !_tomorrow, onSelected: (_) => setState(() => _tomorrow = false)),
          ChoiceChip(label: const Text('Od jutra'), selected: _tomorrow, onSelected: (_) => setState(() => _tomorrow = true)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text('Razem z testami: $total dni (do ${dayLabel(shiftDay(_tomorrow ? shiftDay(todayIso(), 1) : todayIso(), total - 1))}).', style: muted),
      ),
      if (!app.gasSeries.any)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Brak danych FF z Kreski i Rytmu Snu – wynik oprze się na wpisach o trawieniu. Włącz wymianę danych przez Koofr albo wczytaj plik.', style: muted),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: FilledButton.icon(
          onPressed: _groups.isEmpty ? null : _start,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Zacznij dietę'),
        ),
      ),
    ]);
  }

  Widget _progress(BuildContext context, Elimination e) {
    final cs = Theme.of(context).colorScheme;
    final today = todayIso();
    final muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    final bad = violations(e, app.meals.where((m) => m.date.compareTo(today) <= 0).toList());
    final res = elimResult(e, app.gasSeries, app.meals, app.gut);
    final done = e.stopped || e.end.compareTo(today) < 0;
    String f(double? v) => v == null ? '—' : v.toStringAsFixed(1).replaceAll('.', ',');

    final steps = <(String, String, String)>[
      ('Eliminacja', '${dayLabel(e.start)} – ${dayLabel(e.elimEnd)}', 'bez: ${e.groups.map(_short).join(', ')}'),
      for (var i = 0; i < e.groups.length; i++)
        ('Test: ${_short(e.groups[i])}', '${dayLabel(e.testOf(i).$1)} – ${dayLabel(e.testOf(i).$2)}', 'potem $washDays dni przerwy'),
    ];

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(done ? 'Dieta zakończona' : 'Dziś', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(done ? 'Wyniki poniżej. Grupy bez różnicy możesz jeść normalnie.' : phaseText(e, today)),
        ]),
      ),
      const SectionTitle('Plan'),
      for (final s in steps)
        ListTile(dense: true, title: Text(s.$1), subtitle: Text('${s.$2} · ${s.$3}')),
      const SectionTitle('Wyniki'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (app.gasSeries.any) ...[
            Text('FF średnio po dniu: przed dietą ${f(res.baseline)} · w eliminacji ${f(res.elim)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
          ],
          for (final g in e.groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(_short(g))),
                Text(app.gasSeries.any ? 'FF ${f(res.tests[g])}' : 'trawienie ${f(res.gutTests[g])}/5', style: const TextStyle(fontFeatures: tabular)),
                const SizedBox(width: 8),
                switch (res.worse(g)) {
                  true => Chip2('szkodzi', color: Palette.bad(context)),
                  false => Chip2('bez różnicy', color: Palette.good(context)),
                  null => const Chip2('brak danych'),
                },
              ]),
            ),
          const SizedBox(height: 6),
          Text('„Szkodzi”: w dniach testu (i dzień po) co najmniej o 30% i o 1 FF więcej niż w drugiej połowie eliminacji, '
              'albo trawienie gorsze o co najmniej 1 punkt.', style: muted),
        ]),
      ),
      SectionTitle('Wpadki · ${bad.length}'),
      if (bad.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Bez wpadek – tak trzymaj.', style: muted)),
      for (final (m, g) in bad.reversed.take(20))
        ListTile(
          dense: true,
          leading: Icon(Icons.warning_amber_rounded, color: Palette.amber(context)),
          title: Text(m.name),
          subtitle: Text('${dayLabel(m.date)} ${m.time} · ${g.map(_short).join(', ')}'),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          if (!done)
            OutlinedButton.icon(
              onPressed: () async {
                if (await confirm(context, 'Zakończyć dietę?', 'Wyniki zostaną policzone z dotychczasowych dni.', ok: 'Zakończ')) {
                  e.stopped = true;
                  await app.saveElimination(e);
                }
              },
              icon: const Icon(Icons.stop),
              label: const Text('Zakończ wcześniej'),
            ),
          if (done) FilledButton.icon(onPressed: () => setState(() => _new = true), icon: const Icon(Icons.add), label: const Text('Nowa dieta')),
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Usunąć dietę?', 'Plan i wyniki zostaną usunięte (posiłki zostają).')) await app.deleteElimination(e.id);
            },
            child: const Text('Usuń'),
          ),
        ]),
      ),
    ]);
  }
}
