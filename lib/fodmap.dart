// Grupy produktów, które najczęściej powodują FF i wzdęcia (FODMAP + kapustne, gazowane, słodziki),
// ich związek z FF oraz dieta eliminacyjna: eliminacja → wprowadzanie po jednej grupie.
// Czysty Dart (testowany w CI).

import 'calc.dart';
import 'gas.dart';
import 'models.dart';

class FoodGroup {
  final String id;
  final String name;
  final String examples;
  final List<String> keys; // początki słów (bez polskich znaków), np. „cebul”
  const FoodGroup(this.id, this.name, this.examples, this.keys);
}

const foodGroups = [
  FoodGroup('fruktany', 'Fruktany (pszenica, cebula, czosnek)', 'chleb pszenny i żytni, makaron, pierogi, cebula, czosnek, por',
      ['pszen', 'zytn', 'zyto', 'chleb', 'bulk', 'bagiet', 'makaron', 'spaghetti', 'pierog', 'nalesnik', 'pizz', 'kluski', 'kuskus', 'drozdzowk', 'rogal', 'croissant', 'tortill', 'cebul', 'czosn', 'por ', 'pora', 'szalot', 'karczoch', 'cykori', 'inulin']),
  FoodGroup('gos', 'Strączki (GOS)', 'fasola, ciecierzyca, soczewica, groch, hummus, bób',
      ['fasol', 'fasolk', 'ciecierzyc', 'hummus', 'soczewic', 'groch', 'bob ', 'bobu', 'edamame', 'falafel', 'soja', 'soi ']),
  FoodGroup('laktoza', 'Laktoza (mleko)', 'mleko, jogurt, kefir, śmietana, twaróg, lody, budyń',
      ['mlek', 'mleczn', 'jogurt', 'kefir', 'maslank', 'smietan', 'twarog', 'twarozk', 'serek', 'ricott', 'mascarpone', 'lody', 'lodow', 'budyn', 'latte', 'cappuccino', 'kakao']),
  FoodGroup('fruktoza', 'Nadmiar fruktozy', 'jabłko, gruszka, miód, mango, arbuz, soki owocowe',
      ['jablk', 'jablek', 'grusz', 'miod', 'mango', 'arbuz', 'szparag', 'syrop glukozowo', 'sok jabl', 'sok owoc', 'figi', 'daktyl', 'agaw']),
  FoodGroup('poliole', 'Poliole i słodziki', 'śliwki, czereśnie, morele, grzyby, kalafior, guma do żucia, ksylitol',
      ['sliw', 'czeresn', 'wisni', 'morel', 'brzoskw', 'nektaryn', 'awokad', 'grzyb', 'pieczark', 'kurk', 'kalafior', 'guma do zucia', 'ksylitol', 'sorbitol', 'maltitol', 'erytrytol', 'erytrol', 'slodzik', 'bez cukru']),
  FoodGroup('kapustne', 'Kapustne', 'kapusta, brokuł, brukselka, kalafior, kalarepa, jarmuż',
      ['kapust', 'bigos', 'golab', 'brokul', 'brukselk', 'kalafior', 'kalarep', 'jarmuz', 'rzodkiew', 'rzodkiewk']),
  FoodGroup('gazowane', 'Napoje gazowane i piwo', 'woda gazowana, cola, napoje gazowane, piwo',
      ['gazowan', 'cola', 'pepsi', 'sprite', 'fanta', 'tonik', 'piwo', 'piwa', 'cydr', 'prosecco', 'szampan', 'oranzad']),
];

FoodGroup? groupById(String id) => foodGroups.where((g) => g.id == id).firstOrNull;

String _fold(String s) {
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return ' ${b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
}

/// Grupy w tekście (nazwa składnika, posiłku, opis). Słowo musi zaczynać się od klucza.
Set<String> groupsInText(String text) {
  final t = _fold(text);
  final out = <String>{};
  for (final g in foodGroups) {
    for (final k in g.keys) {
      if (t.contains(' $k')) {
        out.add(g.id);
        break;
      }
    }
  }
  // „bez laktozy”, „bezglutenowy” – nie licz
  if (t.contains(' bez laktoz') || t.contains(' bezlaktoz')) out.remove('laktoza');
  if (RegExp(r' (mleko|mleczko|napoj|jogurt) (owsian|migdal|kokos|sojow|ryzow|roslinn)').hasMatch(t)) out.remove('laktoza');
  if (t.contains(' bezglutenow') || t.contains(' bez glutenu')) out.remove('fruktany');
  return out;
}

Set<String> groupsOfMeal(Meal m) => {
      ...groupsInText(m.name),
      for (final i in m.items) ...groupsInText(i.name),
    };

// ---------- FF a grupy ----------

class GroupAssoc {
  final FoodGroup group;
  final int daysWith, daysWithout;
  final double avgWith, avgWithout;
  const GroupAssoc(this.group, this.daysWith, this.daysWithout, this.avgWith, this.avgWithout);
  double get ratio => avgWithout <= 0 ? (avgWith > 0 ? 9 : 1) : avgWith / avgWithout;
  bool get flagged => daysWith >= 3 && daysWithout >= 3 && ratio >= 1.3 && avgWith - avgWithout >= 1;
}

/// Średnio FF po dniach z daną grupą wobec dni bez niej (ta sama definicja skutku co dla składników).
List<GroupAssoc> gasGroupAssociations(List<Meal> meals, GasSeries s) {
  final byDay = <String, Set<String>>{};
  final first = <String, int>{};
  for (final m in meals) {
    byDay.putIfAbsent(m.date, () => {}).addAll(groupsOfMeal(m));
    if (!first.containsKey(m.date) || m.ts < first[m.date]!) first[m.date] = m.ts;
  }
  final out = <String, int>{
    for (final d in byDay.keys)
      if (s.outcome(d, firstMealMs: first[d]) case final o?) d: o
  };
  if (out.length < 5) return const [];
  final rows = <GroupAssoc>[];
  for (final g in foodGroups) {
    final w = [for (final e in out.entries) if (byDay[e.key]!.contains(g.id)) e.value];
    final wo = [for (final e in out.entries) if (!byDay[e.key]!.contains(g.id)) e.value];
    if (w.length < 2) continue;
    rows.add(GroupAssoc(g, w.length, wo.length, avg(w), avg(wo)));
  }
  rows.sort((a, b) => b.ratio.compareTo(a.ratio));
  return rows;
}

// ---------- dieta eliminacyjna ----------

const elimDefaultDays = 14;
const testDays = 3; // dni jedzenia testowanej grupy
const washDays = 2; // przerwa po teście (objawy bywają opóźnione)

class Elimination {
  String id;
  String person;
  List<String> groups; // eliminowane grupy, w kolejności wprowadzania
  String start; // RRRR-MM-DD
  int elimDays;
  bool stopped;
  Map<String, dynamic> extra;

  Elimination({
    required this.id,
    required this.person,
    required this.groups,
    required this.start,
    this.elimDays = elimDefaultDays,
    this.stopped = false,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  factory Elimination.fromJson(Map<String, dynamic> j) => Elimination(
        id: '${j['id'] ?? newId('e')}',
        person: '${j['person'] ?? 'me'}',
        groups: [for (final g in (j['groups'] is List ? j['groups'] as List : const [])) '$g'],
        start: '${j['start'] ?? todayIso()}',
        elimDays: (j['elimDays'] as num?)?.toInt() ?? elimDefaultDays,
        stopped: j['stopped'] == true,
        extra: {for (final e in j.entries) if (!const {'id', 'person', 'groups', 'start', 'elimDays', 'stopped'}.contains(e.key)) e.key: e.value},
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'person': person,
        'groups': groups,
        'start': start,
        'elimDays': elimDays,
        if (stopped) 'stopped': true,
      };

  String get elimEnd => shiftDay(start, elimDays - 1);

  /// Test grupy nr i: (pierwszy dzień testu, ostatni dzień testu, ostatni dzień przerwy).
  (String, String, String) testOf(int i) {
    final s = shiftDay(start, elimDays + i * (testDays + washDays));
    return (s, shiftDay(s, testDays - 1), shiftDay(s, testDays + washDays - 1));
  }

  String get end => groups.isEmpty ? elimEnd : testOf(groups.length - 1).$3;

  /// Grupy, których nie jeść danego dnia: do końca diety wszystkie eliminowane poza grupą testowaną tego dnia
  /// (po teście grupa znów odpada, żeby kolejny test był czysty).
  Set<String> forbiddenOn(String date) {
    if (stopped || date.compareTo(start) < 0 || date.compareTo(end) > 0) return {};
    final p = phaseOn(date);
    return {for (final g in groups) if (!(p.stage == ElimStage.test && p.group == g)) g};
  }

  ElimPhase phaseOn(String date) {
    if (stopped) return const ElimPhase(ElimStage.done);
    if (date.compareTo(start) < 0) return const ElimPhase(ElimStage.before);
    if (date.compareTo(elimEnd) <= 0) {
      return ElimPhase(ElimStage.elimination, day: DateTime.parse('${date}T12:00:00').difference(DateTime.parse('${start}T12:00:00')).inDays + 1, of: elimDays);
    }
    for (var i = 0; i < groups.length; i++) {
      final (ts, te, we) = testOf(i);
      if (date.compareTo(ts) >= 0 && date.compareTo(te) <= 0) {
        return ElimPhase(ElimStage.test, group: groups[i], day: DateTime.parse('${date}T12:00:00').difference(DateTime.parse('${ts}T12:00:00')).inDays + 1, of: testDays);
      }
      if (date.compareTo(te) > 0 && date.compareTo(we) <= 0) return ElimPhase(ElimStage.wash, group: groups[i]);
    }
    return const ElimPhase(ElimStage.done);
  }
}

enum ElimStage { before, elimination, test, wash, done }

class ElimPhase {
  final ElimStage stage;
  final String? group;
  final int day, of;
  const ElimPhase(this.stage, {this.group, this.day = 0, this.of = 0});
}

/// Posiłki z zakazaną grupą w czasie trwania diety: (posiłek, grupy).
List<(Meal, Set<String>)> violations(Elimination e, List<Meal> meals) => [
      for (final m in meals)
        if (groupsOfMeal(m).intersection(e.forbiddenOn(m.date)) case final g when g.isNotEmpty) (m, g)
    ];

class ElimResult {
  final double? baseline; // FF średnio 14 dni przed startem
  final double? elim; // FF średnio w drugiej połowie eliminacji (po wygaszeniu)
  final Map<String, double?> tests; // grupa → FF średnio w dniach testu i 1 dzień po
  final Map<String, double?> gutTests; // grupa → średni komfort trawienia (1–5) w dniach testu
  final double? gutElim;
  const ElimResult(this.baseline, this.elim, this.tests, this.gutTests, this.gutElim);

  /// Werdykt dla grupy: true – wyraźnie gorzej, false – bez różnicy, null – za mało danych.
  bool? worse(String g) {
    final t = tests[g], e = elim;
    if (t != null && e != null) return t >= e * 1.3 && t - e >= 1;
    final gt = gutTests[g], ge = gutElim;
    if (gt != null && ge != null) return ge - gt >= 1;
    return null;
  }
}

ElimResult elimResult(Elimination e, GasSeries s, List<Meal> meals, List<GutEntry> gut) {
  final first = <String, int>{};
  for (final m in meals) {
    if (!first.containsKey(m.date) || m.ts < first[m.date]!) first[m.date] = m.ts;
  }
  double? mean(String from, String to) {
    final v = <int>[];
    for (var d = from; d.compareTo(to) <= 0; d = shiftDay(d, 1)) {
      if (d.compareTo(todayIso()) > 0) break;
      final o = s.outcome(d, firstMealMs: first[d]);
      if (o != null) v.add(o);
    }
    return v.isEmpty ? null : avg(v);
  }

  double? gutMean(String from, String to) {
    final v = <int>[];
    for (var d = from; d.compareTo(to) <= 0; d = shiftDay(d, 1)) {
      final sc = gutDayScore(gut.where((g) => g.date == d));
      if (sc != null) v.add(sc);
    }
    return v.isEmpty ? null : avg(v);
  }

  final half = shiftDay(e.start, e.elimDays ~/ 2);
  return ElimResult(
    mean(shiftDay(e.start, -14), shiftDay(e.start, -1)),
    mean(half, e.elimEnd),
    {for (var i = 0; i < e.groups.length; i++) e.groups[i]: mean(e.testOf(i).$1, shiftDay(e.testOf(i).$2, 1))},
    {for (var i = 0; i < e.groups.length; i++) e.groups[i]: gutMean(e.testOf(i).$1, shiftDay(e.testOf(i).$2, 1))},
    gutMean(half, e.elimEnd),
  );
}
