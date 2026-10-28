import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../gas.dart';
import '../main.dart';
import 'format.dart';

/// Opcjonalny import wiatrów z Kreski (CSV) i Rytmu Snu (JSON) dla wybranej osoby.
class GasScreen extends StatefulWidget {
  const GasScreen({super.key});
  @override
  State<GasScreen> createState() => _GasScreenState();
}

class _GasScreenState extends State<GasScreen> {
  bool busy = false;

  Future<void> _import() async {
    final res = await withExternal(() => FilePicker.platform.pickFiles(type: FileType.any, withData: true));
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.first;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) {
      if (mounted) toast(context, 'Nie udało się odczytać pliku');
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final person = app.active;
    setState(() => busy = true);
    try {
      switch (detectGasFile(text)) {
        case GasFileKind.night:
          final g = parseNightExchange(person.id, text);
          await app.setGas(g);
          if (mounted) toast(context, 'Rytm Snu → ${person.name}: ${g.windows.length} nocy, ${g.events.length} wiatrów');
        case GasFileKind.kreskaJson:
          final g = parseKreskaExchange(person.id, text);
          await app.setGas(g);
          if (mounted) toast(context, 'Kreska („${g.label}”) → ${person.name}: ${g.events.length} wpisów z godziną, ${g.days.length} dni');
        case GasFileKind.kreska:
          final counters = parseKreskaCsv(text);
          if (counters.isEmpty) {
            if (mounted) toast(context, 'W pliku z Kreski nie ma żadnych liczników.');
            return;
          }
          final pick = await _chooseCounter(counters);
          if (pick == null) return;
          final m = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(f.name);
          final g = kreskaSource(person.id, pick, counters[pick]!, fileDate: m?.group(1));
          await app.setGas(g);
          final total = g.days.values.fold<int>(0, (a, b) => a + b);
          if (mounted) toast(context, 'Kreska („$pick”) → ${person.name}: ${g.days.length} dni, razem $total');
        case GasFileKind.unknown:
          if (mounted) toast(context, 'To nie jest eksport CSV z Kreski ani plik wiatrów z Rytmu Snu.');
      }
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'Nie udało się wczytać pliku.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _chooseCounter(Map<String, Map<String, int>> counters) {
    final guess = guessGasCounter(counters.keys);
    return showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Który licznik to wiatry?'),
        children: [
          for (final e in counters.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, e.key),
              child: Row(children: [
                Expanded(child: Text(e.key, style: TextStyle(fontWeight: e.key == guess ? FontWeight.w700 : null))),
                Text('${e.value.length} dni', style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
                if (e.key == guess) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 18)),
              ]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = app.active;
        final mine = app.gasSources.where((g) => g.person == p.id).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Wiatry z innych aplikacji')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Opcjonalnie: liczba wiatrów z Kreski i Rytmu Snu dla osoby „${p.name}”. Gdy dane są, Wzorce i analiza AI '
                'biorą je pod uwagę przy ocenie skutków posiłków (noc po dniu jedzenia i następny dzień).'),
            const SizedBox(height: 16),
            for (final g in mine)
              Card(
                elevation: 0,
                color: cs.surfaceContainer,
                child: ListTile(
                  leading: Icon(g.source == gasKreska ? Icons.exposure_plus_1 : Icons.bedtime_outlined),
                  title: Text(g.source == gasKreska ? 'Kreska · licznik „${g.label}”' : 'Rytm Snu'),
                  subtitle: Text(g.source == gasKreska
                      ? '${g.from != null ? '${dayLabel(g.from!)} – ${dayLabel(g.to!)}' : 'brak dni'} · razem ${g.days.values.fold<int>(0, (a, b) => a + b)}'
                          '${g.events.isNotEmpty ? ' · z godzinami' : ' · tylko sumy dni (CSV)'}'
                      : '${g.windows.length} nocy · ${g.events.length} wiatrów'),
                  trailing: IconButton(
                    tooltip: 'Usuń te dane',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirm(context, 'Usunąć dane?', 'Dane z aplikacji ${g.sourceLabel} dla „${p.name}” zostaną usunięte z Dziennika (w ${g.sourceLabel} zostają).')) {
                        app.deleteGas(g.id);
                      }
                    },
                  ),
                ),
              ),
            if (mine.isEmpty) Text('Brak zaimportowanych danych.', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _import,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_open_outlined),
              label: const Text('Wczytaj plik z Kreski lub Rytmu Snu'),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Jak wyeksportować'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.exposure_plus_1),
              title: const Text('Kreska'),
              subtitle: const Text('Raporty → „Eksportuj wpisy z godzinami (JSON)” i wybierz licznik z wiatrami (np. FF) – wtedy wiatry liczą się od godziny posiłku. '
                  'Starszy eksport CSV też działa, ale daje tylko sumy dni.'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Rytm Snu'),
              subtitle: const Text('Ustawienia → Eksport wiatrów do Kreski. Ten sam plik wczytasz tutaj. Wiatry odrzucone przy weryfikacji nie są liczone.'),
            ),
            const SizedBox(height: 8),
            Text('Pliki zawierają całą historię, więc ponowne wczytanie zastępuje poprzednie dane z danej aplikacji. '
                'Kreska JSON i Rytm Snu podają godziny wiatrów, Kreska CSV – tylko sumy dni.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          ]),
        );
      },
    );
  }
}
