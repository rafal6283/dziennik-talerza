import 'package:flutter/material.dart';

import '../calc.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Person d; // szkic
  final name = TextEditingController();
  final year = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final goal = TextEditingController();
  final notes = TextEditingController();
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    _fill();
  }

  void _fill() {
    d = app.active.copy();
    name.text = d.name;
    year.text = d.birthYear > 0 ? '${d.birthYear}' : '';
    height.text = d.height > 0 ? '${d.height}' : '';
    weight.text = numInput(d.weight);
    goal.text = d.manualGoal > 0 ? '${d.manualGoal}' : '';
    notes.text = d.notes;
    dirty = false;
  }

  @override
  void dispose() {
    for (final c in [name, year, height, weight, goal, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    d
      ..name = name.text.trim().isEmpty ? 'Bez imienia' : name.text.trim()
      ..birthYear = int.tryParse(year.text.trim()) ?? 0
      ..height = (parseNum(height.text) ?? 0).round()
      ..weight = ((parseNum(weight.text) ?? 0) * 10).round() / 10
      ..manualGoal = (parseNum(goal.text) ?? 0).round()
      ..notes = notes.text.trim();
    setState(() => dirty = true);
  }

  Future<void> _save() async {
    _sync();
    final y = DateTime.now().year;
    if (d.birthYear != 0 && (d.birthYear < 1910 || d.birthYear > y)) {
      toast(context, 'Podaj rok urodzenia, np. 1985.');
      return;
    }
    if (d.height != 0 && (d.height < 50 || d.height > 250)) {
      toast(context, 'Wzrost podaj w centymetrach, np. 178.');
      return;
    }
    if (d.weight != 0 && (d.weight < 10 || d.weight > 350)) {
      toast(context, 'Wagę podaj w kilogramach, np. 82,5.');
      return;
    }
    if (d.manualGoal != 0 && (d.manualGoal < 800 || d.manualGoal > 6000)) {
      toast(context, 'Cel kalorii: od 800 do 6000 kcal albo puste pole.');
      return;
    }
    await app.updatePerson(d.copy());
    setState(() => dirty = false);
    if (mounted) toast(context, 'Zapisano profil');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = ageOf(d), b = bmrOf(d), t = tdeeOf(d), auto = autoGoalOf(d), pr = proteinOf(d), bmi = bmiOf(d);
    final minor = a != null && a < 18;
    Widget stat(String l, String v, [String? sub]) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFeatures: tabular)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          ]),
        );
    InputDecoration dec(String l, [String? hint]) => InputDecoration(labelText: l, hintText: hint);
    const gap = SizedBox(height: 12);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
      Text('Profil: ${d.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.3,
        children: [
          stat('Wiek', a != null ? '$a lat' : '–'),
          stat('BMI', bmi != null && !minor ? bmi.toStringAsFixed(1).replaceAll('.', ',') : '–', minor ? 'u dzieci wg siatek' : null),
          stat('Spoczynkowo', b != null ? '${b.round()}' : '–', 'kcal'),
          stat('Zapotrzebowanie', t != null ? '${t.round()}' : '–', 'kcal'),
          stat('Cel', '${goalOf(d)}', d.manualGoal > 0 ? 'ręczny' : (auto != null ? 'wyliczony' : 'domyślny')),
          stat('Białko', pr != null ? '$pr g' : '–', 'dziennie'),
        ],
      ),
      const SizedBox(height: 16),
      TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: dec('Imię'), onChanged: (_) => _sync()),
      gap,
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: d.sex,
            decoration: dec('Płeć'),
            items: const [DropdownMenuItem(value: '', child: Text('—')), DropdownMenuItem(value: 'k', child: Text('Kobieta')), DropdownMenuItem(value: 'm', child: Text('Mężczyzna'))],
            onChanged: (v) {
              d.sex = v ?? '';
              _sync();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: year, keyboardType: TextInputType.number, decoration: dec('Rok urodzenia', 'np. 1985'), onChanged: (_) => _sync())),
      ]),
      gap,
      Row(children: [
        Expanded(child: TextField(controller: height, keyboardType: TextInputType.number, decoration: dec('Wzrost (cm)'), onChanged: (_) => _sync())),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec('Waga (kg)'), onChanged: (_) => _sync())),
      ]),
      gap,
      DropdownButtonFormField<String>(
        value: activityLevels.any((x) => x.$1 == d.activity) ? d.activity : '1.375',
        isExpanded: true,
        decoration: dec('Aktywność'),
        items: [for (final x in activityLevels) DropdownMenuItem(value: x.$1, child: Text(x.$2, overflow: TextOverflow.ellipsis))],
        onChanged: (v) {
          d.activity = v ?? d.activity;
          _sync();
        },
      ),
      gap,
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: goalModes.any((x) => x.$1 == d.mode) ? d.mode : 'keep',
            isExpanded: true,
            decoration: dec('Cel'),
            items: [for (final x in goalModes) DropdownMenuItem(value: x.$1, child: Text(x.$2))],
            onChanged: (v) {
              d.mode = v ?? d.mode;
              _sync();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: goal,
            keyboardType: TextInputType.number,
            decoration: dec('Cel kcal (ręcznie)', auto != null ? 'wyliczony: $auto' : 'np. 2200'),
            onChanged: (_) => _sync(),
          ),
        ),
      ]),
      gap,
      TextField(
        controller: notes,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: dec('Uwagi dla analizy', 'dieta, nietolerancje, alergie, choroby, leki, np. nietolerancja laktozy, trenuje rano'),
        onChanged: (_) => _sync(),
      ),
      const SizedBox(height: 10),
      Text(
        minor
            ? 'Ta osoba ma mniej niż 18 lat. Wzory na zapotrzebowanie są tu tylko orientacyjne, a cel redukcji nie jest stosowany. Dietę dziecka lub nastolatka najlepiej ustalać z pediatrą lub dietetykiem.'
            : 'Zapotrzebowanie liczone wzorem Mifflina-St Jeora razy współczynnik aktywności. Redukcja to ok. 400 kcal mniej (nie mniej niż 110% przemiany spoczynkowej), budowa masy ok. 250 kcal więcej. Białko: 1,2 g/kg przy utrzymaniu, 1,6 g/kg przy redukcji i budowie masy. To szacunek, nie zalecenie medyczne.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: dirty ? _save : null, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: Text(dirty ? 'Zapisz profil' : 'Zapisano')),
      if (app.people.length > 1) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          icon: const Icon(Icons.delete_outline),
          label: Text('Usuń osobę: ${app.active.name}'),
          onPressed: () async {
            final n = app.meals.length, g = app.gut.length;
            if (await confirm(context, 'Usunąć ${app.active.name}?', 'Zostaną usunięte profil, $n posiłków i $g wpisów o trawieniu tej osoby. Tego nie da się cofnąć.')) {
              await app.deletePerson(app.active.id);
            }
          },
        ),
      ],
      const SizedBox(height: 8),
      Text('Każda osoba ma osobny dziennik. Przełączasz je na górze ekranu.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
    ]);
  }
}
