import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../ai.dart';
import '../calc.dart';
import '../main.dart';
import '../models.dart';
import 'format.dart';
import 'home.dart' show MealPhoto;
import 'voice.dart';

class _ItemCtl {
  final name = TextEditingController();
  final grams = TextEditingController();
  final kcal = TextEditingController();
  final p = TextEditingController();
  final c = TextEditingController();
  final f = TextEditingController();
  _ItemCtl([FoodItem? i]) {
    if (i == null) return;
    name.text = i.name;
    grams.text = numInput(i.grams);
    kcal.text = numInput(i.kcal);
    p.text = numInput(i.protein);
    c.text = numInput(i.carbs);
    f.text = numInput(i.fat);
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
  late String date;
  late String time;
  late String type;
  Uint8List? newPhoto; // świeżo zrobione zdjęcie
  String? photoName; // zapisane wcześniej
  bool busy = false;
  bool aiOn = false;
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
    Ai.enabled().then((v) => mounted ? setState(() => aiOn = v) : null);
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
      if (aiOn && items.isEmpty) await _recognize();
    } catch (e) {
      _status('Nie udało się pobrać zdjęcia. Sprawdź uprawnienia aparatu i zdjęć.', err: true);
    }
  }

  Future<void> _dictate() async {
    final t = await dictate(context, title: 'Co jesz?', hint: 'Np. „dwie kromki chleba żytniego z twarożkiem i rzodkiewką, kawa z mlekiem”');
    if (t == null || t.isEmpty) return;
    final cur = desc.text.trim();
    desc.text = cur.isEmpty ? t : '$cur $t';
    setState(() {});
    if (aiOn) await _recognize();
  }

  Future<void> _recognize() async {
    final hasPhoto = newPhoto != null;
    if (!hasPhoto && desc.text.trim().isEmpty) {
      _status('Dodaj zdjęcie albo opis posiłku.', err: true);
      return;
    }
    setState(() => busy = true);
    _status('Claude analizuje posiłek…');
    try {
      final g = await Ai.recognizeMeal(jpeg: newPhoto, desc: desc.text);
      for (final i in items) {
        i.dispose();
      }
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
              OutlinedButton.icon(onPressed: busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Z galerii')),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          aiOn ? 'Claude rozpozna, co jest na talerzu, i oszacuje kalorie.' : 'Rozpoznawanie ze zdjęć włączysz w Ustawieniach (klucz API). Składniki możesz wpisać ręcznie.',
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

  Widget _itemRow(int i, _ItemCtl c) {
    Widget num(TextEditingController ctl, String label) => Expanded(
          child: TextField(
            controller: ctl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(fontFeatures: tabular),
            decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: c.name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Składnik ${i + 1}'),
            ),
          ),
          IconButton(
            tooltip: 'Usuń składnik',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => items.removeAt(i).dispose()),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          num(c.grams, 'g'),
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
      ]),
    );
  }
}
