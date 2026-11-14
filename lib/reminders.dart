// Przypomnienia: rano ocena trawienia (1–5 prosto z powiadomienia), 2 h po posiłku „jak się czujesz?”,
// wieczorem kolacja (gdy jeszcze jej nie ma), w niedzielę podsumowanie tygodnia.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'calc.dart';
import 'models.dart';

class ReminderSettings {
  bool morning, afterMeal, dinner, weekly;
  int morningMin, dinnerMin; // minuty od północy
  ReminderSettings({this.morning = false, this.afterMeal = false, this.dinner = false, this.weekly = false, this.morningMin = 8 * 60, this.dinnerMin = 19 * 60});
  bool get any => morning || afterMeal || dinner || weekly;
}

/// Co ma zrobić aplikacja po stuknięciu powiadomienia.
typedef ReminderTap = void Function(String payload, String? action);

class Reminders {
  Reminders._();

  static final _n = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static final settings = ReminderSettings();
  static ReminderTap? onTap;
  static String? _launchPayload, _launchAction;

  static const _idMorning = 1000, _idDinner = 2000, _idWeek = 3000, _idMealBase = 10000;

  static const _channel = AndroidNotificationDetails(
    'przypomnienia',
    'Przypomnienia',
    channelDescription: 'Trawienie rano, samopoczucie po posiłku, kolacja, podsumowanie tygodnia',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _gutActions = NotificationDetails(
    android: AndroidNotificationDetails(
      'przypomnienia',
      'Przypomnienia',
      channelDescription: 'Trawienie rano, samopoczucie po posiłku, kolacja, podsumowanie tygodnia',
      actions: [
        AndroidNotificationAction('g5', '😊 Dobrze', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('g3', '😐 Średnio', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('g1', '😣 Źle', showsUserInterface: true, cancelNotification: true),
      ],
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _plain = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      settings
        ..morning = p.getBool('rem_morning') ?? false
        ..afterMeal = p.getBool('rem_after') ?? false
        ..dinner = p.getBool('rem_dinner') ?? false
        ..weekly = p.getBool('rem_week') ?? false
        ..morningMin = p.getInt('rem_morning_min') ?? 8 * 60
        ..dinnerMin = p.getInt('rem_dinner_min') ?? 19 * 60;
    } catch (_) {}
  }

  static Future<void> saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('rem_morning', settings.morning);
    await p.setBool('rem_after', settings.afterMeal);
    await p.setBool('rem_dinner', settings.dinner);
    await p.setBool('rem_week', settings.weekly);
    await p.setInt('rem_morning_min', settings.morningMin);
    await p.setInt('rem_dinner_min', settings.dinnerMin);
  }

  static Future<bool> init() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      tzdata.initializeTimeZones();
      await _n.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => _handle(r.payload, r.actionId),
      );
      final d = await _n.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) {
        _launchPayload = d!.notificationResponse?.payload;
        _launchAction = d.notificationResponse?.actionId;
      }
      _ready = true;
    } catch (e) {
      debugPrint('powiadomienia: $e');
    }
    return _ready;
  }

  static void _handle(String? payload, String? action) {
    if (payload == null || payload.isEmpty) return;
    final t = onTap;
    if (t == null) {
      _launchPayload = payload;
      _launchAction = action;
    } else {
      t(payload, action);
    }
  }

  /// Powiadomienie, którym uruchomiono aplikację (jednorazowo).
  static (String, String?)? takeLaunch() {
    final p = _launchPayload;
    if (p == null) return null;
    final a = _launchAction;
    _launchPayload = null;
    _launchAction = null;
    return (p, a);
  }

  static Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      if (Platform.isAndroid) {
        final a = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await a?.requestNotificationsPermission() ?? true;
      }
      final i = _n.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await i?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _at(int id, DateTime at, String title, String body, String payload, {NotificationDetails details = _plain}) async {
    if (!at.isAfter(DateTime.now())) return;
    await _n.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  static Future<void> _cancelRange(int from, int count) async {
    for (var i = 0; i < count; i++) {
      await _n.cancel(id: from + i);
    }
  }

  /// Układa przypomnienia stałe na 7 dni (po starcie, zapisie posiłku/wpisu i zmianie ustawień).
  static Future<void> reschedule({required List<Meal> meals, required List<GutEntry> gut}) async {
    if (!await init()) return;
    try {
      await _cancelRange(_idMorning, 8);
      await _cancelRange(_idDinner, 8);
      await _cancelRange(_idWeek, 2);
      final s = settings;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (var i = 0; i < 7; i++) {
        final day = today.add(Duration(days: i));
        final iso = isoDate(day);
        if (s.morning) {
          final done = gut.any((g) => g.date == iso && g.when == 'rano');
          final hadMeals = meals.any((m) => m.date == shiftDay(iso, -1));
          if (!done && (i > 0 || hadMeals)) {
            await _at(_idMorning + i, day.add(Duration(minutes: s.morningMin)), 'Jak trawienie po wczoraj?',
                'Oceń jednym stuknięciem – pomaga wychwycić opóźnione reakcje.', 'gut:$iso',
                details: _gutActions);
          }
        }
        if (s.dinner) {
          final has = meals.any((m) => m.date == iso && m.type == 'Kolacja');
          if (!has) {
            await _at(_idDinner + i, day.add(Duration(minutes: s.dinnerMin)), 'Kolacja zapisana?',
                'Zrób zdjęcie albo dodaj z ulubionych – zajmie chwilę.', 'meal:Kolacja');
          }
        }
        if (s.weekly && day.weekday == DateTime.sunday) {
          await _at(_idWeek, day.add(const Duration(hours: 19, minutes: 30)), 'Podsumowanie tygodnia',
              'Kalorie, trawienie, woda i waga z ostatnich 7 dni.', 'week');
        }
      }
    } catch (e) {
      debugPrint('powiadomienia (plan): $e');
    }
  }

  static int _mealId(String mealId) => _idMealBase + (mealId.hashCode & 0x7ffff);

  /// 2 h po posiłku: „jak się czujesz?” (tylko świeże posiłki z dziś, bez reakcji).
  static Future<void> afterMeal(Meal m) async {
    if (!settings.afterMeal || !await init()) return;
    try {
      await _n.cancel(id: _mealId(m.id));
      if (m.reactions.isNotEmpty || m.date != todayIso()) return;
      final at = DateTime.fromMillisecondsSinceEpoch(m.ts).add(const Duration(hours: 2));
      final label = m.name.isNotEmpty ? m.name : m.type.toLowerCase();
      await _at(_mealId(m.id), at, 'Jak się czujesz po: $label?', 'Energia, sytość, brzuch – dwa stuknięcia.', 'reaction:${m.id}');
    } catch (e) {
      debugPrint('powiadomienia (posiłek): $e');
    }
  }

  static Future<void> cancelMeal(String mealId) async {
    if (!_ready) return;
    try {
      await _n.cancel(id: _mealId(mealId));
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!await init()) return;
    await _n.cancelAll();
  }
}
