// Stan aplikacji: osoby, posiłki, trawienie. Zapis do pliku JSON w katalogu aplikacji,
// miniatury zdjęć jako osobne pliki w podkatalogu photos/.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'calc.dart';
import 'extras.dart';
import 'fodmap.dart';
import 'gas.dart';
import 'models.dart';

class ImportSummary {
  final int people, meals, gut, added, updated;
  const ImportSummary(this.people, this.meals, this.gut, this.added, this.updated);
}

class AppState extends ChangeNotifier {
  /// Wywoływane po zapisie / usunięciu posiłku (np. synchronizacja z Health Connect).
  Future<void> Function(Meal m)? onMealSaved;
  Future<void> Function(String id)? onMealDeleted;
  Future<void> Function(String mealId)? onReaction;

  /// Odświeżenie widoków po zmianie danych spoza magazynu (np. aktywność z Health Connect).
  void refresh() => notifyListeners();

  List<Person> people = [Person(id: 'me', name: 'Ja')];
  String activeId = 'me';
  List<Meal> allMeals = [];
  List<GutEntry> allGut = [];
  List<GasSource> gasSources = [];
  List<Elimination> eliminations = [];
  List<Favorite> favorites = [];
  List<Recipe> recipes = [];
  List<Drink> allDrinks = [];
  List<WeightEntry> allWeights = [];
  List<MedEntry> allMeds = [];
  List<PantryItem> pantry = [];

  /// Wywoływane po każdej zmianie danych (widżet, przypomnienia).
  final List<void Function()> afterCommit = [];
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
    _diskHash = null;
    _knownIds = const {};
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
  GasSeries get gasSeries => GasSeries(gasSources.where((g) => g.person == active.id));

  // ---------- wczytanie i zapis ----------

  Future<void> load() async {
    try {
      final f = await _dataFile();
      if (await f.exists()) {
        final text = await f.readAsString();
        _apply(jsonDecode(text), replace: true);
        _diskHash = text.hashCode;
        _knownIds = _ids();
      }
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
        if (gasSources.isNotEmpty) 'gasSources': gasSources.map((g) => g.toJson()).toList(),
        if (eliminations.isNotEmpty) 'eliminations': eliminations.map((e) => e.toJson()).toList(),
        if (favorites.isNotEmpty) 'favorites': favorites.map((e) => e.toJson()).toList(),
        if (recipes.isNotEmpty) 'recipes': recipes.map((e) => e.toJson()).toList(),
        if (allDrinks.isNotEmpty) 'drinks': allDrinks.map((e) => e.toJson()).toList(),
        if (allWeights.isNotEmpty) 'weights': allWeights.map((e) => e.toJson()).toList(),
        if (allMeds.isNotEmpty) 'meds': allMeds.map((e) => e.toJson()).toList(),
        if (pantry.isNotEmpty) 'pantry': pantry.map((e) => e.toJson()).toList(),
      };

  // ---------- zapis bezpieczny dla kilku procesów ----------
  // Kopia/wymiana Koofr działa w tle w osobnym procesie (izolacie) z własnym obrazem danych. Gdyby zapisywała
  // plik „na ślepo”, nadpisałaby wpisy dodane w tym czasie w aplikacji (np. leki dodane rano znikały).
  // Dlatego przed każdym zapisem: jeśli plik zmienił się od naszego ostatniego odczytu/zapisu, dołączamy
  // z niego wpisy, których nie znamy (nowe z innego procesu); wpisów, które sami usunęliśmy, nie przywracamy.

  int? _diskHash; // skrót treści pliku przy ostatnim odczycie/zapisie przez ten proces
  Map<String, Set<String>> _knownIds = const {}; // identyfikatory wpisów w tym momencie
  Future<void> _saveChain = Future.value();
  bool _noMerge = false; // przywrócenie kopii: plik na dysku jest nieaktualny z definicji

  Map<String, Set<String>> _ids() => {
        'people': {for (final x in people) x.id},
        'meals': {for (final x in allMeals) x.id},
        'gut': {for (final x in allGut) x.id},
        'gasSources': {for (final x in gasSources) x.id},
        'eliminations': {for (final x in eliminations) x.id},
        'favorites': {for (final x in favorites) x.id},
        'recipes': {for (final x in recipes) x.id},
        'drinks': {for (final x in allDrinks) x.id},
        'weights': {for (final x in allWeights) x.id},
        'meds': {for (final x in allMeds) x.id},
        'pantry': {for (final x in pantry) x.id},
      };

  /// Dołącza wpisy zapisane przez inny proces. Zwraca, czy coś się zmieniło.
  bool _mergeDisk(dynamic j) {
    if (j is! Map || j['people'] is! List) return false;
    var changed = false;
    void add<T>(String key, List<T> into, T Function(Map<String, dynamic>) f, String Function(T) id, {bool preferDisk = false}) {
      final raw = j[key] is List ? j[key] as List : const []; // puste listy nie trafiają do pliku
      final known = _knownIds[key] ?? const <String>{};
      final onDisk = <String>{};
      for (final e in raw) {
        if (e is! Map) continue;
        final T x;
        try {
          x = f(Map<String, dynamic>.from(e));
        } catch (_) {
          continue;
        }
        final k = id(x);
        onDisk.add(k);
        final i = into.indexWhere((y) => id(y) == k);
        if (i >= 0) {
          if (preferDisk) into[i] = x; // wiatry z Rytmu Snu/Kreski pobiera tylko proces w tle
          continue;
        }
        if (known.contains(k)) continue; // usunięty tutaj
        into.add(x);
        changed = true;
      }
      // był w pliku przy naszym ostatnim zapisie, a teraz go nie ma → usunięty w innym procesie
      final before = into.length;
      into.removeWhere((y) => known.contains(id(y)) && !onDisk.contains(id(y)));
      if (into.length != before) changed = true;
    }

    add<Person>('people', people, Person.fromJson, (x) => x.id);
    add<Meal>('meals', allMeals, Meal.fromJson, (x) => x.id);
    add<GutEntry>('gut', allGut, GutEntry.fromJson, (x) => x.id);
    add<GasSource>('gasSources', gasSources, GasSource.fromJson, (x) => x.id, preferDisk: true);
    add<Elimination>('eliminations', eliminations, Elimination.fromJson, (x) => x.id);
    add<Favorite>('favorites', favorites, Favorite.fromJson, (x) => x.id);
    add<Recipe>('recipes', recipes, Recipe.fromJson, (x) => x.id);
    add<Drink>('drinks', allDrinks, Drink.fromJson, (x) => x.id);
    add<WeightEntry>('weights', allWeights, WeightEntry.fromJson, (x) => x.id);
    add<MedEntry>('meds', allMeds, MedEntry.fromJson, (x) => x.id);
    add<PantryItem>('pantry', pantry, PantryItem.fromJson, (x) => x.id);
    return changed;
  }

  /// Po powrocie do aplikacji: dołącz to, co w międzyczasie zapisał proces w tle.
  Future<void> syncFromDisk() async {
    await _saveChain;
    try {
      final f = await _dataFile();
      if (!await f.exists()) return;
      final text = await f.readAsString();
      if (text.hashCode == _diskHash) return;
      final changed = _mergeDisk(jsonDecode(text));
      _diskHash = text.hashCode;
      _knownIds = _ids();
      if (changed) await _commit();
    } catch (e) {
      debugPrint('sync error $e');
    }
  }

  Future<void> _save() {
    final next = _saveChain.then((_) => _saveNow());
    _saveChain = next.catchError((_) {});
    return next;
  }

  Future<void> _saveNow() async {
    final f = await _dataFile();
    if (!_noMerge && await f.exists()) {
      try {
        final text = await f.readAsString();
        if (text.hashCode != _diskHash && _mergeDisk(jsonDecode(text))) notifyListeners();
      } catch (_) {}
    }
    _noMerge = false;
    final out = jsonEncode(toJson());
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(out, flush: true);
    await tmp.rename(f.path);
    _diskHash = out.hashCode;
    _knownIds = _ids();
  }

  Future<void> _commit() async {
    notifyListeners();
    await _save();
    for (final f in afterCommit) {
      try {
        f();
      } catch (_) {}
    }
  }

  /// Tylko do testów: wczytanie danych z mapy.
  void replaceFromJsonForTest(Map<String, dynamic> j) => _apply(j, replace: true);

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
    final ngas = [for (final e in (j['gasSources'] is List ? j['gasSources'] as List : const [])) if (e is Map) GasSource.fromJson(Map<String, dynamic>.from(e))];
    for (final g in ngas) {
      gasSources.removeWhere((x) => x.id == g.id);
      gasSources.add(g);
    }
    final nel = [for (final e in (j['eliminations'] is List ? j['eliminations'] as List : const [])) if (e is Map) Elimination.fromJson(Map<String, dynamic>.from(e))];
    if (replace && j.containsKey('eliminations')) eliminations = [];
    for (final e in nel) {
      eliminations.removeWhere((x) => x.id == e.id);
      eliminations.add(e);
    }
    // dodatkowe dzienniki: zastąpienie przy przywracaniu, scalanie po id przy imporcie
    List<T> extra<T>(String key, List<T> cur, T Function(Map<String, dynamic>) f, String Function(T) id) {
      final raw = j[key];
      if (raw is! List) return replace ? <T>[] : cur;
      final list = [for (final e in raw) if (e is Map) f(Map<String, dynamic>.from(e))];
      if (replace) return list;
      final out = [...cur];
      for (final x in list) {
        out.removeWhere((y) => id(y) == id(x));
        out.add(x);
      }
      return out;
    }

    favorites = extra('favorites', favorites, Favorite.fromJson, (x) => x.id);
    recipes = extra('recipes', recipes, Recipe.fromJson, (x) => x.id);
    allDrinks = extra('drinks', allDrinks, Drink.fromJson, (x) => x.id);
    allWeights = extra('weights', allWeights, WeightEntry.fromJson, (x) => x.id);
    allMeds = extra('meds', allMeds, MedEntry.fromJson, (x) => x.id);
    pantry = extra('pantry', pantry, PantryItem.fromJson, (x) => x.id);
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

  /// Przywrócenie kopii: zastępuje wszystkie dane (zdjęcia podmienia wcześniej wywołujący).
  Future<ImportSummary> replaceFromBytes(List<int> bytes) async {
    final s = _apply(jsonDecode(utf8.decode(bytes)), replace: true);
    _noMerge = true;
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
    gasSources.removeWhere((g) => g.person == id);
    favorites.removeWhere((x) => x.person == id);
    allDrinks.removeWhere((x) => x.person == id);
    allWeights.removeWhere((x) => x.person == id);
    allMeds.removeWhere((x) => x.person == id);
    people.removeWhere((p) => p.id == id);
    if (activeId == id) activeId = people.first.id;
    await _commit();
  }

  // ---------- ulubione, przepisy, napoje, waga, leki, spiżarnia ----------

  List<Favorite> get myFavorites =>
      favorites.where((f) => f.person == active.id).toList()..sort((a, b) => b.lastUsed != a.lastUsed ? b.lastUsed.compareTo(a.lastUsed) : b.uses.compareTo(a.uses));
  List<Drink> get drinks => allDrinks.where((d) => d.person == active.id).toList();
  List<WeightEntry> get weights => allWeights.where((w) => w.person == active.id).toList()..sort((a, b) => a.date.compareTo(b.date));
  List<MedEntry> get meds => allMeds.where((m) => m.person == active.id).toList()..sort((a, b) => a.ts.compareTo(b.ts));
  List<MedEntry> medsOn(String date) => meds.where((m) => m.date == date).toList();

  Future<void> _upsert<T>(List<T> list, T x, String Function(T) id) async {
    final i = list.indexWhere((y) => id(y) == id(x));
    if (i >= 0) {
      list[i] = x;
    } else {
      list.add(x);
    }
    await _commit();
  }

  Future<void> _remove<T>(List<T> list, String id, String Function(T) idOf) async {
    list.removeWhere((y) => idOf(y) == id);
    await _commit();
  }

  Future<void> saveFavorite(Favorite f) => _upsert(favorites, f, (x) => x.id);
  Future<void> deleteFavorite(String id) => _remove<Favorite>(favorites, id, (x) => x.id);
  Future<void> saveRecipe(Recipe r) => _upsert(recipes, r, (x) => x.id);
  Future<void> deleteRecipe(String id) => _remove<Recipe>(recipes, id, (x) => x.id);
  Future<void> saveDrink(Drink d) => _upsert(allDrinks, d, (x) => x.id);
  Future<void> deleteDrink(String id) => _remove<Drink>(allDrinks, id, (x) => x.id);
  Future<void> saveMed(MedEntry m) => _upsert(allMeds, m, (x) => x.id);
  Future<void> deleteMed(String id) => _remove<MedEntry>(allMeds, id, (x) => x.id);
  Future<void> savePantry(PantryItem p) => _upsert(pantry, p, (x) => x.id);
  Future<void> deletePantry(String id) => _remove<PantryItem>(pantry, id, (x) => x.id);
  Future<void> addPantry(Iterable<PantryItem> items) async {
    for (final p in items) {
      pantry.removeWhere((x) => !x.used && x.name.toLowerCase() == p.name.toLowerCase() && x.brand.toLowerCase() == p.brand.toLowerCase());
      pantry.add(p);
    }
    await _commit();
  }

  /// Nowy pomiar wagi; najnowszy pomiar aktualizuje też wagę w profilu (cel kalorii, białko, woda).
  Future<void> saveWeight(WeightEntry w) async {
    allWeights.removeWhere((x) => x.person == w.person && x.date == w.date && x.id != w.id);
    final i = allWeights.indexWhere((x) => x.id == w.id);
    if (i >= 0) {
      allWeights[i] = w;
    } else {
      allWeights.add(w);
    }
    final mine = allWeights.where((x) => x.person == w.person).toList()..sort((a, b) => a.date.compareTo(b.date));
    final pi = people.indexWhere((p) => p.id == w.person);
    if (pi >= 0 && mine.isNotEmpty) people[pi].weight = mine.last.kg;
    await _commit();
  }

  Future<void> deleteWeight(String id) => _remove<WeightEntry>(allWeights, id, (x) => x.id);

  /// Posiłek z ulubionego (albo z „to co zwykle”) – teraz, dla wybranej osoby.
  Future<Meal> addMealFrom({required String name, required List<FoodItem> items, String? type, String? date, String? time}) async {
    final now = DateTime.now();
    final m = Meal(
      id: newId('m'),
      person: active.id,
      date: date ?? isoDate(now),
      time: time ?? hhmm(now),
      type: type ?? mealTypeFor(now.hour),
      name: name,
      items: [for (final i in items) i.copy()],
    );
    await saveMeal(m);
    final f = favorites.where((x) => x.person == active.id && x.name.toLowerCase() == name.toLowerCase());
    for (final x in f) {
      x.uses++;
      x.lastUsed = now.millisecondsSinceEpoch;
    }
    return m;
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
    onMealSaved?.call(m); // w tle — zapis w dzienniku nie czeka na Health Connect
  }

  Future<void> deleteMeal(String id) async {
    final m = allMeals.where((x) => x.id == id);
    if (m.isNotEmpty) await _deletePhoto(m.first.photo);
    allMeals.removeWhere((x) => x.id == id);
    for (final g in allGut) {
      g.suspects.remove(id);
    }
    await _commit();
    onMealDeleted?.call(id);
  }

  Future<void> addReaction(String mealId, Reaction r) async {
    final m = allMeals.firstWhere((x) => x.id == mealId);
    m.reactions.add(r);
    await _commit();
    onReaction?.call(mealId);
  }

  Future<void> deleteReaction(String mealId, int index) async {
    final m = allMeals.firstWhere((x) => x.id == mealId);
    if (index >= 0 && index < m.reactions.length) m.reactions.removeAt(index);
    await _commit();
  }

  // ---------- wiatry z Kreski i Rytmu Snu ----------

  // ---------- dieta eliminacyjna ----------

  /// Bieżąca (albo ostatnia) dieta eliminacyjna aktywnej osoby.
  Elimination? get elimination {
    final mine = eliminations.where((e) => e.person == active.id).toList()..sort((a, b) => b.start.compareTo(a.start));
    return mine.firstOrNull;
  }

  /// Dieta trwa dziś (od startu do końca ostatniej przerwy).
  Elimination? get activeElimination {
    final e = elimination;
    final t = todayIso();
    return e != null && !e.stopped && e.end.compareTo(t) >= 0 ? e : null;
  }

  Future<void> saveElimination(Elimination e) async {
    eliminations.removeWhere((x) => x.id == e.id);
    eliminations.add(e);
    await _commit();
  }

  Future<void> deleteElimination(String id) async {
    eliminations.removeWhere((x) => x.id == id);
    await _commit();
  }

  Future<void> setGas(GasSource g) async {
    gasSources.removeWhere((x) => x.id == g.id);
    gasSources.add(g);
    await _commit();
  }

  Future<void> deleteGas(String id) async {
    gasSources.removeWhere((x) => x.id == id);
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
