import 'package:dziennik_talerza/food_table.dart';
import 'package:dziennik_talerza/ui/quick_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final names = {for (final r in foodTable()) r.name};

  test('każda pozycja szybkiego dodawania ma wartości w tabeli', () {
    for (final c in quickCategories) {
      for (final f in c.items) {
        expect(names, contains(f.table), reason: '${c.label}: ${f.label}');
        final it = quickItem(f, 2);
        expect(it.grams, f.grams * 2);
        expect(it.kcal, greaterThan(0));
      }
    }
    for (final b in sandBases) {
      expect(names, contains(b.table), reason: b.label);
    }
    for (final t in sandToppings) {
      if (t.table.isNotEmpty) expect(names, contains(t.table), reason: t.label);
    }
  });

  test('kanapka z kajzerki: podwójny dodatek i masło, scalanie pozycji', () {
    final kajzerka = sandBases.firstWhere((b) => b.label == 'Kajzerka');
    final szynka = sandToppings.firstWhere((t) => t.label == 'Szynka');
    final its = sandwichItems(kajzerka, true, {'pomidor'}, szynka, 2);
    final g = {for (final i in its) i.name: i.grams};
    expect(g['bułka pszenna'], 100);
    expect(g['masło'], 20);
    expect(g['szynka'], 80);
    expect(g['pomidor'], 120);
    final merged = mergeItems([...its, ...its]);
    expect(merged.length, its.length);
    expect(merged.firstWhere((i) => i.name == 'masło').grams, 40);
  });
}
