#!/usr/bin/env python3
"""Buduje assets/off_pl.json.gz: najpopularniejsze produkty sprzedawane w Polsce z Open Food Facts
(nazwa, marka, kcal/białko/węglowodany/tłuszcz na 100 g, porcja). Dane: Open Food Facts, licencja ODbL.

Źródło: oficjalny dzienny zrzut CSV (strumieniowo, bez limitów API wyszukiwania).
Uruchamiane w GitHub Actions (workflow food-pack.yml)."""
import csv, gzip, io, json, sys, time, urllib.request

UA = 'DziennikTalerza/1.0 (prywatna aplikacja; github.com/rafal6283/dziennik-talerza)'
URL = 'https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz'
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
OUT = 'assets/off_pl.json.gz'

csv.field_size_limit(1 << 30)


def num(v):
    try:
        return round(float(str(v).replace(',', '.')), 1)
    except Exception:
        return None


req = urllib.request.Request(URL, headers={'User-Agent': UA})
rows, seen, n = [], {}, 0
t0 = time.time()
with urllib.request.urlopen(req, timeout=120) as r:
    text = io.TextIOWrapper(gzip.GzipFile(fileobj=r), encoding='utf-8', errors='replace', newline='')
    reader = csv.DictReader(text, delimiter='\t', quoting=csv.QUOTE_NONE)
    for p in reader:
        n += 1
        if n % 500000 == 0:
            print(f'{n} wierszy, {len(seen)} polskich, {int(time.time() - t0)} s', flush=True)
        countries = (p.get('countries_en') or '') + ',' + (p.get('countries_tags') or '')
        if 'Poland' not in countries and 'en:poland' not in countries:
            continue
        kcal = num(p.get('energy-kcal_100g'))
        if kcal is None and num(p.get('energy_100g')):
            kcal = round(num(p.get('energy_100g')) / 4.184, 1)
        name = (p.get('product_name') or p.get('generic_name') or '').strip()
        if not name or kcal is None or kcal < 0 or kcal > 950:
            continue
        prot, carb, fat = num(p.get('proteins_100g')), num(p.get('carbohydrates_100g')), num(p.get('fat_100g'))
        if prot is None or carb is None or fat is None:
            continue
        brand = (p.get('brands') or '').split(',')[0].strip()
        scans = int(num(p.get('unique_scans_n')) or 0)
        serving = num(p.get('serving_quantity'))
        key = (name.lower(), brand.lower())
        row = [name[:80], brand[:40], kcal, prot, carb, fat, serving if serving and 0 < serving < 2000 else 0]
        if key not in seen or scans > seen[key][0]:
            seen[key] = (scans, row)

print(f'gotowe: {n} wierszy, {len(seen)} polskich produktów z wartościami, {int(time.time() - t0)} s', flush=True)
best = sorted(seen.values(), key=lambda x: -x[0])[:LIMIT]
out = [r for _, r in best]
if len(out) < 2000:
    sys.exit(f'Za mało produktów ({len(out)}) – nie nadpisuję paczki')
with gzip.open(OUT, 'wt', encoding='utf-8') as f:
    json.dump({'source': 'Open Food Facts (ODbL)', 'country': 'pl', 'built': int(time.time()), 'products': out}, f, ensure_ascii=False, separators=(',', ':'))
print('zapisano', OUT, len(out))
