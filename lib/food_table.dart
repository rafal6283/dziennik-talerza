// Wbudowana tabela orientacyjnych wartości odżywczych (na 100 g / 100 ml) popularnych produktów i dań w Polsce
// oraz podpowiedzi z historii wpisów. Działa bez internetu.

import 'models.dart';

class FoodRef {
  final String name;
  final List<String> aliases;
  final double kcal, protein, carbs, fat; // na 100 g
  final double portion; // typowa porcja w g
  final String portionLabel;
  final bool mine; // z historii użytkownika
  final int uses;
  const FoodRef(this.name, this.aliases, this.kcal, this.protein, this.carbs, this.fat, this.portion, this.portionLabel,
      {this.mine = false, this.uses = 0});

  FoodItem item(double grams) => FoodItem(
        name: name,
        grams: grams,
        kcal: kcal * grams / 100,
        protein: protein * grams / 100,
        carbs: carbs * grams / 100,
        fat: fat * grams / 100,
      );
}

// nazwa|synonim;kcal;białko;węglowodany;tłuszcz;porcja g;porcja
const _table = '''
chleb żytni|chleb razowy|chleb żytni razowy;220;6;42;1.7;35;kromka
chleb pszenny|chleb biały|chleb tostowy;250;8;50;1.2;30;kromka
chleb mieszany|chleb baltonowski|chleb wiejski;240;7;48;1.5;35;kromka
chleb graham|chleb pełnoziarnisty;236;8;45;1.8;35;kromka
bułka pszenna|kajzerka|bułka;275;8.5;56;2;50;bułka
bułka grahamka|grahamka;255;9;48;2.5;60;bułka
rogal maślany|croissant|rogalik;406;8;46;21;60;sztuka
bagietka;270;9;55;1.5;60;kawałek
tortilla pszenna|tortilla|wrap;310;8.5;52;7.5;60;placek
chałka;300;8;54;5.5;40;kromka
pieczywo chrupkie|wasa;340;9;70;2;10;kromka
wafle ryżowe|wafel ryżowy;390;8;81;3;9;wafel
płatki owsiane|owsiane;370;13;58;7;40;porcja
płatki kukurydziane|corn flakes;375;7.5;84;1;30;porcja
musli;370;9;64;7;50;porcja
granola;450;10;60;18;50;porcja
ryż biały ugotowany|ryż|ryż ugotowany;130;2.7;28;0.3;150;porcja
ryż brązowy ugotowany|ryż brązowy;123;2.7;25.5;1;150;porcja
ryż suchy|ryż surowy;344;6.7;78;0.7;100;woreczek
makaron ugotowany|makaron|spaghetti;158;5.8;31;0.9;200;porcja
makaron suchy|makaron surowy;360;12.5;72;1.5;100;porcja
makaron pełnoziarnisty ugotowany|makaron pełnoziarnisty;150;6;29;1.5;200;porcja
kasza gryczana ugotowana|kasza gryczana;105;3.6;21;0.9;150;porcja
kasza jaglana ugotowana|kasza jaglana|jaglanka;119;3.5;23.7;1;150;porcja
kasza jęczmienna ugotowana|kasza jęczmienna|pęczak;123;2.3;25;0.4;150;porcja
kasza manna sucha|kasza manna|kaszka manna;340;10;71;1;30;porcja
kuskus ugotowany|kuskus;112;3.8;23;0.2;150;porcja
bulgur ugotowany|bulgur;83;3.1;14;0.2;150;porcja
komosa ryżowa ugotowana|quinoa|komosa ryżowa;120;4.4;19;1.9;150;porcja
mąka pszenna|mąka;345;10;72;1.2;10;łyżka
ziemniaki gotowane|ziemniaki|ziemniak;80;1.9;17.5;0.1;200;porcja
ziemniaki puree|puree ziemniaczane|tłuczone ziemniaki;105;2;15;4;200;porcja
frytki;312;3.4;41;15;150;porcja
placki ziemniaczane|placek ziemniaczany;230;4;25;13;150;porcja
pierogi ruskie;195;6;30;5.5;250;porcja
pierogi z mięsem;230;10;28;8.5;250;porcja
pierogi z kapustą i grzybami|pierogi z kapustą;185;5;30;5;250;porcja
naleśnik|naleśniki;225;6;28;10;60;naleśnik
kopytka|kluski śląskie|kluski;160;3.5;32;1.5;200;porcja
pizza|pizza margherita;265;11;33;10;110;kawałek
zapiekanka;250;9;30;10;250;sztuka
pierś z kurczaka pieczona|pierś z kurczaka|pierś z kurczaka grillowana|kurczak grillowany;165;31;0;3.6;120;porcja
pierś z kurczaka surowa|filet z kurczaka surowy;105;22;0;1.8;150;porcja
udko z kurczaka pieczone|udko z kurczaka|udko;210;26;0;11;150;udko
kurczak pieczony|kurczak;215;25;0;12.5;150;porcja
kotlet schabowy|schabowy;285;20;10;18.5;150;kotlet
schab pieczony|schab;200;28;0;9.5;120;porcja
karkówka pieczona|karkówka|karkówka z grilla;260;24;0;18;150;porcja
kotlet mielony|mielony|klopsiki;260;15;9;18;120;kotlet
gulasz wołowy;140;13;5;7.5;250;porcja
stek wołowy|wołowina;220;27;0;12;200;porcja
pierś z indyka pieczona|indyk|pierś z indyka;145;30;0;2.5;120;porcja
mięso mielone wieprzowe|mięso mielone;260;17;0;21;100;porcja
kiełbasa|kiełbasa podwawelska;290;14;1.5;25.5;100;kawałek
kiełbasa śląska|kiełbasa zwyczajna;260;14;1;22;100;kawałek
parówki|parówka;260;11;2;23;40;parówka
szynka|szynka wieprzowa|szynka gotowana;120;19;1.5;4.5;15;plaster
polędwica sopocka|polędwica;115;19;2;3.5;15;plaster
szynka z indyka|polędwica z indyka;100;18;2;2;15;plaster
boczek|boczek wędzony;460;13;1;45;20;plaster
salami;430;22;1;38;10;plaster
kabanos|kabanosy;430;24;2;36;25;kabanos
pasztet;300;12;6;25;30;porcja
łosoś pieczony|łosoś;206;22;0;13;120;porcja
łosoś wędzony;170;21;0;9.5;50;porcja
dorsz pieczony|dorsz|ryba pieczona;105;23;0;0.9;150;porcja
tuńczyk w wodzie|tuńczyk z puszki|tuńczyk;116;26;0;1;120;puszka
tuńczyk w oleju;190;26;0;9;120;puszka
śledź w oleju|śledź;280;14;1;25;60;porcja
makrela wędzona|makrela;260;19;0;20;100;porcja
paluszki rybne;220;12;20;10;100;porcja
krewetki;99;24;0.2;0.3;100;porcja
jajko|jajka|jajo|jajko gotowane;140;12.5;0.7;9.7;60;jajko
jajecznica;185;11.5;1.5;15;150;porcja
jajko sadzone;195;13.5;0.8;15;60;jajko
mleko 2%|mleko;51;3.4;4.8;2;250;szklanka
mleko 3,2%|mleko pełne;61;3.2;4.7;3.2;250;szklanka
mleko 0,5%|mleko odtłuszczone;39;3.5;4.9;0.5;250;szklanka
napój owsiany|mleko owsiane;45;0.5;7;1.5;250;szklanka
napój sojowy|mleko sojowe;40;3.3;2.5;1.8;250;szklanka
jogurt naturalny;61;4.3;6;2;150;kubek
jogurt grecki|jogurt typu greckiego;120;4;4;10;150;kubek
skyr;63;11;3.8;0.2;150;kubek
kefir;50;3.4;4.5;2;250;szklanka
maślanka;37;3.4;4.7;0.5;250;szklanka
jogurt owocowy;95;3.5;14;2.5;150;kubek
serek wiejski;98;11;2.5;4.5;200;opakowanie
twaróg półtłusty|twaróg|ser biały;133;18;3.7;4.7;50;porcja
twaróg chudy;99;19.8;3.5;0.5;50;porcja
twaróg tłusty;175;17;3.5;10;50;porcja
serek śmietankowy|serek do smarowania|serek kanapkowy;230;7;3;21;20;porcja
ser żółty|ser gouda|ser edamski|ser;350;25;0.5;27;20;plaster
mozzarella;250;18;2;19;30;porcja
ser feta|feta;265;14;4;21;30;porcja
parmezan;430;35;3;30;10;łyżka
camembert|brie;300;20;0.5;24;30;porcja
ser topiony;270;12;6;22;20;porcja
śmietana 18%|śmietana;185;2.5;3.5;18;15;łyżka
śmietana 12%;133;2.7;3.8;12;15;łyżka
śmietanka 30%|śmietanka;290;2.3;3;30;15;łyżka
masło;740;0.7;0.6;82;5;porcja na kromkę
margaryna;540;0.2;0.5;60;5;porcja na kromkę
olej rzepakowy|olej|oliwa|oliwa z oliwek;884;0;0;100;10;łyżka
pomidor|pomidory;18;0.9;3;0.2;120;sztuka
pomidorki koktajlowe;20;0.9;3.5;0.2;15;sztuka
ogórek|ogórki;14;0.7;2.4;0.1;100;sztuka
ogórek kiszony|ogórki kiszone;12;0.5;2;0.2;60;sztuka
papryka;28;1;5;0.3;150;sztuka
sałata;15;1.3;1.5;0.2;30;garść
rzodkiewka|rzodkiewki;16;0.7;2.5;0.1;15;sztuka
cebula;40;1.1;8;0.1;100;sztuka
czosnek;150;6;30;0.5;5;ząbek
marchew|marchewka;41;0.9;7;0.2;70;sztuka
brokuł|brokuły;34;2.8;4;0.4;150;porcja
kalafior;25;1.9;3;0.3;150;porcja
kapusta biała|kapusta;25;1.3;4.5;0.1;100;porcja
kapusta kiszona;16;1;2;0.2;100;porcja
szpinak;23;2.9;1.5;0.4;50;garść
burak gotowany|buraki|burak;44;1.7;8;0.2;100;sztuka
fasolka szparagowa;31;1.8;4.5;0.2;150;porcja
groszek zielony|groszek;80;5.4;10;0.4;80;porcja
kukurydza konserwowa|kukurydza;90;3;15;1.5;80;porcja
cukinia;17;1.2;2.5;0.3;150;porcja
bakłażan;25;1;3;0.2;150;porcja
pieczarki|grzyby;22;3.1;1;0.3;100;porcja
awokado;160;2;2;15;75;pół sztuki
surówka z kapusty|surówka|coleslaw;60;1;6;3.5;100;porcja
surówka z marchewki;55;1;9;1.5;100;porcja
mizeria;50;1.2;3.5;3.5;150;porcja
fasola czerwona|fasola;105;7;14;0.5;100;porcja
ciecierzyca;164;8.9;19;2.6;100;porcja
soczewica ugotowana|soczewica;116;9;12;0.4;150;porcja
tofu;130;13;2;7.5;100;porcja
hummus;260;7.5;12;19;30;porcja
jabłko;50;0.3;11.5;0.2;180;sztuka
banan;90;1.1;21;0.3;120;sztuka
gruszka;57;0.4;13;0.1;170;sztuka
pomarańcza;47;0.9;10;0.1;180;sztuka
mandarynka|mandarynki;53;0.8;12;0.3;70;sztuka
truskawki;32;0.7;6;0.3;150;miseczka
borówki|jagody;57;0.7;12;0.3;100;garść
maliny;52;1.2;6;0.7;100;garść
winogrona;69;0.7;16;0.2;100;garść
śliwki;46;0.7;10;0.3;100;porcja
kiwi;61;1.1;12;0.5;75;sztuka
arbuz;30;0.6;7.5;0.2;300;kawałek
brzoskwinia;39;0.9;9;0.3;150;sztuka
ananas;50;0.5;12;0.1;100;porcja
mango;60;0.8;14;0.4;150;porcja
cytryna;29;1.1;6;0.3;10;plasterek
rodzynki;300;3;70;0.5;20;garść
daktyle suszone|daktyle;280;2.5;67;0.4;30;garść
morele suszone;240;3.4;55;0.5;30;garść
orzechy włoskie;654;15;7;65;30;garść
migdały;580;21;9.5;50;30;garść
orzechy laskowe;630;15;7;61;30;garść
orzeszki ziemne|orzeszki;590;26;10;50;30;garść
orzechy nerkowca|nerkowce;553;18;30;44;30;garść
pestki dyni;560;30;5;49;20;garść
słonecznik|pestki słonecznika;584;21;11;51;20;garść
siemię lniane;534;18;2;42;10;łyżka
masło orzechowe;600;25;15;50;15;łyżka
nasiona chia|chia;486;17;8;31;10;łyżka
czekolada mleczna|czekolada;535;7.5;58;30;25;4 kostki
czekolada gorzka;570;8;35;42;25;4 kostki
herbatniki|ciastka;460;7;70;16;10;ciastko
wafelek w czekoladzie|wafelek|prince polo;520;6;60;28;35;batonik
baton czekoladowy|batonik|snickers;490;8;60;24;50;baton
drożdżówka;330;7;52;10;100;sztuka
pączek;380;6;50;17;75;pączek
sernik;300;8;25;18;120;kawałek
szarlotka|jabłecznik;250;3;36;10;120;kawałek
ciasto drożdżowe|placek drożdżowy;320;6;50;10;100;kawałek
lody śmietankowe|lody;210;3.5;24;11;60;gałka
chipsy;540;6.5;50;35;30;garść
paluszki słone|paluszki;380;10;75;4;30;garść
popcorn;450;9;55;22;30;garść
miód;305;0.3;82;0;10;łyżeczka
cukier;400;0;100;0;5;łyżeczka
dżem|konfitura;220;0.4;54;0.1;15;łyżka
krem czekoladowy|nutella;540;6;57;31;15;łyżka
żelki;340;6;77;0.2;25;garść
kawa czarna|kawa;2;0.1;0;0;250;filiżanka
kawa z mlekiem|biała kawa;12;0.7;1;0.5;250;kubek
cappuccino;38;2;3;2;200;filiżanka
latte;45;2.5;4;1.8;300;kubek
herbata;1;0;0.2;0;250;kubek
sok pomarańczowy;45;0.7;10;0.2;250;szklanka
sok jabłkowy;46;0.1;11;0.1;250;szklanka
cola|coca-cola|napój gazowany;42;0;10.6;0;330;puszka
cola zero|napój zero;0;0;0;0;330;puszka
piwo;43;0.5;3.6;0;500;kufel
piwo bezalkoholowe;25;0.4;5.5;0;500;kufel
wino czerwone|wino;85;0.1;2.6;0;150;kieliszek
wino białe;82;0.1;2.6;0;150;kieliszek
wódka;231;0;0;0;40;kieliszek
napój izotoniczny|izotonik;25;0;6;0;500;butelka
woda;0;0;0;0;250;szklanka
kakao|kakao z mlekiem;75;3.4;10;2;250;kubek
rosół;20;1.5;1.5;1;300;talerz
rosół z makaronem;40;2;5;1.2;350;talerz
zupa pomidorowa|pomidorowa;50;1.5;7;1.8;350;talerz
żurek;70;3;5;4.5;350;talerz
barszcz czerwony|barszcz;20;0.5;4;0.1;250;kubek
zupa ogórkowa|ogórkowa;45;1;6;2;350;talerz
grochówka;85;5;9;3;350;talerz
krupnik;45;1.5;6.5;1.5;350;talerz
kapuśniak;40;1.5;4;2;350;talerz
zupa jarzynowa|jarzynowa;40;1.3;5.5;1.5;350;talerz
zupa krem|krem z dyni|krem z brokułów;55;1.5;6;3;350;talerz
gulasz wieprzowy|gulasz;150;13;5;9;250;porcja
bigos;135;7;6;9;250;porcja
gołąbki;120;6.5;9;6.5;250;porcja
spaghetti bolognese;150;7.5;18;5;350;porcja
lasagne;165;9;14;8;300;porcja
leczo;80;3;6;5;300;porcja
sałatka jarzynowa;160;3;8;12.5;150;porcja
sałatka grecka;110;4;4;8.5;250;porcja
kebab;220;11;20;10;350;sztuka
hamburger;250;13;26;11;220;sztuka
sushi;145;6;26;2;25;kawałek
owsianka|owsianka na mleku;95;4;13;3;300;miska
kanapka z szynką|kanapka;250;10;26;11;60;kanapka
tost z serem|tosty;280;12;28;13;90;tost
majonez;690;1.2;2.5;75;15;łyżka
ketchup;105;1.2;24;0.2;15;łyżka
musztarda;100;6;6;5;10;łyżeczka
sos czosnkowy;300;1.5;6;30;30;porcja
odżywka białkowa|białko serwatkowe|whey;380;75;8;6;30;miarka
''';

List<FoodRef>? _cache;

List<FoodRef> foodTable() => _cache ??= [
      for (final line in _table.split('\n'))
        if (line.trim().isNotEmpty)
          () {
            final f = line.split(';');
            final names = f[0].split('|').map((s) => s.trim()).toList();
            double n(int i) => double.parse(f[i]);
            return FoodRef(names.first, names.skip(1).toList(), n(1), n(2), n(3), n(4), n(5), f[6].trim());
          }(),
    ];

const _pl = {'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z'};

String normalizeFood(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    b.write(_pl[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9%,. ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Indeks podpowiedzi: historia użytkownika (wartości na 100 g wyliczone z jego wpisów) + tabela.
class FoodIndex {
  final List<FoodRef> refs;
  FoodIndex(this.refs);

  factory FoodIndex.build(Iterable<Meal> meals) {
    final mine = <String, ({FoodItem item, int uses})>{};
    for (final m in meals.toList()..sort((a, b) => a.ts.compareTo(b.ts))) {
      for (final i in m.items) {
        if (i.name.trim().isEmpty || i.grams <= 0 || i.kcal <= 0) continue;
        final k = normalizeFood(i.name);
        mine[k] = (item: i, uses: (mine[k]?.uses ?? 0) + 1); // najnowszy wpis wygrywa
      }
    }
    final refs = <FoodRef>[
      for (final e in mine.values)
        FoodRef(e.item.name.trim(), const [], e.item.kcal * 100 / e.item.grams, e.item.protein * 100 / e.item.grams,
            e.item.carbs * 100 / e.item.grams, e.item.fat * 100 / e.item.grams, e.item.grams, 'ostatnio', mine: true, uses: e.uses),
    ];
    final mineKeys = mine.keys.toSet();
    refs.addAll(foodTable().where((r) => !mineKeys.contains(normalizeFood(r.name))));
    return FoodIndex(refs);
  }

  static int _score(FoodRef r, String q, List<String> qWords) {
    var best = 0;
    for (final n in [r.name, ...r.aliases]) {
      final t = normalizeFood(n);
      int s;
      if (t == q) {
        s = 100;
      } else if (t.startsWith(q)) {
        s = 80;
      } else {
        final words = t.split(' ');
        // każde słowo zapytania musi zaczynać jakieś słowo nazwy
        if (!qWords.every((w) => words.any((x) => x.startsWith(w)))) continue;
        s = 60;
      }
      if (n != r.name) s -= 5;
      if (s > best) best = s;
    }
    if (best == 0) return 0;
    return best + (r.mine ? 15 + (r.uses > 5 ? 5 : r.uses) : 0);
  }

  List<FoodRef> search(String query, {int limit = 8}) {
    final q = normalizeFood(query);
    if (q.length < 2) return const [];
    final qWords = q.split(' ');
    final scored = <(FoodRef, int)>[
      for (final r in refs)
        if (_score(r, q, qWords) case final s when s > 0) (r, s)
    ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.name.length.compareTo(b.$1.name.length));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  /// Dokładne dopasowanie nazwy (do uzupełnienia wartości po rozpoznaniu AI).
  FoodRef? exact(String name) {
    final q = normalizeFood(name);
    for (final r in refs) {
      if (normalizeFood(r.name) == q || r.aliases.any((a) => normalizeFood(a) == q)) return r;
    }
    return null;
  }
}

/// Nazwy z tabeli do podpowiedzi dla modelu AI.
String tableNamesForPrompt() => foodTable().map((r) => r.name).join(', ');
