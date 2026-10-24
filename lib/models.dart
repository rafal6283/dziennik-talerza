// Modele danych. Pola JSON są takie same jak w wersji przeglądarkowej (artefakt),
// więc eksport z niej da się wczytać wprost. Nieznane pola są zachowywane.

import 'dart:math';

String newId([String prefix = '']) {
  final r = Random.secure();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final s = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$prefix$t$s';
}

int _i(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;
double _d(dynamic v) {
  if (v is num) return v.toDouble();
  // „70 g”, „1,5”, „ok. 120” → liczba
  final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch('${v ?? ''}');
  return m == null ? 0 : double.tryParse(m[0]!.replaceAll(',', '.')) ?? 0;
}
String _s(dynamic v) => v == null ? '' : '$v';

Map<String, dynamic> _rest(Map<String, dynamic> j, Set<String> known) =>
    {for (final e in j.entries) if (!known.contains(e.key)) e.key: e.value};

const mealTypes = ['Śniadanie', 'Drugie śniadanie', 'Obiad', 'Podwieczorek', 'Kolacja', 'Przekąska'];
const reactionSymptoms = ['wzdęcia', 'zgaga', 'ból brzucha', 'nudności', 'senność', 'ból głowy', 'szybko głodny'];
const reactionAfter = ['30 min', '1 h', '2 h', '3 h+', 'następnego dnia'];
const gutSymptoms = ['wzdęcia', 'gazy', 'zgaga', 'ból brzucha', 'skurcze', 'nudności', 'biegunka', 'zaparcie', 'ciężkość', 'odbijanie'];
const severityNames = ['', 'lekki', 'średni', 'silny'];
const gutWhen = [('w nocy', '03:00'), ('rano', '08:00'), ('w ciągu dnia', '14:00'), ('wieczorem', '20:00')];
const bristolScale = [
  (1, 'twarde grudki'),
  (2, 'zbity, grudkowaty'),
  (3, 'z pęknięciami'),
  (4, 'gładki, miękki'),
  (5, 'miękkie kawałki'),
  (6, 'papkowaty'),
  (7, 'wodnisty'),
];
const comfortNames = ['', 'bardzo źle', 'źle', 'tak sobie', 'dobrze', 'świetnie'];
const activityLevels = [
  ('1.2', 'Siedzący tryb życia'),
  ('1.375', 'Lekka aktywność (1–3 treningi/tydz.)'),
  ('1.55', 'Umiarkowana (3–5 treningów/tydz.)'),
  ('1.725', 'Duża (6–7 treningów/tydz.)'),
  ('1.9', 'Bardzo duża / praca fizyczna'),
];
const goalModes = [('keep', 'Utrzymanie wagi'), ('cut', 'Redukcja'), ('gain', 'Budowa masy')];

class Person {
  String id;
  String name;
  String sex; // 'k', 'm' albo ''
  int birthYear;
  int height; // cm
  double weight; // kg
  String activity;
  String mode;
  int manualGoal;
  String notes;
  Map<String, dynamic> extra;

  Person({
    required this.id,
    required this.name,
    this.sex = '',
    this.birthYear = 0,
    this.height = 0,
    this.weight = 0,
    this.activity = '1.375',
    this.mode = 'keep',
    this.manualGoal = 0,
    this.notes = '',
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  static const _known = {'id', 'name', 'sex', 'birthYear', 'height', 'weight', 'activity', 'mode', 'manualGoal', 'notes'};

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: _s(j['id']).isEmpty ? newId('p') : _s(j['id']),
        name: _s(j['name']).isEmpty ? 'Bez imienia' : _s(j['name']),
        sex: _s(j['sex']),
        birthYear: _i(j['birthYear']),
        height: _i(j['height']),
        weight: _d(j['weight']),
        activity: _s(j['activity']).isEmpty ? '1.375' : _s(j['activity']),
        mode: _s(j['mode']).isEmpty ? 'keep' : _s(j['mode']),
        manualGoal: _i(j['manualGoal']),
        notes: _s(j['notes']),
        extra: _rest(j, _known),
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'name': name,
        'sex': sex,
        'birthYear': birthYear,
        'height': height,
        'weight': weight,
        'activity': activity,
        'mode': mode,
        'manualGoal': manualGoal,
        'notes': notes,
      };

  Person copy() => Person.fromJson(toJson());
}

class FoodItem {
  String name;
  double grams, kcal, protein, carbs, fat;
  FoodItem({this.name = '', this.grams = 0, this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0});

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        name: _s(j['name']).trim(),
        grams: _d(j['grams']),
        kcal: _d(j['kcal']),
        protein: _d(j['protein']),
        carbs: _d(j['carbs']),
        fat: _d(j['fat']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams.round(),
        'kcal': kcal.round(),
        'protein': protein.round(),
        'carbs': carbs.round(),
        'fat': fat.round(),
      };
}

class Macros {
  final double kcal, p, c, f;
  const Macros(this.kcal, this.p, this.c, this.f);
  static const zero = Macros(0, 0, 0, 0);
  Macros operator +(Macros o) => Macros(kcal + o.kcal, p + o.p, c + o.c, f + o.f);
  static Macros ofItems(Iterable<FoodItem> items) =>
      items.fold(zero, (a, i) => a + Macros(i.kcal, i.protein, i.carbs, i.fat));
}

class Reaction {
  String after;
  int energy, satiety;
  List<String> symptoms;
  String note;
  int ts;
  Reaction({this.after = '1 h', this.energy = 0, this.satiety = 0, List<String>? symptoms, this.note = '', int? ts})
      : symptoms = symptoms ?? [],
        ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction(
        after: _s(j['after']).isEmpty ? '1 h' : _s(j['after']),
        energy: _i(j['energy']),
        satiety: _i(j['satiety']),
        symptoms: [for (final s in (j['symptoms'] is List ? j['symptoms'] as List : const [])) _s(s)],
        note: _s(j['note']),
        ts: _i(j['ts']),
      );

  Map<String, dynamic> toJson() =>
      {'after': after, 'energy': energy, 'satiety': satiety, 'symptoms': symptoms, 'note': note, 'ts': ts};
}

class Meal {
  String id;
  String person;
  String date; // RRRR-MM-DD
  String time; // GG:MM
  String type;
  String name;
  String desc;
  List<FoodItem> items;
  String? photo; // nazwa pliku miniatury w katalogu aplikacji
  List<Reaction> reactions;
  int created;
  Map<String, dynamic> extra;

  Meal({
    required this.id,
    required this.person,
    required this.date,
    required this.time,
    this.type = 'Obiad',
    this.name = '',
    this.desc = '',
    List<FoodItem>? items,
    this.photo,
    List<Reaction>? reactions,
    int? created,
    Map<String, dynamic>? extra,
  })  : items = items ?? [],
        reactions = reactions ?? [],
        created = created ?? DateTime.now().millisecondsSinceEpoch,
        extra = extra ?? {};

  int get ts => DateTime.tryParse('${date}T$time:00')?.millisecondsSinceEpoch ?? created;
  Macros get total => Macros.ofItems(items);

  static const _known = {'id', 'person', 'date', 'time', 'ts', 'type', 'name', 'desc', 'items', 'total', 'photo', 'photoFile', 'reactions', 'created'};

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: _s(j['id']).isEmpty ? newId('m') : _s(j['id']),
        person: _s(j['person']).isEmpty ? 'me' : _s(j['person']),
        date: _s(j['date']),
        time: _s(j['time']).isEmpty ? '12:00' : _s(j['time']),
        type: _s(j['type']).isEmpty ? 'Obiad' : _s(j['type']),
        name: _s(j['name']),
        desc: _s(j['desc']),
        items: [for (final e in (j['items'] is List ? j['items'] as List : const [])) if (e is Map) FoodItem.fromJson(Map<String, dynamic>.from(e))],
        photo: _s(j['photoFile']).isEmpty ? null : _s(j['photoFile']),
        reactions: [for (final e in (j['reactions'] is List ? j['reactions'] as List : const [])) if (e is Map) Reaction.fromJson(Map<String, dynamic>.from(e))],
        created: _i(j['created']) == 0 ? null : _i(j['created']),
        extra: _rest(j, _known),
      );

  Map<String, dynamic> toJson() {
    final t = total;
    return {
      ...extra,
      'id': id,
      'person': person,
      'date': date,
      'time': time,
      'ts': ts,
      'type': type,
      'name': name,
      'desc': desc,
      'items': items.map((i) => i.toJson()).toList(),
      'total': {'kcal': t.kcal.round(), 'p': t.p.round(), 'c': t.c.round(), 'f': t.f.round()},
      if (photo != null) 'photoFile': photo,
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'created': created,
    };
  }
}

class GutSymptom {
  final String name;
  final int sev; // 1–3
  const GutSymptom(this.name, this.sev);
  Map<String, dynamic> toJson() => {'name': name, 'sev': sev};
}

class GutEntry {
  String id;
  String person;
  String date;
  String when;
  int comfort; // 0 = nie podano
  List<GutSymptom> symptoms;
  int bristol;
  List<String> suspects; // id posiłków
  String note;
  int created;
  Map<String, dynamic> extra;

  GutEntry({
    required this.id,
    required this.person,
    required this.date,
    this.when = 'rano',
    this.comfort = 0,
    List<GutSymptom>? symptoms,
    this.bristol = 0,
    List<String>? suspects,
    this.note = '',
    int? created,
    Map<String, dynamic>? extra,
  })  : symptoms = symptoms ?? [],
        suspects = suspects ?? [],
        created = created ?? DateTime.now().millisecondsSinceEpoch,
        extra = extra ?? {};

  int get ts {
    final hhmm = gutWhen.firstWhere((w) => w.$1 == when, orElse: () => gutWhen[2]).$2;
    return DateTime.tryParse('${date}T$hhmm:00')?.millisecondsSinceEpoch ?? created;
  }

  static const _known = {'id', 'person', 'date', 'when', 'ts', 'comfort', 'symptoms', 'bristol', 'suspects', 'note', 'created'};

  factory GutEntry.fromJson(Map<String, dynamic> j) => GutEntry(
        id: _s(j['id']).isEmpty ? newId('g') : _s(j['id']),
        person: _s(j['person']).isEmpty ? 'me' : _s(j['person']),
        date: _s(j['date']),
        when: _s(j['when']).isEmpty ? 'rano' : _s(j['when']),
        comfort: _i(j['comfort']),
        symptoms: [
          for (final e in (j['symptoms'] is List ? j['symptoms'] as List : const []))
            if (e is Map && _i(e['sev']) > 0) GutSymptom(_s(e['name']), _i(e['sev']).clamp(1, 3))
        ],
        bristol: _i(j['bristol']),
        suspects: [for (final s in (j['suspects'] is List ? j['suspects'] as List : const [])) _s(s)],
        note: _s(j['note']),
        created: _i(j['created']) == 0 ? null : _i(j['created']),
        extra: _rest(j, _known),
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'person': person,
        'date': date,
        'when': when,
        'ts': ts,
        'comfort': comfort,
        'symptoms': symptoms.map((s) => s.toJson()).toList(),
        'bristol': bristol,
        'suspects': suspects,
        'note': note,
        'created': created,
      };
}
