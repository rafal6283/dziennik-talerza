import 'dart:io';

import 'package:dziennik_talerza/calc.dart';
import 'package:dziennik_talerza/extras.dart';
import 'package:dziennik_talerza/main.dart' show app;
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
}
