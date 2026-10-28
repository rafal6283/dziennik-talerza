import 'dart:io';

import 'package:flutter/material.dart';

import '../calc.dart';
import '../main.dart';
import '../models.dart';
import 'imported.dart';
import 'charts.dart';
import 'format.dart';
import 'gut_form.dart';
import 'meal_form.dart';
import 'patterns.dart';
import 'profile.dart';
import 'reaction_sheet.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String day = todayIso();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = app.active;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: _PersonSwitcher(onAdd: () async {
              await app.addPerson();
              setState(() => tab = 2);
            }),
            actions: [
              IconButton(
                tooltip: 'Ustawienia',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          body: !app.loaded
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: tab, children: [
                  JournalTab(
                    day: day,
                    onDay: (d) => setState(() => day = d),
                    onProfile: () => setState(() => tab = 2),
                  ),
                  const PatternsTab(),
                  ProfileTab(key: ValueKey(p.id)),
                ]),
          floatingActionButton: tab == 0 && app.loaded
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealForm(date: day))),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Posiłek'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Dziennik'),
              NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Wzorce'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        );
      },
    );
  }
}

class _PersonSwitcher extends StatelessWidget {
  final VoidCallback onAdd;
  const _PersonSwitcher({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final p = app.active;
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Czyj dziennik',
      onSelected: (v) => v == '+' ? onAdd() : app.setActive(v),
      itemBuilder: (_) => [
        for (final x in app.people)
          CheckedPopupMenuItem(value: x.id, checked: x.id == p.id, child: Text(x.name)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '+', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_add_alt), title: Text('Dodaj osobę'))),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer, child: Text(p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(), style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        const Icon(Icons.arrow_drop_down),
      ]),
    );
  }
}

// ======================= DZIENNIK =======================

class JournalTab extends StatelessWidget {
  final String day;
  final ValueChanged<String> onDay;
  final VoidCallback onProfile;
  const JournalTab({super.key, required this.day, required this.onDay, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    final meals = app.mealsOn(day);
    final today = todayIso();
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          IconButton(tooltip: 'Poprzedni dzień', icon: const Icon(Icons.chevron_left), onPressed: () => onDay(shiftDay(day, -1))),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse('${day}T12:00:00'),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) onDay(isoDate(d));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(dayLabel(day), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          IconButton(tooltip: 'Następny dzień', icon: const Icon(Icons.chevron_right), onPressed: day.compareTo(today) >= 0 ? null : () => onDay(shiftDay(day, 1))),
        ]),
      ),
      if (!profileComplete(app.active))
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Uzupełnij profil'),
              subtitle: const Text('Płeć, wiek, wzrost i waga ustawią cel kalorii i białka dla tej osoby.'),
              onTap: onProfile,
            ),
          ),
        ),
      _BudgetCard(day: day),
      _GutCard(day: day),
      SectionTitle('Posiłki · ${meals.length}'),
      if (meals.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              const Text('Brak posiłków tego dnia.'),
              const SizedBox(height: 4),
              Text('Stuknij „Posiłek”, zrób zdjęcie albo podyktuj, co jesz.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ]),
          ),
        ),
      for (final m in meals) MealCard(meal: m),
    ]);
  }
}

class _BudgetCard extends StatelessWidget {
  final String day;
  const _BudgetCard({required this.day});
  @override
  Widget build(BuildContext context) {
    final t = dayTotal(app.meals, day);
    final goal = app.goal;
    final left = goal - t.kcal;
    final pt = proteinOf(app.active);
    final cs = Theme.of(context).colorScheme;
    Widget macro(String l, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: tabular)),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // liczba kalorii "dolicza się" do nowej wartości
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: t.kcal),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) =>
                Text('${v.round()}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1, fontFeatures: tabular)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('z $goal kcal', overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant)))),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(left >= 0 ? 'zostało ${left.round()}' : '${(-left).round()} ponad cel',
                style: TextStyle(color: left >= 0 ? cs.onSurfaceVariant : Palette.bad(context), fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Meter(goal > 0 ? t.kcal / goal : 0, left >= 0 ? Palette.amber(context) : Palette.bad(context), height: 10),
        const SizedBox(height: 14),
        Row(children: [
          MacroRing(m: t, size: 84),
          const SizedBox(width: 14),
          Expanded(
            child: Column(children: [
              Row(children: [
                macro('Białko', pt != null ? '${t.p.round()} / $pt g' : '${t.p.round()} g'),
                macro('Węglowodany', '${t.c.round()} g'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                macro('Tłuszcz', '${t.f.round()} g'),
                const Expanded(child: SizedBox()),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ---------- trawienie ----------

class _GutCard extends StatelessWidget {
  final String day;
  const _GutCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final entries = app.gutOn(day);
    final yMeals = app.mealsOn(shiftDay(day, -1));
    final morning = day == todayIso() && entries.isEmpty && yMeals.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    void open({GutEntry? e, bool voice = false, String? when}) => Navigator.push(
        context, MaterialPageRoute(builder: (_) => GutForm(date: day, entry: e, startWithVoice: voice, when: when)));
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Trawienie', overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          IconButton(tooltip: 'Powiedz, jak się czujesz', icon: const Icon(Icons.mic_none), onPressed: () => open(voice: true)),
          TextButton.icon(onPressed: () => open(), icon: const Icon(Icons.add), label: const Text('Wpis')),
        ]),
        if (morning)
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Jak trawienie po wczorajszych posiłkach?', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Wpis z rana pomaga wychwycić opóźnione reakcje.', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: () => open(when: 'rano'), child: const Text('Oceń teraz')),
                OutlinedButton.icon(onPressed: () => open(when: 'rano', voice: true), icon: const Icon(Icons.mic_none, size: 18), label: const Text('Powiedz')),
              ]),
            ]),
          ),
        if (entries.isEmpty && !morning)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Brak wpisów tego dnia. Dodaj wpis, gdy coś Ci dolega albo rano po kolacji.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
        for (final g in entries) _GutTile(entry: g, onEdit: () => open(e: g)),
        Builder(builder: (context) {
          final s = app.gasSeries;
          if (!s.any) return const SizedBox.shrink();
          final dd = s.day(day), nb = s.nightAfter(shiftDay(day, -1)), na = s.nightAfter(day);
          final parts = [
            if (nb != null) 'noc przed: $nb',
            if (dd != null) 'w ciągu dnia: $dd',
            if (na != null) 'noc po: $na',
          ];
          if (parts.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Icon(Icons.timeline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text('FF · ${parts.join(' · ')}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
              const SizedBox(width: 6),
              ImportedTag(importedFromGas(kreska: dd != null, night: nb != null || na != null)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _GutTile extends StatelessWidget {
  final GutEntry entry;
  final VoidCallback onEdit;
  const _GutTile({required this.entry, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final g = entry;
    final cs = Theme.of(context).colorScheme;
    final sus = g.suspects.map((id) => app.allMeals.where((m) => m.id == id)).where((x) => x.isNotEmpty).map((x) => x.first.name);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(g.when, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (g.comfort > 0) Chip2('komfort ${g.comfort}/5 · ${comfortNames[g.comfort]}', color: Palette.comfort(context, g.comfort)),
            for (final s in g.symptoms) Chip2('${s.name} · ${severityNames[s.sev]}', color: Palette.severity(context, s.sev), solid: s.sev == 3),
            if (g.symptoms.isEmpty) Chip2('bez objawów', color: Palette.good(context)),
            if (g.bristol > 0) Chip2('Bristol ${g.bristol}'),
          ]),
          if (sus.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Podejrzewane: ${sus.join(', ')}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
          if (g.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(g.note, style: const TextStyle(fontSize: 13.5))),
        ]),
      ),
    );
  }
}

// ---------- posiłek ----------

class MealPhoto extends StatelessWidget {
  final String? name;
  final double size;
  const MealPhoto(this.name, {super.key, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Palette.sunk(context), borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.restaurant, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    if (name == null) return ph;
    return FutureBuilder<File?>(
      future: app.photoFile(name),
      builder: (_, s) => s.data == null
          ? ph
          : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(s.data!, width: size, height: size, fit: BoxFit.cover, cacheWidth: (size * 3).round())),
    );
  }
}

class MealCard extends StatelessWidget {
  final Meal meal;
  const MealCard({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final m = meal;
    final t = m.total;
    final cs = Theme.of(context).colorScheme;
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealForm(date: m.date, meal: m))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MealPhoto(m.photo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m.type} · ${m.time}'.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                Text(m.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(m.items.map((i) => '${i.name} ${i.grams.round()} g').join(' · '), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                Text('B ${t.p.round()} · W ${t.c.round()} · T ${t.f.round()}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontFeatures: tabular)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: Text('${t.kcal.round()} kcal', style: TextStyle(color: Palette.amber(context), fontWeight: FontWeight.w700, fontFeatures: tabular)),
            ),
          ]),
        ),
        for (final (i, r) in m.reactions.indexed)
          Container(
            margin: const EdgeInsets.only(top: 8, right: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('po ${r.after}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  if (r.energy > 0) Chip2('energia ${r.energy}/5', color: r.energy >= 4 ? Palette.good(context) : r.energy <= 2 ? Palette.bad(context) : null),
                  if (r.satiety > 0) Chip2('sytość ${r.satiety}/5'),
                  for (final s in r.symptoms) Chip2(s, color: Palette.bad(context)),
                  if (r.symptoms.isEmpty) Chip2('bez objawów', color: Palette.good(context)),
                  if (r.note.isNotEmpty) Text(r.note, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ]),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Usuń ocenę',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () async {
                  if (await confirm(context, 'Usunąć ocenę?', 'Ocena samopoczucia po ${r.after} zostanie usunięta.')) app.deleteReaction(m.id, i);
                },
              ),
            ]),
          ),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            onPressed: () => showReactionSheet(context, m),
            icon: const Icon(Icons.mood_outlined, size: 18),
            label: const Text('Jak się czujesz po?'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MealForm(date: m.date, meal: m)));
              } else if (v == 'copy') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MealForm(date: todayIso(), copyOf: m)));
              } else if (v == 'del' && await confirm(context, 'Usunąć posiłek?', '„${m.name}” zostanie usunięty razem z ocenami.')) {
                app.deleteMeal(m.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edytuj')),
              PopupMenuItem(value: 'copy', child: Text('Zjedz ponownie dziś')),
              PopupMenuItem(value: 'del', child: Text('Usuń')),
            ],
          ),
        ]),
      ]),
    );
  }
}
