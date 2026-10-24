#!/usr/bin/env python3
"""Buduje assets/off_pl.json.gz: najpopularniejsze produkty sprzedawane w Polsce z Open Food Facts
(nazwa, marka, kcal/białko/węglowodany/tłuszcz na 100 g, porcja). Dane: Open Food Facts, licencja ODbL.
Uruchamiane w GitHub Actions (workflow food-pack.yml)."""
import gzip, json, sys, time, urllib.parse, urllib.request

UA = 'DziennikTalerza/1.0 (prywatna aplikacja; github.com/rafal6283/dziennik-talerza)'
FIELDS = 'code,product_name,product_name_pl,generic_name_pl,brands,nutriments,serving_quantity'
PAGES = int(sys.argv[1]) if len(sys.argv) > 1 else 150
OUT = 'assets/off_pl.json.gz'


def get(page):
    q = urllib.parse.urlencode({
        'countries_tags_en': 'poland', 'fields': FIELDS, 'page_size': 100, 'page': page,
        'sort_by': 'unique_scans_n', 'states_tags': 'en:nutrition-facts-completed',
    })
    req = urllib.request.Request('https://world.openfoodfacts.org/api/v2/search?' + q, headers={'User-Agent': UA})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:  # limit zapytań albo przeciążenie – czekamy dłużej
            print('page', page, 'retry', attempt, e, flush=True)
            time.sleep(20 * (attempt + 1))
    return None


def num(v):
    try:
        return round(float(str(v).replace(',', '.')), 1)
    except Exception:
        return None


out, seen = [], set()
for page in range(1, PAGES + 1):
    j = get(page)
    if not j or not j.get('products'):
        print('koniec na stronie', page, flush=True)
        break
    for p in j['products']:
        n = p.get('nutriments') or {}
        kcal = num(n.get('energy-kcal_100g'))
        if kcal is None and num(n.get('energy_100g')):
            kcal = round(num(n.get('energy_100g')) / 4.184, 1)
        name = next((s.strip() for s in (p.get('product_name_pl'), p.get('product_name'), p.get('generic_name_pl')) if s and s.strip()), '')
        if not name or kcal is None or kcal < 0 or kcal > 950:
            continue
        brand = (p.get('brands') or '').split(',')[0].strip()
        key = (name.lower(), brand.lower())
        if key in seen:
            continue
        seen.add(key)
        prot, carb, fat = num(n.get('proteins_100g')) or 0, num(n.get('carbohydrates_100g')) or 0, num(n.get('fat_100g')) or 0
        serving = num(p.get('serving_quantity'))
        out.append([name[:80], brand[:40], kcal, prot, carb, fat, serving if serving and 0 < serving < 2000 else 0])
    print('strona', page, 'produktów', len(out), flush=True)
    time.sleep(6.5)  # limit wyszukiwania Open Food Facts: 10 zapytań na minutę

if len(out) < 500:
    sys.exit(f'Za mało produktów ({len(out)}) – nie nadpisuję paczki')
with gzip.open(OUT, 'wt', encoding='utf-8') as f:
    json.dump({'source': 'Open Food Facts (ODbL)', 'country': 'pl', 'built': int(time.time()), 'products': out}, f, ensure_ascii=False, separators=(',', ':'))
print('zapisano', OUT, len(out))
