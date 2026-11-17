// Dodatkowe dzienniki: ulubione posiłki, własne przepisy, napoje, waga, leki i suplementy, spiżarnia.
// Wszystko w tym samym pliku danych co posiłki (klucze JSON poniżej), z kopią na Koofr.

import 'calc.dart';
import 'models.dart';

int _i(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';
List<FoodItem> _items(dynamic v) =>
    [for (final e in (v is List ? v : const [])) if (e is Map) FoodItem.fromJson(Map<String, dynamic>.from(e))];

/// Ulubiony posiłek – zestaw składników dodawany jednym stuknięciem.
class Favorite {
  String id, person, name, type;
  List<FoodItem> items;
  int uses, lastUsed;
  Favorite({required this.id, required this.person, required this.name, this.type = '', List<FoodItem>? items, this.uses = 0, this.lastUsed = 0})
      : items = items ?? [];
  factory Favorite.fromJson(Map<String, dynamic> j) => Favorite(
        id: _s(j['id']).isEmpty ? newId('fav') : _s(j['id']),
        person: _s(j['person']).isEmpty ? 'me' : _s(j['person']),
        name: _s(j['name']),
        type: _s(j['type']),
        items: _items(j['items']),
        uses: _i(j['uses']),
        lastUsed: _i(j['lastUsed']),
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'person': person, 'name': name, 'type': type, 'items': items.map((i) => i.toJson()).toList(), 'uses': uses, 'lastUsed': lastUsed};
  Macros get total => Macros.ofItems(items);
}

/// Własny przepis: składniki całego garnka + waga gotowego dania. Zjedzoną porcję liczy się z wagi.
class Recipe {
  String id, name, note;
  List<FoodItem> items;
  double cookedGrams; // waga gotowego dania (0 = suma składników)
  int portions;
  Recipe({required this.id, required this.name, this.note = '', List<FoodItem>? items, this.cookedGrams = 0, this.portions = 1}) : items = items ?? [];
  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: _s(j['id']).isEmpty ? newId('rec') : _s(j['id']),
        name: _s(j['name']),
        note: _s(j['note']),
        items: _items(j['items']),
        cookedGrams: _d(j['cookedGrams']),
        portions: _i(j['portions']) < 1 ? 1 : _i(j['portions']),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        'items': items.map((i) => i.toJson()).toList(),
        'cookedGrams': cookedGrams,
        'portions': portions,
      };
  double get rawGrams => items.fold(0.0, (a, i) => a + i.grams);
  double get weight => cookedGrams > 0 ? cookedGrams : rawGrams;
  Macros get total => Macros.ofItems(items);
  Micro get micro => Micro.ofItems(items);
  double get portion => weight > 0 ? weight / portions : 0;

  /// Zjedzona ilość jako jeden składnik posiłku (domyślnie jedna porcja).
  FoodItem portionItem([double? grams]) {
    final g = grams ?? portion;
    final w = weight;
    final k = w > 0 ? g / w : 0.0;
    final t = total, m = micro, known = m.coverage > 0;
    return FoodItem(
      name: name,
      grams: g,
      kcal: t.kcal * k,
      protein: t.p * k,
      carbs: t.c * k,
      fat: t.f * k,
      fiber: known ? m.fiber * k : null,
      sugar: known ? m.sugar * k : null,
      salt: known ? m.salt * k : null,
    );
  }

  /// Wartości na 100 g gotowego dania.
  Macros get per100 {
    final w = weight;
    if (w <= 0) return Macros.zero;
    final t = total;
    return Macros(t.kcal * 100 / w, t.p * 100 / w, t.c * 100 / w, t.f * 100 / w);
  }
}

/// Napój poza posiłkami: woda (ml), kawa, herbata.
class Drink {
  String id, person, date, time, kind; // kind: id z [drinkKinds]
  int ml;
  double? kcal100; // własna wartość kcal/100 ml (null = domyślna dla rodzaju)
  String name; // opcjonalna nazwa, np. „Żywiec”, „sok jabłkowy”
  Drink({required this.id, required this.person, required this.date, required this.time, this.kind = 'woda', this.ml = 250, this.kcal100, this.name = ''});

  DrinkKind get kindInfo => drinkKind(kind);
  String get label => name.isNotEmpty ? name : kindInfo.label;
  double get _k => ml / 100.0;
  double get kcal => (kcal100 ?? kindInfo.kcal) * _k;

  /// Wartości odżywcze napoju; makro skalowane, gdy kcal zmienione ręcznie.
  Macros get macros {
    final k = kindInfo;
    final r = kcal100 != null && k.kcal > 0 ? kcal100! / k.kcal : 1.0;
    return Macros(kcal, k.protein * _k * r, k.carbs * _k * r, k.fat * _k * r);
  }

  double get sugar => kindInfo.sugar * _k * (kcal100 != null && kindInfo.kcal > 0 ? kcal100! / kindInfo.kcal : 1.0);

  /// Gramy czystego alkoholu.
  double get alcohol => kindInfo.alcohol * _k;

  factory Drink.fromJson(Map<String, dynamic> j) => Drink(
        id: _s(j['id']).isEmpty ? newId('d') : _s(j['id']),
        person: _s(j['person']).isEmpty ? 'me' : _s(j['person']),
        date: _s(j['date']),
        time: _s(j['time']).isEmpty ? '12:00' : _s(j['time']),
        kind: _s(j['kind']).isEmpty ? 'woda' : _s(j['kind']),
        ml: _i(j['ml']),
        kcal100: j['kcal100'] == null ? null : _d(j['kcal100']),
        name: _s(j['name']),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'person': person,
        'date': date,
        'time': time,
        'kind': kind,
        'ml': ml,
        if (kcal100 != null) 'kcal100': kcal100,
        if (name.isNotEmpty) 'name': name,
      };
  int get ts => DateTime.tryParse('${date}T$time:00')?.millisecondsSinceEpoch ?? 0;
}

class WeightEntry {
  String id, person, date;
  double kg;
  WeightEntry({required this.id, required this.person, required this.date, required this.kg});
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        id: _s(j['id']).isEmpty ? newId('w') : _s(j['id']),
        person: _s(j['person']).isEmpty ? 'me' : _s(j['person']),
        date: _s(j['date']),
        kg: _d(j['kg']),
      );
  Map<String, dynamic> toJson() => {'id': id, 'person': person, 'date': date, 'kg': kg};
}

/// Lek albo suplement – osobno od jedzenia, żeby nie mylił się przy szukaniu przyczyn objawów.
class MedEntry {
  String id, person, date, time, name, dose, kind; // kind: lek | suplement
  MedEntry({required this.id, required this.person, required this.date, required this.time, required this.name, this.dose = '', this.kind = 'suplement'});
  factory MedEntry.fromJson(Map<String, dynamic> j) => MedEntry(
        id: _s(j['id']).isEmpty ? newId('med') : _s(j['id']),
        person: _s(j['person']).isEmpty ? 'me' : _s(j['person']),
        date: _s(j['date']),
        time: _s(j['time']).isEmpty ? '08:00' : _s(j['time']),
        name: _s(j['name']),
        dose: _s(j['dose']),
        kind: _s(j['kind']).isEmpty ? 'suplement' : _s(j['kind']),
      );
  Map<String, dynamic> toJson() => {'id': id, 'person': person, 'date': date, 'time': time, 'name': name, 'dose': dose, 'kind': kind};
  int get ts => DateTime.tryParse('${date}T$time:00')?.millisecondsSinceEpoch ?? 0;
}

/// Produkt w spiżarni (z paragonu, listy zakupów albo dodany ręcznie) – wspólny dla domu.
class PantryItem {
  String id, name, brand;
  double kcal, protein, carbs, fat; // na 100 g (0 = nieznane)
  double? fiber, sugar, salt;
  double portion;
  int added;
  bool used; // zużyty / wyrzucony
  PantryItem({
    required this.id,
    required this.name,
    this.brand = '',
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber,
    this.sugar,
    this.salt,
    this.portion = 100,
    int? added,
    this.used = false,
  }) : added = added ?? DateTime.now().millisecondsSinceEpoch;
  factory PantryItem.fromJson(Map<String, dynamic> j) => PantryItem(
        id: _s(j['id']).isEmpty ? newId('pan') : _s(j['id']),
        name: _s(j['name']),
        brand: _s(j['brand']),
        kcal: _d(j['kcal']),
        protein: _d(j['protein']),
        carbs: _d(j['carbs']),
        fat: _d(j['fat']),
        fiber: j['fiber'] is num ? (j['fiber'] as num).toDouble() : null,
        sugar: j['sugar'] is num ? (j['sugar'] as num).toDouble() : null,
        salt: j['salt'] is num ? (j['salt'] as num).toDouble() : null,
        portion: _d(j['portion']) > 0 ? _d(j['portion']) : 100,
        added: _i(j['added']) == 0 ? null : _i(j['added']),
        used: j['used'] == true,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        if (fiber != null) 'fiber': fiber,
        if (sugar != null) 'sugar': sugar,
        if (salt != null) 'salt': salt,
        'portion': portion,
        'added': added,
        'used': used,
      };
  String get display => brand.isEmpty ? name : '$name ($brand)';
}

// ---------- obliczenia ----------

/// Rodzaj napoju: wartości na 100 ml (orientacyjne, z tabel), domyślna porcja.
class DrinkKind {
  final String id, label;
  final int ml; // typowa porcja
  final double kcal, protein, carbs, fat, sugar, alcohol; // na 100 ml; alkohol w gramach
  final bool hydrating; // liczy się do wody
  const DrinkKind(this.id, this.label, this.ml, {this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0, this.sugar = 0, this.alcohol = 0, this.hydrating = false});
  bool get isAlcohol => alcohol > 0;
}

const drinkKinds = [
  DrinkKind('woda', 'Woda', 250, hydrating: true),
  DrinkKind('kawa', 'Kawa czarna', 150, kcal: 2, protein: 0.1),
  DrinkKind('kawa_mleko', 'Kawa z mlekiem', 250, kcal: 30, protein: 1.6, carbs: 2.4, fat: 1.5, sugar: 2.4),
  DrinkKind('herbata', 'Herbata', 250, kcal: 1),
  DrinkKind('ziolowa', 'Napar ziołowy', 250, kcal: 1),
  DrinkKind('mleko', 'Mleko 2%', 250, kcal: 50, protein: 3.4, carbs: 4.8, fat: 2, sugar: 4.8),
  DrinkKind('kefir', 'Kefir / maślanka', 250, kcal: 45, protein: 3.4, carbs: 4.5, fat: 1.5, sugar: 4.5),
  DrinkKind('sok', 'Sok owocowy', 250, kcal: 45, protein: 0.4, carbs: 10.5, sugar: 10),
  DrinkKind('slodzony', 'Napój słodzony', 330, kcal: 42, carbs: 10.6, sugar: 10.6),
  DrinkKind('zero', 'Napój zero', 330, kcal: 0.3),
  DrinkKind('izotonik', 'Izotonik', 500, kcal: 25, carbs: 6, sugar: 6),
  DrinkKind('piwo', 'Piwo', 500, kcal: 43, protein: 0.5, carbs: 3.6, alcohol: 3.9),
  DrinkKind('piwo0', 'Piwo bezalkoholowe', 500, kcal: 22, protein: 0.3, carbs: 5, sugar: 2.5),
  DrinkKind('wino', 'Wino wytrawne', 150, kcal: 83, carbs: 2.6, sugar: 0.6, alcohol: 10.5),
  DrinkKind('wino_slodkie', 'Wino słodkie', 150, kcal: 110, carbs: 10, sugar: 9, alcohol: 9.5),
  DrinkKind('cydr', 'Cydr', 330, kcal: 49, carbs: 5, sugar: 4.5, alcohol: 4),
  DrinkKind('mocny', 'Wódka / mocny alkohol', 40, kcal: 231, alcohol: 33),
  DrinkKind('drink', 'Drink / koktajl', 200, kcal: 120, carbs: 12, sugar: 11, alcohol: 8),
  DrinkKind('inne', 'Inny napój', 250),
];

DrinkKind drinkKind(String id) => drinkKinds.firstWhere((k) => k.id == id, orElse: () => drinkKinds.last);
const waterGoalMlPerKg = 30; // orientacyjnie 30 ml na kg masy ciała

int waterGoalMl(Person p) => p.weight > 0 ? ((p.weight * waterGoalMlPerKg) / 250).round() * 250 : 2000;

/// Płyny dnia: woda i napoje z dziennika napojów (ml) oraz liczba kaw (z napojów i z posiłków).
({int waterMl, int allMl, int coffees, double kcal, double alcoholG, double sugar}) drinksOn(String date, Iterable<Drink> drinks, Iterable<Meal> meals) {
  var water = 0, all = 0, coffees = 0;
  var kcal = 0.0, alc = 0.0, sugar = 0.0;
  for (final d in drinks.where((d) => d.date == date)) {
    all += d.ml;
    if (d.kindInfo.hydrating) water += d.ml;
    if (d.kind.startsWith('kawa')) coffees++;
    kcal += d.kcal;
    alc += d.alcohol;
    sugar += d.sugar;
  }
  final coffeeRe = RegExp(r'\b(kaw|cappuccino|latte|espresso|americano|flat white)', caseSensitive: false);
  for (final m in meals.where((m) => m.date == date)) {
    for (final i in m.items) {
      if (coffeeRe.hasMatch(i.name)) coffees++;
    }
  }
  return (waterMl: water, allMl: all, coffees: coffees, kcal: kcal, alcoholG: alc, sugar: sugar);
}

/// Kalorie i makro napojów danego dnia (doliczane do bilansu dnia).
Macros drinkMacros(String date, Iterable<Drink> drinks) =>
    drinks.where((d) => d.date == date).fold(Macros.zero, (a, d) => a + d.macros);

/// Bilans dnia: posiłki + napoje.
Macros dayTotalAll(Iterable<Meal> meals, Iterable<Drink> drinks, String date) => dayTotal(meals, date) + drinkMacros(date, drinks);

/// Waga: średnia krocząca z 7 dni (mniej skacze niż pojedyncze pomiary) i zmiana tygodniowa.
class WeightTrend {
  final List<(String, double)> points; // data, kg (posortowane)
  WeightTrend(Iterable<WeightEntry> entries)
      : points = ([for (final e in entries) if (e.kg > 0) (e.date, e.kg)]..sort((a, b) => a.$1.compareTo(b.$1)));

  double? get last => points.isEmpty ? null : points.last.$2;

  /// Średnia z pomiarów w 7 dniach kończących się [date].
  double? avgAt(String date) {
    final from = shiftDay(date, -6);
    final xs = [for (final p in points) if (p.$1.compareTo(from) >= 0 && p.$1.compareTo(date) <= 0) p.$2];
    return xs.isEmpty ? null : avg(xs);
  }

  /// Zmiana kg na tydzień z ostatnich [days] dni (regresja liniowa), null przy < 3 pomiarach.
  double? weeklyChange({int days = 28, String? until}) {
    final end = until ?? todayIso();
    final from = shiftDay(end, -days);
    final xs = [for (final p in points) if (p.$1.compareTo(from) >= 0 && p.$1.compareTo(end) <= 0) p];
    if (xs.length < 3) return null;
    final t0 = DateTime.parse('${xs.first.$1}T12:00:00');
    final x = [for (final p in xs) DateTime.parse('${p.$1}T12:00:00').difference(t0).inHours / 24.0];
    final y = [for (final p in xs) p.$2];
    final mx = avg(x), my = avg(y);
    var num = 0.0, den = 0.0;
    for (var i = 0; i < x.length; i++) {
      num += (x[i] - mx) * (y[i] - my);
      den += (x[i] - mx) * (x[i] - mx);
    }
    if (den == 0) return null;
    return num / den * 7;
  }
}

/// Okno żywieniowe dnia: pierwszy i ostatni posiłek (minuty od północy).
({int first, int last})? eatingWindow(Iterable<Meal> meals, String date) {
  final ms = meals.where((m) => m.date == date && m.total.kcal > 20).toList();
  if (ms.isEmpty) return null;
  int mins(Meal m) {
    final p = m.time.split(':');
    return (int.tryParse(p[0]) ?? 12) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  final xs = ms.map(mins).toList()..sort();
  return (first: xs.first, last: xs.last);
}

String hm(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Porównanie: późna kolacja (ostatni posiłek od [lateFrom]) a następny poranek / noc.
class LateDinnerResult {
  final int lateDays, earlyDays;
  final double? lateGut, earlyGut; // średni komfort następnego dnia (1–5)
  final double? lateSleepH, earlySleepH; // średnia długość snu w nocy po
  final double? lateFF, earlyFF; // średnio FF w nocy po
  const LateDinnerResult(this.lateDays, this.earlyDays, this.lateGut, this.earlyGut, this.lateSleepH, this.earlySleepH, this.lateFF, this.earlyFF);
}

LateDinnerResult lateDinner({
  required List<Meal> meals,
  required List<GutEntry> gut,
  required Map<String, double> sleepHours, // data wieczoru → godziny snu
  required int? Function(String date) nightFF,
  int lateFrom = 20 * 60 + 30,
}) {
  final days = {for (final m in meals) m.date};
  final lG = <int>[], eG = <int>[], lS = <double>[], eS = <double>[], lF = <int>[], eF = <int>[];
  var late = 0, early = 0;
  for (final d in days) {
    final w = eatingWindow(meals, d);
    if (w == null) continue;
    final isLate = w.last >= lateFrom;
    if (isLate) {
      late++;
    } else {
      early++;
    }
    final next = shiftDay(d, 1);
    final g = gut.where((x) => x.date == next && (x.when == 'rano' || x.when == 'w nocy')).map((x) => x.comfort).where((c) => c > 0);
    if (g.isNotEmpty) (isLate ? lG : eG).add(g.reduce((a, b) => a < b ? a : b));
    final s = sleepHours[d];
    if (s != null) (isLate ? lS : eS).add(s);
    final f = nightFF(d);
    if (f != null) (isLate ? lF : eF).add(f);
  }
  double? a(List<num> x) => x.isEmpty ? null : avg(x);
  return LateDinnerResult(late, early, a(lG), a(eG), a(lS), a(eS), a(lF), a(eF));
}

/// Podsumowanie tygodnia (7 dni kończących się [until]).
class WeekSummary {
  final String from, until;
  final int daysLogged;
  final double avgKcal;
  final int goal;
  final double avgProtein;
  final double? avgFiber;
  final int? bestGutDayScore, worstGutDayScore;
  final String? bestGutDay, worstGutDay;
  final double avgWaterMl;
  final double? weightChange;
  final int? avgFirst, avgLast;
  final int symptomsCount;
  final double alcoholG; // suma czystego alkoholu w tygodniu
  final int alcoholDays;
  const WeekSummary({
    this.alcoholG = 0,
    this.alcoholDays = 0,
    required this.from,
    required this.until,
    required this.daysLogged,
    required this.avgKcal,
    required this.goal,
    required this.avgProtein,
    required this.avgFiber,
    required this.bestGutDay,
    required this.bestGutDayScore,
    required this.worstGutDay,
    required this.worstGutDayScore,
    required this.avgWaterMl,
    required this.weightChange,
    required this.avgFirst,
    required this.avgLast,
    required this.symptomsCount,
  });
}

WeekSummary weekSummary({
  required List<Meal> meals,
  required List<GutEntry> gut,
  required List<Drink> drinks,
  required List<WeightEntry> weights,
  required int goal,
  String? until,
}) {
  final end = until ?? todayIso();
  final from = shiftDay(end, -6);
  bool inWeek(String d) => d.compareTo(from) >= 0 && d.compareTo(end) <= 0;
  final days = [for (var i = 0; i < 7; i++) shiftDay(from, i)];
  final logged = days.where((d) => meals.any((m) => m.date == d)).toList();
  final kcal = [for (final d in logged) dayTotalAll(meals, drinks, d).kcal];
  final prot = [for (final d in logged) dayTotalAll(meals, drinks, d).p];
  final alc = [for (final d in days) drinksOn(d, drinks, const []).alcoholG];
  final fib = [
    for (final d in logged)
      if (Micro.ofItems(meals.where((m) => m.date == d).expand((m) => m.items)) case final mi when mi.coverage >= 0.5) mi.fiber
  ];
  String? best, worst;
  int? bestS, worstS;
  for (final d in days) {
    final s = gutDayScore(gut.where((g) => g.date == d));
    if (s == null) continue;
    if (bestS == null || s > bestS) {
      bestS = s;
      best = d;
    }
    if (worstS == null || s < worstS) {
      worstS = s;
      worst = d;
    }
  }
  final water = [for (final d in days) drinksOn(d, drinks, const []).waterMl.toDouble()];
  final windows = [for (final d in logged) eatingWindow(meals, d)].whereType<({int first, int last})>().toList();
  final wt = WeightTrend(weights.where((w) => inWeek(w.date) || w.date.compareTo(shiftDay(from, -21)) >= 0));
  return WeekSummary(
    alcoholG: alc.fold(0.0, (a, b) => a + b),
    alcoholDays: alc.where((a) => a > 0).length,
    from: from,
    until: end,
    daysLogged: logged.length,
    avgKcal: avg(kcal),
    goal: goal,
    avgProtein: avg(prot),
    avgFiber: fib.isEmpty ? null : avg(fib),
    bestGutDay: best,
    bestGutDayScore: bestS,
    worstGutDay: worst,
    worstGutDayScore: worstS,
    avgWaterMl: avg(water.where((w) => w > 0)),
    weightChange: wt.weeklyChange(days: 28, until: end),
    avgFirst: windows.isEmpty ? null : avg(windows.map((w) => w.first)).round(),
    avgLast: windows.isEmpty ? null : avg(windows.map((w) => w.last)).round(),
    symptomsCount: gut.where((g) => inWeek(g.date)).fold(0, (a, g) => a + g.symptoms.length),
  );
}

/// „To co zwykle”: posiłki jedzone najczęściej o tej porze (±90 min) w ostatnich 60 dniach.
List<(String name, List<FoodItem> items, int count)> usualMeals(List<Meal> meals, DateTime now, {int limit = 4}) {
  final since = shiftDay(isoDate(now), -60);
  final nowMin = now.hour * 60 + now.minute;
  final groups = <String, (List<FoodItem>, int, int)>{}; // klucz → (składniki z ostatniego, liczba, ostatni ts)
  for (final m in meals) {
    if (m.date.compareTo(since) < 0 || m.items.isEmpty) continue;
    final p = m.time.split(':');
    final mm = (int.tryParse(p[0]) ?? 12) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    if ((mm - nowMin).abs() > 90) continue;
    final key = m.name.trim().toLowerCase();
    if (key.isEmpty) continue;
    final g = groups[key];
    if (g == null || m.ts > g.$3) {
      groups[key] = (m.items, (g?.$2 ?? 0) + 1, m.ts);
    } else {
      groups[key] = (g.$1, g.$2 + 1, g.$3);
    }
  }
  final names = {for (final m in meals) m.name.trim().toLowerCase(): m.name.trim()};
  final out = [for (final e in groups.entries) if (e.value.$2 >= 2) (names[e.key] ?? e.key, e.value.$1, e.value.$2)]
    ..sort((a, b) => b.$3.compareTo(a.$3));
  return out.take(limit).toList();
}
