// Claude przez API Anthropic, z własnym kluczem użytkownika (Ustawienia → Rozpoznawanie AI).
// Bez klucza aplikacja działa normalnie, tylko bez rozpoznawania i analizy.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'calc.dart';
import 'models.dart';

const aiModels = [
  ('claude-sonnet-5-5', 'Sonnet – dokładny, zalecany'),
  ('claude-haiku-5-5', 'Haiku – szybki i tańszy'),
  ('claude-opus-5-5', 'Opus – najdokładniejszy, najdroższy'),
];

class AiError implements Exception {
  final String message;
  const AiError(this.message);
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

class Ai {
  static const _kKey = 'ai_key';
  static const _kModel = 'ai_model';
  static http.Client client = http.Client();

  static Future<String?> key() async {
    final k = (await SharedPreferences.getInstance()).getString(_kKey);
    return (k == null || k.trim().isEmpty) ? null : k.trim();
  }

  static Future<bool> enabled() async => (await key()) != null;
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
  static Map<String, dynamic> parseJson(String text) {
    var t = text.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(t);
    if (fence != null) t = fence.group(1)!.trim();
    try {
      final v = jsonDecode(t);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    final a = t.indexOf('{'), b = t.lastIndexOf('}');
    if (a >= 0 && b > a) {
      try {
        final v = jsonDecode(t.substring(a, b + 1));
        if (v is Map) return Map<String, dynamic>.from(v);
      } catch (_) {}
    }
    throw const AiError('Odpowiedź przyszła w złym formacie. Spróbuj jeszcze raz.');
  }

  static Future<void> testKey(String k) async {
    await _ask([
      {'type': 'text', 'text': 'Odpowiedz jednym słowem: OK'}
    ], maxTokens: 10, keyOverride: k);
  }

  static Future<MealGuess> recognizeMeal({List<int>? jpeg, String desc = ''}) async {
    if (jpeg == null && desc.trim().isEmpty) throw const AiError('Dodaj zdjęcie albo opis posiłku.');
    final prompt = '''Jesteś dietetykiem szacującym wartości odżywcze posiłku.${jpeg != null ? ' Na zdjęciu jest posiłek.' : ''}
${desc.trim().isNotEmpty ? 'Opis od użytkownika (mógł być podyktowany głosem): ${desc.trim()}' : 'Brak opisu.'}
Rozpoznaj składniki, oszacuj realistyczne gramatury (porcje typowe dla Polski) i wartości odżywcze każdego składnika. Jeśli opis kłóci się ze zdjęciem, ufaj opisowi.
Odpowiedz wyłącznie JSON-em w tym kształcie, nazwy po polsku, liczby bez jednostek:
{"name":"krótka nazwa posiłku","items":[{"name":"składnik","grams":120,"kcal":180,"protein":6,"carbs":30,"fat":4}],"confidence":"niska|średnia|wysoka","note":"jedno zdanie: co było niepewne"}''';
    final j = parseJson(await _ask([
      if (jpeg != null) {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(jpeg)}},
      {'type': 'text', 'text': prompt},
    ]));
    final items = [for (final e in (j['items'] is List ? j['items'] as List : const [])) if (e is Map) FoodItem.fromJson(Map<String, dynamic>.from(e))]
        .where((i) => i.name.isNotEmpty)
        .toList();
    if (items.isEmpty) throw const AiError('Nie rozpoznano składników. Dodaj opis albo wpisz je ręcznie.');
    return MealGuess('${j['name'] ?? ''}', items, '${j['confidence'] ?? ''}', '${j['note'] ?? ''}');
  }

  /// Zamienia podyktowany opis samopoczucia trawiennego na pola formularza.
  static Future<GutGuess> parseGut(String said) async {
    final prompt = '''Użytkownik podyktował, jak czuje się jego układ pokarmowy: "$said"
Zamień to na dane. Dozwolone objawy (użyj dokładnie tych nazw): ${gutSymptoms.join(', ')}. Nasilenie: 1 lekki, 2 średni, 3 silny.
comfort to ogólny komfort brzucha 1–5 (1 bardzo źle, 5 świetnie), 0 jeśli nie da się ocenić. bristol 1–7 tylko jeśli opisano stolec, inaczej 0.
when: jedno z ${gutWhen.map((w) => w.$1).join(', ')} albo null. note: to, czego nie dało się zapisać w polach, krótko, po polsku.
Odpowiedz wyłącznie JSON-em: {"comfort":3,"symptoms":[{"name":"wzdęcia","sev":2}],"bristol":0,"when":null,"note":""}''';
    final j = parseJson(await _ask([
      {'type': 'text', 'text': prompt}
    ], maxTokens: 500));
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
    final j = parseJson(await _ask([
      {'type': 'text', 'text': prompt}
    ], maxTokens: 400));
    return ReactionGuess(
      ((j['energy'] as num?)?.round() ?? 0).clamp(0, 5),
      ((j['satiety'] as num?)?.round() ?? 0).clamp(0, 5),
      [for (final s in (j['symptoms'] is List ? j['symptoms'] as List : const [])) if (reactionSymptoms.contains('$s')) '$s'],
      reactionAfter.contains(j['after']) ? '${j['after']}' : null,
      '${j['note'] ?? ''}',
    );
  }

  static String journalText(Person p, List<Meal> meals, List<GutEntry> gut, String since) {
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
    return 'Posiłki:\n${cut(lines, 60000)}\n\nWpisy o trawieniu (często z rana, dotyczą posiłków z poprzedniego dnia; reakcje bywają opóźnione o 6–30 godzin):\n${gl.isEmpty ? 'brak' : cut(gl, 30000)}';
  }

  static Future<String> analyze(Person p, List<Meal> meals, List<GutEntry> gut) async {
    final since = shiftDay(todayIso(), -30);
    final prompt = '''Oto dziennik posiłków z ostatnich 30 dni osoby o imieniu ${p.name} i to, jak się czuła po jedzeniu.
Dane osoby: ${personLine(p)}.
Uwzględnij wiek, płeć, masę ciała, aktywność, cel i uwagi przy ocenie kalorii, białka i objawów (np. inne potrzeby nastolatka, osoby starszej, kobiety i mężczyzny; nietolerancje z uwag). Jeśli danych osoby brakuje, napisz, które warto uzupełnić. Zwracaj się bezpośrednio do tej osoby.

${journalText(p, meals, gut, since)}

Przeanalizuj to po polsku, zwięźle (maks. ok. 300 słów), zwykłym tekstem bez nagłówków markdown i bez gwiazdek:
1. 2–4 najwyraźniejsze zależności między jedzeniem a samopoczuciem i trawieniem (także opóźnione, z dnia na dzień), z liczbą przypadków, na których się opierasz.
2. Co widać w kaloriach i makroskładnikach względem celu tej osoby (regularność, pory, białko).
3. 2–3 konkretne rzeczy do przetestowania w kolejnych tygodniach.
Zaznacz, gdzie danych jest za mało na wniosek. Nie stawiaj diagnoz; przy powtarzających się objawach trawiennych zasugeruj konsultację z lekarzem.''';
    return _ask([
      {'type': 'text', 'text': prompt}
    ], maxTokens: 2000);
  }
}
