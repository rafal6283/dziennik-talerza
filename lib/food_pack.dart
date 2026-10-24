// Paczka polskich produktów z Open Food Facts dołączona do aplikacji (assets/off_pl.json.gz) – działa bez internetu.
// Budowana co miesiąc w GitHub Actions skryptem tool/off_pack.py. Dane: Open Food Facts, licencja ODbL.

import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart' show rootBundle;

import 'food_table.dart';

class FoodPack {
  static List<FoodRef>? cached;
  static Future<List<FoodRef>>? _loading;
  static int builtAt = 0;

  static final _company = RegExp(r'\s+(sp\.?\s*z\s*o\.?\s*o\.?|spółka.*|s\.?\s*a\.?(/nv)?|sa/nv|services.*|polska.*|gmbh.*|ltd.*|inc\.?.*)$', caseSensitive: false);

  /// „MARS POLSKA SPÓŁKA Z O.O.” → „Mars”, „COCA-COLA SERVICES SA/NV” → „Coca-Cola”.
  static String cleanBrand(String b) {
    var s = b.trim().replaceFirst(_company, '').trim();
    if (s.isEmpty) s = b.trim();
    if (s.length > 3 && s == s.toUpperCase()) {
      s = s.toLowerCase().split(RegExp(r'(?<=[\s-])|(?=[\s-])')).map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join();
    }
    return s;
  }

  static List<FoodRef> decode(List<int> gz) {
    final j = jsonDecode(utf8.decode(gzip.decode(gz)));
    if (j is! Map || j['products'] is! List) return const [];
    builtAt = (j['built'] as num?)?.toInt() ?? 0;
    double d(dynamic v) => v is num ? v.toDouble() : 0;
    return [
      for (final p in j['products'] as List)
        if (p is List && p.length >= 7 && p[0] is String)
          FoodRef(p[0] as String, const [], d(p[2]), d(p[3]), d(p[4]), d(p[5]), d(p[6]) > 0 ? d(p[6]) : 100, d(p[6]) > 0 ? 'porcja' : '100 g',
              brand: cleanBrand('${p[1] ?? ''}'), packaged: true),
    ];
  }

  /// Wczytuje paczkę raz; przy błędzie zwraca pustą listę (aplikacja działa wtedy na tabeli).
  static Future<List<FoodRef>> load() => _loading ??= () async {
        try {
          final data = await rootBundle.load('assets/off_pl.json.gz');
          cached = decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        } catch (_) {
          cached = const [];
        }
        return cached!;
      }();
}
