import 'dart:convert';
import 'dart:io';

import 'package:dziennik_talerza/calc.dart';
import 'package:dziennik_talerza/main.dart';
import 'package:dziennik_talerza/ui/extras_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zgłoszenie z telefonu: lek dodany przez „Dodaj” nie pojawia się (z historią leków z poprzedniego dnia).
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('cała aplikacja: Dodaj → Kwas kaprylowy → Zapisz', (t) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await t.runAsync(() => Directory.systemTemp.createTemp('dziennik-leki2'));
    final day = todayIso(), y = shiftDay(day, -1);
    final meds = [
      for (final d in [y, day])
        for (final n in ['Potazek', 'Diosmina', 'Maślan sodu Sodium'])
          {'id': 'm$d$n', 'person': 'me', 'date': d, 'time': '07:30', 'name': n, 'dose': '', 'kind': 'suplement'},
      {'id': 'kk', 'person': 'me', 'date': y, 'time': '08:00', 'name': 'Kwas kaprylowy', 'dose': '', 'kind': 'suplement'},
    ];
    await t.runAsync(() => File('${dir!.path}/dziennik.json').writeAsString(jsonEncode({
          'app': 'dziennik-talerza', 'version': 1, 'active': 'me',
          'people': [{'id': 'me', 'name': 'Ja', 'sex': 'm', 'age': 40, 'height': 180, 'weight': 80}],
          'meals': [], 'gut': [], 'meds': meds,
        })));
    app.useDirectory(dir!);
    await t.binding.setSurfaceSize(const Size(400, 860));
    await t.pumpWidget(const DziennikApp());
    await t.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await _settle(t);
    final dodaj = find.descendant(of: find.byType(MedsCard), matching: find.text('Dodaj'));
    await t.ensureVisible(dodaj);
    await _settle(t);
    debugPrint('LEKI: loaded=${app.loaded} meds=${app.medsOn(day).length} texts=${find.byType(Text).evaluate().take(40).map((e) => (e.widget as Text).data).toList()}');
    expect(find.text('Leki i suplementy · 3'), findsOneWidget);
    await t.tap(dodaj);
    await _settle(t);
    await t.enterText(find.widgetWithText(TextField, 'Nazwa'), 'Kwas kaprylowy');
    await _settle(t);
    await t.tap(find.text('Zapisz'));
    await _settle(t);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await _settle(t);
    expect(app.medsOn(day).map((m) => m.name), contains('Kwas kaprylowy'));
    expect(find.text('Leki i suplementy · 4'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.binding.setSurfaceSize(null);
  });
}
