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
cukier|cukru|cukrem;400;0;100;0;5;łyżeczka
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
ptasie mleczko;430;3.5;63;18;10;sztuka
delicje szampańskie|delicje;370;3.5;67;10;12;ciastko
krówki|krówka;410;2.5;80;9;8;cukierek
michałki|michałek;520;6;57;29;10;cukierek
cukierki czekoladowe|praliny|czekoladki;500;5;58;27;10;sztuka
cukierki|landrynki|cukierki twarde;390;0;97;0;5;cukierek
lizak;390;0;98;0;10;lizak
dropsy|draże;390;0;96;0.5;10;porcja
marcepan;450;7;60;20;20;kawałek
chałwa;520;12;55;29;30;kawałek
pierniki|piernik;380;6;72;7;25;sztuka
pierniki w czekoladzie;400;5;68;12;25;sztuka
kremówka|napoleonka;320;4;30;20;120;kawałek
eklerka|ptyś;330;5;30;21;60;sztuka
babka|babka piaskowa;400;6;52;19;60;kawałek
makowiec;370;7;50;15;80;kawałek
faworki|chrust;480;7;55;26;30;porcja
tiramisu;290;5;28;17;120;porcja
brownie;450;6;55;23;60;kawałek
muffinka|muffin;400;5.5;52;19;80;sztuka
gofr|gofry;290;7;38;12;80;gofr
gofr z bitą śmietaną;320;5;38;16;150;gofr
rurki z kremem|rurka z kremem;480;4.5;50;29;40;sztuka
wafle|wafle przekładane;520;6;62;28;20;wafel
grześki;515;6;61;27;34;baton
princessa;520;6;60;28;34;baton
knoppers;545;8.5;51;34;25;sztuka
kinder bueno;570;8.6;50;37;22;batonik
kinder czekoladka;560;8.7;53;35;13;batonik
kit kat|kitkat;520;7;61;27;42;baton
mars;450;4;70;17;51;baton
twix;495;4.5;65;24;50;baton
bounty;485;3.7;58;26;57;baton
lion;485;5;66;21;42;baton
oreo|ciastka oreo;475;5;69;20;11;ciastko
petitki|herbatniki maślane;440;8;74;12;6;ciastko
markizy|ciastka z kremem;490;5;67;22;14;ciastko
ciastka owsiane;460;6.5;65;19;15;ciastko
batonik musli|baton zbożowy;400;6;65;12;25;baton
baton proteinowy;370;30;35;12;50;baton
budyń;100;3;16;2.5;250;kubek
kisiel;65;0;16;0;250;kubek
galaretka;60;1.5;13;0;150;porcja
ryż na mleku|ryż z mlekiem;110;3.5;18;2.5;300;miska
serek homogenizowany waniliowy|serek homogenizowany;160;7;16;7.5;150;kubek
danio|serek waniliowy;140;7;18;4.5;140;kubek
jogurt pitny;75;3;12;1.5;250;butelka
mleko czekoladowe;80;3.2;12;2;250;kubek
gorąca czekolada;90;3;13;3;250;kubek
lody na patyku|lody w polewie;290;3.5;28;18;70;sztuka
sorbet;130;0.5;32;0.2;100;gałka
bita śmietana;260;2.5;12;22;20;porcja
krem czekoladowo-orzechowy;540;6;57;31;15;łyżka
syrop klonowy;260;0;67;0;15;łyżka
ksylitol;240;0;100;0;5;łyżeczka
krakersy;480;9;65;20;25;garść
chrupki kukurydziane;500;7;68;22;20;garść
prażynki;520;3;60;30;30;garść
nachos|tortilla chips;500;7;62;24;40;garść
orzeszki w posypce|orzeszki w skorupce smakowej;520;17;35;35;30;garść
pistacje;570;20;18;46;30;garść
orzechy brazylijskie;660;14;5;67;20;garść
sezam;575;18;12;50;10;łyżka
bułka maślana;330;8.5;55;8;60;bułka
croissant z czekoladą;430;7;48;23;70;sztuka
bajgiel;270;10;52;1.5;90;sztuka
pita|chlebek pita;275;9;55;1.2;60;sztuka
bułka tarta;370;12;75;2;10;łyżka
chleb bezglutenowy;250;3;45;6;35;kromka
otręby owsiane|otręby;250;17;45;7;15;łyżka
płatki jaglane;360;11;71;3;40;porcja
hot dog;270;10;28;13;120;sztuka
nuggetsy|nuggetsy z kurczaka;280;15;17;17;100;porcja (6 szt.)
kurczak w panierce|kotlet z kurczaka panierowany;250;18;12;14;150;porcja
skrzydełka|skrzydełka z kurczaka;240;20;3;17;150;porcja
kotlet de volaille|de volaille;270;17;12;17;180;kotlet
gyros;210;18;4;14;200;porcja
kebab w tortilli|tortilla z kebabem;230;11;22;11;350;sztuka
tortilla z kurczakiem|wrap z kurczakiem;200;11;20;8;250;sztuka
pizza pepperoni|pizza z salami;290;12;32;13;110;kawałek
pizza hawajska;250;11;32;9;110;kawałek
shake|milkshake;120;3.5;19;3.5;300;kubek
fasolka po bretońsku;120;7;12;5;300;porcja
placki z jabłkami|racuchy;240;5;35;9;150;porcja
pierogi leniwe|leniwe;190;9;27;5;250;porcja
pyzy|kluski na parze;190;5;38;2;150;porcja
naleśniki z serem;200;9;24;8;150;porcja (2 szt.)
naleśniki z dżemem;230;5;38;7;150;porcja (2 szt.)
omlet;155;10.5;1.5;12;150;porcja
jajecznica na boczku;250;13;1;21;150;porcja
jajka faszerowane;180;10;2;15;60;połówka
kanapka z serem;270;11;27;13;60;kanapka
kanapka z jajkiem;210;9;24;8.5;60;kanapka
kanapka z pastą jajeczną;240;8;23;13;60;kanapka
owsianka z owocami;105;3.5;17;2.5;300;miska
risotto;150;4;22;5;300;porcja
curry z kurczakiem;140;11;6;8;300;porcja
chili con carne;110;8;9;4.5;300;porcja
sałatka cezar;150;8;7;10;250;porcja
sałatka z tuńczykiem;120;10;5;7;250;porcja
śledź w śmietanie;190;10;4;15;100;porcja
ryba po grecku;140;10;7;8;150;porcja
krokiety;220;9;22;11;150;sztuka
paszteciki;320;8;32;18;80;sztuka
zupa grzybowa|grzybowa;45;1.3;5;2.2;350;talerz
flaki|flaczki;75;8;3;3.5;350;talerz
kasza z gulaszem;140;8;16;5;350;porcja
schab w sosie;160;16;4;9;200;porcja
kotlet z indyka;180;24;5;7;150;kotlet
kiełbaski z grilla|kiełbaska;290;13;2;26;100;sztuka
wątróbka drobiowa;140;19;1;6.5;120;porcja
filet z mintaja|mintaj;80;17;0;1;150;porcja
pstrąg;150;21;0;7;150;porcja
sardynki w oleju|sardynki;210;24;0;12.5;90;puszka
paluszki krabowe|surimi;95;7.5;15;0.5;60;porcja
halloumi;320;22;2;25;50;porcja
mascarpone;430;5;4;44;20;łyżka
ricotta;150;10;3.5;11;50;porcja
ser pleśniowy|lazur;350;21;0.5;29;30;porcja
twarożek ze szczypiorkiem|pasta twarogowa;140;12;4;8;50;porcja
napój migdałowy|mleko migdałowe;25;0.5;3;1.2;250;szklanka
mleko kokosowe;180;2;3;18;50;porcja
seler|seler korzeniowy;21;1.5;2.5;0.3;100;porcja
por;31;1.5;4.5;0.3;80;porcja
rukola;25;2.6;2;0.7;30;garść
kalarepa;27;1.7;4;0.1;100;porcja
dynia;26;1;5.5;0.1;150;porcja
batat|słodki ziemniak;86;1.6;17;0.1;150;porcja
szparagi;20;2.2;2;0.1;100;porcja
oliwki;145;1;2;15;30;garść
papryka konserwowa;30;1;6;0.2;50;porcja
pomidory suszone;210;5;12;15;20;porcja
kiełki;30;3;3;0.5;20;garść
czereśnie;63;1.1;14;0.2;150;garść
wiśnie;50;1;11;0.3;150;garść
porzeczki;45;1.2;8;0.3;100;garść
agrest;44;0.9;8;0.6;100;garść
grejpfrut;42;0.8;9;0.1;250;sztuka
nektarynka;44;1.1;9;0.3;140;sztuka
morela;48;1.4;10;0.4;40;sztuka
figa;74;0.8;16;0.3;50;sztuka
granat;83;1.7;15;1.2;100;porcja
melon;34;0.8;8;0.2;200;kawałek
borówka amerykańska;57;0.7;12;0.3;100;garść
mus owocowy|przecier owocowy;55;0.4;12;0.1;100;tubka
napój energetyczny|energetyk;45;0;11;0;250;puszka
napój pomarańczowy|oranżada;40;0;10;0;330;szklanka
kompot;35;0.1;9;0;250;szklanka
sok marchwiowy;40;0.5;9;0.1;250;szklanka
smoothie;55;0.8;12;0.3;300;butelka
piwo smakowe|radler;40;0.3;8;0;500;butelka
cydr;45;0;5;0;330;butelka
whisky;250;0;0;0;40;kieliszek
nalewka|likier;300;0;30;0;30;kieliszek
sos pomidorowy;50;1.5;8;1.2;100;porcja
pesto;450;5;5;45;20;łyżka
sos sojowy;55;8;5;0;15;łyżka
sos bbq;160;1;38;0.5;20;łyżka
sos tatarski;390;1.5;6;40;20;łyżka
chrzan;60;1.5;8;2;10;łyżeczka
sól;0;0;0;0;1;szczypta
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

  static int _score(FoodRef r, String q, List<String> qWords, List<String> qStems) {
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
        final stems = words.map(stemFood).toList();
        // każde słowo zapytania (także w innej formie: „chleba żytniego”) musi zaczynać jakieś słowo nazwy
        var ok = true;
        var exactStems = 0;
        for (var k = 0; k < qWords.length; k++) {
          final w = qWords[k], st = qStems[k];
          if (_stop.contains(w)) continue;
          var hit = false;
          for (var m = 0; m < words.length; m++) {
            if (words[m].startsWith(w) || stems[m].startsWith(st)) {
              hit = true;
              if (stems[m] == st) exactStems++;
              break;
            }
          }
          if (!hit) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        s = 60 + (exactStems * 5 > 15 ? 15 : exactStems * 5);
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
    final qStems = qWords.map(stemFood).toList();
    final scored = <(FoodRef, int)>[
      for (final r in refs)
        if (_score(r, q, qWords, qStems) case final s when s > 0) (r, s)
    ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.name.length.compareTo(b.$1.name.length));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  /// Dopasowanie nazwy z dokładnością do odmiany (do uzupełnienia wartości po rozpoznaniu AI).
  FoodRef? exact(String name) {
    final q = normalizeFood(name);
    final qs = stemPhrase(name);
    FoodRef? byStem;
    for (final r in refs) {
      if (normalizeFood(r.name) == q || r.aliases.any((a) => normalizeFood(a) == q)) return r;
      if (byStem == null && qs.isNotEmpty && [r.name, ...r.aliases].any((n) => _sameList(stemPhrase(n), qs))) byStem = r;
    }
    return byStem;
  }
}

/// Nazwy z tabeli do podpowiedzi dla modelu AI.
String tableNamesForPrompt() => foodTable().map((r) => r.name).join(', ');


// ---------- odmiana słów i rozpisywanie opisu ----------

const _stop = {'z', 'ze', 'i', 'oraz', 'na', 'w', 'we', 'do', 'bez', 'a', 'albo', 'lub', 'po', 'od', 'dla', 'plus', 'troche', 'jakies', 'jakis', 'sobie', 'zjadlem', 'zjadlam', 'jem', 'pije', 'wypilem', 'wypilam', 'mialem', 'mialam', 'bylo', 'byl', 'byla', 'to', 'tez', 'jeszcze', 'potem'};
const _suffixes = ['owego', 'owych', 'owej', 'iego', 'owym', 'iami', 'ych', 'ich', 'ami', 'ach', 'owi', 'ego', 'emu', 'ymi', 'imi', 'iem', 'ow', 'om', 'em', 'ie', 'ia', 'y', 'i', 'a', 'o', 'u', 'e'];

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Prosty „rdzeń” polskiego słowa (po normalizacji): chleba → chleb, żytniego → zytn, jajek → jajk.
String stemFood(String word) {
  var w = normalizeFood(word);
  if (w.length <= 3 || RegExp(r'^\d').hasMatch(w)) return w;
  // ruchome „e”: jajek, kromek, bułek → jajk, kromk, bulk
  if (w.length > 4 && w.endsWith('ek')) return '${w.substring(0, w.length - 2)}k';
  for (final suf in _suffixes) {
    if (w.endsWith(suf) && w.length - suf.length >= 3) return w.substring(0, w.length - suf.length);
  }
  return w;
}

/// Rdzenie słów nazwy bez słów pomocniczych („pierś z kurczaka” → [piers, kurczak]).
List<String> stemPhrase(String s) =>
    normalizeFood(s).split(' ').where((w) => w.isNotEmpty && !_stop.contains(w)).map(stemFood).toList();

class ParsedFood {
  final FoodRef ref;
  final double grams;
  final String text; // fragment opisu
  const ParsedFood(this.ref, this.grams, this.text);
  FoodItem get item => ref.item(grams);
}

class ParsedDescription {
  final List<ParsedFood> items;
  final List<String> unknown; // fragmenty bez dopasowania
  const ParsedDescription(this.items, this.unknown);
}

const _numberWords = {
  'pol': 0.5, 'polowa': 0.5, 'polowe': 0.5, 'poltora': 1.5, 'poltorej': 1.5,
  'jeden': 1, 'jedna': 1, 'jedno': 1, 'jednej': 1,
  'dwa': 2, 'dwie': 2, 'dwoch': 2, 'dwiema': 2, 'pare': 2, 'para': 2,
  'trzy': 3, 'trzech': 3, 'kilka': 3, 'cztery': 4, 'czterech': 4, 'piec': 5, 'pieciu': 5, 'szesc': 6, 'siedem': 7, 'osiem': 8, 'dziesiec': 10,
};

/// Jednostki: rdzeń → gramy na jednostkę (null = porcja z tabeli).
const _units = <String, double?>{
  'g': 1, 'gr': 1, 'gram': 1, 'dag': 10, 'deko': 10, 'kg': 1000, 'kilo': 1000, 'ml': 1, 'l': 1000, 'litr': 1000,
  'kromk': 35, 'kromecz': 30, 'plaster': 15, 'plasterk': 15, 'lyzk': 15, 'lyzeczk': 5, 'szklank': 250, 'kubek': 250, 'kubk': 250,
  'garsc': 30, 'garstk': 20, 'misk': 300, 'miseczk': 150, 'talerz': 350, 'puszk': null, 'opakowan': null, 'paczk': null,
  'porcj': null, 'sztuk': null, 'szt': null, 'kawalek': null, 'kawalk': null, 'filizank': 150, 'kieliszek': null, 'kieliszk': null,
  'butelk': 500, 'kostk': 5, 'tabliczk': 100, 'galk': 60, 'szczypt': 1, 'plastr': 15,
};

double? _unitGrams(String unitStem, FoodRef r) {
  final label = stemPhrase(r.portionLabel);
  if (label.isNotEmpty && (label.first == unitStem || label.first.startsWith(unitStem) || unitStem.startsWith(label.first))) return r.portion;
  if (!_units.containsKey(unitStem)) return null;
  return _units[unitStem] ?? r.portion;
}

/// Rozpisuje opis (pisany albo podyktowany) na produkty z tabeli i historii, z ilościami.
/// „2 kromki chleba żytniego z masłem i szynką, kawa z mlekiem” → chleb żytni 70 g, masło 5 g, szynka 15 g, kawa z mlekiem 250 g.
ParsedDescription parseDescription(String text, FoodIndex index) {
  // tokeny: słowa, liczby, separatory
  final tokens = <({String raw, String norm, String stem, bool sep, double? num})>[];
  // „200g” → „200 g”; przecinek i kropka między cyframi zostają (1,5 kg), poza tym oddzielają produkty
  final cleaned = text
      .replaceAllMapped(RegExp(r'(\d)([^\d\s.,/%])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[;+\n]|,(?!\d)|\.(?!\d)'), ' | ');
  for (final part in cleaned.split(RegExp(r'\s+'))) {
    final raw = part.trim();
    if (raw.isEmpty) continue;
    if (raw == '|') {
      tokens.add((raw: raw, norm: '', stem: '', sep: true, num: null));
      continue;
    }
    final n = normalizeFood(raw);
    if (n.isEmpty) continue;
    double? num;
    if (RegExp(r'^\d+([.,]\d+)?$').hasMatch(n)) num = double.tryParse(n.replaceAll(',', '.'));
    if (RegExp(r'^\d+/\d+$').hasMatch(raw)) {
      final f = raw.split('/');
      num = double.parse(f[0]) / double.parse(f[1]);
    }
    num ??= _numberWords[n]?.toDouble();
    tokens.add((raw: raw, norm: n, stem: stemFood(n), sep: false, num: num));
  }

  // kandydaci: rdzenie nazw i synonimów
  final cands = <(FoodRef, List<String>, bool)>[
    for (final r in index.refs)
      for (final (k, n) in [r.name, ...r.aliases].indexed)
        if (stemPhrase(n) case final st when st.isNotEmpty) (r, st, k == 0)
  ];

  bool isUnit(String stem) => _units.containsKey(stem);

  final items = <ParsedFood>[];
  final unknown = <String>[];
  final unk = <String>[];
  void flushUnknown() {
    if (unk.isNotEmpty) unknown.add(unk.join(' '));
    unk.clear();
  }

  double? qty;
  String? unit;
  var i = 0;
  while (i < tokens.length) {
    final t = tokens[i];
    if (t.sep) {
      flushUnknown();
      qty = null;
      unit = null;
      i++;
      continue;
    }
    if (t.num != null) {
      flushUnknown();
      qty = (qty != null && t.num == 0.5) ? qty + 0.5 : t.num; // „dwie i pół” → 2,5
      i++;
      continue;
    }
    if (isUnit(t.stem) && (qty != null || t.stem != 'g')) {
      flushUnknown();
      unit = t.stem;
      i++;
      continue;
    }
    if (_stop.contains(t.norm)) {
      i++;
      continue;
    }
    // najdłuższe dopasowanie nazwy od pozycji i (słowa pomocnicze w środku są pomijane)
    (FoodRef, int, int)? best; // ref, liczba słów nazwy, pozycja końca
    for (final (r, st, primary) in cands) {
      var j = i, k = 0;
      while (k < st.length && j < tokens.length) {
        final tj = tokens[j];
        if (tj.sep) break;
        if (_stop.contains(tj.norm) && k > 0) {
          j++;
          continue;
        }
        if (tj.stem == st[k] || (st[k].length >= 4 && tj.stem.startsWith(st[k])) || (tj.stem.length >= 4 && st[k].startsWith(tj.stem))) {
          k++;
          j++;
        } else {
          break;
        }
      }
      if (k == st.length) {
        final score = st.length * 10 + (r.mine ? 3 : 0) + (primary ? 1 : 0);
        if (best == null || score > best.$2) best = (r, score, j);
      }
    }
    if (best == null) {
      unk.add(t.raw);
      i++;
      continue;
    }
    flushUnknown();
    final r = best.$1;
    var end = best.$3;
    // ilość po nazwie: „ryż 150 g”, „chleb 2 kromki”
    if (qty == null && end < tokens.length && tokens[end].num != null) {
      final after = end + 1 < tokens.length ? tokens[end + 1] : null;
      if (after == null || after.sep || isUnit(after.stem)) {
        qty = tokens[end].num;
        end++;
        if (after != null && !after.sep && isUnit(after.stem)) {
          unit = after.stem;
          end++;
        }
      }
    }
    double grams;
    if (unit != null) {
      final ug = _unitGrams(unit, r) ?? r.portion;
      grams = (qty ?? 1) * ug;
    } else {
      grams = (qty ?? 1) * r.portion;
    }
    items.add(ParsedFood(r, grams, tokens.sublist(i, end).where((x) => !x.sep).map((x) => x.raw).join(' ')));
    qty = null;
    unit = null;
    i = end;
  }
  flushUnknown();
  return ParsedDescription(items, unknown.where((u) => u.trim().length > 1).toList());
}
