import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../ai.dart';
import '../calc.dart';
import '../food_table.dart';
import '../main.dart';
import '../models.dart';
import 'barcode.dart';
import 'format.dart';
import 'home.dart' show MealPhoto;
import 'voice.dart';

String _fmtKcal(double v) => v <= 0 ? '' : v.round().toString();
String _fmtMacro(double v) {
  if (v <= 0) return '';
  if (v >= 10) return v.round().toString();
  return v.toStringAsFixed(1).replaceAll('.', ',').replaceFirst(RegExp(r',0$'), '');
}

class _ItemCtl {
  final name = TextEditingController();
  final grams = TextEditingController();
  final kcal = TextEditingController();
  final p = TextEditingController();
  final c = TextEditingController();
  final f = TextEditingController();
  final focus = FocusNode();
  /// Wartości na 100 g – przy zmianie gramatury kcal i makro przeliczają się same.
  Macros? per100;
  FoodRef? ref; // wybrana podpowiedź (porcja do szybkich przycisków)

  _ItemCtl([FoodItem? i]) {
    if (i == null) return;
    name.text = i.name;
    grams.text = numInput(i.grams);
    kcal.text = _fmtKcal(i.kcal);
    p.text = _fmtMacro(i.protein);
    c.text = _fmtMacro(i.carbs);
    f.text = _fmtMacro(i.fat);
    _derivePer100();
  }

  double get g => parseNum(grams.text) ?? 0;

  void _derivePer100() {
    final gg = g;
    if (gg <= 0) {
      per100 = null;
      return;
    }
    final it = item;
    per100 = Macros(it.kcal * 100 / gg, it.protein * 100 / gg, it.carbs * 100 / gg, it.fat * 100 / gg);
  }

  /// Zmieniono gramaturę: przelicz wartości z bazy na 100 g.
  void gramsChanged() {
    final b = per100;
    if (b == null) {
      _derivePer100();
      return;
    }
    final k = g / 100;
    kcal.text = _fmtKcal(b.kcal * k);
    p.text = _fmtMacro(b.p * k);
    c.text = _fmtMacro(b.c * k);
    f.text = _fmtMacro(b.f * k);
  }

  /// Zmieniono kcal lub makro ręcznie: to staje się nową bazą na 100 g.
  void macroChanged() => _derivePer100();

  void apply(FoodRef r) {
    ref = r;
    name.text = r.name;
    per100 = Macros(r.kcal, r.protein, r.carbs, r.fat);
    if (g <= 0) grams.text = numInput(r.portion);
    gramsChanged();
  }

  void setGrams(double v) {
    grams.text = numInput(v);
    gramsChanged();
  }

  FoodItem get item => FoodItem(
        name: name.text.trim(),
        grams: parseNum(grams.text) ?? 0,
        kcal: parseNum(kcal.text) ?? 0,
        protein: parseNum(p.text) ?? 0,
        carbs: parseNum(c.text) ?? 0,
        fat: parseNum(f.text) ?? 0,
      );
  void dispose() {
    for (final x in [name, grams, kcal, p, c, f]) {
      x.dispose();
    }
    focus.dispose();
  }
}

class MealForm extends StatefulWidget {
  final String date;
  final Meal? meal; // edycja
  final Meal? copyOf; // „zjedz ponownie”
  const MealForm({super.key, required this.date, this.meal, this.copyOf});
  @override
  State<MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<MealForm> {
  final desc = TextEditingController();
  final name = TextEditingController();
  final items = <_ItemCtl>[];
  late final FoodIndex index = FoodIndex.build(app.allMeals);
  late String date;
  late String time;
  late String type;
  Uint8List? newPhoto; // świeżo zrobione zdjęcie
  String? photoName; // zapisane wcześniej
  bool busy = false;
  bool aiOn = false;
  bool aiLocal = false;
  String aiHint = '';
  String? aiNote;
  String? status;
  bool statusErr = false;

  @override
  void initState() {
    super.initState();
    final src = widget.meal ?? widget.copyOf;
    final now = DateTime.now();
    date = widget.meal?.date ?? widget.date;
    time = widget.meal?.time ?? hhmm(now);
    type = src?.type ?? _guessType(now.hour);
    if (src != null) {
      name.text = src.name;
      desc.text = src.desc;
      for (final i in src.items) {
        items.add(_ItemCtl(i));
      }
      photoName = widget.meal?.photo;
    }
    Future.wait([Ai.enabled(), Ai.isLocal(), Ai.setupHint()]).then((r) {
      if (mounted) {
        setState(() {
          aiOn = r[0] as bool;
          aiLocal = r[1] as bool;
          aiHint = r[2] as String;
        });
      }
    });
  }

  static String _guessType(int h) => h < 10
      ? 'Śniadanie'
      : h < 12
          ? 'Drugie śniadanie'
          : h < 16
              ? 'Obiad'
              : h < 18
                  ? 'Podwieczorek'
                  : h < 22
                      ? 'Kolacja'
                      : 'Przekąska';

  @override
  void dispose() {
    desc.dispose();
    name.dispose();
    for (final i in items) {
      i.dispose();
    }
    super.dispose();
  }

  void _status(String? s, {bool err = false}) => setState(() {
        status = s;
        statusErr = err;
      });

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await withExternal(() => ImagePicker().pickImage(source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 80));
      if (x == null) return;
      final b = await x.readAsBytes();
      setState(() => newPhoto = b);
      if (!aiOn || items.isNotEmpty || !mounted) return;
      // opis znacznie poprawia rozpoznanie – pytamy o niego od razu
      if (desc.text.trim().isEmpty) {
        final go = await _askDescription();
        if (go != true) return;
      }
      await _recognize();
    } catch (e) {
      _status('Nie udało się pobrać zdjęcia. Sprawdź uprawnienia aparatu i zdjęć.', err: true);
    }
  }

  /// Arkusz po zrobieniu zdjęcia: krótki opis (pisany lub dyktowany) przed rozpoznaniem.
  Future<bool?> _askDescription() => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Co jest na talerzu?', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Kilka słów wystarczy, np. „ryż, pierś z kurczaka, surówka z marchewki” albo „2 jajka sadzone na maśle”. '
                'AI weźmie produkty i ilości z opisu, a ze zdjęcia oszacuje porcje.',
                style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextField(
              controller: desc,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Opis',
                suffixIcon: IconButton(
                  tooltip: 'Dyktuj',
                  icon: const Icon(Icons.mic_none),
                  onPressed: () async {
                    final t = await dictate(c, title: 'Co jest na talerzu?');
                    if (t == null || t.isEmpty) return;
                    final cur = desc.text.trim();
                    desc.text = cur.isEmpty ? t : '$cur $t';
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Później')),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  desc.clear();
                  Navigator.pop(c, true);
                },
                child: const Text('Bez opisu'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Rozpoznaj')),
            ]),
          ]),
        ),
      ).whenComplete(() {
        if (mounted) setState(() {});
      });

  Future<void> _scan() async {
    final it = await scanFood(context);
    if (it == null) return;
    setState(() {
      items.add(_ItemCtl(it));
      if (name.text.trim().isEmpty) name.text = it.name;
    });
  }

  Future<void> _dictate() async {
    final t = await dictate(context, title: 'Co jesz?', hint: 'Np. „dwie kromki chleba żytniego z twarożkiem i rzodkiewką, kawa z mlekiem”');
    if (t == null || t.isEmpty) return;
    final cur = desc.text.trim();
    desc.text = cur.isEmpty ? t : '$cur $t';
    setState(() {});
    if (aiOn) {
      await _recognize();
    } else {
      _fromDescription();
    }
  }

  /// Rozpisuje opis na składniki z tabeli i historii – bez AI i bez internetu.
  void _fromDescription() {
    final d = desc.text.trim();
    if (d.isEmpty) {
      _status('Najpierw wpisz albo podyktuj, co jesz.', err: true);
      return;
    }
    final r = parseDescription(d, index);
    if (r.items.isEmpty) {
      _status('Nie znalazłem tych produktów w bazie. Dodaj składniki ręcznie${aiOn ? ' albo użyj „Rozpoznaj”' : ''}.', err: true);
      return;
    }
    setState(() {
      final old = items.where((c) => c.name.text.trim().isEmpty).toList();
      items.removeWhere(old.contains);
      _disposeLater(old);
      for (final p in r.items) {
        items.add(_ItemCtl(p.item)..ref = p.ref..per100 = Macros(p.ref.kcal, p.ref.protein, p.ref.carbs, p.ref.fat));
      }
      if (name.text.trim().isEmpty) name.text = d.length > 60 ? '${d.substring(0, 57)}…' : d[0].toUpperCase() + d.substring(1);
    });
    final n = r.items.length;
    _status('Rozpisano: $n ${n == 1 ? 'składnik' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? 'składniki' : 'składników'}.'
        '${r.unknown.isNotEmpty ? ' Nie znaleziono: ${r.unknown.map((u) => '„$u”').join(', ')} – dodaj je ręcznie.' : ' Sprawdź ilości.'}');
  }

  Future<void> _recognize() async {
    final hasPhoto = newPhoto != null;
    if (!hasPhoto && desc.text.trim().isEmpty) {
      _status('Dodaj zdjęcie albo opis posiłku.', err: true);
      return;
    }
    setState(() => busy = true);
    _status(aiLocal ? 'Model na telefonie analizuje posiłek… (to może potrwać do minuty)' : 'Claude analizuje posiłek…');
    try {
      final draft = desc.text.trim().isEmpty ? null : parseDescription(desc.text, index);
      final g = await Ai.recognizeMeal(
        jpeg: newPhoto,
        desc: desc.text,
        index: index,
        draft: draft == null || draft.items.isEmpty ? null : draft.items.map((p) => '${p.ref.name} ${p.grams.round()} g').join(', '),
      );
      _disposeLater([...items]);
      items
        ..clear()
        ..addAll(g.items.map(_ItemCtl.new));
      if (name.text.trim().isEmpty || widget.meal == null) name.text = g.name;
      aiNote = [if (g.confidence.isNotEmpty) 'Pewność rozpoznania: ${g.confidence}.', if (g.note.isNotEmpty) g.note].join(' ');
      _status('Sprawdź gramatury i popraw, jeśli trzeba.');
    } on AiError catch (e) {
      _status(e.message, err: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final its = items.map((c) => c.item).where((i) => i.name.isNotEmpty).toList();
    if (its.isEmpty) {
      _status('Dodaj przynajmniej jeden składnik.', err: true);
      return;
    }
    setState(() => busy = true);
    var photo = photoName;
    if (newPhoto != null) photo = await app.savePhoto(newPhoto!);
    final old = widget.meal;
    final m = Meal(
      id: old?.id ?? newId('m'),
      person: old?.person ?? app.active.id,
      date: date,
      time: time,
      type: type,
      name: name.text.trim().isEmpty ? its.take(3).map((i) => i.name).join(', ') : name.text.trim(),
      desc: desc.text.trim(),
      items: its,
      photo: photo,
      reactions: old?.reactions,
      created: old?.created,
      extra: old?.extra,
    );
    await app.saveMeal(m);
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, old == null ? 'Zapisano. Za jakiś czas dodaj, jak się czujesz.' : 'Zapisano zmiany');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = Macros.ofItems(items.map((c) => c.item));
    return Scaffold(
      appBar: AppBar(title: Text(widget.meal != null ? 'Edytuj posiłek' : 'Nowy posiłek')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
        // zdjęcie
        Row(children: [
          GestureDetector(
            onTap: () => _pick(ImageSource.camera),
            child: newPhoto != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(newPhoto!, width: 96, height: 96, fit: BoxFit.cover))
                : photoName != null
                    ? MealPhoto(photoName, size: 96)
                    : Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(color: Palette.sunk(context), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.photo_camera_outlined, size: 36, color: cs.onSurfaceVariant),
                      ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.tonalIcon(onPressed: busy ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Zrób zdjęcie')),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(onPressed: busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Kod'))),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          aiOn
              ? (aiLocal ? 'Model na telefonie rozpozna, co jest na talerzu, i oszacuje kalorie (darmowo, bez internetu).' : 'Claude rozpozna, co jest na talerzu, i oszacuje kalorie.')
              : '$aiHint Produkty paczkowane dodasz skanerem kodów, resztę ręcznie.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: desc,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Opis (opcjonalnie)',
            hintText: 'np. dwie kromki chleba żytniego z twarożkiem, kawa z mlekiem',
            suffixIcon: IconButton(tooltip: 'Dyktuj', icon: const Icon(Icons.mic_none), onPressed: busy ? null : _dictate),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (desc.text.trim().isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : _fromDescription,
              icon: const Icon(Icons.format_list_bulleted, size: 18),
              label: const Text('Rozpisz opis na składniki (bez AI)'),
            ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
              value: type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Posiłek'),
              items: [for (final t in mealTypes) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => type = v ?? type),
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 18),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.parse('${date}T12:00:00'), firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => date = isoDate(d));
              },
              label: Text(dayLabel(date), overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule, size: 18),
            onPressed: () async {
              final p = time.split(':');
              final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 12, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0));
              if (t != null) setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
            },
            label: Text(time),
          ),
        ]),
        const SizedBox(height: 16),
        if (aiOn)
          FilledButton.icon(
            onPressed: busy ? null : _recognize,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(items.isEmpty ? 'Rozpoznaj i policz' : 'Rozpoznaj ponownie'),
          ),
        if (status != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(status!, style: TextStyle(color: statusErr ? cs.error : cs.onSurfaceVariant))),
        const SizedBox(height: 12),
        TextField(controller: name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nazwa posiłku', hintText: 'np. Owsianka z bananem')),
        SectionTitle('Składniki', trailing: TextButton.icon(onPressed: () => setState(() => items.add(_ItemCtl())), icon: const Icon(Icons.add), label: const Text('Składnik'))),
        if (items.isEmpty)
          Text('Brak składników. ${aiOn ? 'Zrób zdjęcie, podyktuj opis albo dodaj składnik ręcznie.' : 'Dodaj składnik ręcznie.'}', style: TextStyle(color: cs.onSurfaceVariant)),
        for (final (i, c) in items.indexed) _itemRow(i, c),
        if (aiNote != null && aiNote!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(aiNote!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text('Razem', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${total.kcal.round()} kcal · B ${total.p.round()} · W ${total.c.round()} · T ${total.f.round()}',
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tabular)),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Zapisz posiłek')),
        ),
      ),
    );
  }

  /// Kontrolery zwalniamy po klatce, gdy pola już zniknęły z ekranu.
  void _disposeLater(Iterable<_ItemCtl> xs) {
    final list = xs.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final x in list) {
        x.dispose();
      }
    });
  }

  void _removeItem(int i) {
    final x = items.removeAt(i);
    setState(() {});
    _disposeLater([x]);
  }

  Widget _itemRow(int i, _ItemCtl c) {
    final cs = Theme.of(context).colorScheme;
    Widget num(TextEditingController ctl, String label, {bool isGrams = false}) => Expanded(
          child: TextField(
            controller: ctl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(fontFeatures: tabular, fontWeight: isGrams ? FontWeight.w700 : null),
            decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            onChanged: (_) => setState(() {
              if (isGrams) {
                c.gramsChanged();
              } else {
                c.macroChanged();
              }
            }),
          ),
        );
    final b = c.per100;
    final r = c.ref;
    return Padding(
      key: ObjectKey(c),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: RawAutocomplete<FoodRef>(
              textEditingController: c.name,
              focusNode: c.focus,
              displayStringForOption: (o) => o.name,
              optionsBuilder: (v) => index.search(v.text),
              onSelected: (o) => setState(() => c.apply(o)),
              fieldViewBuilder: (context, ctl, focus, onSubmit) => TextField(
                controller: ctl,
                focusNode: focus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Składnik ${i + 1}', hintText: 'zacznij pisać, np. chleb, jajko, ryż'),
                onSubmitted: (_) => onSubmit(),
              ),
              optionsViewBuilder: (context, onSelect, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 300, maxWidth: MediaQuery.of(context).size.width - 80),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                            dense: true,
                            title: Text(o.name),
                            subtitle: Text('${o.kcal.round()} kcal · B ${_fmtMacro(o.protein).isEmpty ? '0' : _fmtMacro(o.protein)} · W ${_fmtMacro(o.carbs).isEmpty ? '0' : _fmtMacro(o.carbs)} · T ${_fmtMacro(o.fat).isEmpty ? '0' : _fmtMacro(o.fat)} na 100 g',
                                style: const TextStyle(fontFeatures: tabular)),
                            trailing: o.mine ? const Chip2('Twoje') : null,
                            onTap: () => onSelect(o),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Usuń składnik',
            icon: const Icon(Icons.close),
            onPressed: () => _removeItem(i),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          num(c.grams, 'g', isGrams: true),
          const SizedBox(width: 6),
          num(c.kcal, 'kcal'),
          const SizedBox(width: 6),
          num(c.p, 'B'),
          const SizedBox(width: 6),
          num(c.c, 'W'),
          const SizedBox(width: 6),
          num(c.f, 'T'),
          const SizedBox(width: 48),
        ]),
        if (b != null || r != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (b != null) Text('${b.kcal.round()} kcal/100 g', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              if (r != null && r.portion > 0)
                for (final n in const [0.5, 1.0, 2.0])
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${n == 0.5 ? '½' : n.round()} × ${r.portionLabel} (${(r.portion * n).round()} g)', style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => c.setGrams(r.portion * n)),
                  ),
            ]),
          ),
      ]),
    );
  }
}
