// Widżet Androida na ekranie głównym: aplikacja wysyła mu dzisiejsze liczby, a widżet otwiera
// aplikację z akcją (posiłek, woda, trawienie).

import 'dart:io';

import 'package:flutter/services.dart';

class HomeWidget {
  HomeWidget._();
  static const _ch = MethodChannel('pl.dziennik/widget');
  static void Function(String action)? onAction;
  static bool _bound = false;

  static bool get supported => Platform.isAndroid;

  static void bind() {
    if (!supported || _bound) return;
    _bound = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'action' && call.arguments is String) onAction?.call(call.arguments as String);
      return null;
    });
  }

  /// Akcja z widżetu, którą uruchomiono aplikację.
  static Future<String?> takeAction() async {
    if (!supported) return null;
    try {
      return await _ch.invokeMethod<String>('takeAction');
    } catch (_) {
      return null;
    }
  }

  static String _last = '';

  static Future<void> update({required String person, required int kcal, required int goal, required int waterMl, required int waterGoal}) async {
    if (!supported) return;
    final left = goal - kcal;
    final data = <String, Object>{
      'person': person,
      'kcal': '$kcal',
      'goalText': left >= 0 ? 'z $goal kcal · zostało $left' : 'z $goal kcal · $left',
      'pct': '${goal > 0 ? (kcal * 100 / goal).round().clamp(0, 100) : 0}',
      'waterText': 'Woda ${(waterMl / 1000).toStringAsFixed(1)} z ${(waterGoal / 1000).toStringAsFixed(1)} l',
    };
    final key = data.toString();
    if (key == _last) return;
    _last = key;
    try {
      await _ch.invokeMethod('update', data);
    } catch (_) {}
  }
}
