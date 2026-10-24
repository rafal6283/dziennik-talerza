import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../ai.dart';
import '../calc.dart';
import '../local_ai.dart';
import '../main.dart';
import '../security/lock.dart';
import 'format.dart';
import 'model_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LockConfig? lock;
  String? key;
  String model = aiModels.first.$1;
  String provider = 'local';
  bool localReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await Lock.load();
    final k = await Ai.key();
    final m = await Ai.model();
    final pr = await Ai.provider();
    final lr = await LocalAi.ready();
    if (mounted) {
      setState(() {
        lock = c;
        key = k;
        model = m;
        provider = pr;
        localReady = lr;
      });
    }
  }

  String get _lockLabel => switch (lock?.method) {
        LockMethod.pin => 'PIN${lock!.biometric ? ' + biometria' : ''}',
        LockMethod.pattern => 'Wzór${lock!.biometric ? ' + biometria' : ''}',
        LockMethod.device => 'Blokada ekranu telefonu',
        _ => 'Wyłączone',
      };

  Future<void> _editKey() async {
    final ctl = TextEditingController(text: key ?? '');
    String? err;
    bool testing = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Klucz API Anthropic'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Klucz utworzysz na console.anthropic.com → API Keys. Opłaty nalicza Anthropic za faktyczne użycie (zwykle grosze za jedno zdjęcie).'),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              decoration: InputDecoration(labelText: 'sk-ant-…', errorText: err, errorMaxLines: 3),
            ),
          ]),
          actions: [
            if (key != null)
              TextButton(
                onPressed: () async {
                  await Ai.setKey(null);
                  if (c.mounted) Navigator.pop(c, true);
                },
                child: const Text('Usuń klucz'),
              ),
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
            FilledButton(
              onPressed: testing
                  ? null
                  : () async {
                      final k = ctl.text.trim();
                      if (k.isEmpty) return;
                      set(() {
                        testing = true;
                        err = null;
                      });
                      try {
                        await Ai.testKey(k);
                        await Ai.setKey(k);
                        if (c.mounted) Navigator.pop(c, true);
                      } on AiError catch (e) {
                        set(() {
                          testing = false;
                          err = e.message;
                        });
                      }
                    },
              child: Text(testing ? 'Sprawdzam…' : 'Sprawdź i zapisz'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) toast(context, key != null ? 'Klucz działa. Rozpoznawanie włączone.' : 'Klucz usunięty');
    }
  }

  Future<void> _export() async {
    final name = 'dziennik-talerza-${todayIso()}.json';
    try {
      final path = await withExternal(() => FilePicker.platform.saveFile(dialogTitle: 'Zapisz kopię', fileName: name, bytes: app.exportBytes()));
      if (path != null && mounted) toast(context, 'Zapisano kopię');
    } catch (e) {
      if (mounted) toast(context, 'Nie udało się zapisać kopii: $e');
    }
  }

  Future<void> _import() async {
    final res = await withExternal(() => FilePicker.platform.pickFiles(type: FileType.any, withData: true));
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) {
      if (mounted) toast(context, 'Nie udało się odczytać pliku');
      return;
    }
    try {
      final s = await app.importBytes(bytes);
      if (mounted) toast(context, 'Wczytano: ${s.people} osób, ${s.meals} posiłków, ${s.gut} wpisów o trawieniu (nowe: ${s.added}, zaktualizowane: ${s.updated})');
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'To nie jest plik kopii Dziennika talerza (.json)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photos = app.allMeals.where((m) => m.photo != null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(children: [
        const SectionTitle('Rozpoznawanie AI'),
        for (final p in aiProviders)
          RadioListTile<String>(
            value: p.$1,
            groupValue: provider,
            title: Text(p.$2),
            subtitle: Text(switch (p.$1) {
              'local' => localReady ? 'Gemma 4 na telefonie – pobrany, działa bez internetu' : 'Gemma 4 na telefonie – wymaga pobrania ${LocalAi.sizeLabel}',
              'claude' => key == null ? 'Najdokładniejsze, płatne za użycie – brak klucza' : 'Najdokładniejsze, płatne za użycie – klucz ustawiony',
              _ => 'Składniki wpisujesz ręcznie albo skanujesz kod kreskowy',
            }),
            onChanged: (v) async {
              await Ai.setProvider(v!);
              await _load();
              if (v == 'local' && !localReady && mounted) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelScreen()));
                _load();
              }
              if (v == 'claude' && key == null && mounted) _editKey();
            },
          ),
        if (provider == 'local')
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Model na telefonie'),
            subtitle: Text(localReady ? 'Pobrany · test, usuwanie' : 'Pobierz (${LocalAi.sizeLabel})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelScreen()));
              _load();
            },
          ),
        if (provider == 'claude') ...[
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Klucz API Anthropic'),
            subtitle: Text(key == null ? 'Brak' : 'Ustawiony (…${key!.substring(key!.length > 4 ? key!.length - 4 : 0)})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editKey,
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Model'),
            subtitle: Text(aiModels.firstWhere((m) => m.$1 == model, orElse: () => (model, model)).$2),
            enabled: key != null,
            onTap: () async {
              final m = await showDialog<String>(
                context: context,
                builder: (c) => SimpleDialog(title: const Text('Model'), children: [
                  for (final x in aiModels)
                    RadioListTile<String>(value: x.$1, groupValue: model, title: Text(x.$2), subtitle: Text(x.$1), onChanged: (v) => Navigator.pop(c, v)),
                ]),
              );
              if (m != null) {
                await Ai.setModel(m);
                await _load();
              }
            },
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            provider == 'claude'
                ? 'Do Anthropic trafia tylko to, co analizujesz w danej chwili (zdjęcie, opis albo dziennik z profilem osoby). Klucz jest zapisany tylko w tym telefonie.'
                : 'Produkty paczkowane najdokładniej dodasz skanerem kodów kreskowych (darmowa baza Open Food Facts) – przycisk „Kod” w formularzu posiłku.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
          ),
        ),
        const SectionTitle('Dane'),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Importuj kopię'),
          subtitle: const Text('Plik .json z tej aplikacji albo z wersji przeglądarkowej. Wpisy o tym samym id zostaną zaktualizowane.'),
          onTap: _import,
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('Zapisz kopię'),
          subtitle: Text('${app.people.length} osób, ${app.allMeals.length} posiłków, ${app.allGut.length} wpisów o trawieniu. Bez zdjęć ($photos).'),
          onTap: _export,
        ),
        const SectionTitle('Prywatność'),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Logowanie do aplikacji'),
          subtitle: Text(_lockLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
            _load();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Text(
            'Dziennik i zdjęcia są zapisane tylko w tym telefonie. Dyktowanie korzysta z rozpoznawania mowy telefonu (Google lub Apple). '
            'Szacunki kalorii i analizy to pomoc, nie porada medyczna.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
          ),
        ),
      ]),
    );
  }
}
