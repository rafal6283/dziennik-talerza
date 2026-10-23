import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dziennik_talerza/ai.dart';
import 'package:dziennik_talerza/calc.dart';
import 'package:dziennik_talerza/models.dart';
import 'package:dziennik_talerza/store.dart';

Meal meal(String id, String date, String time, List<String> ings, {List<Reaction>? r, String person = 'me', String type = 'Obiad'}) => Meal(
      id: id,
      person: person,
      date: date,
      time: time,
      type: type,
      name: ings.join(', '),
      items: [for (final i in ings) FoodItem(name: i, grams: 100, kcal: 200, protein: 10, carbs: 20, fat: 5)],
      reactions: r,
    );

void main() {
  final now = DateTime(2026, 10, 23);

  group('profil', () {
    test('Mifflin-St Jeor i cele', () {
      final p = Person(id: 'a', name: 'A', sex: 'm', birthYear: 1991, height: 180, weight: 80, activity: '1.375');
      expect(ageOf(p, now), 35);
      expect(bmrOf(p, now), closeTo(1755, 0.01));
      expect(tdeeOf(p, now), closeTo(2413.125, 0.01));
      expect(autoGoalOf(p, now), 2410);
      p.mode = 'cut';
      expect(autoGoalOf(p, now), 2010);
      p.mode = 'gain';
      expect(autoGoalOf(p, now), 2660);
      p.manualGoal = 1900;
      expect(goalOf(p, now), 1900);
      expect(proteinOf(p), 128);
    });

    test('kobieta, redukcja nie schodzi poniżej 110% BMR', () {
      final p = Person(id: 'b', name: 'B', sex: 'k', birthYear: 1966, height: 160, weight: 55, activity: '1.2', mode: 'cut');
      final bmr = bmrOf(p, now)!; // 550+1000-300-161 = 1089
      expect(bmr, closeTo(1089, 0.01));
      expect(autoGoalOf(p, now), ((bmr * 1.1) / 10).round() * 10);
    });

    test('niepełnoletni: bez redukcji', () {
      final p = Person(id: 'c', name: 'C', sex: 'k', birthYear: 2012, height: 155, weight: 45, mode: 'cut');
      expect(autoGoalOf(p, now), ((tdeeOf(p, now)!) / 10).round() * 10);
    });

    test('niepełny profil: cel domyślny', () {
      final p = Person(id: 'd', name: 'D');
      expect(profileComplete(p), isFalse);
      expect(goalOf(p, now), 2200);
      expect(personLine(p, now), contains('cel dzienny 2200 kcal'));
    });
  });

  group('trawienie', () {
    test('okno 30 h i podejrzane posiłki', () {
      final meals = [
        meal('m1', '2026-10-21', '20:00', ['fasola']), // 36 h przed wpisem – poza oknem
        meal('m2', '2026-10-22', '19:00', ['fasola', 'cebula']),
        meal('m3', '2026-10-23', '07:30', ['owsianka']),
      ];
      final g = GutEntry(id: 'g', person: 'me', date: '2026-10-23', when: 'rano');
      expect(gutWindow(g, meals).map((m) => m.id), ['m2', 'm3']);
      g.suspects.add('m1');
      expect(gutWindow(g, meals).map((m) => m.id), ['m1']);
    });

    test('składniki przed złym trawieniem', () {
      final meals = <Meal>[];
      final gut = <GutEntry>[];
      for (var d = 1; d <= 6; d++) {
        final day = '2026-10-${(10 + d).toString()}';
        final prev = shiftDay(day, -1);
        final bad = d.isEven;
        meals.add(meal('m$d', prev, '19:00', bad ? ['fasola', 'chleb'] : ['ryż', 'chleb']));
        gut.add(GutEntry(id: 'g$d', person: 'me', date: day, when: 'rano', comfort: bad ? 2 : 4,
            symptoms: bad ? [const GutSymptom('wzdęcia', 2)] : []));
      }
      final r = gutAssociations(gut, meals);
      expect(r.windows, 6);
      expect(r.bad, 3);
      final fasola = r.rows.firstWhere((a) => a.ingredient == 'fasola');
      expect(fasola.hits, 3);
      expect(fasola.total, 3);
      expect(r.flagged(fasola), isTrue);
      final chleb = r.rows.firstWhere((a) => a.ingredient == 'chleb');
      expect(chleb.rate, closeTo(0.5, 1e-9));
      expect(r.flagged(chleb), isFalse);
      expect(gutDayScore(gut.where((g) => g.id == 'g2')), 2);
      expect(gutDayScore(const []), isNull);
    });

    test('lekki objaw bez oceny komfortu to nie „złe” trawienie', () {
      expect(gutBad(GutEntry(id: 'x', person: 'me', date: '2026-10-23', symptoms: [const GutSymptom('gazy', 1)])), isFalse);
      expect(gutBad(GutEntry(id: 'y', person: 'me', date: '2026-10-23', symptoms: [const GutSymptom('gazy', 3)])), isTrue);
    });
  });

  test('reakcje po posiłkach i energia', () {
    final meals = [
      meal('a', '2026-10-20', '13:00', ['makaron'], r: [Reaction(energy: 2, symptoms: ['senność'])], type: 'Obiad'),
      meal('b', '2026-10-21', '13:00', ['makaron'], r: [Reaction(energy: 2, symptoms: ['senność'])], type: 'Obiad'),
      meal('c', '2026-10-21', '08:00', ['jajka'], r: [Reaction(energy: 5)], type: 'Śniadanie'),
    ];
    final ra = reactionAssociations(meals);
    expect(ra.single.symptom, 'senność');
    expect(ra.single.rows.single.ingredient, 'makaron');
    final en = energyByType(meals);
    expect(en.first.$1, 'Śniadanie');
    expect(dayTotal(meals, '2026-10-21').kcal, 400);
  });

  test('daty', () {
    expect(shiftDay('2026-03-01', -1), '2026-02-28');
    expect(shiftDay('2026-12-31', 1), '2027-01-01');
    expect(shiftDay('2026-03-29', 1), '2026-03-30'); // zmiana czasu
  });

  test('JSON z odpowiedzi AI', () {
    expect(Ai.parseJson('```json\n{"a":1}\n```')['a'], 1);
    expect(Ai.parseJson('Oto wynik: {"name":"x","items":[]} gotowe')['name'], 'x');
    expect(() => Ai.parseJson('brak'), throwsA(isA<AiError>()));
  });

  test('zapis, odczyt i import z wersji przeglądarkowej', () async {
    final dir = await Directory.systemTemp.createTemp('dziennik');
    final s = AppState()..useDirectory(dir);
    await s.load();
    expect(s.people.single.id, 'me');
    await s.saveMeal(meal('m1', '2026-10-23', '12:00', ['zupa']));
    final p2 = await s.addPerson();
    await s.saveGut(GutEntry(id: 'g1', person: p2.id, date: '2026-10-23', comfort: 3));
    expect(s.meals, isEmpty); // aktywna jest nowa osoba
    expect(s.gut.single.id, 'g1');

    final s2 = AppState()..useDirectory(dir);
    await s2.load();
    expect(s2.people.length, 2);
    expect(s2.activeId, p2.id);
    expect(s2.allMeals.single.items.single.name, 'zupa');

    // format eksportu artefaktu: osoby, posiłki z miniaturą data:image, wpisy o trawieniu
    final png = base64Encode(List<int>.filled(16, 7));
    final web = {
      'people': [
        {'id': 'me', 'name': 'Rafał', 'sex': 'm', 'birthYear': 1980, 'height': 180, 'weight': 85, 'activity': '1.55', 'mode': 'cut', 'manualGoal': 0, 'notes': ''},
        {'id': 'pk', 'name': 'Kasia', 'sex': 'k'},
      ],
      'meals': [
        {
          'id': 'w1', 'person': 'pk', 'date': '2026-10-22', 'time': '18:30', 'ts': 0, 'type': 'Kolacja', 'name': 'Kanapki',
          'items': [{'name': 'chleb', 'grams': 80, 'kcal': 200, 'protein': 7, 'carbs': 38, 'fat': 2}],
          'total': {'kcal': 200}, 'photo': 'data:image/jpeg;base64,$png', 'reactions': [{'after': '1 h', 'energy': 4, 'symptoms': []}],
        }
      ],
      'gut': [
        {'id': 'wg', 'person': 'pk', 'date': '2026-10-23', 'when': 'rano', 'comfort': 2, 'symptoms': [{'name': 'wzdęcia', 'sev': 2}], 'suspects': ['w1']}
      ],
    };
    final sum = await s2.importBytes(utf8.encode(jsonEncode(web)));
    expect(sum.meals, 1);
    expect(s2.people.firstWhere((p) => p.id == 'me').name, 'Rafał');
    expect(s2.people.any((p) => p.id == 'pk'), isTrue);
    final w1 = s2.allMeals.firstWhere((m) => m.id == 'w1');
    expect(w1.photo, isNotNull);
    expect(await (await s2.photoFile(w1.photo))!.readAsBytes(), List<int>.filled(16, 7));
    expect(w1.reactions.single.energy, 4);
    expect(s2.allGut.firstWhere((g) => g.id == 'wg').symptoms.single.sev, 2);

    await s2.deletePerson('pk');
    expect(s2.allMeals.any((m) => m.person == 'pk'), isFalse);
    expect(s2.allGut.any((g) => g.person == 'pk'), isFalse);
    await dir.delete(recursive: true);
  });
}
