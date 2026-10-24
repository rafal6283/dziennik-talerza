import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dziennik_talerza/main.dart';
import 'package:dziennik_talerza/ui/gut_form.dart';
import 'package:dziennik_talerza/ui/meal_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ekrany otwierają się bez błędów', (t) async {
    final dir = await t.runAsync(() => Directory.systemTemp.createTemp('dziennik_ui'));
    app.useDirectory(dir!);
    await t.binding.setSurfaceSize(const Size(400, 860));
    await t.pumpWidget(const DziennikApp());
    await t.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await t.pumpAndSettle();

    expect(find.text('Trawienie'), findsOneWidget);
    expect(find.text('Posiłek'), findsOneWidget);

    await t.tap(find.text('Posiłek'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    expect(find.byType(MealForm), findsOneWidget);
    await t.tap(find.text('Składnik'));
    await t.pumpAndSettle();
    expect(find.text('Składnik 1'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();

    await t.tap(find.text('Wpis'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    expect(find.byType(GutForm), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();

    await t.tap(find.text('Wzorce'));
    await t.pumpAndSettle();
    expect(find.text('Kalorie dzień po dniu'), findsOneWidget);

    await t.tap(find.text('Profil'));
    await t.pumpAndSettle();
    expect(find.text('Profil: Ja'), findsOneWidget);

    expect(t.takeException(), isNull);
    await t.binding.setSurfaceSize(null);
  });
}
