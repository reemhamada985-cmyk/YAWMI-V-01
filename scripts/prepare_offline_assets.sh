#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AS="$ROOT/app/src/main/assets"
BASE="https://cdn.jsdelivr.net/gh/mohammed-2-5/islamic-library-data@master"
QBASE="https://cdn.quran.ws/svg/pages/v1.1.1/hafs-kfqc"
DATA="$AS/data"
RESRAW="$ROOT/app/src/main/res/raw"
mkdir -p "$DATA/azkar" "$DATA/hadith" "$DATA/forties" "$DATA/names_of_allah" "$DATA/tafseer" "$DATA/prophet_stories" "$DATA/quran/chapters/ar" "$AS/quran-pages" "$AS/adhan" "$AS/audio" "$RESRAW"

CURL=(curl -fL --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 180 -sS)
fetch(){ local url="$1" out="$2"; echo "GET $url"; "${CURL[@]}" "$url" -o "$out"; test -s "$out"; }

echo '1/7 — Azkar and duas'
for f in azkar-sabah.json azkar-masaa.json sleep.json after_prayer.json ruqyah-shariah.json famous-doaa.json travel.json food.json mosque.json home.json wudu.json morning_evening.json doaa-for-all-death-people.json doaa-for-dead-person.json; do
  fetch "$BASE/azkar/$f" "$DATA/azkar/$f"
done

echo '2/7 — Full Sahih Bukhari and Sahih Muslim'
fetch "$BASE/hadith/bukhari.json" "$DATA/hadith/bukhari.json"
fetch "$BASE/hadith/muslim.json" "$DATA/hadith/muslim.json"

echo '3/7 — 40 Hadith + 99 Names + Tafseer Muyassar'
for f in nawawi40.json qudsi40.json shahwaliullah40.json; do fetch "$BASE/forties/$f" "$DATA/forties/$f"; done
fetch "$BASE/names_of_allah/names_of_allah.json" "$DATA/names_of_allah/names_of_allah.json"
fetch "$BASE/tafseer/muyassar.json" "$DATA/tafseer/muyassar.json"

echo '4/7 — Prophet stories (25 stories + index + quizzes)'
fetch "$BASE/prophet_stories/index.json" "$DATA/prophet_stories/index.json"
for name in adam idris nuh hud salih ibrahim lut ismail ishaq yaqub yusuf ayyub shuaib musa harun dawud sulayman ilyas alyasa dhul_kifl yunus zakariya yahya isa muhammad; do
  fetch "$BASE/prophet_stories/$name.json" "$DATA/prophet_stories/$name.json"
  fetch "$BASE/prophet_stories/quizzes/$name.json" "$DATA/prophet_stories/${name}_quiz.json"
done

echo '5/7 — Quran metadata/text indexes for complete offline search/reference'
fetch "$BASE/quran/qcf_v2_pages.json" "$DATA/quran/qcf_v2_pages.json"
fetch "$BASE/quran/mushaf_pages.json" "$DATA/quran/mushaf_pages.json"
fetch "$BASE/quran/qcf_surah_starts.json" "$DATA/quran/qcf_surah_starts.json"
fetch "$BASE/quran/quran_segments.json" "$DATA/quran/quran_segments.json"
fetch "$BASE/quran/quran_symbols.json" "$DATA/quran/quran_symbols.json"
fetch "$BASE/quran/quran_duas.json" "$DATA/quran/quran_duas.json"
fetch "$BASE/quran/hizb_quarters.json" "$DATA/quran/hizb_quarters.json"
seq 1 114 | xargs -P12 -I{} bash -c 'n=$(printf "%03d" "$1" | sed "s/^0\+//"); [ -n "$n" ] || n=0; src="$2/quran/chapters/ar/$1.json"; out="$3/quran/chapters/ar/$1.json"; curl -fL --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 --max-time 120 -sS "$src" -o "$out"; test -s "$out"' _ {} "$BASE" "$DATA"
test "$(find "$DATA/quran/chapters/ar" -maxdepth 1 -name '*.json' | wc -l)" -eq 114

echo '6/7 — 604-page Madinah Mushaf SVG + page maps'
export QBASE QOUT="$AS/quran-pages"
seq 1 604 | xargs -P12 -I{} bash -c '
  p=$(printf "%03d" "$1");
  curl -fL --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 --max-time 180 -sS "$QBASE/$p.svg" -o "$QOUT/$p.svg";
  test -s "$QOUT/$p.svg"
' _ {}
test "$(find "$AS/quran-pages" -maxdepth 1 -type f -name '*.svg' | wc -l)" -eq 604

# Keep the existing local fallback filename/path expected by the HTML layer.
fetch 'https://commons.wikimedia.org/wiki/Special:Redirect/file/Adhan.ogg' "$RESRAW/adhan.ogg"
cp "$RESRAW/adhan.ogg" "$AS/adhan/adhan.ogg"
cp "$RESRAW/notification.wav" "$AS/audio/notification.wav"

echo '7/7 — Offline manifest and attribution'
cat > "$AS/OFFLINE_CONTENT.txt" <<'EOT'
YAWMY v1.1.0 — complete offline content bundle

At build time, all required text, Mushaf pages, stories, Hadith, adhkar and adhan audio are downloaded into the APK assets. The running application reads only the bundled local paths under the appassets origin. Internet access is not required for the bundled content.

Bundled: 604 Hafs/KFQC Mushaf SVG pages; Quran Arabic metadata/reference JSON; Sahih al-Bukhari; Sahih Muslim; 40 Hadith collections; 99 Names of Allah; Tafseer Muyassar; 25 Prophet stories + quizzes; 14 azkar/dua datasets; CC0 adhan audio; local notification sound.
EOT
cat > "$AS/ATTRIBUTIONS_OFFLINE.txt" <<'EOT'
Quran page artwork/data:
- quran-ws/quran-svg, Hafs/KFQC 604-page SVG release. See the repository notice and source terms.
  https://github.com/quran-ws/quran-svg

Islamic datasets:
- Islamic App Data by mohammed-2-5; Hadith, Azkar, Quran metadata, Prophet Stories, 99 Names, Tafseer and related datasets.
  https://github.com/mohammed-2-5/islamic-library-data

Adhan:
- Adhan.ogg by Aishatu98 on Wikimedia Commons; CC0 1.0.
  https://commons.wikimedia.org/wiki/File:Adhan.ogg
EOT

echo 'Offline assets prepared successfully.'
