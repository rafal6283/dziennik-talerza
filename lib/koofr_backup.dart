import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:koofr_backup_ui/koofr_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gas.dart';
import 'main.dart' show app;

/// Kopia Dziennika talerza na rodzinnym Koofr: dane JSON + miniatury zdjęć wysyłane raz.
class DziennikBackup extends BackupAdapter {
  @override
  String get appId => 'dziennik-talerza';
  @override
  String get appName => 'Dziennik talerza';
  @override
  String get contentNote => 'W kopii są osoby, posiłki, wpisy o trawieniu i miniatury zdjęć.';

  @override
  ExchangeAdapter get exchange => DziennikExchange.instance;

  Future<Directory> _photos() async => Directory('${(await app.dir()).path}/photos');

  @override
  Future<BackupContent> export() async {
    final dir = await _photos();
    final blobs = <BackupBlob>[];
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) blobs.add(BackupBlob('photos/${e.uri.pathSegments.last}', e.readAsBytes));
      }
    }
    return BackupContent(app.exportBytes(), blobs);
  }

  @override
  Future<void> import(RestoredBackup r, void Function(String step) progress) async {
    final base = (await app.dir()).path;
    final tmp = Directory('$base/photos.przywracanie');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    var i = 0;
    for (final e in r.blobs.entries) {
      progress('Zdjęcia: ${++i} z ${r.blobs.length}');
      if (!e.key.startsWith('photos/') || e.key.contains('..')) continue;
      await File('${tmp.path}/${e.key.substring(7)}').writeAsBytes(await r.blob(e.value), flush: true);
    }
    progress('Zapisywanie…');
    try {
      await app.replaceFromBytes(r.data);
    } on FormatException catch (e) {
      await tmp.delete(recursive: true);
      throw KoofrException(e.message);
    }
    final photos = await _photos();
    if (await photos.exists()) await photos.delete(recursive: true);
    await tmp.rename(photos.path);
  }
}

/// Wiatry z Rytmu Snu i licznik z Kreski pobierane automatycznie przez Koofr.
class DziennikExchange extends ExchangeAdapter {
  static final instance = DziennikExchange();

  static const _kPerson = 'ex_person';
  static const _kCounter = 'ex_kreska_counter';

  @override
  List<(String, String)> get sources => const [
        ('rytm-snu', 'Rytm Snu (wiatry w nocy)'),
        ('kreska', 'Kreska (licznik wiatrów w ciągu dnia)'),
      ];

  /// Osoba w Dzienniku, do której trafiają pobrane dane (domyślnie pierwsza — zwykle „Ja”).
  Future<String> person() async {
    final id = (await SharedPreferences.getInstance()).getString(_kPerson);
    return app.people.any((p) => p.id == id) ? id! : app.people.first.id;
  }

  /// Licznik z Kreski; pusty = zgadywany (FF, „wiatry”…).
  Future<String> counter() async => (await SharedPreferences.getInstance()).getString(_kCounter) ?? '';

  @override
  Future<void> import(String name, Uint8List data) async {
    final text = utf8.decode(data, allowMalformed: true);
    final who = await person();
    switch (detectGasFile(text)) {
      case GasFileKind.night:
        await app.setGas(parseNightExchange(who, text));
      case GasFileKind.kreskaJson:
        final g = parseKreskaExchange(who, text);
        final want = await counter();
        final ok = want.isEmpty ? guessGasCounter([g.label]) != null : g.label.trim().toLowerCase() == want.trim().toLowerCase();
        if (ok) await app.setGas(g);
      default:
        break;
    }
  }

  @override
  Widget? extraSettings(BuildContext context) => const _DziennikExchangeSettings();
}

class _DziennikExchangeSettings extends StatefulWidget {
  const _DziennikExchangeSettings();

  @override
  State<_DziennikExchangeSettings> createState() => _DziennikExchangeSettingsState();
}

class _DziennikExchangeSettingsState extends State<_DziennikExchangeSettings> {
  String? person;
  final counter = TextEditingController();

  @override
  void initState() {
    super.initState();
    () async {
      final p = await DziennikExchange.instance.person();
      counter.text = await DziennikExchange.instance.counter();
      if (mounted) setState(() => person = p);
    }();
  }

  Future<void> _saveCounter(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(DziennikExchange._kCounter, v.trim());
    // nowy licznik — pobierz Kreskę od nowa
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano — użyj „Wymień teraz”')));
  }

  @override
  Widget build(BuildContext context) {
    final p = person;
    if (p == null) return const SizedBox();
    return Column(children: [
      ListTile(
        title: const Text('Zapisuj dla osoby'),
        trailing: DropdownButton<String>(
          value: p,
          underline: const SizedBox(),
          items: [for (final x in app.people) DropdownMenuItem(value: x.id, child: Text(x.name))],
          onChanged: (v) async {
            if (v == null) return;
            await (await SharedPreferences.getInstance()).setString(DziennikExchange._kPerson, v);
            setState(() => person = v);
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: counter,
          decoration: const InputDecoration(
            labelText: 'Licznik z Kreski',
            hintText: 'np. FF (puste = zgadnij)',
            helperText: 'W Kresce ten licznik musi być zaznaczony do udostępniania',
          ),
          onSubmitted: _saveCounter,
          onEditingComplete: () => _saveCounter(counter.text),
        ),
      ),
    ]);
  }
}
