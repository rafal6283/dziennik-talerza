import 'package:flutter/material.dart';

import '../ai.dart';
import '../calc.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';
import 'voice.dart';

class GutForm extends StatefulWidget {
  final String date;
  final GutEntry? entry;
  final bool startWithVoice;
  final String? when;
  const GutForm({super.key, required this.date, this.entry, this.startWithVoice = false, this.when});
  @override
  State<GutForm> createState() => _GutFormState();
}

class _GutFormState extends State<GutForm> {
  late String when;
  int comfort = 0;
  final sev = <String, int>{};
  int bristol = 0;
  final suspects = <String>{};
  final note = TextEditingController();
  bool busy = false;
  String? status;
  bool statusErr = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final h = DateTime.now().hour;
    when = e?.when ?? widget.when ?? (h < 5 ? 'w nocy' : h < 11 ? 'rano' : h < 18 ? 'w ciągu dnia' : 'wieczorem');
    if (e != null) {
      comfort = e.comfort;
      for (final s in e.symptoms) {
        sev[s.name] = s.sev;
      }
      bristol = e.bristol;
      suspects.addAll(e.suspects);
      note.text = e.note;
    }
    if (widget.startWithVoice) WidgetsBinding.instance.addPostFrameCallback((_) => _voice());
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _voice() async {
    final t = await dictate(context, title: 'Jak Twój brzuch?', hint: 'Np. „rano lekkie wzdęcia i trochę gazów, poza tym dobrze, stolec normalny”');
    if (t == null || t.isEmpty) return;
    if (!await Ai.enabled()) {
      setState(() {
        note.text = note.text.trim().isEmpty ? t : '${note.text.trim()} $t';
        status = 'Zapisałem to w notatce. Zaznacz objawy poniżej. Z modelem AI (Ustawienia → Rozpoznawanie AI) pola uzupełnią się same.';
        statusErr = false;
      });
      return;
    }
    setState(() {
      busy = true;
      status = 'Uzupełniam z tego, co powiedziałeś…';
      statusErr = false;
    });
    try {
      final g = await Ai.parseGut(t);
      setState(() {
        if (g.comfort > 0) comfort = g.comfort;
        for (final s in g.symptoms) {
          sev[s.name] = s.sev;
        }
        if (g.bristol > 0) bristol = g.bristol;
        if (g.when != null) when = g.when!;
        final extra = g.note.isNotEmpty ? g.note : (g.symptoms.isEmpty && g.comfort == 0 ? t : '');
        if (extra.isNotEmpty) note.text = note.text.trim().isEmpty ? extra : '${note.text.trim()} $extra';
        status = 'Sprawdź i zapisz.';
      });
    } on AiError catch (e) {
      setState(() {
        note.text = note.text.trim().isEmpty ? t : '${note.text.trim()} $t';
        status = '${e.message} Tekst trafił do notatki.';
        statusErr = true;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final syms = [for (final e in sev.entries) if (e.value > 0) GutSymptom(e.key, e.value)];
    if (comfort == 0 && syms.isEmpty) {
      setState(() {
        status = 'Zaznacz komfort albo choć jeden objaw.';
        statusErr = true;
      });
      return;
    }
    final old = widget.entry;
    await app.saveGut(GutEntry(
      id: old?.id ?? newId('g'),
      person: old?.person ?? app.active.id,
      date: old?.date ?? widget.date,
      when: when,
      comfort: comfort,
      symptoms: syms,
      bristol: bristol,
      suspects: suspects.toList(),
      note: note.text.trim(),
      created: old?.created,
      extra: old?.extra,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = widget.entry?.date ?? widget.date;
    final cands = [...app.mealsOn(date), ...app.mealsOn(shiftDay(date, -1))]..sort((a, b) => b.ts.compareTo(a.ts));
    Widget label(String t, [String? sub]) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (sub != null) Text(sub, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry != null ? 'Wpis o trawieniu' : 'Trawienie · ${dayLabel(date).toLowerCase()}'),
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: 'Usuń wpis',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Usunąć wpis?', 'Wpis o trawieniu zostanie usunięty.')) {
                  await app.deleteGut(widget.entry!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
        Material(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: busy ? null : _voice,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(backgroundColor: cs.primary, child: busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary)) : Icon(Icons.mic, color: cs.onPrimary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Powiedz, jak się czujesz', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                    Text('Formularz uzupełni się sam, potem tylko sprawdzasz.', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        if (status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(status!, style: TextStyle(color: statusErr ? cs.error : cs.onSurfaceVariant))),
        label('Kiedy'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final w in gutWhen) ChoiceChip(label: Text(w.$1), selected: when == w.$1, onSelected: (_) => setState(() => when = w.$1)),
        ]),
        label('Ogólny komfort brzucha'),
        ScalePicker(value: comfort, labels: comfortNames, onChanged: (v) => setState(() => comfort = v)),
        label('Objawy', 'Stuknij kilka razy: lekki → średni → silny → brak'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in gutSymptoms)
            _SevChip(name: s, sev: sev[s] ?? 0, onTap: () => setState(() => sev[s] = ((sev[s] ?? 0) + 1) % 4)),
        ]),
        label('Stolec wg skali bristolskiej', 'Opcjonalnie. 3–4 to norma.'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.25,
          children: [
            for (final b in bristolScale)
              _Tile(
                selected: bristol == b.$1,
                onTap: () => setState(() => bristol = bristol == b.$1 ? 0 : b.$1),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${b.$1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(b.$2, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
                ]),
              ),
          ],
        ),
        label('Co mogło to wywołać?', 'Opcjonalnie. Bez zaznaczenia liczą się wszystkie posiłki z 30 godzin przed wpisem.'),
        if (cands.isEmpty) Text('Brak zapisanych posiłków z tego i poprzedniego dnia.', style: TextStyle(color: cs.onSurfaceVariant)),
        for (final m in cands)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: suspects.contains(m.id),
            onChanged: (v) => setState(() => v == true ? suspects.add(m.id) : suspects.remove(m.id)),
            title: Text(m.name),
            subtitle: Text('${dayLabel(m.date)} · ${m.type} ${m.time}'),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Notatka', hintText: 'np. obudziło mnie w nocy, pomogła mięta', suffixIcon: MicButton(controller: note, title: 'Notatka')),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Zapisz wpis')),
        ),
      ),
    );
  }
}

class _SevChip extends StatelessWidget {
  final String name;
  final int sev;
  final VoidCallback onTap;
  const _SevChip({required this.name, required this.sev, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = sev == 0 ? null : Palette.severity(context, sev);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c == null ? null : (sev == 3 ? c : c.withValues(alpha: 0.16)),
          border: Border.all(color: c ?? cs.outlineVariant),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(sev == 0 ? name : '$name · ${severityNames[sev]}',
            style: TextStyle(fontSize: 13.5, fontWeight: sev == 0 ? FontWeight.w500 : FontWeight.w700, color: sev == 3 ? cs.surface : (c ?? cs.onSurface))),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _Tile({required this.selected, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : null,
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
