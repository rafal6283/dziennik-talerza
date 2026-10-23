// Obliczenia bez Fluttera: zapotrzebowanie, cele, wzorce. Testy w test/calc_test.dart.

import 'models.dart';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String todayIso([DateTime? now]) => isoDate(now ?? DateTime.now());
String shiftDay(String iso, int days) {
  final d = DateTime.parse('${iso}T12:00:00');
  return isoDate(DateTime(d.year, d.month, d.day + days, 12));
}

double avg(Iterable<num> xs) => xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;

// ---------- profil i cele ----------

int? ageOf(Person p, [DateTime? now]) => p.birthYear > 0 ? (now ?? DateTime.now()).year - p.birthYear : null;

/// Przemiana spoczynkowa wzorem Mifflina-St Jeora.
double? bmrOf(Person p, [DateTime? now]) {
  final a = ageOf(p, now);
  if (p.sex.isEmpty || a == null || p.height <= 0 || p.weight <= 0) return null;
  return 10 * p.weight + 6.25 * p.height - 5 * a + (p.sex == 'm' ? 5 : -161);
}

double? tdeeOf(Person p, [DateTime? now]) {
  final b = bmrOf(p, now);
  return b == null ? null : b * (double.tryParse(p.activity) ?? 1.375);
}

/// Cel wyliczony: redukcja ok. −400 kcal (nie mniej niż 110% BMR), masa +250 kcal.
/// U osób poniżej 18 lat zawsze utrzymanie.
int? autoGoalOf(Person p, [DateTime? now]) {
  final t = tdeeOf(p, now);
  if (t == null) return null;
  var g = t;
  final a = ageOf(p, now) ?? 0;
  if (a >= 18) {
    if (p.mode == 'cut') g = (t - 400) > bmrOf(p, now)! * 1.1 ? t - 400 : bmrOf(p, now)! * 1.1;
    if (p.mode == 'gain') g = t + 250;
  }
  return (g / 10).round() * 10;
}

int goalOf(Person p, [DateTime? now]) => p.manualGoal > 0 ? p.manualGoal : (autoGoalOf(p, now) ?? 2200);
int? proteinOf(Person p) => p.weight > 0 ? (p.weight * (p.mode == 'keep' ? 1.2 : 1.6)).round() : null;
double? bmiOf(Person p) => p.height > 0 && p.weight > 0 ? p.weight / ((p.height / 100) * (p.height / 100)) : null;
bool profileComplete(Person p) => bmrOf(p) != null;

String activityLabel(String v) => activityLevels.firstWhere((x) => x.$1 == v, orElse: () => activityLevels[1]).$2;
String modeLabel(String v) => goalModes.firstWhere((x) => x.$1 == v, orElse: () => goalModes[0]).$2;

/// Opis osoby dla analizy AI.
String personLine(Person p, [DateTime? now]) {
  final a = ageOf(p, now);
  final parts = <String>[
    if (p.sex.isNotEmpty) p.sex == 'm' ? 'mężczyzna' : 'kobieta',
    if (a != null) '$a lat',
    if (p.height > 0) '${p.height} cm',
    if (p.weight > 0) '${p.weight} kg',
    'aktywność: ${activityLabel(p.activity).toLowerCase()}',
    'cel: ${modeLabel(p.mode).toLowerCase()}',
  ];
  final t = tdeeOf(p, now);
  if (t != null) parts.add('szacowane zapotrzebowanie ok. ${t.round()} kcal');
  parts.add('cel dzienny ${goalOf(p, now)} kcal');
  final pr = proteinOf(p);
  if (pr != null) parts.add('cel białka ok. $pr g');
  if (p.notes.isNotEmpty) parts.add('uwagi: ${p.notes}');
  return parts.join(', ');
}

// ---------- dzień ----------

Macros dayTotal(Iterable<Meal> meals, String date) =>
    meals.where((m) => m.date == date).fold(Macros.zero, (a, m) => a + m.total);

// ---------- trawienie ----------

bool gutBad(GutEntry g) => (g.comfort > 0 && g.comfort <= 2) || g.symptoms.any((s) => s.sev >= 2);

/// Ocena dnia do paska 14 dni: najgorszy wpis (1–5) albo null.
int? gutDayScore(Iterable<GutEntry> entries) {
  final scores = entries.map((g) => g.comfort > 0 ? g.comfort : (gutBad(g) ? 2 : (g.symptoms.isNotEmpty ? 3 : 4)));
  return scores.isEmpty ? null : scores.reduce((a, b) => a < b ? a : b);
}

/// Posiłki, które mogły wpłynąć na wpis: zaznaczone jako podejrzane, a bez zaznaczenia – z 30 godzin przed wpisem.
List<Meal> gutWindow(GutEntry g, List<Meal> meals) {
  if (g.suspects.isNotEmpty) return meals.where((m) => g.suspects.contains(m.id)).toList();
  final t = g.ts;
  return meals.where((m) => m.ts < t && m.ts >= t - 30 * 3600 * 1000).toList();
}

Set<String> ingredientsOf(Iterable<Meal> meals) =>
    {for (final m in meals) for (final i in m.items) if (i.name.trim().isNotEmpty) i.name.trim().toLowerCase()};

class Assoc {
  final String ingredient;
  final int hits; // ile razy przed złym wynikiem
  final int total; // ile razy w ogóle
  const Assoc(this.ingredient, this.hits, this.total);
  double get rate => total == 0 ? 0 : hits / total;
}

class GutAssocResult {
  final int windows; // wpisy z posiłkami przed nimi
  final int bad;
  final List<Assoc> rows;
  const GutAssocResult(this.windows, this.bad, this.rows);
  double get base => windows == 0 ? 0 : bad / windows;
  bool flagged(Assoc a) => a.total >= 3 && a.rate >= base + 0.25;
}

GutAssocResult gutAssociations(List<GutEntry> gut, List<Meal> meals, {int top = 8}) {
  final wins = <(bool, Set<String>)>[];
  for (final g in gut) {
    final ings = ingredientsOf(gutWindow(g, meals));
    if (ings.isNotEmpty) wins.add((gutBad(g), ings));
  }
  final n = <String, int>{}, k = <String, int>{};
  for (final (bad, ings) in wins) {
    for (final i in ings) {
      n[i] = (n[i] ?? 0) + 1;
      if (bad) k[i] = (k[i] ?? 0) + 1;
    }
  }
  final rows = [for (final e in k.entries) if (e.value >= 2) Assoc(e.key, e.value, n[e.key]!)]
    ..sort((a, b) => b.rate != a.rate ? b.rate.compareTo(a.rate) : b.hits.compareTo(a.hits));
  return GutAssocResult(wins.length, wins.where((w) => w.$1).length, rows.take(top).toList());
}

/// Objawy po posiłkach (oceny „jak się czujesz po”): dla każdego objawu najczęstsze składniki.
class SymptomAssoc {
  final String symptom;
  final int meals; // po ilu posiłkach wystąpił
  final List<Assoc> rows;
  const SymptomAssoc(this.symptom, this.meals, this.rows);
}

List<SymptomAssoc> reactionAssociations(List<Meal> meals) {
  final rated = meals.where((m) => m.reactions.isNotEmpty).toList();
  final count = <String, int>{};
  for (final m in rated) {
    for (final i in ingredientsOf([m])) {
      count[i] = (count[i] ?? 0) + 1;
    }
  }
  final out = <SymptomAssoc>[];
  for (final s in reactionSymptoms) {
    final withS = rated.where((m) => m.reactions.any((r) => r.symptoms.contains(s))).toList();
    if (withS.isEmpty) continue;
    final k = <String, int>{};
    for (final m in withS) {
      for (final i in ingredientsOf([m])) {
        k[i] = (k[i] ?? 0) + 1;
      }
    }
    final rows = [for (final e in k.entries) if (e.value >= 2) Assoc(e.key, e.value, count[e.key]!)]
      ..sort((a, b) => b.rate != a.rate ? b.rate.compareTo(a.rate) : b.hits.compareTo(a.hits));
    out.add(SymptomAssoc(s, withS.length, rows.take(4).toList()));
  }
  return out;
}

/// Średnia energia po posiłkach danego typu, od najlepszego.
List<(String, double, int)> energyByType(List<Meal> meals) {
  final by = <String, List<int>>{};
  for (final m in meals) {
    final es = m.reactions.map((r) => r.energy).where((e) => e > 0);
    if (es.isEmpty) continue;
    by.putIfAbsent(m.type, () => []).add(avg(es).round());
  }
  final out = [for (final e in by.entries) (e.key, avg(e.value), e.value.length)];
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}

/// Częstość objawów trawiennych: nazwa → (liczba, średnie nasilenie).
List<(String, int, double)> gutFrequency(List<GutEntry> gut) {
  final f = <String, List<int>>{};
  for (final g in gut) {
    for (final s in g.symptoms) {
      f.putIfAbsent(s.name, () => []).add(s.sev);
    }
  }
  final out = [for (final e in f.entries) (e.key, e.value.length, avg(e.value))];
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}
