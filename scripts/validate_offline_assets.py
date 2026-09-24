#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
assets = ROOT / 'app' / 'src' / 'main' / 'assets'
data = assets / 'data'

required = [
    assets / 'index.html',
    assets / 'adhan' / 'adhan.ogg',
    assets / 'audio' / 'notification.wav',
    data / 'hadith' / 'bukhari.json',
    data / 'hadith' / 'muslim.json',
    data / 'tafseer' / 'muyassar.json',
    data / 'names_of_allah' / 'names_of_allah.json',
    data / 'forties' / 'nawawi40.json',
    data / 'prophet_stories' / 'index.json',
]
for p in required:
    if not p.is_file() or p.stat().st_size == 0:
        raise SystemExit(f'Missing or empty required asset: {p}')

json_files = list(data.rglob('*.json'))
for p in json_files:
    try:
        with p.open('r', encoding='utf-8') as f:
            json.load(f)
    except Exception as e:
        raise SystemExit(f'Invalid JSON: {p}: {e}')

azkar = list((data / 'azkar').glob('*.json'))
if len(azkar) < 14:
    raise SystemExit(f'Expected at least 14 azkar/dua JSON files, found {len(azkar)}')

chapters = list((data / 'quran' / 'chapters' / 'ar').glob('*.json'))
if len(chapters) != 114:
    raise SystemExit(f'Expected 114 Quran chapter JSON files, found {len(chapters)}')

pages = sorted((assets / 'quran-pages').glob('*.svg'))
if len(pages) != 604:
    raise SystemExit(f'Expected 604 Mushaf SVG pages, found {len(pages)}')
expected = [assets / 'quran-pages' / f'{i:03d}.svg' for i in range(1, 605)]
missing = [p.name for p in expected if not p.is_file() or p.stat().st_size == 0]
if missing:
    raise SystemExit(f'Missing/empty Mushaf pages: {missing[:10]}')
for p in pages:
    head = p.read_text(encoding='utf-8', errors='ignore')[:500].lstrip()
    if '<svg' not in head:
        raise SystemExit(f'Invalid SVG header: {p}')

html = (assets / 'index.html').read_text(encoding='utf-8')
for required_text in (
    "const CONTENT_CDN='./data';",
    "const MUSHAF_PAGE_IMAGE='./quran-pages/';",
    'const ACHIEVEMENTS=',
    'function createKhatmaPlan',
    'function completeKhatmaDay',
):
    if required_text not in html:
        raise SystemExit(f'Missing offline/app invariant: {required_text}')
if '🔖' in html:
    raise SystemExit('Old bookmark emoji remains')
if 'bookmarkIcon' in html:
    raise SystemExit('Empty bookmarkIcon placeholder remains')
if 'https://' in html or 'http://' in html:
    raise SystemExit('External URL literal found in runtime HTML')
if html.count('fetch(') != 1:
    raise SystemExit(f'Unexpected fetch() count in runtime HTML: {html.count("fetch(")}')

print(f'Offline validation OK: {len(json_files)} JSON files, {len(azkar)} azkar/dua files, {len(chapters)} Quran chapter files, {len(pages)} Mushaf SVG pages.')
