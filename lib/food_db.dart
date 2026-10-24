// Open Food Facts – darmowa, otwarta baza produktów spożywczych (dużo polskich produktów).
// https://world.openfoodfacts.org – dane na licencji ODbL.

import 'dart:convert';

import 'package:http/http.dart' as http;

class Product {
  final String code;
  final String name;
  final String brand;
  final double kcal100, protein100, carbs100, fat100;
  final double? serving; // g na porcję, jeśli podano
  const Product(this.code, this.name, this.brand, this.kcal100, this.protein100, this.carbs100, this.fat100, this.serving);

  String get label => brand.isEmpty ? name : '$name ($brand)';
}

class FoodDbError implements Exception {
  final String message;
  const FoodDbError(this.message);
  @override
  String toString() => message;
}

class FoodDb {
  static http.Client client = http.Client();
  static const _ua = 'DziennikTalerza/1.0 (aplikacja prywatna)';

  static double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;

  /// Produkt z odpowiedzi API (wydzielone do testów).
  static Product? parse(String code, Map<String, dynamic> j) {
    if (j['status'] != 1 && j['status'] != '1' && j['product'] == null) return null;
    final p = j['product'];
    if (p is! Map) return null;
    final n = p['nutriments'] is Map ? Map<String, dynamic>.from(p['nutriments'] as Map) : <String, dynamic>{};
    var kcal = _n(n['energy-kcal_100g']);
    if (kcal == 0 && _n(n['energy_100g']) > 0) kcal = _n(n['energy_100g']) / 4.184; // kJ → kcal
    final name = ['${p['product_name_pl'] ?? ''}', '${p['product_name'] ?? ''}', '${p['generic_name_pl'] ?? ''}']
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => 'Produkt $code');
    final brand = '${p['brands'] ?? ''}'.split(',').first.trim();
    final serving = _n(p['serving_quantity']);
    return Product(code, name, brand, kcal, _n(n['proteins_100g']), _n(n['carbohydrates_100g']), _n(n['fat_100g']), serving > 0 ? serving : null);
  }

  static Future<Product?> byBarcode(String code) async {
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$code.json'
        '?fields=product_name,product_name_pl,generic_name_pl,brands,nutriments,serving_quantity');
    final http.Response r;
    try {
      r = await client.get(uri, headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const FoodDbError('Brak połączenia z bazą produktów. Sprawdź internet.');
    }
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw FoodDbError('Baza produktów nie odpowiada (błąd ${r.statusCode}). Spróbuj za chwilę.');
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j is Map ? parse(code, Map<String, dynamic>.from(j)) : null;
  }
}
