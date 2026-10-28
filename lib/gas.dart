// Wiatry z innych aplikacji użytkownika:
// - Kreska: eksport JSON „wymiana-zdarzen” (każde kliknięcie z godziną) albo starszy CSV (typ;nazwa;data;wartość;…) – tylko sumy dni,
// - Rytm Snu (dawniej Nocny Licznik): plik „wymiana-zdarzen” v1 (JSON) – noce z nagraniem i godziny wykrytych wiatrów.
// Każdy plik zawiera całą historię źródła, więc ponowny import zastępuje poprzedni.

import 'dart:convert';

import 'calc.dart';
import 'models.dart';

const gasKreska = 'kreska';
/// Rytm Snu — zapisywany pod dawnym identyfikatorem; pliki mają teraz źródło "rytm-snu".
const gasNight = 'nocny-licznik';
const gasNightNew = 'rytm-snu';
bool isNightSource(Object? s) => s == gasNight || s == gasNightNew;

class GasSource {
  final String person;
  final String source; // gasKreska | gasNight
  final String label; // nazwa licznika w Kresce
  final int importedAt;
  final Map<String, int> days; // Kreska: data → liczba
  final String? from, to; // zakres dni pokrytych przez plik Kreski
  final List<(int, int)> windows; // Rytm Snu: noce (ms)
  final List<int> events; // wiatry z godziną (ms): Rytm Snu bez odrzuconych, Kreska z eksportu JSON

  GasSource({
    required this.person,
    required this.source,
    this.label = '',
    int? importedAt,
    Map<String, int>? days,
    this.from,
    this.to,
    List<(int, int)>? windows,
    List<int>? events,
  })  : importedAt = importedAt ?? DateTime.now().millisecondsSinceEpoch,
        days = days ?? {},
        windows = windows ?? [],
        events = events ?? [];

  String get id => '$person:$source';
  String get sourceLabel => source == gasKreska ? 'Kreska' : 'Rytm Snu';

  factory GasSource.fromJson(Map<String, dynamic> j) => GasSource(
        person: '${j['person'] ?? 'me'}',
        source: '${j['source'] ?? ''}',
        label: '${j['label'] ?? ''}',
        importedAt: (j['importedAt'] as num?)?.toInt(),
        days: {
          if (j['days'] is Map)
            for (final e in (j['days'] as Map).entries)
              if (e.value is num) '${e.key}': (e.value as num).toInt()
        },
        from: j['from'] as String?,
        to: j['to'] as String?,
        windows: [
          for (final w in (j['windows'] is List ? j['windows'] as List : const []))
            if (w is List && w.length == 2 && w[0] is num && w[1] is num) ((w[0] as num).toInt(), (w[1] as num).toInt())
        ],
        events: [for (final e in (j['events'] is List ? j['events'] as List : const [])) if (e is num) e.toInt()],
      );

  Map<String, dynamic> toJson() => {
        'person': person,
        'source': source,
        'label': label,
        'importedAt': importedAt,
        if (days.isNotEmpty) 'days': days,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (windows.isNotEmpty) 'windows': [for (final w in windows) [w.$1, w.$2]],
        if (events.isNotEmpty) 'events': events,
      };
}

// ---------- rozpoznanie i odczyt plików ----------

enum GasFileKind { kreska, kreskaJson, night, unknown }

GasFileKind detectGasFile(String text) {
  final t = text.replaceFirst('﻿', '').trimLeft();
  if (t.startsWith('typ;nazwa;data')) return GasFileKind.kreska;
  if (t.startsWith('{')) {
    try {
      final j = jsonDecode(t);
      if (j is Map && j['format'] == 'wymiana-zdarzen' && isNightSource(j['source'])) return GasFileKind.night;
      if (j is Map && j['format'] == 'wymiana-zdarzen' && j['source'] == gasKreska) return GasFileKind.kreskaJson;
    } catch (_) {}
  }
  return GasFileKind.unknown;
}

List<String> _csvFields(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var q = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (q) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          q = false;
        }
      } else {
        b.write(ch);
      }
    } else if (ch == '"') {
      q = true;
    } else if (ch == ';') {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString());
  return out;
}

/// Kreska CSV → licznik → (data → suma). Wiersze „zdarzenie” są pomijane.
Map<String, Map<String, int>> parseKreskaCsv(String text) {
  final out = <String, Map<String, int>>{};
  final lines = text.replaceFirst('﻿', '').split(RegExp(r'\r?\n'));
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final f = _csvFields(line);
    if (f.length < 4 || f[0] != 'licznik') continue;
    final date = f[2].trim();
    final v = int.tryParse(f[3].trim());
    if (date.length != 10 || v == null) continue;
    final m = out.putIfAbsent(f[1].trim(), () => {});
    m[date] = (m[date] ?? 0) + v;
  }
  return out;
}

/// Nazwa licznika z wiatrami: „FF” albo coś podobnego, inaczej null.
String? guessGasCounter(Iterable<String> names) {
  final list = names.toList();
  for (final n in list) {
    if (n.trim().toLowerCase() == 'ff') return n;
  }
  for (final n in list) {
    final l = n.toLowerCase();
    if (l.contains('wiatr') || l.contains('gaz') || l.contains('bąk') || l.contains('bak') || l.contains('fart')) return n;
  }
  return null;
}

GasSource kreskaSource(String person, String counter, Map<String, int> days, {String? fileDate}) {
  final keys = days.keys.toList()..sort();
  final to = [if (keys.isNotEmpty) keys.last, if (fileDate != null) fileDate]..sort();
  return GasSource(person: person, source: gasKreska, label: counter, days: days, from: keys.isEmpty ? null : keys.first, to: to.isEmpty ? null : to.last);
}

/// Kreska JSON („Eksportuj wpisy z godzinami”) → kliknięcia z godziną i sumy dni.
GasSource parseKreskaExchange(String person, String text) {
  final j = jsonDecode(text.replaceFirst('\uFEFF', ''));
  if (j is! Map || j['format'] != 'wymiana-zdarzen' || j['source'] != gasKreska) {
    throw const FormatException('To nie jest plik eksportu z Kreski');
  }
  if (j['version'] != 1) throw const FormatException('Nieobsługiwana wersja pliku z Kreski');
  final days = <String, int>{
    for (final d in (j['day_totals'] is List ? j['day_totals'] as List : const []))
      if (d is Map && d['date'] is String && d['total'] is num) d['date'] as String: (d['total'] as num).toInt()
  };
  final events = <int>[
    for (final e in (j['events'] is List ? j['events'] as List : const []))
      if (e is Map && e['start'] is num) (e['start'] as num).toInt()
  ]..sort();
  String? from;
  final ws = j['windows'] is List ? j['windows'] as List : const [];
  if (ws.isNotEmpty && ws.first is Map && (ws.first as Map)['start'] is num) {
    from = isoDate(DateTime.fromMillisecondsSinceEpoch(((ws.first as Map)['start'] as num).toInt()));
  }
  final keys = days.keys.toList()..sort();
  from ??= keys.isEmpty ? null : keys.first;
  final exported = j['exported_at'] is num ? isoDate(DateTime.fromMillisecondsSinceEpoch((j['exported_at'] as num).toInt())) : null;
  final to = [if (keys.isNotEmpty) keys.last, if (exported != null) exported]..sort();
  return GasSource(
    person: person,
    source: gasKreska,
    label: '${j['counter'] ?? 'licznik'}',
    days: days,
    from: from,
    to: to.isEmpty ? null : to.last,
    events: events,
  );
}

/// Rytm Snu → noce i wiatry (bez odrzuconych przez użytkownika).
GasSource parseNightExchange(String person, String text) {
  final j = jsonDecode(text.replaceFirst('﻿', ''));
  if (j is! Map || j['format'] != 'wymiana-zdarzen' || !isNightSource(j['source'])) {
    throw const FormatException('To nie jest plik eksportu z Rytmu Snu');
  }
  if (j['version'] != 1) throw const FormatException('Nieobsługiwana wersja pliku z Rytmu Snu');
  final windows = <(int, int)>[
    for (final w in (j['windows'] is List ? j['windows'] as List : const []))
      if (w is Map && w['start'] is num && w['end'] is num) ((w['start'] as num).toInt(), (w['end'] as num).toInt())
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final events = <int>[
    for (final e in (j['events'] is List ? j['events'] as List : const []))
      if (e is Map && e['type'] == 'fart' && e['start'] is num && e['verified'] != false) (e['start'] as num).toInt()
  ]..sort();
  return GasSource(person: person, source: gasNight, windows: windows, events: events);
}

// ---------- obliczenia ----------

/// Dzień, do którego należy noc: zasypianie przed południem następnego dnia liczy się do dnia poprzedniego.
String nightDate(int startMs) => isoDate(DateTime.fromMillisecondsSinceEpoch(startMs).subtract(const Duration(hours: 12)));

class GasSeries {
  final GasSource? kreska;
  final GasSource? night;
  final Map<String, int> _nights = {};

  GasSeries(Iterable<GasSource> sources)
      : kreska = sources.where((s) => s.source == gasKreska).firstOrNull,
        night = sources.where((s) => s.source == gasNight).firstOrNull {
    final n = night;
    if (n != null) {
      var i = 0;
      final ev = n.events;
      for (final w in n.windows) {
        while (i < ev.length && ev[i] < w.$1) {
          i++;
        }
        var c = 0;
        var k = i;
        while (k < ev.length && ev[k] <= w.$2) {
          c++;
          k++;
        }
        final d = nightDate(w.$1);
        _nights[d] = (_nights[d] ?? 0) + c;
      }
    }
  }

  bool get any => kreska != null || night != null;

  /// Wiatry w ciągu dnia z Kreski (0 w dniach bez wpisu w zakresie pliku), null poza zakresem.
  int? day(String date) {
    final k = kreska;
    if (k == null || k.from == null || k.to == null) return null;
    if (date.compareTo(k.from!) < 0 || date.compareTo(k.to!) > 0) return null;
    return k.days[date] ?? 0;
  }

  /// Wiatry w nocy po danym dniu z Rytmu Snu, null gdy tej nocy nie nagrywano.
  int? nightAfter(String date) => _nights[date];

  /// Kreska z godzinami (eksport JSON).
  bool get kreskaTimed => (kreska?.events.isNotEmpty ?? false);

  /// Kliknięcia z Kreski od [fromMs] do końca następnego dnia po [date]; null poza zakresem pliku.
  int? kreskaAfter(String date, int fromMs) {
    final k = kreska;
    final next = shiftDay(date, 1);
    if (k == null || day(date) == null || day(next) == null) return null;
    final end = DateTime.parse('${shiftDay(next, 1)}T00:00:00').millisecondsSinceEpoch;
    return k.events.where((t) => t >= fromMs && t < end).length;
  }

  /// Skutek jedzenia z dnia D: noc po D + Kreska. Z godzinami: od 2 h po pierwszym posiłku dnia do końca
  /// następnego dnia; bez godzin: cały następny dzień (reakcje bywają opóźnione o 6–30 h).
  int? outcome(String date, {int? firstMealMs}) {
    final n = nightAfter(date);
    final d = kreskaTimed && firstMealMs != null ? kreskaAfter(date, firstMealMs + 2 * 3600 * 1000) : day(shiftDay(date, 1));
    if (n == null && d == null) return null;
    return (n ?? 0) + (d ?? 0);
  }

  String get outcomeLabel => [
        if (night != null) 'noc po dniu jedzenia',
        if (kreska != null) kreskaTimed ? 'Kreska od 2 h po pierwszym posiłku do końca następnego dnia' : 'Kreska: następny dzień',
      ].join(' + ');
}

class GasAssoc {
  final String ingredient;
  final int days; // dni, w które jadłeś ten składnik (z danymi o wiatrach)
  final double avg; // średnio wiatrów po takich dniach
  const GasAssoc(this.ingredient, this.days, this.avg);
}

class GasAssocResult {
  final int days; // dni z posiłkami i danymi o wiatrach
  final double base; // średnia po wszystkich takich dniach
  final List<GasAssoc> rows;
  const GasAssocResult(this.days, this.base, this.rows);
  double ratio(GasAssoc a) => base <= 0 ? 0 : a.avg / base;
  bool flagged(GasAssoc a) => a.days >= 3 && ratio(a) >= 1.3;
}

GasAssocResult gasAssociations(List<Meal> meals, GasSeries s, {int top = 8}) {
  final byDay = <String, Set<String>>{};
  final firstMeal = <String, int>{};
  for (final m in meals) {
    byDay.putIfAbsent(m.date, () => {}).addAll(ingredientsOf([m]));
    final t = m.ts;
    if (!firstMeal.containsKey(m.date) || t < firstMeal[m.date]!) firstMeal[m.date] = t;
  }
  final outcomes = <String, int>{
    for (final d in byDay.keys)
      if (s.outcome(d, firstMealMs: firstMeal[d]) case final o?) d: o
  };
  if (outcomes.isEmpty) return const GasAssocResult(0, 0, []);
  final base = avg(outcomes.values);
  final per = <String, List<int>>{};
  for (final e in outcomes.entries) {
    for (final i in byDay[e.key]!) {
      per.putIfAbsent(i, () => []).add(e.value);
    }
  }
  final rows = [for (final e in per.entries) if (e.value.length >= 2) GasAssoc(e.key, e.value.length, avg(e.value))]
    ..sort((a, b) => b.avg != a.avg ? b.avg.compareTo(a.avg) : b.days.compareTo(a.days));
  return GasAssocResult(outcomes.length, base, rows.take(top).toList());
}

/// Linie do analizy AI: dzień → wiatry.
String gasLines(GasSeries s, String since, String until) {
  if (!s.any) return '';
  final out = <String>[];
  for (var d = since; d.compareTo(until) <= 0; d = shiftDay(d, 1)) {
    final day = s.day(d), n = s.nightAfter(d);
    if (day == null && n == null) continue;
    out.add('$d: ${[if (day != null) 'w ciągu dnia $day (Kreska)', if (n != null) 'w nocy po tym dniu $n (Rytm Snu)'].join(', ')}');
  }
  return out.join('\n');
}
