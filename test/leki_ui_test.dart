import 'dart:convert';
import 'dart:io';

import 'package:dziennik_talerza/calc.dart';
import 'package:dziennik_talerza/extras.dart';
import 'package:dziennik_talerza/main.dart';
import 'package:dziennik_talerza/models.dart';
import 'package:dziennik_talerza/ui/extras_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zgłoszenie: dodany przez „Dodaj” lek nie pojawia się na liście.
void main() {
  testWidgets('lek dodany formularzem widać na liście dnia', (t) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await t.runAsync(() => Directory.systemTemp.createTemp('dziennik-leki'));
    app.useDirectory(dir!);
    await t.runAsync(app.load);
    final day = todayIso();
    for (final n in ['Potazek', 'Diosmina', 'Maślan sodu']) {
      await t.runAsync(() => app.saveMed(MedEntry(id: newId('med'), person: app.active.id, date: day, time: '07:30', name: n)));
    }
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(listenable: app, builder: (_, __) => ListView(children: [MedsCard(day: day)])),
      ),
    ));
    expect(find.text('Leki i suplementy · 3'), findsOneWidget);
    await t.tap(find.text('Dodaj'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Nazwa'), 'Kwas kaprylowy');
    await t.pumpAndSettle();
    await t.tap(find.text('Zapisz'));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    expect(app.medsOn(day).map((m) => m.name), contains('Kwas kaprylowy'));
    expect(find.textContaining('Kwas kaprylowy'), findsOneWidget);
    expect(find.text('Leki i suplementy · 4'), findsOneWidget);
  });

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
    await t.binding.setSurfaceSize(const Size(400, 3000));
    await t.pumpWidget(const DziennikApp());
    await t.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await t.pumpAndSettle();
    final dodaj = find.descendant(of: find.byType(MedsCard), matching: find.text('Dodaj'));
    debugPrint('LEKI: loaded=${app.loaded} meds=${app.medsOn(day).length} texts=${find.byType(Text).evaluate().take(40).map((e) => (e.widget as Text).data).toList()}');
    expect(find.text('Leki i suplementy · 3'), findsOneWidget);
    await t.tap(dodaj);
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Nazwa'), 'Kwas kaprylowy');
    await t.pumpAndSettle();
    await t.tap(find.text('Zapisz'));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    expect(app.medsOn(day).map((m) => m.name), contains('Kwas kaprylowy'));
    expect(find.text('Leki i suplementy · 4'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.binding.setSurfaceSize(null);
  });
}
