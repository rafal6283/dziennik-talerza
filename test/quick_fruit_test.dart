import 'package:dziennik_talerza/food_table.dart';
import 'package:dziennik_talerza/ui/fruit_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('każdy szybki owoc ma wartości w tabeli', () {
    final names = {for (final r in foodTable()) r.name};
    for (final f in quickFruits) {
      expect(names, contains(f.table), reason: f.label);
      final it = fruitItem(f, 2);
      expect(it.grams, f.grams * 2);
      expect(it.kcal, greaterThan(0));
    }
  });
}
