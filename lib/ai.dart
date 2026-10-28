// Claude przez API Anthropic, z własnym kluczem użytkownika (Ustawienia → Rozpoznawanie AI).
// Bez klucza aplikacja działa normalnie, tylko bez rozpoznawania i analizy.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'calc.dart';
import 'food_table.dart';
import 'gas.dart';
import 'local_ai.dart';
import 'models.dart';

const aiModels = [
  ('claude-sonnet-5-5', 'Sonnet – dokładny, zalecany'),
  ('claude-haiku-5-5', 'Haiku – szybki i tańszy'),
  ('claude-opus-5-5', 'Opus – najdokładniejszy, najdroższy'),
];

class AiError implements Exception {
  final String message;
  final String? raw; // surowa odpowiedź modelu (do podglądu, gdy nie dała się odczytać)
  const AiError(this.message, [this.raw]);
  @override
  String toString() => message;
}

class MealGuess {
  final String name;
  final List<FoodItem> items;
  final String confidence;
  final String note;
  const MealGuess(this.name, this.items, this.confidence, this.note);
}

class GutGuess {
  final int comfort;
  final List<GutSymptom> symptoms;
  final int bristol;
  final String? when;
  final String note;
  const GutGuess(this.comfort, this.symptoms, this.bristol, this.when, this.note);
}

class ReactionGuess {
  final int energy, satiety;
  final List<String> symptoms;
  final String? after;
  final String note;
  const ReactionGuess(this.energy, this.satiety, this.symptoms, this.after, this.note);
}

/// Kto rozpoznaje: 'local' – Gemma na telefonie (darmowe), 'claude' – API Anthropic (płatne), 'off'.
const aiProviders = [
  ('local', 'Na telefonie – darmowe'),
  ('claude', 'Claude – płatne (klucz API)'),
  ('off', 'Wyłączone'),
];

class Ai {
  static const _kKey = 'ai_key';
  static const _kModel = 'ai_model';
  static const _kProvider = 'ai_provider';
  static http.Client client = http.Client();

  static Future<String> provider() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kProvider);
    if (v != null) return v;
    // starsze wersje: kto miał klucz, zostaje przy Claude
    return (p.getString(_kKey) ?? '').trim().isNotEmpty ? 'claude' : 'local';
  }

  static Future<void> setProvider(String v) async => (await SharedPreferences.getInstance()).setString(_kProvider, v);
  static Future<bool> isLocal() async => (await provider()) == 'local';

  static Future<String?> key() async {
    final k = (await SharedPreferences.getInstance()).getString(_kKey);
    return (k == null || k.trim().isEmpty) ? null : k.trim();
  }

  /// Czy rozpoznawanie jest gotowe do użycia.
  static Future<bool> enabled() async => switch (await provider()) {
        'local' => await LocalAi.ready(),
        'claude' => (await key()) != null,
        _ => false,
      };

  /// Podpowiedź, gdy rozpoznawanie nie jest gotowe.
  static Future<String> setupHint() async => switch (await provider()) {
        'local' => 'Pobierz darmowy model w Ustawieniach → Rozpoznawanie AI.',
        'claude' => 'Dodaj klucz API w Ustawieniach → Rozpoznawanie AI.',
        _ => 'Rozpoznawanie jest wyłączone w Ustawieniach.',
      };

  /// Wspólne wejście: tekst + opcjonalne zdjęcie, wybrany dostawca.
  static Future<String> complete(String prompt, {Uint8List? jpeg, int maxTokens = 1500}) async {
    final prov = await provider();
    if (prov == 'local') {
      if (!await LocalAi.ready()) throw const AiError('Pobierz darmowy model w Ustawieniach → Rozpoznawanie AI.');
      try {
        final t = await LocalAi.ask(prompt, image: jpeg, maxOutputTokens: maxTokens > 1024 ? 1024 : maxTokens);
        if (t.isEmpty) throw const AiError('Model nie zwrócił odpowiedzi. Spróbuj ponownie.');
        return t;
      } on AiError {
        rethrow;
      } catch (e) {
        final m = '$e';
        if (m.contains('memory') || m.contains('OutOfMemory') || m.contains('killed')) {
          throw const AiError('Za mało pamięci na model. Zamknij inne aplikacje i spróbuj ponownie.');
        }
        throw AiError('Model na telefonie nie zadziałał ($m). Jeśli to się powtarza, usuń i pobierz model ponownie w Ustawieniach.');
      }
    }
    if (prov == 'off') throw const AiError('Rozpoznawanie jest wyłączone w Ustawieniach.');
    return _ask([
      if (jpeg != null) {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(jpeg)}},
      {'type': 'text', 'text': prompt},
    ], maxTokens: maxTokens);
  }
  static Future<void> setKey(String? k) async {
    final p = await SharedPreferences.getInstance();
    if (k == null || k.trim().isEmpty) {
      await p.remove(_kKey);
    } else {
      await p.setString(_kKey, k.trim());
    }
  }

  static Future<String> model() async => (await SharedPreferences.getInstance()).getString(_kModel) ?? aiModels.first.$1;
  static Future<void> setModel(String m) async => (await SharedPreferences.getInstance()).setString(_kModel, m);

  static Future<String> _ask(List<Map<String, dynamic>> content, {int maxTokens = 1500, String? keyOverride}) async {
    final k = keyOverride ?? await key();
    if (k == null) throw const AiError('Dodaj klucz API w Ustawieniach, żeby korzystać z rozpoznawania.');
    final http.Response r;
    try {
      r = await client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {'x-api-key': k, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
            body: jsonEncode({
              'model': await model(),
              'max_tokens': maxTokens,
              'messages': [
                {'role': 'user', 'content': content}
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw const AiError('Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.');
    }
    if (r.statusCode != 200) {
      String msg = '';
      try {
        msg = '${(jsonDecode(utf8.decode(r.bodyBytes)) as Map)['error']?['message'] ?? ''}';
      } catch (_) {}
      throw AiError(switch (r.statusCode) {
        401 => 'Klucz API jest nieprawidłowy. Sprawdź go w Ustawieniach.',
        403 => 'Ten klucz API nie ma dostępu do wybranego modelu.',
        404 => 'Wybrany model nie jest dostępny. Zmień model w Ustawieniach.',
        429 => 'Za dużo zapytań albo wyczerpany limit konta. Spróbuj za chwilę.',
        400 when msg.contains('credit') => 'Brak środków na koncie API (console.anthropic.com → Billing).',
        529 || 500 || 502 || 503 => 'Serwer jest przeciążony. Spróbuj za chwilę.',
        _ => 'Błąd ${r.statusCode}${msg.isNotEmpty ? ': $msg' : ''}',
      });
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
    final parts = (j['content'] as List? ?? const []).whereType<Map>().where((c) => c['type'] == 'text').map((c) => '${c['text']}');
    final text = parts.join('\n').trim();
    if (text.isEmpty) throw const AiError('Pusta odpowiedź. Spróbuj ponownie.');
    return text;
  }

  /// Wyciąga jeden obiekt JSON z odpowiedzi (całość, blok ``` albo od pierwszej { do ostatniej }).
  /// Wyciąga obiekt JSON z odpowiedzi modelu – także gdy jest w bloku ```, ma komentarze, przecinki na końcu,
  /// polskie przecinki dziesiętne albo została ucięta w połowie (mały model na telefonie).
  static Map<String, dynamic> parseJson(String text) {
    final v = tryParseJson(text);
    if (v != null) return v;
    throw AiError('Odpowiedź przyszła w złym formacie. Spróbuj jeszcze raz.', text);
  }

  static Map<String, dynamic>? tryParseJson(String text) {
    var t = text.trim();
    final fence = RegExp(r'```(?:json|JSON)?\s*([\s\S]*?)(```|$)').firstMatch(t);
    if (fence != null && fence.group(1)!.contains(RegExp(r'[{\[]'))) t = fence.group(1)!.trim();
    final start = t.indexOf(RegExp(r'[{\[]'));
    if (start < 0) return null;
    t = t.substring(start);
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is List) return {'items': v};
      return null;
    }

    String clean(String x) => x
        .replaceAll(RegExp(r'//[^\n"]*\n'), '\n') // komentarze
        .replaceAll(RegExp('[„”“]'), '"')
        .replaceAllMapped(RegExp(r'(:\s*-?\d+),(\d+)'), (m) => '${m[1]}.${m[2]}') // 1,5 → 1.5
        .replaceAllMapped(RegExp(r'(:\s*-?\d+(?:\.\d+)?)\s*(?:g|kcal|ml)\b'), (m) => m[1]!) // „120 g” → 120
        .replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!); // przecinek na końcu
    for (final cand in [t, clean(t)]) {
      try {
        if (asMap(jsonDecode(cand)) case final m?) return m;
      } catch (_) {}
      // nadmiar tekstu po JSON-ie
      final end = cand.lastIndexOf(RegExp(r'[}\]]'));
      if (end > 0) {
        try {
          if (asMap(jsonDecode(cand.substring(0, end + 1))) case final m?) return m;
        } catch (_) {}
      }
    }
    // ucięta odpowiedź: tniemy na kolejnych „}” od końca i domykamy nawiasy
    final c = clean(t);
    var tries = 0;
    for (var pos = c.lastIndexOf('}'); pos > 0 && tries < 60; pos = c.lastIndexOf('}', pos - 1), tries++) {
      final head = c.substring(0, pos + 1);
      final stack = <String>[];
      var inStr = false, esc = false;
      for (final ch in head.split('')) {
        if (inStr) {
          if (esc) {
            esc = false;
          } else if (ch == r'\') {
            esc = true;
          } else if (ch == '"') {
            inStr = false;
          }
          continue;
        }
        if (ch == '"') inStr = true;
        if (ch == '{' || ch == '[') stack.add(ch);
        if ((ch == '}' || ch == ']') && stack.isNotEmpty) stack.removeLast();
      }
      if (inStr) continue;
      final closed = head + stack.reversed.map((x) => x == '{' ? '}' : ']').join();
      try {
        if (asMap(jsonDecode(closed.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!))) case final m? when (m['items'] is List)) return m;
      } catch (_) {}
    }
    return null;
  }

  /// Ostatnia deska ratunku: linie typu „- ryż: 150 g” albo „ryż – 150g, 195 kcal”.
  static List<FoodItem> itemsFromLines(String text) {
    final out = <FoodItem>[];
    final re = RegExp(r'^[\s\-*•\d.)]*([A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż][^:\n\d]{1,60}?)\s*[:\-–(]?\s*(\d+(?:[.,]\d+)?)\s*(?:g|ml|gram)\b(?:[^\n\d]*(\d+(?:[.,]\d+)?)\s*kcal)?',
        multiLine: true);
    for (final m in re.allMatches(text)) {
      final name = m[1]!.replaceAll(RegExp(r'["*]'), '').trim();
      if (name.length < 2) continue;
      final g = double.tryParse(m[2]!.replaceAll(',', '.')) ?? 0;
      final k = m[3] == null ? 0.0 : double.tryParse(m[3]!.replaceAll(',', '.')) ?? 0;
      if (g > 0) out.add(FoodItem(name: name, grams: g, kcal: k));
    }
    return out;
  }

  static Future<void> testKey(String k) async {
    await _ask([
      {'type': 'text', 'text': 'Odpowiedz jednym słowem: OK'}
    ], maxTokens: 10, keyOverride: k);
  }

  static Future<MealGuess> recognizeMeal({List<int>? jpeg, String desc = '', FoodIndex? index, String? draft}) async {
    final d = desc.trim();
    if (jpeg == null && d.isEmpty) throw const AiError('Dodaj zdjęcie albo opis posiłku.');
    final photo = jpeg != null;
    final local = await isLocal();
    final String prompt;
    if (local) {
      // mały model ma okno 4096 tokenów (zdjęcie zajmuje kilkaset): krótkie polecenie, tylko nazwy i gramatury –
      // wartości odżywcze aplikacja bierze z tabeli i bazy produktów
      prompt = """Rozpisz posiłek na składniki z gramaturą.
${photo ? 'Zdjęcie przedstawia posiłek.' : ''}${d.isNotEmpty ? ' Opis użytkownika (najważniejszy, produkty i ilości z opisu są pewne): "$d".' : ''}
${draft != null ? 'Wstępnie z opisu: $draft. Popraw ilości według zdjęcia i dodaj widoczne dodatki.' : ''}
Gramatury dla produktów w postaci zjedzonej, porcje typowe dla Polski. Nazwy krótkie, po polsku, np. "ryż biały ugotowany", "pierś z kurczaka", "surówka z marchewki".
Odpowiedz tylko JSON-em, bez komentarzy:
{"name":"nazwa posiłku","items":[{"name":"składnik","grams":150,"kcal":200}]}""";
    } else {
      prompt = """Jesteś dietetykiem. Rozpisz posiłek na składniki z gramaturą i wartościami odżywczymi.
${photo ? 'Masz zdjęcie posiłku.' : 'Nie ma zdjęcia, jest tylko opis.'}
${d.isNotEmpty ? 'Opis od użytkownika (mógł być podyktowany głosem): "$d"' : 'Użytkownik nie dodał opisu.'}
${d.isNotEmpty && photo ? 'Zasady: opis jest najważniejszy – produkty, ilości (sztuki, łyżki, kromki, gramy) i sposób przygotowania z opisu traktuj jako fakty. Zdjęcie służy do oszacowania wielkości porcji tego, czego ilości opis nie podaje, i do wychwycenia widocznych dodatków (sos, masło, posypka). Nie zmieniaj produktów z opisu na inne podobne.' : ''}
${d.isNotEmpty && !photo ? 'Zasady: produkty i ilości z opisu traktuj jako fakty; gdy ilości brak, przyjmij typową porcję w Polsce.' : ''}
${draft != null ? 'Wstępne rozpisanie opisu z tabeli produktów (popraw ilości i dodaj, czego brakuje, ale nie usuwaj produktów z opisu): $draft' : ''}
${d.isEmpty ? 'Rozpoznaj składniki na zdjęciu i oszacuj gramatury po wielkości talerza i sztućców (porcje typowe dla Polski).' : ''}
Gramatury podawaj dla produktów w postaci zjedzonej (np. ugotowany ryż, pieczone mięso). Gdy składnik pasuje do jednej z tych nazw, użyj dokładnie tej nazwy: ${tableNamesForPrompt()}.
Odpowiedz wyłącznie JSON-em, nazwy po polsku, liczby bez jednostek:
{"name":"krótka nazwa posiłku","items":[{"name":"składnik","grams":120,"kcal":180,"protein":6,"carbs":30,"fat":4}],"confidence":"niska|średnia|wysoka","note":"jedno zdanie: co było niepewne"}""";
    }
    final raw = await complete(prompt, jpeg: jpeg == null ? null : Uint8List.fromList(jpeg));
    final j = tryParseJson(raw);
    var items = j == null
        ? itemsFromLines(raw)
        : [for (final e in (j['items'] is List ? j['items'] as List : const [])) if (e is Map) FoodItem.fromJson(Map<String, dynamic>.from(e))]
            .where((i) => i.name.isNotEmpty)
            .toList();
    if (items.isEmpty) {
      throw AiError(j == null ? 'Odpowiedź modelu nie dała się odczytać.' : 'Nie rozpoznano składników. Dodaj opis albo wpisz je ręcznie.', raw);
    }
    // wartości odżywcze z tabeli, bazy produktów albo historii – AI szacuje wtedy tylko gramaturę
    var matched = 0;
    if (index != null) {
      items = [
        for (final i in items)
          if (matchFood(i.name, index) case final r? when i.grams > 0) () {
            matched++;
            return r.item(i.grams)..name = i.name;
          }() else i
      ];
    }
    final note = [
      '${j?['note'] ?? ''}'.trim(),
      if (matched > 0) 'Wartości ${matched == items.length ? 'wszystkich składników' : '$matched z ${items.length} składników'} z tabeli i bazy produktów, gramatury od AI.',
      if (items.any((i) => i.kcal <= 0)) 'Uzupełnij kalorie składników z zerem (wybierz nazwę z podpowiedzi).',
    ].where((x) => x.isNotEmpty).join(' ');
    return MealGuess('${j?['name'] ?? ''}', items, '${j?['confidence'] ?? ''}', note);
  }

  /// Dopasowanie nazwy od AI do tabeli/bazy: najpierw dokładnie (z odmianą), potem rozpisaniem nazwy.
  static FoodRef? matchFood(String name, FoodIndex index) {
    if (index.exact(name) case final r?) return r;
    final p = parseDescription(name, index);
    if (p.items.length == 1 && p.unknown.isEmpty) return p.items.first.ref;
    return null;
  }


  /// Zamienia podyktowany opis samopoczucia trawiennego na pola formularza.
  static Future<GutGuess> parseGut(String said) async {
    final prompt = '''Użytkownik podyktował, jak czuje się jego układ pokarmowy: "$said"
Zamień to na dane. Dozwolone objawy (użyj dokładnie tych nazw): ${gutSymptoms.join(', ')}. Nasilenie: 1 lekki, 2 średni, 3 silny.
comfort to ogólny komfort brzucha 1–5 (1 bardzo źle, 5 świetnie), 0 jeśli nie da się ocenić. bristol 1–7 tylko jeśli opisano stolec, inaczej 0.
when: jedno z ${gutWhen.map((w) => w.$1).join(', ')} albo null. note: to, czego nie dało się zapisać w polach, krótko, po polsku.
Odpowiedz wyłącznie JSON-em: {"comfort":3,"symptoms":[{"name":"wzdęcia","sev":2}],"bristol":0,"when":null,"note":""}''';
    final j = parseJson(await complete(prompt, maxTokens: 500));
    final syms = <GutSymptom>[
      for (final e in (j['symptoms'] is List ? j['symptoms'] as List : const []))
        if (e is Map && gutSymptoms.contains('${e['name']}')) GutSymptom('${e['name']}', ((e['sev'] as num?)?.round() ?? 1).clamp(1, 3))
    ];
    final when = gutWhen.any((w) => w.$1 == j['when']) ? '${j['when']}' : null;
    return GutGuess(((j['comfort'] as num?)?.round() ?? 0).clamp(0, 5), syms, ((j['bristol'] as num?)?.round() ?? 0).clamp(0, 7), when,
        '${j['note'] ?? ''}');
  }

  static Future<ReactionGuess> parseReaction(String said) async {
    final prompt = '''Użytkownik podyktował, jak się czuje po posiłku: "$said"
Dozwolone objawy (dokładnie te nazwy): ${reactionSymptoms.join(', ')}.
energy 1–5 (1 zero sił, 5 pełno energii), satiety 1–5 (1 głodny, 5 przejedzony), 0 jeśli nie wiadomo.
after: jedno z ${reactionAfter.join(', ')} albo null. note: reszta, krótko, po polsku.
Odpowiedz wyłącznie JSON-em: {"energy":3,"satiety":4,"symptoms":["senność"],"after":"1 h","note":""}''';
    final j = parseJson(await complete(prompt, maxTokens: 400));
    return ReactionGuess(
      ((j['energy'] as num?)?.round() ?? 0).clamp(0, 5),
      ((j['satiety'] as num?)?.round() ?? 0).clamp(0, 5),
      [for (final s in (j['symptoms'] is List ? j['symptoms'] as List : const [])) if (reactionSymptoms.contains('$s')) '$s'],
      reactionAfter.contains(j['after']) ? '${j['after']}' : null,
      '${j['note'] ?? ''}',
    );
  }

  static String journalText(Person p, List<Meal> meals, List<GutEntry> gut, String since, {int mealChars = 60000, int gutChars = 30000}) {
    final ms = meals.where((m) => m.date.compareTo(since) >= 0).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final gs = gut.where((g) => g.date.compareTo(since) >= 0).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final byId = {for (final m in meals) m.id: m};
    final lines = ms.map((m) {
      final t = m.total;
      final base = '${m.date} ${m.time} ${m.type}: ${m.items.map((i) => '${i.name} ${i.grams.round()}g').join(', ')} | '
          '${t.kcal.round()} kcal, B${t.p.round()} W${t.c.round()} T${t.f.round()}';
      if (m.reactions.isEmpty) return '$base | bez oceny';
      return '$base | ${m.reactions.map((r) => 'po ${r.after}: energia ${r.energy > 0 ? r.energy : '?'}/5, sytość ${r.satiety > 0 ? r.satiety : '?'}/5, '
          'objawy: ${r.symptoms.isEmpty ? 'brak' : r.symptoms.join(', ')}${r.note.isNotEmpty ? ', notatka: ${r.note}' : ''}').join('; ')}';
    }).join('\n');
    final gl = gs.map((g) {
      final sus = g.suspects.map((id) => byId[id]).whereType<Meal>().map((m) => '${m.date} ${m.type} ${m.name}');
      return '${g.date} ${g.when}: komfort ${g.comfort > 0 ? g.comfort : '?'}/5, objawy: '
          '${g.symptoms.isEmpty ? 'brak' : g.symptoms.map((s) => '${s.name} (${severityNames[s.sev]})').join(', ')}'
          '${g.bristol > 0 ? ', Bristol ${g.bristol}' : ''}${sus.isNotEmpty ? ', podejrzewa: ${sus.join('; ')}' : ''}'
          '${g.note.isNotEmpty ? ', notatka: ${g.note}' : ''}';
    }).join('\n');
    String cut(String s, int n) => s.length > n ? s.substring(s.length - n) : s;
    return 'Posiłki:\n${cut(lines, mealChars)}\n\nWpisy o trawieniu (często z rana, dotyczą posiłków z poprzedniego dnia; reakcje bywają opóźnione o 6–30 godzin):\n${gl.isEmpty ? 'brak' : cut(gl, gutChars)}';
  }

  static Future<String> analyze(Person p, List<Meal> meals, List<GutEntry> gut, {GasSeries? gas}) async {
    // model na telefonie ma małe okno kontekstu (4096 tokenów) – dostaje 14 dni i skrócony dziennik
    final local = await isLocal();
    final days = local ? 14 : 30;
    final since = shiftDay(todayIso(), -days);
    final prompt = '''Oto dziennik posiłków z ostatnich $days dni osoby o imieniu ${p.name} i to, jak się czuła po jedzeniu.
Dane osoby: ${personLine(p)}.
Uwzględnij wiek, płeć, masę ciała, aktywność, cel i uwagi przy ocenie kalorii, białka i objawów (np. inne potrzeby nastolatka, osoby starszej, kobiety i mężczyzny; nietolerancje z uwag). Jeśli danych osoby brakuje, napisz, które warto uzupełnić. Zwracaj się bezpośrednio do tej osoby.

${local ? journalText(p, meals, gut, since, mealChars: 5200, gutChars: 1800) : journalText(p, meals, gut, since)}${gas != null && gas.any ? '\n\nLiczba wiatrów z aplikacji użytkownika (Kreska – ręczne wpisy w ciągu dnia, Rytm Snu – wykryte w nocy). Traktuj je jako miarę skutków jedzenia z poprzednich 6–30 godzin:\n${() { final g = gasLines(gas!, since, todayIso()); return local && g.length > 900 ? g.substring(g.length - 900) : g; }()}' : ''}

Przeanalizuj to po polsku, zwięźle (maks. ok. ${local ? 200 : 300} słów), zwykłym tekstem bez nagłówków markdown i bez gwiazdek:
1. 2–4 najwyraźniejsze zależności między jedzeniem a samopoczuciem i trawieniem (także opóźnione, z dnia na dzień)${gas != null && gas.any ? ', w tym z liczbą wiatrów' : ''}, z liczbą przypadków, na których się opierasz.
2. Co widać w kaloriach i makroskładnikach względem celu tej osoby (regularność, pory, białko).
3. 2–3 konkretne rzeczy do przetestowania w kolejnych tygodniach.
Zaznacz, gdzie danych jest za mało na wniosek. Nie stawiaj diagnoz; przy powtarzających się objawach trawiennych zasugeruj konsultację z lekarzem.''';
    return complete(prompt, maxTokens: 2000);
  }
}
