import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dziennik_talerza/calc.dart';
import 'package:dziennik_talerza/extras.dart';
import 'package:dziennik_talerza/food_table.dart';
import 'package:dziennik_talerza/models.dart';
import 'package:dziennik_talerza/report_pdf.dart';
import 'package:dziennik_talerza/gas.dart';
import 'package:dziennik_talerza/store.dart';
import 'package:dziennik_talerza/ui/extras_ui.dart';

Meal meal(String id, String date, String time, String name, {double kcal = 400, String type = 'Obiad', double? fiber}) => Meal(
      id: id,
      person: 'me',
      date: date,
      time: time,
      type: type,
      name: name,
      items: [FoodItem(name: name, grams: 300, kcal: kcal, protein: 20, carbs: 40, fat: 10, fiber: fiber)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('przepis: porcja liczona z wagi gotowego dania', () {
    final r = Recipe(id: 'r', name: 'Bigos', items: [
      FoodItem(name: 'kapusta', grams: 1000, kcal: 300, protein: 10, carbs: 50, fat: 2, fiber: 25),
      FoodItem(name: 'kiełbasa', grams: 500, kcal: 1500, protein: 70, carbs: 5, fat: 130),
    ], cookedGrams: 1200, portions: 4);
    expect(r.portion, 300);
    expect(r.per100.kcal, closeTo(150, 0.01));
    final it = r.portionItem(240);
    expect(it.kcal, closeTo(360, 0.01));
    expect(it.fiber, closeTo(5, 0.01));
    final back = Recipe.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(back.portions, 4);
    expect(back.items.length, 2);
  });

  test('przepis i spiżarnia w podpowiedziach', () {
    final idx = FoodIndex.build(const [], recipes: [
      Recipe(id: 'r', name: 'Zupa krem z dyni', items: [FoodItem(name: 'dynia', grams: 1000, kcal: 260)], cookedGrams: 1300),
    ], pantry: [
      PantryItem(id: 'p', name: 'Skyr naturalny', kcal: 63, protein: 11),
    ]);
    expect(idx.search('zupa krem').first.tag, 'przepis');
    expect(idx.search('skyr').first.tag, 'spiżarnia');
  });

  test('mikroskładniki: pokrycie tylko ze składników z danymi', () {
    final m = Micro.ofItems([FoodItem(kcal: 100, fiber: 3, sugar: 1, salt: 0.5), FoodItem(kcal: 300)]);
    expect(m.fiber, 3);
    expect(m.coverage, closeTo(0.25, 0.001));
    expect(FoodItem.fromJson(FoodItem(name: 'x', fiber: 2.345).toJson()).fiber, closeTo(2.3, 0.001));
    expect(FoodItem(name: 'x').toJson().containsKey('fiber'), isFalse);
  });

  test('napoje i kawy (także z posiłków)', () {
    final d = [
      Drink(id: '1', person: 'me', date: '2026-11-10', time: '08:00', kind: 'woda', ml: 500),
      Drink(id: '2', person: 'me', date: '2026-11-10', time: '09:00', kind: 'kawa', ml: 150),
      Drink(id: '3', person: 'me', date: '2026-11-11', time: '09:00', kind: 'woda', ml: 250),
    ];
    final s = drinksOn('2026-11-10', d, [meal('m', '2026-11-10', '12:00', 'Kawa z mlekiem')]);
    expect(s.waterMl, 500);
    expect(s.allMl, 650);
    expect(s.coffees, 2);
    expect(waterGoalMl(Person(id: 'a', name: 'A', weight: 80)), 2500);
  });

  test('waga: trend tygodniowy i średnia 7 dni', () {
    final ws = [for (var i = 0; i < 15; i++) WeightEntry(id: '$i', person: 'me', date: shiftDay('2026-11-01', i * 2), kg: 90 - i * 0.2)];
    final t = WeightTrend(ws);
    expect(t.weeklyChange(until: '2026-11-29'), closeTo(-0.7, 0.01));
    expect(t.avgAt('2026-11-05'), closeTo(89.8, 0.01));
    expect(WeightTrend(ws.take(2)).weeklyChange(until: '2026-11-29'), isNull);
  });

  test('okno żywieniowe i późna kolacja', () {
    final ms = [
      meal('a', '2026-11-01', '08:00', 'owsianka'),
      meal('b', '2026-11-01', '21:30', 'kanapki', type: 'Kolacja'),
      meal('c', '2026-11-02', '07:30', 'jajecznica'),
      meal('d', '2026-11-02', '18:00', 'zupa'),
      meal('e', '2026-11-03', '22:00', 'pizza'),
      meal('f', '2026-11-04', '18:30', 'ryba'),
    ];
    final w = eatingWindow(ms, '2026-11-01')!;
    expect(hm(w.first), '08:00');
    expect(hm(w.last), '21:30');
    final gut = [
      GutEntry(id: 'g1', person: 'me', date: '2026-11-02', when: 'rano', comfort: 2),
      GutEntry(id: 'g2', person: 'me', date: '2026-11-03', when: 'rano', comfort: 5),
      GutEntry(id: 'g3', person: 'me', date: '2026-11-04', when: 'rano', comfort: 1),
      GutEntry(id: 'g4', person: 'me', date: '2026-11-05', when: 'rano', comfort: 4),
    ];
    final r = lateDinner(meals: ms, gut: gut, sleepHours: {'2026-11-01': 6, '2026-11-02': 8}, nightFF: (d) => null);
    expect(r.lateDays, 2);
    expect(r.earlyDays, 2);
    expect(r.lateGut, 1.5);
    expect(r.earlyGut, 4.5);
    expect(r.lateSleepH, 6);
  });

  test('to co zwykle o tej porze', () {
    final ms = [
      for (var i = 1; i <= 4; i++) meal('o$i', '2026-11-0$i', '07:45', 'Owsianka', type: 'Śniadanie'),
      meal('x', '2026-11-02', '13:00', 'Schabowy'),
      meal('y', '2026-11-03', '13:00', 'Schabowy'),
    ];
    final u = usualMeals(ms, DateTime(2026, 11, 5, 8, 10));
    expect(u.map((e) => e.$1), ['Owsianka']);
    expect(u.first.$3, 4);
  });

  test('podsumowanie tygodnia', () {
    final ms = [for (var i = 0; i < 5; i++) meal('m$i', shiftDay('2026-11-08', -i), '12:00', 'obiad', kcal: 1800, fiber: 20)];
    final s = weekSummary(meals: ms, gut: const [], drinks: const [], weights: const [], goal: 2000, until: '2026-11-08');
    expect(s.daysLogged, 5);
    expect(s.avgKcal, 1800);
    expect(s.avgFiber, 20);
    expect(s.from, '2026-11-02');
  });

  test('co zjeść: pomija to, po czym było źle, i to, co już dziś zjedzone', () {
    final now = DateTime(2026, 11, 10, 13, 0);
    final ms = <Meal>[
      for (var i = 1; i <= 3; i++) meal('a$i', '2026-11-0$i', '13:00', 'Kurczak z ryżem', kcal: 600),
      for (var i = 1; i <= 3; i++) meal('b$i', '2026-11-0${i + 3}', '13:00', 'Fasolka po bretońsku', kcal: 600),
      meal('t', '2026-11-10', '08:00', 'Owsianka', type: 'Śniadanie'),
      meal('t2', '2026-11-09', '08:00', 'Owsianka', type: 'Śniadanie'),
    ];
    final gut = [
      for (var i = 1; i <= 3; i++) GutEntry(id: 'g$i', person: 'me', date: '2026-11-0${i + 4}', when: 'rano', comfort: 1),
      for (var i = 1; i <= 3; i++) GutEntry(id: 'h$i', person: 'me', date: '2026-11-0${i + 1}', when: 'rano', comfort: 5),
    ];
    final s = suggestMeals(meals: ms, gut: gut, favs: const [], recipes: const [], kcalLeft: 1400, proteinLeft: 40, now: now);
    final names = s.map((x) => x.name).toList();
    expect(names, contains('Kurczak z ryżem'));
    expect(names, isNot(contains('Fasolka po bretońsku')));
    expect(names, isNot(contains('Owsianka')));
  });

  test('dane dodatków przechodzą przez zapis i odczyt', () async {
    final a = AppState();
    final j = {
      'people': [Person(id: 'me', name: 'Ja').toJson()],
      'meals': [],
      'gut': [],
      'favorites': [Favorite(id: 'f', person: 'me', name: 'Owsianka', items: [FoodItem(name: 'płatki', grams: 50, kcal: 180)]).toJson()],
      'drinks': [Drink(id: 'd', person: 'me', date: '2026-11-10', time: '08:00', ml: 300).toJson()],
      'weights': [WeightEntry(id: 'w', person: 'me', date: '2026-11-10', kg: 81.5).toJson()],
      'meds': [MedEntry(id: 'x', person: 'me', date: '2026-11-10', time: '08:00', name: 'Witamina D').toJson()],
      'pantry': [PantryItem(id: 'p', name: 'Skyr').toJson()],
      'recipes': [Recipe(id: 'r', name: 'Bigos').toJson()],
    };
    a.replaceFromJsonForTest(j);
    expect(a.favorites.single.items.single.kcal, 180);
    expect(a.allDrinks.single.ml, 300);
    expect(a.allWeights.single.kg, 81.5);
    expect(a.allMeds.single.name, 'Witamina D');
    expect(a.pantry.single.name, 'Skyr');
    expect(a.recipes.single.name, 'Bigos');
    final back = jsonDecode(jsonEncode(a.toJson())) as Map;
    expect((back['favorites'] as List).length, 1);
  });

  test('raport PDF się buduje (polskie znaki)', () async {
    final p = Person(id: 'me', name: 'Zażółć', sex: 'k', birthYear: 1990, height: 165, weight: 60);
    final bytes = await buildReport(ReportInput(
      person: p,
      meals: [meal('a', '2026-11-01', '08:00', 'Jajecznica z łososiem', fiber: 2)],
      gut: [GutEntry(id: 'g', person: 'me', date: '2026-11-02', comfort: 2, symptoms: [const GutSymptom('wzdęcia', 2)], note: 'źle')],
      meds: [MedEntry(id: 'x', person: 'me', date: '2026-11-01', time: '08:00', name: 'Probiotyk')],
      drinks: const [],
      weights: [WeightEntry(id: 'w', person: 'me', date: '2026-11-01', kg: 60)],
      gas: GasSeries(const []),
      from: '2026-10-28',
      to: '2026-11-03',
    ));
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
