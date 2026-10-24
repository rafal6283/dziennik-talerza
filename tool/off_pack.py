#!/usr/bin/env python3
"""Buduje assets/off_pl.json.gz: najpopularniejsze produkty sprzedawane w Polsce z Open Food Facts
(polska nazwa, marka, kcal/białko/węglowodany/tłuszcz na 100 g, porcja). Dane: Open Food Facts, licencja ODbL.

Źródło: oficjalny zrzut Parquet na Hugging Face (openfoodfacts/product-database) – zawiera nazwy w każdym
języku, więc bierzemy polską, a gdy jej nie ma – główną. Uruchamiane w GitHub Actions (food-pack.yml)."""
import gzip, json, re, sys, time

import duckdb

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
OUT = 'assets/off_pl.json.gz'
SRC = 'hf://datasets/openfoodfacts/product-database/food.parquet'

con = duckdb.connect()
for col in con.sql(f"DESCRIBE SELECT * FROM read_parquet('{SRC}')").fetchall():
    if col[0] in ('product_name', 'nutriments', 'countries_tags', 'serving_quantity', 'unique_scans_n', 'lang', 'brands'):
        print(col[0], col[1], flush=True)

t0 = time.time()
sql = f"""
WITH pl AS (
  SELECT
    code, brands, lang, unique_scans_n, serving_quantity, product_name, nutriments
  FROM read_parquet('{SRC}')
  WHERE list_contains(countries_tags, 'en:poland')
)
SELECT
  coalesce(list_filter(product_name, lambda x: x.lang = 'pl')[1].text,
           list_filter(product_name, lambda x: x.lang = 'main')[1].text,
           product_name[1].text) AS name,
  list_filter(product_name, lambda x: x.lang = 'pl')[1].text IS NOT NULL OR lang = 'pl' AS polish,
  brands,
  list_filter(nutriments, lambda x: x.name = 'energy-kcal')[1]."100g" AS kcal,
  list_filter(nutriments, lambda x: x.name = 'energy')[1]."100g" AS kj,
  list_filter(nutriments, lambda x: x.name = 'proteins')[1]."100g" AS prot,
  list_filter(nutriments, lambda x: x.name = 'carbohydrates')[1]."100g" AS carb,
  list_filter(nutriments, lambda x: x.name = 'fat')[1]."100g" AS fat,
  serving_quantity,
  coalesce(unique_scans_n, 0) AS scans
FROM pl
"""
rows = con.sql(sql).fetchall()
print(f'{len(rows)} produktów z Polski, {int(time.time() - t0)} s', flush=True)


def num(v):
    try:
        return round(float(str(v).replace(',', '.')), 1)
    except Exception:
        return None


PL_CHARS = re.compile('[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]')
seen = {}
for name, polish, brands, kcal, kj, prot, carb, fat, serving, scans in rows:
    name = (name or '').strip()
    kcal = num(kcal)
    if kcal is None and num(kj):
        kcal = round(num(kj) / 4.184, 1)
    prot, carb, fat = num(prot), num(carb), num(fat)
    if not name or kcal is None or not (0 <= kcal <= 950) or None in (prot, carb, fat):
        continue
    brand = (brands or '').split(',')[0].strip()
    s = num(serving)
    # produkty z polską nazwą wyżej; obcojęzyczne tylko te najczęściej skanowane
    pl = bool(polish) or bool(PL_CHARS.search(name))
    rank = (scans or 0) * (3 if pl else 1)
    key = (name.lower(), brand.lower())
    row = [name[:80], brand[:40], kcal, prot, carb, fat, s if s and 0 < s < 2000 else 0]
    if key not in seen or rank > seen[key][0]:
        seen[key] = (rank, row)

best = sorted(seen.values(), key=lambda x: -x[0])[:LIMIT]
out = [r for _, r in best]
print(f'wybrano {len(out)} z {len(seen)}', flush=True)
if len(out) < 2000:
    sys.exit(f'Za mało produktów ({len(out)}) – nie nadpisuję paczki')
with gzip.open(OUT, 'wt', encoding='utf-8') as f:
    json.dump({'source': 'Open Food Facts (ODbL)', 'country': 'pl', 'built': int(time.time()), 'products': out}, f, ensure_ascii=False, separators=(',', ':'))
print('zapisano', OUT, len(out))
for r in out[:15]:
    print(r)
