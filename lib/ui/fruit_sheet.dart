// Szybkie dodawanie surowych owoców: stuknięcie = +1 sztuka (porcja), bez zdjęcia i formularza.

import 'package:flutter/material.dart';

import '../calc.dart';
import '../fodmap.dart';
import '../food_table.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';

class QuickFruit {
  final String emoji, label, table; // table = nazwa w tabeli wartości odżywczych
  final double grams; // jedna sztuka / porcja
  final String unit;
  const QuickFruit(this.emoji, this.label, this.table, this.grams, [this.unit = 'szt.']);
}

const quickFruits = [
  QuickFruit('🍎', 'Jabłko', 'jabłko', 180),
  QuickFruit('🍐', 'Gruszka', 'gruszka', 170),
  QuickFruit('🍌', 'Banan', 'banan', 120),
  QuickFruit('🍊', 'Mandarynka', 'mandarynka', 70),
  QuickFruit('🍊', 'Pomarańcza', 'pomarańcza', 180),
  QuickFruit('🟣', 'Śliwka', 'śliwki', 30),
  QuickFruit('🥝', 'Kiwi', 'kiwi', 75),
  QuickFruit('🍑', 'Brzoskwinia', 'brzoskwinia', 150),
  QuickFruit('🍑', 'Nektarynka', 'nektarynka', 140),
  QuickFruit('🟠', 'Morela', 'morela', 40),
  QuickFruit('🍈', 'Grejpfrut', 'grejpfrut', 250),
  QuickFruit('🍇', 'Winogrona', 'winogrona', 100, 'garść'),
  QuickFruit('🍓', 'Truskawki', 'truskawki', 150, 'miseczka'),
  QuickFruit('🫐', 'Borówki', 'borówki', 100, 'garść'),
  QuickFruit('🍒', 'Czereśnie', 'czereśnie', 150, 'garść'),
  QuickFruit('🍒', 'Wiśnie', 'wiśnie', 150, 'garść'),
  QuickFruit('🍉', 'Arbuz', 'arbuz', 300, 'kawałek'),
  QuickFruit('🍈', 'Melon', 'melon', 200, 'kawałek'),
];

FoodRef? _ref(String name) {
  for (final r in foodTable()) {
    if (r.name == name) return r;
  }
  return null;
}

/// Pozycja posiłku dla [n] sztuk/porcji owocu (wartości z wbudowanej tabeli).
FoodItem fruitItem(QuickFruit f, double n) {
  final r = _ref(f.table);
  final g = f.grams * n;
  return r?.item(g) ?? FoodItem(name: f.table, grams: g);
}

Future<void> showFruitSheet(BuildContext context, String date) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FruitSheet(date: date),
    );

class _FruitSheet extends StatefulWidget {
  final String date;
  const _FruitSheet({required this.date});
  @override
  State<_FruitSheet> createState() => _FruitSheetState();
}

class _FruitSheetState extends State<_FruitSheet> {
  final count = <int, double>{};
  String type = 'Przekąska';
  late String time = hhmm(DateTime.now());
  bool busy = false;

  List<FoodItem> get items => [
        for (final e in count.entries)
          if (e.value > 0) fruitItem(quickFruits[e.key], e.value),
      ];

  String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

  Future<void> _save() async {
    final its = items;
    if (its.isEmpty) return;
    setState(() => busy = true);
    final names = [
      for (final e in count.entries)
        if (e.value > 0) e.value == 1 ? quickFruits[e.key].label : '${quickFruits[e.key].label} ×${_n(e.value)}',
    ];
    final m = Meal(
      id: newId('m'),
      person: app.active.id,
      date: widget.date,
      time: time,
      type: type,
      name: names.join(', '),
      items: its,
    );
    await app.saveMeal(m);
    if (!mounted) return;
    final nav = Navigator.of(context);
    final ctx = nav.context;
    nav.pop();
    final el = app.activeElimination;
    final hit = el == null ? const <String>{} : groupsOfMeal(m).intersection(el.forbiddenOn(m.date));
    toast(
        ctx,
        hit.isNotEmpty
            ? 'Dodano ${m.name}. Uwaga – dieta eliminacyjna: ${hit.map((g) => groupById(g)?.name.split(' (').first ?? g).join(', ')}.'
            : 'Dodano: ${m.name} (${its.fold<double>(0, (s, i) => s + i.kcal).round()} kcal)');
  }

  Future<void> _pickTime() async {
    final p = time.split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    if (t != null) setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final its = items;
    final kcal = its.fold<double>(0, (s, i) => s + i.kcal);
    final grams = its.fold<double>(0, (s, i) => s + i.grams);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Szybko: owoce', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('Stuknij owoc, aby dodać sztukę (porcję). Przytrzymaj, aby dodać pół.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < quickFruits.length; i++) _tile(i, cs),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            DropdownButton<String>(
              value: type,
              underline: const SizedBox(),
              items: [for (final t in mealTypes) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => type = v ?? type),
            ),
            const SizedBox(width: 8),
            TextButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule, size: 18), label: Text(time)),
            const Spacer(),
            if (its.isNotEmpty)
              Text('${grams.round()} g · ${kcal.round()} kcal', style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: its.isEmpty || busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(its.isEmpty ? 'Wybierz owoce' : 'Dodaj do dziennika'),
          ),
        ]),
      ),
    );
  }

  Widget _tile(int i, ColorScheme cs) {
    final f = quickFruits[i];
    final n = count[i] ?? 0;
    final on = n > 0;
    return Material(
      color: on ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => count[i] = n + 1),
        onLongPress: () => setState(() => count[i] = n + 0.5),
        child: SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(children: [
              Text(f.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(on ? '${_n(n)} ${f.unit}' : '${f.grams.round()} g',
                      style: TextStyle(fontSize: 11, color: on ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                ]),
              ),
              if (on)
                InkWell(
                  onTap: () => setState(() {
                    final v = n >= 1 ? n - 1 : 0.0;
                    if (v <= 0) {
                      count.remove(i);
                    } else {
                      count[i] = v;
                    }
                  }),
                  child: Icon(Icons.remove_circle_outline, size: 20, color: cs.onPrimaryContainer),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
