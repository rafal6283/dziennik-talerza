import 'dart:io';

import 'package:dziennik_talerza/extras.dart';
import 'package:dziennik_talerza/gas.dart';
import 'package:dziennik_talerza/store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kopia/wymiana Koofr w tle działa w osobnym procesie z własnym obrazem danych – jej zapis nie może
/// skasować wpisów dodanych w tym czasie w aplikacji (zgłoszenie: widać 3 z 5 leków).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MedEntry med(String id, String name) => MedEntry(id: id, person: 'me', date: '2026-11-21', time: '08:00', name: name);

  test('zapis procesu w tle nie kasuje leków dodanych w aplikacji', () async {
    final dir = await Directory.systemTemp.createTemp('dziennik-wsp');
    final ui = AppState()..useDirectory(dir);
    await ui.load();
    await ui.saveMed(med('a', 'Witamina D'));
    final bg = AppState()..useDirectory(dir); // proces w tle: wczytał dane, gdy był jeden lek
    await bg.load();
    for (final (id, n) in [('b', 'Magnez'), ('c', 'Omega-3'), ('d', 'Probiotyk'), ('e', 'IPP')]) {
      await ui.saveMed(med(id, n));
    }
    await bg.setGas(GasSource(person: 'me', source: 'gasNight')); // wymiana z Rytmu Snu zapisuje plik
    final check = AppState()..useDirectory(dir);
    await check.load();
    expect(check.medsOn('2026-11-21').length, 5);
    expect(check.gasSources.length, 1);

    // usunięcie w aplikacji nie wraca po kolejnym zapisie procesu w tle
    await ui.deleteMed('a');
    await bg.setGas(GasSource(person: 'me', source: 'gasNight'));
    await ui.syncFromDisk();
    final again = AppState()..useDirectory(dir);
    await again.load();
    expect(again.medsOn('2026-11-21').map((m) => m.name), isNot(contains('Witamina D')));
    expect(again.medsOn('2026-11-21').length, 4);
    expect(ui.gasSources.length, 1); // aplikacja widzi wiatry pobrane w tle
  });
}
