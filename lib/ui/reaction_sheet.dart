import 'package:flutter/material.dart';

import '../ai.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';
import 'voice.dart';

Future<void> showReactionSheet(BuildContext context, Meal meal) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReactionSheet(meal: meal),
    );

class _ReactionSheet extends StatefulWidget {
  final Meal meal;
  const _ReactionSheet({required this.meal});
  @override
  State<_ReactionSheet> createState() => _ReactionSheetState();
}

class _ReactionSheetState extends State<_ReactionSheet> {
  late String after;
  int energy = 0, satiety = 0;
  final symptoms = <String>{};
  final note = TextEditingController();
  bool busy = false;
  String? status;

  @override
  void initState() {
    super.initState();
    // podpowiedź „po ilu” na podstawie czasu od posiłku
    final mins = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(widget.meal.ts)).inMinutes;
    after = mins < 45
        ? '30 min'
        : mins < 90
            ? '1 h'
            : mins < 150
                ? '2 h'
                : mins < 12 * 60
                    ? '3 h+'
                    : 'następnego dnia';
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _voice() async {
    final t = await dictate(context, title: 'Jak się czujesz po posiłku?', hint: 'Np. „trochę senny, pełny, lekko wzdęty”');
    if (t == null || t.isEmpty) return;
    if (!await Ai.enabled()) {
      setState(() => note.text = note.text.trim().isEmpty ? t : '${note.text.trim()} $t');
      return;
    }
    setState(() {
      busy = true;
      status = 'Uzupełniam z tego, co powiedziałeś…';
    });
    try {
      final g = await Ai.parseReaction(t);
      setState(() {
        if (g.energy > 0) energy = g.energy;
        if (g.satiety > 0) satiety = g.satiety;
        symptoms.addAll(g.symptoms);
        if (g.after != null) after = g.after!;
        final extra = g.note.isNotEmpty ? g.note : (g.symptoms.isEmpty && g.energy == 0 && g.satiety == 0 ? t : '');
        if (extra.isNotEmpty) note.text = note.text.trim().isEmpty ? extra : '${note.text.trim()} $extra';
        status = 'Sprawdź i zapisz.';
      });
    } on AiError catch (e) {
      setState(() {
        note.text = note.text.trim().isEmpty ? t : '${note.text.trim()} $t';
        status = '${e.message} Tekst trafił do notatki.';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Po: ${widget.meal.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            FilledButton.tonalIcon(onPressed: busy ? null : _voice, icon: const Icon(Icons.mic_none), label: const Text('Powiedz')),
          ]),
          if (status != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(status!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
          label('Ile czasu po jedzeniu'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in reactionAfter) ChoiceChip(label: Text(a), selected: after == a, onSelected: (_) => setState(() => after = a)),
          ]),
          label('Energia (1 = zero sił, 5 = pełno energii)'),
          ScalePicker(value: energy, onChanged: (v) => setState(() => energy = v)),
          label('Sytość (1 = głodny, 5 = przejedzony)'),
          ScalePicker(value: satiety, onChanged: (v) => setState(() => satiety = v)),
          label('Objawy (zostaw puste, jeśli wszystko OK)'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in reactionSymptoms)
              FilterChip(
                label: Text(s),
                selected: symptoms.contains(s),
                selectedColor: Palette.bad(context).withValues(alpha: 0.18),
                onSelected: (v) => setState(() => v ? symptoms.add(s) : symptoms.remove(s)),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Notatka', hintText: 'np. ciężko w brzuchu, dobry trening', suffixIcon: MicButton(controller: note, title: 'Notatka')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    await app.addReaction(widget.meal.id, Reaction(after: after, energy: energy, satiety: satiety, symptoms: symptoms.toList(), note: note.text.trim()));
                    if (context.mounted) Navigator.pop(context);
                  },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Zapisz samopoczucie'),
          ),
        ]),
      ),
    );
  }
}
