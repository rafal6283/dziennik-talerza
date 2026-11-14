// Ekrany i karty dodatków: szybkie dodawanie (ulubione, „to co zwykle”), napoje, leki i suplementy,
// przepisy, waga, podsumowanie tygodnia, „Co zjeść dziś”, spiżarnia z paragonu i raport PDF.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../ai.dart';
import '../calc.dart';
import '../extras.dart';
import '../food_pack.dart';
import '../food_table.dart';
import '../health.dart';
import '../main.dart';
import '../models.dart';
import '../report_pdf.dart';
import 'format.dart';
import 'meal_form.dart';

String _now() => hhmm(DateTime.now());
String _kg(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
String _l(int ml) => (ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1).replaceAll('.', ',');

void _undoToast(BuildContext context, String text, Future<void> Function() undo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: SnackBarAction(label: 'Cofnij', onPressed: () => undo())));
}

// ======================= SZYBKIE DODAWANIE =======================

/// Ulubione i „to co zwykle” – jedno stuknięcie dodaje posiłek na wybrany dzień.
class QuickAddCard extends StatelessWidget {
  final String day;
  const QuickAddCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final favs = app.myFavorites;
    final usual = day == todayIso() ? usualMeals(app.meals, DateTime.now()) : const <(String, List<FoodItem>, int)>[];
    final favNames = {for (final f in favs) f.name.toLowerCase()};
    final extra = [for (final u in usual) if (!favNames.contains(u.$1.toLowerCase())) u];
    if (favs.isEmpty && extra.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    Future<void> add(String name, List<FoodItem> items, String? type) async {
      final m = await app.addMealFrom(name: name, items: items, type: type, date: day, time: day == todayIso() ? _now() : '12:00');
      if (context.mounted) _undoToast(context, 'Dodano: $name (${m.total.kcal.round()} kcal)', () => app.deleteMeal(m.id));
    }

    return SizedBox(
      height: 46,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
        for (final u in extra)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              avatar: Icon(Icons.history, size: 16, color: cs.primary),
              label: Text('${u.$1} · ${Macros.ofItems(u.$2).kcal.round()}'),
              tooltip: 'To co zwykle o tej porze (${u.$3}×)',
              onPressed: () => add(u.$1, u.$2, null),
            ),
          ),
        for (final f in favs)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onLongPress: () async {
                if (await confirm(context, 'Usunąć z ulubionych?', '„${f.name}” zniknie z szybkiego dodawania.')) await app.deleteFavorite(f.id);
              },
              child: ActionChip(
                avatar: Icon(Icons.star, size: 16, color: Palette.amber(context)),
                label: Text('${f.name} · ${f.total.kcal.round()}'),
                onPressed: () => add(f.name, f.items, f.type.isEmpty ? null : f.type),
              ),
            ),
          ),
      ]),
    );
  }
}

// ======================= NAPOJE =======================

class DrinksCard extends StatelessWidget {
  final String day;
  const DrinksCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final p = app.active;
    final list = app.drinks.where((d) => d.date == day).toList()..sort((a, b) => a.time.compareTo(b.time));
    final s = drinksOn(day, app.drinks, app.mealsOn(day));
    final goal = waterGoalMl(p);
    final cs = Theme.of(context).colorScheme;

    Future<void> add(String kind, int ml) async {
      final d = Drink(id: newId('d'), person: p.id, date: day, time: day == todayIso() ? _now() : '12:00', kind: kind, ml: ml);
      await app.saveDrink(d);
      if (context.mounted) _undoToast(context, '${drinkKinds.firstWhere((k) => k.$1 == kind).$2} $ml ml', () => app.deleteDrink(d.id));
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Napoje', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          Text('woda ${_l(s.waterMl)} / ${_l(goal)} l', style: TextStyle(color: cs.onSurfaceVariant, fontFeatures: tabular)),
        ]),
        const SizedBox(height: 8),
        Meter(goal > 0 ? s.waterMl / goal : 0, const Color(0xFF3B82C4), height: 8),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          FilledButton.tonalIcon(onPressed: () => add('woda', 250), icon: const Icon(Icons.water_drop_outlined, size: 18), label: const Text('Szklanka')),
          OutlinedButton(onPressed: () => add('woda', 500), child: const Text('0,5 l')),
          OutlinedButton.icon(onPressed: () => add('kawa', 150), icon: const Icon(Icons.coffee_outlined, size: 18), label: const Text('Kawa')),
          OutlinedButton.icon(onPressed: () => add('herbata', 250), icon: const Icon(Icons.emoji_food_beverage_outlined, size: 18), label: const Text('Herbata')),
          OutlinedButton(onPressed: () => _customDrink(context, day), child: const Text('Inny…')),
        ]),
        if (s.coffees > 0 || list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                if (s.coffees > 0) 'kawy: ${s.coffees}${s.coffees >= 4 ? ' – sporo, kofeina może nasilać dolegliwości jelitowe' : ''}',
                if (list.isNotEmpty) 'wszystkie płyny ${_l(s.allMl)} l (bez zup i napojów z posiłków)',
              ].join(' · '),
              style: TextStyle(color: s.coffees >= 4 ? Palette.amber(context) : cs.onSurfaceVariant, fontSize: 12.5),
            ),
          ),
        if (list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final d in list)
                InputChip(
                  label: Text('${d.time} ${d.kind == 'woda' ? '' : '${d.kind} '}${d.ml} ml', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => app.deleteDrink(d.id),
                ),
            ]),
          ),
      ]),
    );
  }
}

Future<void> _customDrink(BuildContext context, String day) async {
  var kind = 'woda';
  final ml = TextEditingController(text: '250');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Napój'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: kind,
            decoration: const InputDecoration(labelText: 'Rodzaj'),
            items: [for (final k in drinkKinds) DropdownMenuItem(value: k.$1, child: Text(k.$2))],
            onChanged: (v) => set(() => kind = v ?? kind),
          ),
          const SizedBox(height: 10),
          TextField(controller: ml, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ilość (ml)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Dodaj')),
        ],
      ),
    ),
  );
  final v = parseNum(ml.text)?.round() ?? 0;
  if (ok == true && v > 0) {
    await app.saveDrink(Drink(id: newId('d'), person: app.active.id, date: day, time: day == todayIso() ? _now() : '12:00', kind: kind, ml: v));
  }
}

// ======================= LEKI I SUPLEMENTY =======================

class MedsCard extends StatelessWidget {
  final String day;
  const MedsCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final list = app.medsOn(day);
    final y = app.medsOn(shiftDay(day, -1));
    final cs = Theme.of(context).colorScheme;
    if (list.isEmpty && y.isEmpty && app.meds.isEmpty) {
      // pierwsze użycie: nie zajmuj miejsca, wystarczy przycisk
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => editMed(context, day), icon: const Icon(Icons.medication_outlined, size: 18), label: const Text('Lek albo suplement')),
        ),
      );
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Leki i suplementy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: () => editMed(context, day), icon: const Icon(Icons.add), label: const Text('Dodaj')),
        ]),
        if (list.isEmpty && y.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.replay, size: 18),
              label: Text('Jak wczoraj: ${y.map((m) => m.name).join(', ')}', overflow: TextOverflow.ellipsis),
              onPressed: () async {
                for (final m in y) {
                  await app.saveMed(MedEntry(id: newId('med'), person: m.person, date: day, time: m.time, name: m.name, dose: m.dose, kind: m.kind));
                }
              },
            ),
          ),
        if (list.isEmpty && y.isEmpty) Text('Nic tego dnia.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        for (final m in list)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(m.kind == 'lek' ? Icons.medication_outlined : Icons.spa_outlined, color: cs.primary),
            title: Text(m.dose.isEmpty ? m.name : '${m.name} · ${m.dose}'),
            subtitle: Text('${m.time} · ${m.kind}'),
            onTap: () => editMed(context, day, m),
          ),
      ]),
    );
  }
}

Future<void> editMed(BuildContext context, String day, [MedEntry? e]) async {
  final name = TextEditingController(text: e?.name ?? '');
  final dose = TextEditingController(text: e?.dose ?? '');
  var kind = e?.kind ?? 'suplement';
  var time = e?.time ?? (day == todayIso() ? _now() : '08:00');
  final known = <String, MedEntry>{for (final m in app.meds) m.name.toLowerCase(): m};
  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(e == null ? 'Lek albo suplement' : 'Edytuj', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'suplement', label: Text('Suplement')), ButtonSegment(value: 'lek', label: Text('Lek'))],
            selected: {kind},
            onSelectionChanged: (s) => set(() => kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nazwa', hintText: 'np. witamina D, probiotyk, IPP'),
            onChanged: (v) {
              final k = known[v.trim().toLowerCase()];
              if (k != null && dose.text.isEmpty) set(() {
                dose.text = k.dose;
                kind = k.kind;
              });
            },
          ),
          if (known.isNotEmpty && name.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, children: [
                for (final k in known.values.take(6))
                  ActionChip(
                      label: Text(k.name),
                      onPressed: () => set(() {
                            name.text = k.name;
                            dose.text = k.dose;
                            kind = k.kind;
                          })),
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: dose, decoration: const InputDecoration(labelText: 'Dawka (opcjonalnie)', hintText: 'np. 2000 j.m., 1 kaps.'))),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(time),
              onPressed: () async {
                final p = time.split(':');
                final t = await showTimePicker(context: c, initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p[1]) ?? 0));
                if (t != null) set(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
              },
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            if (e != null) TextButton(onPressed: () => Navigator.pop(c, 'del'), child: Text('Usuń', style: TextStyle(color: Theme.of(c).colorScheme.error))),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Zapisz')),
          ]),
        ]),
      ),
    ),
  );
  if (res == 'del' && e != null) await app.deleteMed(e.id);
  if (res == 'save' && name.text.trim().isNotEmpty) {
    await app.saveMed(MedEntry(
        id: e?.id ?? newId('med'), person: e?.person ?? app.active.id, date: day, time: time, name: name.text.trim(), dose: dose.text.trim(), kind: kind));
  }
}

// ======================= NARZĘDZIA (menu) =======================

void showToolsSheet(BuildContext context, String day) {
  Widget tile(BuildContext c, IconData icon, String title, String sub, Widget Function() screen) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(sub),
        onTap: () {
          Navigator.pop(c);
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen()));
        },
      );
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          tile(c, Icons.lightbulb_outline, 'Co zjeść dziś', 'Propozycje pod resztę kalorii i białka, bez tego, co Ci szkodzi', () => const SuggestScreen()),
          tile(c, Icons.calendar_view_week, 'Podsumowanie tygodnia', 'Kalorie, trawienie, okno jedzenia, sen, aktywność', () => const WeekScreen()),
          tile(c, Icons.monitor_weight_outlined, 'Waga', 'Pomiary, wykres i trend', () => const WeightScreen()),
          tile(c, Icons.menu_book_outlined, 'Przepisy', 'Własne dania – liczone z wagi gotowego garnka', () => const RecipesScreen()),
          tile(c, Icons.kitchen_outlined, 'Spiżarnia', 'Produkty z paragonu albo listy zakupów', () => const PantryScreen()),
          tile(c, Icons.picture_as_pdf_outlined, 'Raport PDF dla lekarza', 'Dzień po dniu, objawy, podejrzane składniki, leki', () => const ReportScreen()),
        ]),
      ),
    ),
  );
}

// ======================= PRZEPISY =======================

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final rs = [...app.recipes]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Przepisy')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealForm(date: todayIso(), recipeMode: true))),
            icon: const Icon(Icons.add),
            label: const Text('Przepis'),
          ),
          body: rs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Dodaj danie, które gotujesz w większej ilości (zupa, bigos, gulasz). Wpisz składniki całego garnka i wagę gotowego dania '
                    '– potem zjedzoną porcję wybierzesz z podpowiedzi przy dodawaniu posiłku, a kalorie policzą się z wagi.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                  for (final r in rs)
                    Panel(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${r.per100.kcal.round()} kcal/100 g · porcja ${r.portion.round()} g = ${(r.total.kcal / r.portions).round()} kcal'
                            ' · ${r.items.length} skł.'),
                        trailing: IconButton(
                          tooltip: 'Zjedz porcję',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _eatRecipe(context, r),
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealForm(date: todayIso(), recipeMode: true, recipe: r))),
                      ),
                    ),
                ]),
        );
      },
    );
  }
}

Future<void> _eatRecipe(BuildContext context, Recipe r) async {
  final g = TextEditingController(text: '${r.portion.round()}');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(r.name),
      content: TextField(
        controller: g,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Zjedzona ilość (g)', helperText: '${r.per100.kcal.round()} kcal na 100 g'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Dodaj do dziś')),
      ],
    ),
  );
  final grams = parseNum(g.text) ?? 0;
  if (ok != true || grams <= 0) return;
  final m = await app.addMealFrom(name: r.name, items: [r.portionItem(grams)]);
  if (context.mounted) _undoToast(context, 'Dodano ${r.name} – ${m.total.kcal.round()} kcal', () => app.deleteMeal(m.id));
}

// ======================= WAGA =======================

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  int span = 90;

  Future<void> _add([WeightEntry? e]) async {
    final kg = TextEditingController(text: e != null ? numInput(e.kg) : (app.weights.isNotEmpty ? numInput(app.weights.last.kg) : ''));
    var date = e?.date ?? todayIso();
    final res = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(e == null ? 'Pomiar wagi' : 'Edytuj pomiar'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: kg, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Waga (kg)')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 18),
              label: Text(dayLabel(date)),
              onPressed: () async {
                final d = await showDatePicker(context: c, initialDate: DateTime.parse('${date}T12:00:00'), firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) set(() => date = isoDate(d));
              },
            ),
          ]),
          actions: [
            if (e != null) TextButton(onPressed: () => Navigator.pop(c, 'del'), child: const Text('Usuń')),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Zapisz')),
          ],
        ),
      ),
    );
    if (res == 'del' && e != null) await app.deleteWeight(e.id);
    final v = parseNum(kg.text) ?? 0;
    if (res == 'save' && v > 20 && v < 400) {
      await app.saveWeight(WeightEntry(id: e?.id ?? newId('w'), person: app.active.id, date: date, kg: v));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final ws = app.weights;
        final t = WeightTrend(ws);
        final ch = t.weeklyChange();
        final cs = Theme.of(context).colorScheme;
        final from = shiftDay(todayIso(), -span);
        final pts = [for (final w in ws) if (w.date.compareTo(from) >= 0) w];
        final p = app.active;
        String verdict() {
          if (ch == null) return 'Trend pojawi się po 3 pomiarach w ciągu 4 tygodni.';
          final dir = ch.abs() < 0.1 ? 'waga stoi w miejscu' : (ch < 0 ? 'chudniesz ${_kg(-ch)} kg/tydz.' : 'przybierasz ${_kg(ch)} kg/tydz.');
          final want = switch (p.mode) { 'cut' => ch < -0.1, 'gain' => ch > 0.1, _ => ch.abs() <= 0.25 };
          final tooFast = p.mode == 'cut' && p.weight > 0 && -ch > p.weight * 0.01;
          return '${dir[0].toUpperCase()}${dir.substring(1)} (z 4 tygodni)'
              '${tooFast ? ' – szybciej niż 1% masy ciała tygodniowo, rozważ większy cel kalorii' : want ? ' – zgodnie z celem' : ''}.';
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Waga')),
          floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Pomiar')),
          body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(t.last != null ? _kg(t.last!) : '–', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, height: 1, fontFeatures: tabular)),
                  const SizedBox(width: 6),
                  Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('kg', style: TextStyle(color: cs.onSurfaceVariant))),
                  const Spacer(),
                  if (t.avgAt(todayIso()) case final a?)
                    Text('średnia 7 dni ${_kg(a)}', style: TextStyle(color: cs.onSurfaceVariant, fontFeatures: tabular)),
                ]),
                const SizedBox(height: 8),
                Text(verdict(), style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [ButtonSegment(value: 30, label: Text('30 dni')), ButtonSegment(value: 90, label: Text('90 dni')), ButtonSegment(value: 365, label: Text('Rok'))],
                  selected: {span},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => span = s.first),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: pts.length < 2
                      ? Center(child: Text('Dodaj co najmniej dwa pomiary, żeby zobaczyć wykres.', style: TextStyle(color: cs.onSurfaceVariant)))
                      : CustomPaint(
                          size: Size.infinite,
                          painter: _WeightPainter(pts, t, from, todayIso(), cs.primary, Palette.amber(context), cs.outlineVariant, cs.onSurfaceVariant)),
                ),
              ]),
            ),
            SectionTitle('Pomiary · ${ws.length}'),
            for (final w in ws.reversed.take(60))
              ListTile(
                dense: true,
                title: Text('${_kg(w.kg)} kg', style: const TextStyle(fontFeatures: tabular)),
                subtitle: Text(dayLabel(w.date)),
                onTap: () => _add(w),
              ),
          ]),
        );
      },
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<WeightEntry> pts;
  final WeightTrend trend;
  final String from, to;
  final Color line, avgColor, grid, text;
  _WeightPainter(this.pts, this.trend, this.from, this.to, this.line, this.avgColor, this.grid, this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final t0 = DateTime.parse('${pts.first.date.compareTo(from) > 0 ? pts.first.date : from}T12:00:00');
    final t1 = DateTime.parse('${to}T12:00:00');
    final spanD = math.max(1, t1.difference(t0).inDays);
    var lo = pts.map((p) => p.kg).reduce(math.min), hi = pts.map((p) => p.kg).reduce(math.max);
    if (hi - lo < 2) {
      final mid = (hi + lo) / 2;
      lo = mid - 1;
      hi = mid + 1;
    }
    lo -= 0.3;
    hi += 0.3;
    const left = 34.0, bottom = 4.0;
    final w = size.width - left, h = size.height - bottom;
    double x(String d) => left + DateTime.parse('${d}T12:00:00').difference(t0).inDays / spanD * w;
    double y(double kg) => (hi - kg) / (hi - lo) * h;
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3;
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), gp);
      tp.text = TextSpan(text: v.toStringAsFixed(hi - lo < 4 ? 1 : 0), style: TextStyle(fontSize: 10, color: text));
      tp.layout();
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }
    // średnia 7-dniowa
    final avgPath = Path();
    var started = false;
    for (final p in pts) {
      final a = trend.avgAt(p.date);
      if (a == null) continue;
      final o = Offset(x(p.date), y(a));
      if (!started) {
        avgPath.moveTo(o.dx, o.dy);
        started = true;
      } else {
        avgPath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
        avgPath,
        Paint()
          ..color = avgColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    final dot = Paint()..color = line;
    for (final p in pts) {
      canvas.drawCircle(Offset(x(p.date), y(p.kg)), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) => old.pts != pts || old.from != from;
}

// ======================= PODSUMOWANIE TYGODNIA =======================

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});
  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  String until = todayIso();

  @override
  void initState() {
    super.initState();
    HealthSync.refreshActivity().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = app.active;
    final s = weekSummary(meals: app.meals, gut: app.gut, drinks: app.drinks, weights: app.weights, goal: app.goal, until: until);
    final gas = app.gasSeries;
    final late = lateDinner(meals: app.meals, gut: app.gut, sleepHours: gas.sleepHours, nightFF: gas.nightAfter);
    final cs = Theme.of(context).colorScheme;
    final days = [for (var i = 0; i < 7; i++) shiftDay(s.from, i)];
    final act = [for (final d in days) HealthSync.activityFor(p.id, d)].whereType<(int, double)>().toList();
    final prev = weekSummary(meals: app.meals, gut: app.gut, drinks: app.drinks, weights: app.weights, goal: app.goal, until: shiftDay(until, -7));
    final medsWeek = app.meds.where((m) => m.date.compareTo(s.from) >= 0 && m.date.compareTo(s.until) <= 0).toList();
    final ffWeek = [for (final d in days) gas.nightAfter(d)].whereType<int>().toList();
    final ffPrev = [for (final d in days) gas.nightAfter(shiftDay(d, -7))].whereType<int>().toList();

    Widget row(IconData icon, String title, String value, {String? sub, Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? cs.primary),
          title: Text(title),
          subtitle: sub != null ? Text(sub) : null,
          trailing: Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color, fontFeatures: tabular)),
        );
    String delta(double a, double b, {String unit = '', int digits = 0}) {
      if (b == 0) return '';
      final d = a - b;
      return ' (${d >= 0 ? '+' : '−'}${d.abs().toStringAsFixed(digits)}$unit vs poprzedni)';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Podsumowanie tygodnia')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => until = shiftDay(until, -7))),
            Expanded(
              child: Text('${dayOfMonth(s.from)}.${s.from.substring(5, 7)} – ${dayOfMonth(s.until)}.${s.until.substring(5, 7)}',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: until.compareTo(todayIso()) >= 0 ? null : () => setState(() => until = shiftDay(until, 7))),
          ]),
        ),
        if (s.daysLogged == 0)
          Padding(padding: const EdgeInsets.all(24), child: Text('Brak posiłków w tym tygodniu.', style: TextStyle(color: cs.onSurfaceVariant)))
        else ...[
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              row(Icons.local_fire_department_outlined, 'Średnio kalorii', '${s.avgKcal.round()}',
                  sub: 'cel ${s.goal} · dni z wpisami ${s.daysLogged}/7${delta(s.avgKcal, prev.avgKcal, unit: ' kcal')}',
                  color: (s.avgKcal - s.goal).abs() <= s.goal * 0.1 ? Palette.good(context) : Palette.amber(context)),
              row(Icons.egg_outlined, 'Białko dziennie', '${s.avgProtein.round()} g', sub: proteinOf(p) != null ? 'zalecane ok. ${proteinOf(p)} g' : null),
              if (s.avgFiber != null)
                row(Icons.grass_outlined, 'Błonnik dziennie', '${s.avgFiber!.round()} g',
                    sub: 'zalecane 25–30 g', color: s.avgFiber! >= 25 ? Palette.good(context) : Palette.amber(context)),
              if (s.avgWaterMl > 0) row(Icons.water_drop_outlined, 'Woda (dni z wpisem)', '${_l(s.avgWaterMl.round())} l', sub: 'cel ${_l(waterGoalMl(p))} l'),
              if (s.avgFirst != null && s.avgLast != null)
                row(Icons.schedule, 'Okno jedzenia', '${hm(s.avgFirst!)}–${hm(s.avgLast!)}',
                    sub: 'średnio ${((s.avgLast! - s.avgFirst!) / 60).toStringAsFixed(1).replaceAll('.', ',')} h między pierwszym a ostatnim posiłkiem'),
              if (s.weightChange != null)
                row(Icons.monitor_weight_outlined, 'Waga', '${s.weightChange! >= 0 ? '+' : '−'}${_kg(s.weightChange!.abs())} kg/tydz.', sub: 'trend z 4 tygodni'),
            ]),
          ),
          SectionTitle('Trawienie'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              if (s.bestGutDay != null) row(Icons.sentiment_satisfied_alt, 'Najlepszy dzień', '${s.bestGutDayScore}/5', sub: dayLabel(s.bestGutDay!), color: Palette.good(context)),
              if (s.worstGutDay != null && s.worstGutDay != s.bestGutDay)
                row(Icons.sentiment_dissatisfied, 'Najgorszy dzień', '${s.worstGutDayScore}/5', sub: _worstHint(s.worstGutDay!), color: Palette.bad(context)),
              row(Icons.healing_outlined, 'Objawy w wpisach', '${s.symptomsCount}', sub: 'poprzedni tydzień: ${prev.symptomsCount}'),
              if (ffWeek.isNotEmpty)
                row(Icons.nightlight_outlined, 'Wiatry nocą (Rytm Snu)', avg(ffWeek).toStringAsFixed(1), sub: ffPrev.isNotEmpty ? 'poprzedni tydzień: ${avg(ffPrev).toStringAsFixed(1)}' : null),
              if (medsWeek.isNotEmpty)
                row(Icons.medication_outlined, 'Leki i suplementy', '${medsWeek.length}', sub: {for (final m in medsWeek) m.name}.join(', ')),
            ]),
          ),
          if (act.isNotEmpty) ...[
            SectionTitle('Aktywność (Health Connect)'),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                row(Icons.directions_walk, 'Kroki dziennie', '${avg(act.map((a) => a.$1)).round()}'),
                row(Icons.bolt_outlined, 'Aktywnie spalone', '${avg(act.map((a) => a.$2)).round()} kcal',
                    sub: HealthSync.adjustGoal ? 'połowa dolicza się do celu dnia' : 'możesz doliczać połowę do celu – Ustawienia'),
              ]),
            ),
          ],
        ],
        SectionTitle('Późna kolacja a noc i poranek'),
        Panel(
          child: late.lateDays < 2 || late.earlyDays < 2
              ? Text('Za mało danych: potrzeba co najmniej po 2 dni z ostatnim posiłkiem przed i po 20:30.', style: TextStyle(color: cs.onSurfaceVariant))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Dni z ostatnim posiłkiem po 20:30: ${late.lateDays}, wcześniej: ${late.earlyDays} (cała historia).', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  _cmp(context, 'Trawienie rano (1–5)', late.earlyGut, late.lateGut, higherBetter: true),
                  _cmp(context, 'Sen (h)', late.earlySleepH, late.lateSleepH, higherBetter: true),
                  _cmp(context, 'Wiatry w nocy', late.earlyFF, late.lateFF, higherBetter: false),
                ]),
        ),
      ]),
    );
  }

  String _worstHint(String day) {
    final y = app.mealsOn(shiftDay(day, -1));
    if (y.isEmpty) return dayLabel(day);
    return '${dayLabel(day)} · dzień wcześniej: ${y.map((m) => m.name.isNotEmpty ? m.name : m.type).take(3).join(', ')}';
  }

  Widget _cmp(BuildContext context, String label, double? early, double? late, {required bool higherBetter}) {
    if (early == null || late == null) return const SizedBox.shrink();
    final worse = higherBetter ? late < early * 0.93 : late > early * 1.07;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text('wcześnie ${early.toStringAsFixed(1)}', style: TextStyle(color: cs.onSurfaceVariant, fontFeatures: tabular)),
        const SizedBox(width: 12),
        Text('późno ${late.toStringAsFixed(1)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: worse ? Palette.bad(context) : null, fontFeatures: tabular)),
      ]),
    );
  }
}

// ======================= CO ZJEŚĆ DZIŚ =======================

class Suggestion {
  final String name;
  final List<FoodItem> items;
  final String why;
  final String source; // ulubione | przepis | historia
  final double score;
  const Suggestion(this.name, this.items, this.why, this.source, this.score);
  Macros get total => Macros.ofItems(items);
}

/// Nazwy posiłków i składniki, po których częściej było źle.
Set<String> badFoods(List<Meal> meals, List<GutEntry> gut) {
  final out = <String>{};
  final a = gutAssociations(gut, meals, top: 20);
  for (final r in a.rows) {
    if (a.flagged(r)) out.add(r.ingredient.toLowerCase());
  }
  for (final s in reactionAssociations(meals)) {
    for (final r in s.rows) {
      if (r.total >= 3 && r.rate >= 0.6) out.add(r.ingredient.toLowerCase());
    }
  }
  return out;
}

List<Suggestion> suggestMeals({required List<Meal> meals, required List<GutEntry> gut, required List<Favorite> favs, required List<Recipe> recipes,
    required double kcalLeft, required double proteinLeft, required DateTime now}) {
  final bad = badFoods(meals, gut);
  final type = mealTypeFor(now.hour);
  final mealsLeft = switch (now.hour) { < 11 => 3, < 15 => 2, _ => 1 };
  final target = kcalLeft <= 0 ? 0.0 : kcalLeft / mealsLeft;
  final cands = <String, (List<FoodItem>, String)>{};
  for (final f in favs) {
    cands[f.name.toLowerCase()] = (f.items, 'ulubione');
  }
  for (final r in recipes) {
    cands.putIfAbsent(r.name.toLowerCase(), () => ([r.portionItem()], 'przepis'));
  }
  final since = shiftDay(isoDate(now), -90);
  final count = <String, int>{};
  final latest = <String, Meal>{};
  for (final m in meals.where((m) => m.date.compareTo(since) >= 0 && m.items.isNotEmpty && m.name.trim().isNotEmpty)) {
    final k = m.name.trim().toLowerCase();
    count[k] = (count[k] ?? 0) + 1;
    if (latest[k] == null || m.ts > latest[k]!.ts) latest[k] = m;
  }
  for (final e in latest.entries) {
    if ((count[e.key] ?? 0) >= 2) cands.putIfAbsent(e.key, () => (e.value.items, 'historia'));
  }
  // zjedzone dziś – nie powtarzaj
  final today = {for (final m in meals.where((m) => m.date == isoDate(now))) m.name.trim().toLowerCase()};
  final out = <Suggestion>[];
  for (final e in cands.entries) {
    if (today.contains(e.key)) continue;
    final items = e.value.$1;
    final t = Macros.ofItems(items);
    if (t.kcal < 50) continue;
    final ings = items.map((i) => i.name.toLowerCase());
    if (ings.any((i) => bad.any((b) => i.contains(b))) || bad.contains(e.key)) continue;
    final name = latest[e.key]?.name ?? (favs.where((f) => f.name.toLowerCase() == e.key).firstOrNull?.name ?? recipes.firstWhere((r) => r.name.toLowerCase() == e.key, orElse: () => Recipe(id: '', name: e.key)).name);
    var score = 0.0;
    final why = <String>[];
    if (target > 0) {
      final fit = 1 - ((t.kcal - target).abs() / math.max(target, 200.0)).clamp(0.0, 1.0).toDouble();
      score += fit * 3;
      if (fit > 0.7) why.add('pasuje do reszty kalorii');
      if (t.kcal > kcalLeft + 150) score -= 3;
    }
    if (proteinLeft > 20) {
      final double dens = t.kcal > 0 ? t.p * 4 / t.kcal : 0.0;
      score += dens * 6;
      if (dens >= 0.25) why.add('dużo białka');
    }
    final fiber = Micro.ofItems(items);
    if (fiber.coverage > 0.5 && fiber.fiber >= 6) {
      score += 0.8;
      why.add('błonnik ${fiber.fiber.round()} g');
    }
    final usualType = latest[e.key]?.type;
    if (usualType == type) {
      score += 1;
      why.add('zwykle na ${type.toLowerCase()}');
    }
    final good = meals.where((m) => m.name.trim().toLowerCase() == e.key && m.reactions.isNotEmpty);
    if (good.isNotEmpty && good.every((m) => m.reactions.every((r) => r.symptoms.isEmpty))) {
      score += 1;
      why.add('bez objawów po nim');
    }
    score += math.min(count[e.key] ?? 0, 6) * 0.15 + (e.value.$2 == 'ulubione' ? 0.5 : 0);
    out.add(Suggestion(name, items, why.isEmpty ? 'często jedzone' : why.join(' · '), e.value.$2, score));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out.take(8).toList();
}

class SuggestScreen extends StatelessWidget {
  const SuggestScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = todayIso();
    final t = dayTotal(app.meals, today);
    final goal = app.goal + HealthSync.goalBonus(app.active.id, today);
    final left = goal - t.kcal;
    final pt = proteinOf(app.active);
    final pLeft = pt == null ? 0.0 : pt - t.p;
    final list = suggestMeals(meals: app.meals, gut: app.gut, favs: app.myFavorites, recipes: app.recipes, kcalLeft: left, proteinLeft: pLeft, now: now);
    final pantry = app.pantry.where((x) => !x.used).toList();
    final bad = badFoods(app.meals, app.gut);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Co zjeść dziś')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Panel(
          child: Text(
            left > 0
                ? 'Zostało ${left.round()} kcal${pLeft > 5 ? ' i ok. ${pLeft.round()} g białka' : ''}. Propozycje z Twoich ulubionych, przepisów i tego, co jesz najczęściej'
                    '${bad.isNotEmpty ? ' – bez: ${bad.take(5).join(', ')}' : ''}.'
                : 'Cel kalorii na dziś osiągnięty. Jeśli jesteś głodny, wybierz coś lekkiego z dużą ilością białka lub warzyw.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Za mało historii. Dodaj kilka ulubionych posiłków (gwiazdka w formularzu) albo przepisów.', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        for (final s in list)
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(switch (s.source) { 'ulubione' => Icons.star, 'przepis' => Icons.menu_book_outlined, _ => Icons.history }, color: Palette.amber(context)),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.total.kcal.round()} kcal · B ${s.total.p.round()} g\n${s.why}'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Zjedz teraz',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  final m = await app.addMealFrom(name: s.name, items: s.items);
                  if (context.mounted) {
                    _undoToast(context, 'Dodano: ${s.name}', () => app.deleteMeal(m.id));
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        if (pantry.isNotEmpty) ...[
          SectionTitle('Masz w spiżarni'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final x in pantry.take(24))
                Chip(label: Text(x.kcal > 0 ? '${x.display} · ${x.kcal.round()}/100 g' : x.display), visualDensity: VisualDensity.compact),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ======================= SPIŻARNIA =======================

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});
  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  bool busy = false;
  bool showUsed = false;
  String? status;

  FoodIndex _index() => FoodIndex.build(app.allMeals, pack: FoodPack.cached ?? const []);

  PantryItem _fromName(String raw, FoodIndex index) {
    final name = raw.trim();
    final r = Ai.matchFood(name, index) ?? index.search(name, limit: 1).firstOrNull;
    if (r == null) return PantryItem(id: newId('pan'), name: name);
    return PantryItem(
      id: newId('pan'),
      name: name.length > 2 ? name : r.name,
      brand: r.brand,
      kcal: r.kcal,
      protein: r.protein,
      carbs: r.carbs,
      fat: r.fat,
      fiber: r.fiber,
      sugar: r.sugar,
      salt: r.salt,
      portion: r.portion > 0 ? r.portion : 100,
    );
  }

  Future<void> _scan(ImageSource src) async {
    final x = await withExternal(() => ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85));
    if (x == null) return;
    if (!await Ai.enabled()) {
      setState(() => status = 'Do odczytu paragonu potrzebne jest rozpoznawanie AI (Ustawienia → Rozpoznawanie AI). Możesz dodać produkty ręcznie.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Odczytuję produkty…';
    });
    try {
      final bytes = await x.readAsBytes();
      final t = await Ai.complete(
        'To zdjęcie paragonu ze sklepu albo listy zakupów. Wypisz TYLKO produkty spożywcze i napoje, po jednym w linii, '
        'zwykłą polską nazwą (rozwiń skróty z paragonu, np. "SER GOU PLAST" → "ser gouda plastry", "JOG NAT" → "jogurt naturalny"), '
        'bez cen, ilości i kodów. Pomiń torby, środki czystości, kosmetyki i kaucje. Bez numeracji i bez komentarzy.',
        jpeg: bytes,
        maxTokens: 700,
      );
      final names = t
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'^[\s\-\*•\d\.\)]+'), '').replaceAll('"', '').trim())
          .where((l) => l.length >= 3 && l.length <= 60 && !l.endsWith(':'))
          .toSet()
          .toList();
      if (names.isEmpty) throw const AiError('Nie znalazłem produktów spożywczych na zdjęciu.');
      final idx = _index();
      final items = [for (final n in names) _fromName(n, idx)];
      if (!mounted) return;
      final chosen = await _review(items);
      if (chosen != null && chosen.isNotEmpty) {
        await app.addPantry(chosen);
        setState(() => status = 'Dodano do spiżarni: ${chosen.length}. Pojawią się w podpowiedziach składników.');
      } else {
        setState(() => status = null);
      }
    } on AiError catch (e) {
      setState(() => status = e.message);
    } catch (e) {
      setState(() => status = 'Nie udało się odczytać: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<List<PantryItem>?> _review(List<PantryItem> items) {
    final on = List<bool>.filled(items.length, true);
    return showModalBottomSheet<List<PantryItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SizedBox(
          height: MediaQuery.of(c).size.height * 0.75,
          child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Znalezione produkty (${items.length})', style: Theme.of(c).textTheme.titleMedium)),
            Expanded(
              child: ListView(children: [
                for (final (i, p) in items.indexed)
                  CheckboxListTile(
                    value: on[i],
                    onChanged: (v) => set(() => on[i] = v ?? false),
                    title: Text(p.display),
                    subtitle: Text(p.kcal > 0 ? '${p.kcal.round()} kcal/100 g · B ${p.protein.round()} W ${p.carbs.round()} T ${p.fat.round()}' : 'bez wartości – uzupełnisz przy posiłku'),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(c, [for (final (i, p) in items.indexed) if (on[i]) p]),
                child: const Text('Dodaj do spiżarni'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _addManual() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Produkt'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nazwa', hintText: 'np. skyr naturalny')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Dodaj')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) await app.addPantry([_fromName(c.text, _index())]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final all = [...app.pantry]..sort((a, b) => b.added.compareTo(a.added));
        final list = all.where((x) => showUsed || !x.used).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Spiżarnia'), actions: [
            IconButton(
              tooltip: showUsed ? 'Ukryj zużyte' : 'Pokaż zużyte',
              icon: Icon(showUsed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => showUsed = !showUsed),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: busy ? null : () => _scan(ImageSource.camera),
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.receipt_long_outlined),
            label: const Text('Paragon'),
          ),
          body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Zrób zdjęcie paragonu albo listy zakupów – produkty trafią do spiżarni z wartościami z bazy, a przy dodawaniu posiłku podpowiedzą się jako pierwsze.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 6, children: [
                OutlinedButton.icon(onPressed: busy ? null : () => _scan(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Z galerii')),
                OutlinedButton.icon(onPressed: _addManual, icon: const Icon(Icons.add, size: 18), label: const Text('Ręcznie')),
              ]),
            ),
            if (status != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(status!, style: TextStyle(color: cs.onSurfaceVariant))),
            const SizedBox(height: 8),
            if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Spiżarnia jest pusta.', style: TextStyle(color: cs.onSurfaceVariant))),
            for (final x in list)
              Dismissible(
                key: ValueKey(x.id),
                background: Container(color: cs.errorContainer, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_outline)),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => app.deletePantry(x.id),
                child: CheckboxListTile(
                  value: x.used,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) {
                    x.used = v ?? false;
                    app.savePantry(x);
                  },
                  title: Text(x.display, style: TextStyle(decoration: x.used ? TextDecoration.lineThrough : null)),
                  subtitle: Text(x.kcal > 0 ? '${x.kcal.round()} kcal/100 g' : 'bez wartości odżywczych'),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ======================= RAPORT PDF =======================

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int days = 30;
  bool mealList = true;
  bool busy = false;

  Future<void> _make() async {
    setState(() => busy = true);
    try {
      final to = todayIso();
      final f = await saveReport(ReportInput(
        person: app.active,
        meals: app.meals,
        gut: app.gut,
        meds: app.meds,
        drinks: app.drinks,
        weights: app.weights,
        gas: app.gasSeries,
        from: shiftDay(to, -(days - 1)),
        to: to,
        mealList: mealList,
      ));
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/pdf')], subject: 'Dziennik żywienia – ${app.active.name}'));
    } catch (e) {
      if (mounted) toast(context, 'Nie udało się przygotować raportu: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Raport PDF')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          'Raport dla lekarza albo dietetyka: dane osoby (${app.active.name}), kalorie i makro dzień po dniu, okno jedzenia, woda, trawienie, '
          'wiatry i sen (jeśli importujesz), objawy, składniki częściej przed złym samopoczuciem, leki i suplementy, waga.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 14, label: Text('14 dni')), ButtonSegment(value: 30, label: Text('30 dni')), ButtonSegment(value: 90, label: Text('90 dni'))],
          selected: {days},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => days = s.first),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: mealList,
          onChanged: (v) => setState(() => mealList = v),
          title: const Text('Pełna lista posiłków'),
          subtitle: const Text('Wyłącz, żeby raport był krótszy'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: busy ? null : _make,
          icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Utwórz i udostępnij'),
        ),
      ]),
    );
  }
}
