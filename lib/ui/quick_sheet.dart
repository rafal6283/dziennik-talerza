// Szybkie dodawanie bez zdjęcia i formularza: owoce, ciasta, kanapki, wędliny.
// Stuknięcie = +1 sztuka/porcja, przytrzymanie = +½. Wartości z wbudowanej tabeli (food_table.dart).

import 'package:flutter/material.dart';

import '../calc.dart';
import '../fodmap.dart';
import '../food_table.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';

class QuickItem {
  final String emoji, label, table; // table = nazwa w tabeli wartości odżywczych
  final double grams; // jedna sztuka / porcja (w kanapce: na jedną kromkę / połówkę bułki)
  final String unit;
  const QuickItem(this.emoji, this.label, this.table, this.grams, [this.unit = 'szt.']);
}

const quickFruits = [
  QuickItem('🍎', 'Jabłko', 'jabłko', 180),
  QuickItem('🍐', 'Gruszka', 'gruszka', 170),
  QuickItem('🍌', 'Banan', 'banan', 120),
  QuickItem('🍊', 'Mandarynka', 'mandarynka', 70),
  QuickItem('🍊', 'Pomarańcza', 'pomarańcza', 180),
  QuickItem('🟣', 'Śliwka', 'śliwki', 30),
  QuickItem('🥝', 'Kiwi', 'kiwi', 75),
  QuickItem('🍑', 'Brzoskwinia', 'brzoskwinia', 150),
  QuickItem('🍑', 'Nektarynka', 'nektarynka', 140),
  QuickItem('🟠', 'Morela', 'morela', 40),
  QuickItem('🍈', 'Grejpfrut', 'grejpfrut', 250),
  QuickItem('🍇', 'Winogrona', 'winogrona', 100, 'garść'),
  QuickItem('🍓', 'Truskawki', 'truskawki', 150, 'miseczka'),
  QuickItem('🫐', 'Borówki', 'borówki', 100, 'garść'),
  QuickItem('🍒', 'Czereśnie', 'czereśnie', 150, 'garść'),
  QuickItem('🍒', 'Wiśnie', 'wiśnie', 150, 'garść'),
  QuickItem('🍉', 'Arbuz', 'arbuz', 300, 'kawałek'),
  QuickItem('🍈', 'Melon', 'melon', 200, 'kawałek'),
];

// kawałek deserowy
const quickCakes = [
  QuickItem('🍰', 'Sernik', 'sernik', 100, 'kawałek'),
  QuickItem('🥧', 'Szarlotka', 'szarlotka', 100, 'kawałek'),
  QuickItem('🍫', 'Murzynek', 'murzynek', 80, 'kawałek'),
  QuickItem('🍞', 'Drożdżowe', 'ciasto drożdżowe', 80, 'kawałek'),
  QuickItem('🍑', 'Z owocami', 'ciasto z owocami', 100, 'kawałek'),
  QuickItem('🍮', 'Z kremem', 'ciasto z kremem', 100, 'kawałek'),
  QuickItem('🎂', 'Tort', 'tort', 120, 'kawałek'),
  QuickItem('🍮', 'Kremówka', 'kremówka', 120, 'kawałek'),
  QuickItem('🌀', 'Makowiec', 'makowiec', 70, 'kawałek'),
  QuickItem('🧁', 'Babka', 'babka', 60, 'kawałek'),
  QuickItem('🍞', 'Keks', 'keks', 60, 'kawałek'),
  QuickItem('🌀', 'Rolada', 'rolada biszkoptowa', 60, 'kawałek'),
  QuickItem('🟫', 'Brownie', 'brownie', 60, 'kawałek'),
  QuickItem('🍪', 'Piernik', 'pierniki', 50, 'kawałek'),
  QuickItem('🧁', 'Muffinka', 'muffinka', 80),
  QuickItem('🍩', 'Pączek', 'pączek', 75),
  QuickItem('🥐', 'Drożdżówka', 'drożdżówka', 100),
  QuickItem('🍪', 'Ciastko', 'herbatniki', 10),
];

const quickMeats = [
  QuickItem('🌭', 'Kiełbasa', 'kiełbasa', 50, 'kawałek'),
  QuickItem('🌭', 'Kiełbasa śląska', 'kiełbasa śląska', 50, 'kawałek'),
  QuickItem('⚫', 'Kaszanka', 'kaszanka', 100, 'kawałek'),
  QuickItem('🌭', 'Biała kiełbasa', 'kiełbasa biała', 120),
  QuickItem('🔥', 'Kiełbaska z grilla', 'kiełbaski z grilla', 100),
  QuickItem('🌭', 'Parówka', 'parówki', 40),
  QuickItem('🥢', 'Kabanos', 'kabanos', 25),
  QuickItem('🥓', 'Szynka', 'szynka', 15, 'plaster'),
  QuickItem('🥩', 'Polędwica', 'polędwica sopocka', 15, 'plaster'),
  QuickItem('🦃', 'Szynka z indyka', 'szynka z indyka', 15, 'plaster'),
  QuickItem('🔴', 'Krakowska', 'kiełbasa krakowska', 15, 'plaster'),
  QuickItem('🍕', 'Salami', 'salami', 10, 'plaster'),
  QuickItem('🥓', 'Boczek', 'boczek', 20, 'plaster'),
  QuickItem('🩷', 'Mortadela', 'mortadela', 15, 'plaster'),
  QuickItem('🟤', 'Salceson', 'salceson', 20, 'plaster'),
  QuickItem('🟫', 'Pasztet', 'pasztet', 30, 'porcja'),
  QuickItem('🟫', 'Pasztetowa', 'pasztetowa', 30, 'porcja'),
];

class SandBase {
  final String label, short, table;
  final double grams; // całe pieczywo jednej kanapki
  final int sides; // ile powierzchni do posmarowania i obłożenia (kromki / połówki bułki)
  const SandBase(this.label, this.short, this.table, this.grams, this.sides);
}

const sandBases = [
  SandBase('1 kromka pszenna', 'kromka pszenna', 'chleb pszenny', 30, 1),
  SandBase('1 kromka żytnia', 'kromka żytnia', 'chleb żytni', 35, 1),
  SandBase('1 kromka mieszana', 'kromka mieszana', 'chleb mieszany', 35, 1),
  SandBase('2 kromki pszenne', '2 kromki pszenne', 'chleb pszenny', 60, 2),
  SandBase('2 kromki żytnie', '2 kromki żytnie', 'chleb żytni', 70, 2),
  SandBase('2 kromki mieszane', '2 kromki mieszane', 'chleb mieszany', 70, 2),
  SandBase('Kajzerka', 'kajzerka', 'bułka pszenna', 50, 2),
  SandBase('Grahamka', 'grahamka', 'bułka grahamka', 60, 2),
];

// dodatki na jedną kromkę / połówkę bułki
const sandToppings = [
  QuickItem('🧈', 'Samo masło', '', 0),
  QuickItem('🥓', 'Szynka', 'szynka', 20),
  QuickItem('🥩', 'Polędwica', 'polędwica sopocka', 20),
  QuickItem('🦃', 'Szynka z indyka', 'szynka z indyka', 20),
  QuickItem('🔴', 'Krakowska', 'kiełbasa krakowska', 20),
  QuickItem('🍕', 'Salami', 'salami', 10),
  QuickItem('🩷', 'Mortadela', 'mortadela', 20),
  QuickItem('🧀', 'Ser żółty', 'ser żółty', 20),
  QuickItem('⚪', 'Twaróg', 'twaróg półtłusty', 40),
  QuickItem('🥛', 'Serek', 'serek śmietankowy', 20),
  QuickItem('🟫', 'Pasztet', 'pasztet', 25),
  QuickItem('🥚', 'Jajko', 'jajko', 30),
  QuickItem('🐷', 'Smalec', 'smalec', 10),
  QuickItem('🥜', 'Masło orzech.', 'masło orzechowe', 15),
  QuickItem('🍓', 'Dżem', 'dżem', 15),
];

const _sandVeg = [('pomidor', 'Pomidor', 30.0), ('ogórek', 'Ogórek', 20.0), ('sałata', 'Sałata', 8.0)];

class QuickCategory {
  final String label;
  final List<QuickItem> items;
  final bool snack; // domyślnie „Przekąska”
  const QuickCategory(this.label, this.items, {this.snack = false});
}

const quickCategories = [
  QuickCategory('Owoce', quickFruits, snack: true),
  QuickCategory('Ciasta', quickCakes, snack: true),
  QuickCategory('Wędliny', quickMeats),
];

FoodRef? quickRef(String name) {
  for (final r in foodTable()) {
    if (r.name == name) return r;
  }
  return null;
}

FoodItem _item(String table, double grams) => quickRef(table)?.item(grams) ?? FoodItem(name: table, grams: grams);

/// Pozycja posiłku dla [n] sztuk/porcji (wartości z wbudowanej tabeli).
FoodItem quickItem(QuickItem f, double n) => _item(f.table, f.grams * n);

/// Składniki [n] kanapek.
List<FoodItem> sandwichItems(SandBase b, bool butter, Set<String> veg, QuickItem topping, double n) => [
      _item(b.table, b.grams * n),
      if (butter) _item('masło', 5.0 * b.sides * n),
      if (topping.table.isNotEmpty) _item(topping.table, topping.grams * b.sides * n),
      for (final v in _sandVeg)
        if (veg.contains(v.$1)) _item(v.$1, v.$3 * b.sides * n),
    ];

/// Sumuje pozycje o tej samej nazwie (np. masło z kilku kanapek).
List<FoodItem> mergeItems(Iterable<FoodItem> xs) {
  final out = <String, FoodItem>{};
  double? add(double? a, double? b) => a == null && b == null ? null : (a ?? 0) + (b ?? 0);
  for (final x in xs) {
    final o = out[x.name];
    if (o == null) {
      out[x.name] = FoodItem(
          name: x.name, grams: x.grams, kcal: x.kcal, protein: x.protein, carbs: x.carbs, fat: x.fat, fiber: x.fiber, sugar: x.sugar, salt: x.salt);
    } else {
      o
        ..grams += x.grams
        ..kcal += x.kcal
        ..protein += x.protein
        ..carbs += x.carbs
        ..fat += x.fat
        ..fiber = add(o.fiber, x.fiber)
        ..sugar = add(o.sugar, x.sugar)
        ..salt = add(o.salt, x.salt);
    }
  }
  return out.values.toList();
}

Future<void> showQuickSheet(BuildContext context, String date) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickSheet(date: date),
    );

class _Sand {
  final int base, topping;
  final bool butter;
  final Set<String> veg;
  double n = 0;
  _Sand(this.base, this.butter, this.veg, this.topping);
  String get key => '$base|$butter|${(veg.toList()..sort()).join(',')}|$topping';
  SandBase get b => sandBases[base];
  QuickItem get t => sandToppings[topping];
  List<FoodItem> get items => sandwichItems(b, butter, veg, t, n);
  String get label {
    final what = topping == 0 ? (butter ? 'z masłem' : '') : 'z ${_instr[t.label] ?? t.label.toLowerCase()}';
    return 'Kanapka${what.isEmpty ? '' : ' $what'} (${b.short})';
  }
}

const _instr = {
  'Szynka': 'szynką',
  'Polędwica': 'polędwicą',
  'Szynka z indyka': 'szynką z indyka',
  'Krakowska': 'krakowską',
  'Salami': 'salami',
  'Mortadela': 'mortadelą',
  'Ser żółty': 'serem żółtym',
  'Twaróg': 'twarogiem',
  'Serek': 'serkiem',
  'Pasztet': 'pasztetem',
  'Jajko': 'jajkiem',
  'Smalec': 'smalcem',
  'Masło orzech.': 'masłem orzechowym',
  'Dżem': 'dżemem',
};

class _QuickSheet extends StatefulWidget {
  final String date;
  const _QuickSheet({required this.date});
  @override
  State<_QuickSheet> createState() => _QuickSheetState();
}

class _QuickSheetState extends State<_QuickSheet> {
  final count = <String, double>{}; // 'kategoria:indeks' → liczba
  final sands = <String, _Sand>{};
  int base = 0;
  bool butter = true;
  final veg = <String>{};
  String? userType;
  late String time = hhmm(DateTime.now());
  bool busy = false;

  static String _guessType(int h) => h < 10
      ? 'Śniadanie'
      : h < 12
          ? 'Drugie śniadanie'
          : h < 16
              ? 'Obiad'
              : h < 18
                  ? 'Podwieczorek'
                  : h < 22
                      ? 'Kolacja'
                      : 'Przekąska';

  String get type {
    if (userType != null) return userType!;
    final onlySnacks = sands.values.every((s) => s.n <= 0) &&
        count.entries.where((e) => e.value > 0).every((e) => quickCategories[int.parse(e.key.split(':')[0])].snack);
    return onlySnacks ? 'Przekąska' : _guessType(int.parse(time.split(':')[0]));
  }

  QuickItem _q(String key) {
    final p = key.split(':');
    return quickCategories[int.parse(p[0])].items[int.parse(p[1])];
  }

  List<(String, double, List<FoodItem>)> get chosen => [
        for (final e in count.entries)
          if (e.value > 0) (_q(e.key).label, e.value, [quickItem(_q(e.key), e.value)]),
        for (final s in sands.values)
          if (s.n > 0) (s.label, s.n, s.items),
      ];

  static String n2(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

  Future<void> _save() async {
    final ch = chosen;
    if (ch.isEmpty) return;
    setState(() => busy = true);
    final its = mergeItems([for (final c in ch) ...c.$3]);
    final m = Meal(
      id: newId('m'),
      person: app.active.id,
      date: widget.date,
      time: time,
      type: type,
      name: [for (final c in ch) c.$2 == 1 ? c.$1 : '${c.$1} ×${n2(c.$2)}'].join(', '),
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
            ? 'Dodano. Uwaga – dieta eliminacyjna: ${hit.map((g) => groupById(g)?.name.split(' (').first ?? g).join(', ')}.'
            : 'Dodano: ${m.name} (${its.fold<double>(0, (s, i) => s + i.kcal).round()} kcal)');
  }

  Future<void> _pickTime() async {
    final p = time.split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    if (t != null) setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  void _dec(double n, void Function(double) set) {
    final v = n >= 1 ? n - 1 : 0.0;
    set(v < 0 ? 0 : v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ch = chosen;
    final its = [for (final c in ch) ...c.$3];
    final kcal = its.fold<double>(0, (s, i) => s + i.kcal);
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const TabBar(tabs: [Tab(text: 'Owoce'), Tab(text: 'Ciasta'), Tab(text: 'Kanapki'), Tab(text: 'Wędliny')]),
            Expanded(
              child: TabBarView(children: [
                _grid(0, cs),
                _grid(1, cs),
                _sandwiches(cs),
                _grid(2, cs),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (ch.isNotEmpty)
                  Text([for (final c in ch) c.$2 == 1 ? c.$1 : '${c.$1} ×${n2(c.$2)}'].join(', '),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Row(children: [
                  DropdownButton<String>(
                    value: type,
                    underline: const SizedBox(),
                    items: [for (final t in mealTypes) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => userType = v),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule, size: 18), label: Text(time)),
                  const Spacer(),
                  if (ch.isNotEmpty) Text('${kcal.round()} kcal', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ]),
                FilledButton.icon(
                  onPressed: ch.isEmpty || busy ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(ch.isEmpty ? 'Stuknij, aby dodać (przytrzymaj: ½)' : 'Dodaj do dziennika'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _grid(int cat, ColorScheme cs) {
    final items = quickCategories[cat].items;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < items.length; i++)
          () {
            final key = '$cat:$i';
            final n = count[key] ?? 0;
            final f = items[i];
            return _tile(f.emoji, f.label, n > 0 ? '${n2(n)} ${f.unit}' : '${f.grams.round()} g', n,
                (d) => setState(() => count[key] = n + d), () => _dec(n, (v) => setState(() => v <= 0 ? count.remove(key) : (count[key] = v))), cs);
          }(),
      ]),
    );
  }

  Widget _sandwiches(ColorScheme cs) {
    final b = sandBases[base];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 0, children: [
          for (var i = 0; i < sandBases.length; i++)
            ChoiceChip(
              label: Text(sandBases[i].label),
              selected: base == i,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => base = i),
            ),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: [
          FilterChip(label: const Text('Masło'), selected: butter, visualDensity: VisualDensity.compact, onSelected: (v) => setState(() => butter = v)),
          for (final v in _sandVeg)
            FilterChip(
              label: Text(v.$2),
              selected: veg.contains(v.$1),
              visualDensity: VisualDensity.compact,
              onSelected: (on) => setState(() => on ? veg.add(v.$1) : veg.remove(v.$1)),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < sandToppings.length; i++)
            if (i != 0 || butter)
              () {
                final probe = _Sand(base, butter, {...veg}, i);
                final s = sands[probe.key];
                final n = s?.n ?? 0;
                final kcal = sandwichItems(b, butter, veg, sandToppings[i], 1).fold<double>(0, (a, x) => a + x.kcal);
                return _tile(sandToppings[i].emoji, sandToppings[i].label, n > 0 ? '${n2(n)} szt.' : '${kcal.round()} kcal', n, (d) {
                  setState(() => (sands[probe.key] ??= probe).n = n + d);
                }, () => _dec(n, (v) => setState(() => v <= 0 ? sands.remove(probe.key) : (sands[probe.key]!.n = v))), cs);
              }(),
        ]),
      ]),
    );
  }

  Widget _tile(String emoji, String label, String sub, double n, void Function(double) add, VoidCallback dec, ColorScheme cs) {
    final on = n > 0;
    return Material(
      color: on ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => add(1),
        onLongPress: () => add(0.5),
        child: SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(sub, style: TextStyle(fontSize: 11, color: on ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                ]),
              ),
              if (on) InkWell(onTap: dec, child: Icon(Icons.remove_circle_outline, size: 20, color: cs.onPrimaryContainer)),
            ]),
          ),
        ),
      ),
    );
  }
}
