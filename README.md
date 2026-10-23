# Dziennik talerza

Prywatna aplikacja na Androida i iPhone'a (Flutter): co jem, ile to kalorii i jak się po tym czuję. Dane są tylko na telefonie.

## Co potrafi

- **Kilka osób** z osobnymi dziennikami i profilami: płeć, rok urodzenia, wzrost, waga, aktywność, cel (utrzymanie, redukcja, masa), uwagi (dieta, nietolerancje, leki). Z profilu liczony jest cel kalorii (Mifflin-St Jeor × aktywność) i białka.
- **Posiłki**: zdjęcie z aparatu lub galerii, opis (także dyktowany), składniki z gramaturą, kcal, B/W/T. Edycja, „zjedz ponownie dziś”.
- **Rozpoznawanie AI** (opcjonalne, własny klucz API Anthropic): Claude rozpoznaje składniki ze zdjęcia lub opisu i szacuje wartości odżywcze.
- **Jak się czujesz po**: energia, sytość, objawy, notatka, po ilu godzinach.
- **Trawienie** jako osobne wpisy (też następnego dnia): pora, komfort 1–5, objawy z nasileniem, skala bristolska, podejrzane posiłki. Rano przypomnienie o ocenie po wczorajszych posiłkach.
- **Dyktowanie głosem** w opisie posiłku, notatkach, ocenie po posiłku i wpisie o trawieniu. Z kluczem API powiedziane zdanie samo wypełnia formularz (objawy, nasilenie, komfort, energia).
- **Wzorce**: kalorie z 7 dni względem celu, pasek trawienia z 14 dni, częstość objawów, składniki przed gorszym trawieniem (okno 30 h albo zaznaczone posiłki), objawy po posiłkach, energia wg pory posiłku, analiza Claude uwzględniająca profil osoby.
- **Kopia zapasowa** w pliku `.json` (import scala po id). Import przyjmuje też eksport z wersji przeglądarkowej, razem z miniaturami zdjęć.
- **Logowanie** opcjonalne, domyślnie wyłączone: PIN, wzór, blokada ekranu telefonu, biometria.

## Instalacja

Każdy push na `main` buduje aplikację w GitHub Actions i publikuje ją w zakładce **Releases**:

- **Android** – `dziennik-talerza.apk`: pobierz na telefonie i zainstaluj. Kolejne wersje instalują się jako aktualizacja (stały klucz), dane zostają.
- **iPhone** – `dziennik-talerza.ipa` (niepodpisany, budowany gdy w opisie commita jest `[ios]` albo przy ręcznym uruchomieniu): zainstaluj z komputera przez [Sideloadly](https://sideloadly.io) lub AltStore swoim Apple ID. Przy darmowym koncie aplikację trzeba odświeżać co 7 dni (dane zostają).

Rozpoznawanie AI: **Ustawienia → Klucz API Anthropic** (klucz z console.anthropic.com → API Keys).

## Struktura

- `lib/models.dart` – osoby, posiłki, oceny, wpisy o trawieniu (JSON zgodny z wersją przeglądarkową, nieznane pola zachowane)
- `lib/calc.dart` – zapotrzebowanie, cele, wzorce (czysty Dart, testy w `test/calc_test.dart`)
- `lib/ai.dart` – rozpoznawanie posiłków, uzupełnianie z dyktowania, analiza (API Anthropic)
- `lib/store.dart` – stan, zapis do pliku, zdjęcia, import/eksport
- `lib/ui/` – ekrany; `voice.dart` – dyktowanie

Szacunki kalorii i analizy to pomoc, nie porada medyczna.
