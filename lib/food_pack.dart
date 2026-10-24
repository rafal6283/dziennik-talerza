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

  static List<FoodRef> decode(List<int> gz) {
    final j = jsonDecode(utf8.decode(gzip.decode(gz)));
    if (j is! Map || j['products'] is! List) return const [];
    builtAt = (j['built'] as num?)?.toInt() ?? 0;
    double d(dynamic v) => v is num ? v.toDouble() : 0;
    return [
      for (final p in j['products'] as List)
        if (p is List && p.length >= 7 && p[0] is String)
          FoodRef(p[0] as String, const [], d(p[2]), d(p[3]), d(p[4]), d(p[5]), d(p[6]) > 0 ? d(p[6]) : 100, d(p[6]) > 0 ? 'porcja' : '100 g',
              brand: '${p[1] ?? ''}', packaged: true),
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
