// Stan aplikacji: osoby, posiłki, trawienie. Zapis do pliku JSON w katalogu aplikacji,
// miniatury zdjęć jako osobne pliki w podkatalogu photos/.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'calc.dart';
import 'models.dart';

class ImportSummary {
  final int people, meals, gut, added, updated;
  const ImportSummary(this.people, this.meals, this.gut, this.added, this.updated);
}

class AppState extends ChangeNotifier {
  List<Person> people = [Person(id: 'me', name: 'Ja')];
  String activeId = 'me';
  List<Meal> allMeals = [];
  List<GutEntry> allGut = [];
  bool loaded = false;

  Directory? _dir;
  File? _file;

  /// Katalog danych – w testach można podać tymczasowy.
  Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    _dir = await getApplicationDocumentsDirectory();
    return _dir!;
  }

  @visibleForTesting
  void useDirectory(Directory d) {
    _dir = d;
    _file = null;
  }

  Future<File> _dataFile() async => _file ??= File('${(await dir()).path}/dziennik.json');
  Future<Directory> _photoDir() async {
    final d = Directory('${(await dir()).path}/photos');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File?> photoFile(String? name) async {
    if (name == null) return null;
    final f = File('${(await _photoDir()).path}/$name');
    return await f.exists() ? f : null;
  }

  // ---------- widok wybranej osoby ----------

  Person get active => people.firstWhere((p) => p.id == activeId, orElse: () => people.first);
  List<Meal> get meals => allMeals.where((m) => m.person == active.id).toList()..sort((a, b) => a.ts.compareTo(b.ts));
  List<GutEntry> get gut => allGut.where((g) => g.person == active.id).toList()..sort((a, b) => a.ts.compareTo(b.ts));
  List<Meal> mealsOn(String date) => meals.where((m) => m.date == date).toList();
  List<GutEntry> gutOn(String date) => gut.where((g) => g.date == date).toList();
  int get goal => goalOf(active);

  // ---------- wczytanie i zapis ----------

  Future<void> load() async {
    try {
      final f = await _dataFile();
      if (await f.exists()) _apply(jsonDecode(await f.readAsString()), replace: true);
    } catch (e) {
      debugPrint('load error $e');
    }
    loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson({bool withPhotos = false}) => {
        'app': 'dziennik-talerza',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'active': activeId,
        'people': people.map((p) => p.toJson()).toList(),
        'meals': allMeals.map((m) => m.toJson()).toList(),
        'gut': allGut.map((g) => g.toJson()).toList(),
      };

  Future<void> _save() async {
    final f = await _dataFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> _commit() async {
    notifyListeners();
    await _save();
  }

  ImportSummary _apply(dynamic j, {required bool replace}) {
    if (j is! Map) throw const FormatException('To nie jest plik kopii Dziennika talerza');
    final rawP = j['people'], rawM = j['meals'], rawG = j['gut'];
    if (rawP is! List && rawM is! List && rawG is! List) throw const FormatException('W pliku nie ma danych Dziennika talerza');
    final np = [for (final e in (rawP is List ? rawP : const [])) if (e is Map) Person.fromJson(Map<String, dynamic>.from(e))];
    final nm = [for (final e in (rawM is List ? rawM : const [])) if (e is Map) Meal.fromJson(Map<String, dynamic>.from(e))]
        .where((m) => m.date.length == 10)
        .toList();
    final ng = [for (final e in (rawG is List ? rawG : const [])) if (e is Map) GutEntry.fromJson(Map<String, dynamic>.from(e))]
        .where((g) => g.date.length == 10)
        .toList();
    var added = 0, updated = 0;
    if (replace) {
      if (np.isNotEmpty) people = np;
      allMeals = nm;
      allGut = ng;
      final a = j['active'];
      if (a is String && people.any((p) => p.id == a)) activeId = a;
    } else {
      void merge<T>(List<T> into, List<T> from, String Function(T) id) {
        for (final x in from) {
          final i = into.indexWhere((y) => id(y) == id(x));
          if (i >= 0) {
            into[i] = x;
            updated++;
          } else {
            into.add(x);
            added++;
          }
        }
      }

      merge<Person>(people, np, (p) => p.id);
      merge<Meal>(allMeals, nm, (m) => m.id);
      merge<GutEntry>(allGut, ng, (g) => g.id);
    }
    if (people.isEmpty) people = [Person(id: 'me', name: 'Ja')];
    // wpisy osób, których nie ma na liście, trafiają do nowej osoby zamiast znikać
    for (final pid in {...allMeals.map((m) => m.person), ...allGut.map((g) => g.person)}) {
      if (!people.any((p) => p.id == pid)) people.add(Person(id: pid, name: pid == 'me' ? 'Ja' : 'Osoba ${people.length + 1}'));
    }
    if (!people.any((p) => p.id == activeId)) activeId = people.first.id;
    return ImportSummary(np.length, nm.length, ng.length, added, updated);
  }

  Uint8List exportBytes() => Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(toJson())));

  /// Import kopii z aplikacji albo eksportu z wersji przeglądarkowej (miniatury w polu `photo` jako data:image).
  Future<ImportSummary> importBytes(List<int> bytes) async {
    final j = jsonDecode(utf8.decode(bytes));
    final s = _apply(j, replace: false);
    // miniatury z wersji przeglądarkowej
    if (j is Map && j['meals'] is List) {
      for (final e in j['meals'] as List) {
        if (e is! Map) continue;
        final data = e['photo'];
        if (data is String && data.startsWith('data:image')) {
          final m = allMeals.where((x) => x.id == '${e['id']}');
          if (m.isEmpty || m.first.photo != null) continue;
          try {
            final b = base64Decode(data.substring(data.indexOf(',') + 1));
            m.first.photo = await savePhoto(b);
          } catch (_) {}
        }
      }
    }
    await _commit();
    return s;
  }

  Future<String> savePhoto(List<int> bytes) async {
    final name = '${newId('f')}.jpg';
    await File('${(await _photoDir()).path}/$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<void> _deletePhoto(String? name) async {
    if (name == null) return;
    try {
      final f = File('${(await _photoDir()).path}/$name');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---------- osoby ----------

  Future<void> setActive(String id) async {
    activeId = id;
    await _commit();
  }

  Future<Person> addPerson() async {
    final p = Person(id: newId('p'), name: 'Osoba ${people.length + 1}');
    people.add(p);
    activeId = p.id;
    await _commit();
    return p;
  }

  Future<void> updatePerson(Person p) async {
    final i = people.indexWhere((x) => x.id == p.id);
    if (i >= 0) people[i] = p;
    await _commit();
  }

  Future<void> deletePerson(String id) async {
    if (people.length < 2) return;
    for (final m in allMeals.where((m) => m.person == id)) {
      await _deletePhoto(m.photo);
    }
    allMeals.removeWhere((m) => m.person == id);
    allGut.removeWhere((g) => g.person == id);
    people.removeWhere((p) => p.id == id);
    if (activeId == id) activeId = people.first.id;
    await _commit();
  }

  // ---------- posiłki ----------

  Future<void> saveMeal(Meal m) async {
    final i = allMeals.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      if (allMeals[i].photo != m.photo) await _deletePhoto(allMeals[i].photo);
      allMeals[i] = m;
    } else {
      allMeals.add(m);
    }
    await _commit();
  }

  Future<void> deleteMeal(String id) async {
    final m = allMeals.where((x) => x.id == id);
    if (m.isNotEmpty) await _deletePhoto(m.first.photo);
    allMeals.removeWhere((x) => x.id == id);
    for (final g in allGut) {
      g.suspects.remove(id);
    }
    await _commit();
  }

  Future<void> addReaction(String mealId, Reaction r) async {
    final m = allMeals.firstWhere((x) => x.id == mealId);
    m.reactions.add(r);
    await _commit();
  }

  Future<void> deleteReaction(String mealId, int index) async {
    final m = allMeals.firstWhere((x) => x.id == mealId);
    if (index >= 0 && index < m.reactions.length) m.reactions.removeAt(index);
    await _commit();
  }

  // ---------- trawienie ----------

  Future<void> saveGut(GutEntry g) async {
    final i = allGut.indexWhere((x) => x.id == g.id);
    if (i >= 0) {
      allGut[i] = g;
    } else {
      allGut.add(g);
    }
    await _commit();
  }

  Future<void> deleteGut(String id) async {
    allGut.removeWhere((x) => x.id == id);
    await _commit();
  }
}
