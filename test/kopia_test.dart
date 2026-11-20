import 'dart:io';

import 'package:dziennik_talerza/koofr_backup.dart';
import 'package:dziennik_talerza/main.dart' show app;
import 'package:dziennik_talerza/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koofr_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kopia na Koofr → nowy telefon (tylko kod odzyskiwania) → przywrócenie: posiłki i zdjęcia wracają.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('przywrócenie kopii na czystym telefonie', () async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null; // serwer WebDAV w pamięci potrzebuje prawdziwego HttpClient
    final dir = await Directory.systemTemp.createTemp('dziennik');
    app.useDirectory(dir);
    await app.load();
    await app.saveMeal(Meal(
        id: 'm1', person: 'me', date: '2026-11-19', time: '13:00', type: 'Obiad', name: 'Pierogi',
        items: [FoodItem(name: 'pierogi', grams: 300, kcal: 600)]));
    await Directory('${dir.path}/photos').create();
    await File('${dir.path}/photos/m1.jpg').writeAsBytes([1, 2, 3]);
    final restored = await kopiaAdapteraNaNowyTelefon(DziennikBackup());

    // „nowy telefon”: pusty katalog danych
    final fresh = await Directory.systemTemp.createTemp('dziennik-nowy');
    app.useDirectory(fresh);
    app.allMeals = [];

    await DziennikBackup().import(restored, (_) {});
    expect(app.allMeals.map((m) => m.name), ['Pierogi']);
    expect(await File('${fresh.path}/photos/m1.jpg').readAsBytes(), [1, 2, 3]);
  });
}
