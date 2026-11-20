import 'dart:convert';

import 'package:dziennik_talerza/fodmap.dart';
import 'package:dziennik_talerza/gas.dart';
import 'package:dziennik_talerza/koofr_backup.dart';
import 'package:dziennik_talerza/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koofr_backup_ui/koofr_backup_ui.dart';

/// Kontrakt wymiany (WYMIANA.md w repozytorium Rytmu Snu) z perspektywy Dziennika talerza.
void main() {
  final sources = [for (final s in DziennikExchange.instance.sources) s.$1];

  test('wysyłane czynniki-posilki są zgodne z kontraktem', () {
    Meal m(String date, String time, String name, List<String> items) => Meal(
        id: newId('m'), person: 'me', date: date, time: time, type: 'inny', name: name,
        items: [for (final i in items) FoodItem(name: i)]);
    final f = mealFactors([
      m('2026-11-19', '08:00', 'Śniadanie', ['kawa z mlekiem', 'bułka']),
      m('2026-11-19', '20:30', 'Kolacja', ['piwo', 'pizza']),
      m('2026-11-20', '13:00', 'Obiad', ['zupa']),
    ], 'me');
    expect(sprawdzWymiane('czynniki-posilki', utf8.encode(jsonEncode(f))), isEmpty);
  });

  test('każdy pobierany plik wczytuje się bez wyjątku (nieznany jest pomijany)', () {
    final pulled = przykladyDlaZrodel(sources);
    expect(pulled, containsAll(['rytm-snu', 'kreska-ff']));
    for (final n in pulled) {
      final text = wymianaPrzyklady[n]!;
      switch (detectGasFile(text)) {
        case GasFileKind.night:
          expect(parseNightExchange('me', text).events, isNotEmpty, reason: n);
        case GasFileKind.kreskaJson:
          parseKreskaExchange('me', text);
        default:
          expect(n, isIn(['rytm-snu-rytm']), reason: '$n nie został rozpoznany');
      }
    }
  });

  test('FF z Rytmu Snu bez odrzuconych, licznik z Kreski z sumami dni', () {
    final night = parseNightExchange('me', wymianaPrzyklady['rytm-snu']!);
    expect(night.events, hasLength(2)); // verified: null liczy się (nieodrzucone)
    final k = parseKreskaExchange('me', wymianaPrzyklady['kreska-ff']!);
    expect(k.label, 'FF');
    // plik zdarzenia (kreska-z-…) nie jest licznikiem FF — przy domyślnym wyborze licznika jest pomijany
    expect(guessGasCounter([parseKreskaExchange('me', wymianaPrzyklady['kreska-z-afib']!).label]), isNull);
  });
}
