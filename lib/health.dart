// Posiłki → Health Connect (Android). Samsung Health, Google Fit i inne aplikacje
// odczytują je stamtąd. Zapisywane są posiłki jednej, wybranej osoby (właściciela telefonu).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HealthSync {
  HealthSync._();

  static const _ch = MethodChannel('pl.dziennik/health');
  static const _kOn = 'hc_on', _kPerson = 'hc_person';

  static bool get supported => Platform.isAndroid;

  static bool _on = false;
  static String? _person;

  static bool get enabled => _on;
  static String? get person => _person;

  static Future<void> init() async {
    if (!supported) return;
    try {
      final p = await SharedPreferences.getInstance();
      _on = p.getBool(_kOn) ?? false;
      _person = p.getString(_kPerson);
    } catch (_) {}
  }

  /// 'available' | 'update' (trzeba zainstalować/zaktualizować Health Connect) | 'unavailable'
  static Future<String> status() async {
    try {
      return await _ch.invokeMethod<String>('status') ?? 'unavailable';
    } catch (_) {
      return 'unavailable';
    }
  }

  static Future<bool> requestPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> configure({required bool on, String? person}) async {
    _on = on;
    if (person != null) _person = person;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOn, on);
    if (_person != null) await p.setString(_kPerson, _person!);
  }

  static Map<String, Object?> _meal(Meal m) {
    final t = m.total;
    return {
      'id': m.id,
      'ts': m.ts,
      'name': m.name.isNotEmpty ? m.name : m.type,
      'type': m.type,
      'kcal': t.kcal,
      'p': t.p,
      'c': t.c,
      'f': t.f,
    };
  }

  /// Zapis wielu posiłków; liczba zapisanych albo -1.
  static Future<int> writeMeals(Iterable<Meal> meals) async {
    final list = [for (final m in meals) _meal(m)];
    if (list.isEmpty) return 0;
    try {
      return await _ch.invokeMethod<int>('writeMeals', {'meals': list}) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> deleteMeals(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _ch.invokeMethod('deleteMeals', {'ids': ids});
    } catch (_) {}
  }

  /// Po zapisie posiłku: dla wybranej osoby zapis (posiłek bez kalorii = usunięcie), dla innych usunięcie
  /// (na wypadek przeniesienia posiłku do innej osoby).
  static Future<void> mealSaved(Meal m) async {
    if (!supported || !_on) return;
    if (m.person == _person && m.total.kcal > 0) {
      await writeMeals([m]);
    } else {
      await deleteMeals([m.id]);
    }
  }

  static Future<void> mealDeleted(String id) async {
    if (!supported || !_on) return;
    await deleteMeals([id]);
  }
}
