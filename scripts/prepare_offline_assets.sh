#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AS="$ROOT/app/src/main/assets"

BASE="https://cdn.jsdelivr.net/gh/mohammed-2-5/islamic-library-data@master"
GITHUB_API="https://api.github.com/repos/mohammed-2-5/islamic-library-data/git/trees/master?recursive=1"
QBASE="https://cdn.quran.ws/svg/pages/v1.1.1/hafs-kfqc"

DATA="$AS/data"
RESRAW="$ROOT/app/src/main/res/raw"

mkdir -p \
  "$DATA/azkar" \
  "$DATA/hadith" \
  "$DATA/forties" \
  "$DATA/names_of_allah" \
  "$DATA/tafseer" \
  "$DATA/prophet_stories" \
  "$DATA/prophet_stories/quizzes" \
  "$DATA/quran/chapters/ar" \
  "$AS/quran-pages" \
  "$AS/adhan" \
  "$AS/audio" \
  "$RESRAW"

# لا نستخدم --retry-all-errors حتى لا نكرر طلبات 404 عشرات المرات.
CURL=(
  curl
  -fL
  --retry 5
  --retry-delay 2
  --connect-timeout 20
  --max-time 180
  -sS
)

fetch() {
  local url="$1"
  local out="$2"

  echo "GET $url"

  rm -f "$out"

  "${CURL[@]}" "$url" -o "$out"

  if [ ! -s "$out" ]; then
    echo "ERROR: Downloaded file is empty:"
    echo "       $url"
    exit 1
  fi
}

fetch_json() {
  local url="$1"
  local out="$2"

  fetch "$url" "$out"

  python3 - "$out" <<'PY'
import json
import sys

path = sys.argv[1]

try:
    with open(path, "r", encoding="utf-8-sig") as f:
        json.load(f)
except Exception as exc:
    print(f"ERROR: Invalid JSON: {path}")
    print(exc)
    raise SystemExit(1)
PY
}

echo "=============================================="
echo "YAWMY OFFLINE ASSET PREPARATION"
echo "=============================================="

# --------------------------------------------------
# 1/7 — Azkar and Duas
# --------------------------------------------------

echo "1/7 — Azkar and duas"

AZKAR_FILES=(
  azkar-sabah.json
  azkar-masaa.json
  sleep.json
  after_prayer.json
  ruqyah-shariah.json
  famous-doaa.json
  travel.json
  food.json
  mosque.json
  home.json
  wudu.json
  morning_evening.json
  doaa-for-all-death-people.json
  doaa-for-dead-person.json
)

for f in "${AZKAR_FILES[@]}"; do
  fetch_json \
    "$BASE/azkar/$f" \
    "$DATA/azkar/$f"
done

# --------------------------------------------------
# 2/7 — Sahih Bukhari + Sahih Muslim
# --------------------------------------------------

echo "2/7 — Full Sahih Bukhari and Sahih Muslim"

fetch_json \
  "$BASE/hadith/bukhari.json" \
  "$DATA/hadith/bukhari.json"

fetch_json \
  "$BASE/hadith/muslim.json" \
  "$DATA/hadith/muslim.json"

# --------------------------------------------------
# 3/7 — 40 Hadith + 99 Names + Tafseer
# --------------------------------------------------

echo "3/7 — 40 Hadith + 99 Names + Tafseer Muyassar"

FORTY_FILES=(
  nawawi40.json
  qudsi40.json
  shahwaliullah40.json
)

for f in "${FORTY_FILES[@]}"; do
  fetch_json \
    "$BASE/forties/$f" \
    "$DATA/forties/$f"
done

fetch_json \
  "$BASE/names_of_allah/names_of_allah.json" \
  "$DATA/names_of_allah/names_of_allah.json"

fetch_json \
  "$BASE/tafseer/muyassar.json" \
  "$DATA/tafseer/muyassar.json"

# --------------------------------------------------
# 4/7 — Prophet Stories
#     لا نعتمد على أسماء hard-coded.
#     نقرأ index.json + شجرة الملفات الحالية من GitHub.
# --------------------------------------------------

echo "4/7 — Prophet stories"

fetch_json \
  "$BASE/prophet_stories/index.json" \
  "$DATA/prophet_stories/index.json"

TREE_FILE="$DATA/prophet_stories/_github_tree.json"

echo "GET $GITHUB_API"
rm -f "$TREE_FILE"
"${CURL[@]}" \
  -H "Accept: application/vnd.github+json" \
  "$GITHUB_API" \
  -o "$TREE_FILE"

python3 - "$TREE_FILE" "$DATA/prophet_stories" <<'PY'
import json
import os
import sys

tree_file = sys.argv[1]
out_dir = sys.argv[2]

with open(tree_file, "r", encoding="utf-8") as f:
    tree = json.load(f)

tree_paths = []
for item in tree.get("tree", []):
    if item.get("type") == "blob":
        path = item.get("path", "")
        if path.startswith("prophet_stories/") and path.endswith(".json"):
            tree_paths.append(path)

with open(
    os.path.join(out_dir, "_prophet_paths.txt"),
    "w",
    encoding="utf-8"
) as f:
    for p in sorted(tree_paths):
        f.write(p + "\n")

print(f"Found {len(tree_paths)} prophet-story JSON files in repository tree.")
PY

# استخراج IDs من index.json
mapfile -t PROPHET_IDS < <(
  python3 - "$DATA/prophet_stories/index.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8-sig") as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit("ERROR: prophet_stories/index.json is not an array")

ids = []
for item in data:
    if not isinstance(item, dict):
        continue
    pid = str(item.get("id", "")).strip()
    if pid:
        ids.append(pid)

if len(ids) != 25:
    print(
        f"WARNING: Prophet index contains {len(ids)} IDs, expected 25.",
        file=sys.stderr
    )

for pid in ids:
    print(pid)
PY
)

if [ "${#PROPHET_IDS[@]}" -eq 0 ]; then
  echo "ERROR: No prophet IDs found in index.json"
  exit 1
fi

PROPHET_PATHS_FILE="$DATA/prophet_stories/_prophet_paths.txt"

# Python helper:
# العثور على أفضل مسار فعلي للقصة/الاختبار بدل افتراض اسم الملف.
find_story_path() {
  local id="$1"

  python3 - "$PROPHET_PATHS_FILE" "$id" <<'PY'
import sys
import os

paths_file = sys.argv[1]
pid = sys.argv[2]

with open(paths_file, "r", encoding="utf-8") as f:
    paths = [x.strip() for x in f if x.strip()]

normalized = pid.lower().replace("-", "_")

# 1) exact prophet_stories/<id>.json
for p in paths:
    base = os.path.basename(p)
    if p.startswith("prophet_stories/") and not p.startswith("prophet_stories/quizzes/"):
        if base == f"{pid}.json":
            print(p)
            raise SystemExit(0)

# 2) normalized underscore/hyphen fallback
for p in paths:
    base = os.path.basename(p)
    stem = os.path.splitext(base)[0].lower().replace("-", "_")

    if (
        p.startswith("prophet_stories/")
        and not p.startswith("prophet_stories/quizzes/")
        and stem == normalized
    ):
        print(p)
        raise SystemExit(0)

raise SystemExit(1)
PY
}

find_quiz_path() {
  local id="$1"

  python3 - "$PROPHET_PATHS_FILE" "$id" <<'PY'
import sys
import os

paths_file = sys.argv[1]
pid = sys.argv[2]

with open(paths_file, "r", encoding="utf-8") as f:
    paths = [x.strip() for x in f if x.strip()]

normalized = pid.lower().replace("-", "_")

# 1) exact
for p in paths:
    base = os.path.basename(p)
    if p.startswith("prophet_stories/quizzes/"):
        if base == f"{pid}.json":
            print(p)
            raise SystemExit(0)

# 2) normalized fallback
for p in paths:
    base = os.path.basename(p)
    stem = os.path.splitext(base)[0].lower().replace("-", "_")

    if (
        p.startswith("prophet_stories/quizzes/")
        and stem == normalized
    ):
        print(p)
        raise SystemExit(0)

raise SystemExit(1)
PY
}

story_count=0
quiz_count=0

for id in "${PROPHET_IDS[@]}"; do

  echo "----------------------------------------------"
  echo "Prophet: $id"

  # القصة
  if story_path="$(find_story_path "$id")"; then

    story_file="$(basename "$story_path")"

    fetch_json \
      "$BASE/$story_path" \
      "$DATA/prophet_stories/$story_file"

    story_count=$((story_count + 1))

  else

    echo "ERROR: Could not locate story file for prophet ID: $id"

    echo "Available prophet story files:"
    grep '^prophet_stories/[^/]*\.json$' "$PROPHET_PATHS_FILE" | sort || true

    exit 1
  fi

  # الاختبار
  if quiz_path="$(find_quiz_path "$id")"; then

    quiz_file="$(basename "$quiz_path")"

    fetch_json \
      "$BASE/$quiz_path" \
      "$DATA/prophet_stories/quizzes/$quiz_file"

    quiz_count=$((quiz_count + 1))

  else

    echo "ERROR: Could not locate quiz file for prophet ID: $id"

    echo "Available quiz files:"
    grep '^prophet_stories/quizzes/' "$PROPHET_PATHS_FILE" | sort || true

    exit 1
  fi

done

rm -f "$TREE_FILE" "$PROPHET_PATHS_FILE"

if [ "$story_count" -ne "${#PROPHET_IDS[@]}" ]; then
  echo "ERROR: Prophet story count mismatch."
  exit 1
fi

if [ "$quiz_count" -ne "${#PROPHET_IDS[@]}" ]; then
  echo "ERROR: Prophet quiz count mismatch."
  exit 1
fi

echo "Prophet stories downloaded: $story_count"
echo "Prophet quizzes downloaded:  $quiz_count"

# --------------------------------------------------
# 5/7 — Quran metadata/text
# --------------------------------------------------

echo "5/7 — Quran metadata/text indexes for complete offline search/reference"

QURAN_METADATA_FILES=(
  qcf_v2_pages.json
  mushaf_pages.json
  qcf_surah_starts.json
  quran_segments.json
  quran_symbols.json
  quran_duas.json
  hizb_quarters.json
)

for f in "${QURAN_METADATA_FILES[@]}"; do
  fetch_json \
    "$BASE/quran/$f" \
    "$DATA/quran/$f"
done

echo "Downloading 114 Quran surahs..."

download_surah() {
  local n="$1"

  fetch_json \
    "$BASE/quran/chapters/ar/$n.json" \
    "$DATA/quran/chapters/ar/$n.json"
}

export -f download_surah
export -f fetch
export -f fetch_json

export BASE
export DATA

seq 1 114 | xargs -P12 -I{} bash -c 'download_surah "$1"' _ {}

QURAN_COUNT="$(
  find "$DATA/quran/chapters/ar" \
    -maxdepth 1 \
    -type f \
    -name "*.json" \
    | wc -l
)"

if [ "$QURAN_COUNT" -ne 114 ]; then
  echo "ERROR: Expected 114 Quran surah files, found $QURAN_COUNT"
  exit 1
fi

echo "Quran surahs downloaded: $QURAN_COUNT"

# --------------------------------------------------
# 6/7 — 604 Madinah Mushaf pages
# --------------------------------------------------

echo "6/7 — 604-page Madinah Mushaf SVG"

download_page() {
  local page="$1"
  local padded

  padded="$(printf "%03d" "$page")"

  fetch \
    "$QBASE/$padded.svg" \
    "$AS/quran-pages/$padded.svg"
}

export -f download_page
export AS
export QBASE

seq 1 604 | xargs -P12 -I{} bash -c 'download_page "$1"' _ {}

MUSHAF_COUNT="$(
  find "$AS/quran-pages" \
    -maxdepth 1 \
    -type f \
    -name "*.svg" \
    | wc -l
)"

if [ "$MUSHAF_COUNT" -ne 604 ]; then
  echo "ERROR: Expected 604 Mushaf pages, found $MUSHAF_COUNT"
  exit 1
fi

echo "Mushaf pages downloaded: $MUSHAF_COUNT"

# --------------------------------------------------
# Adhan + local notification sound
# --------------------------------------------------

echo "Downloading local adhan audio..."

fetch \
  "https://commons.wikimedia.org/wiki/Special:Redirect/file/Adhan.ogg" \
  "$RESRAW/adhan.ogg"

cp "$RESRAW/adhan.ogg" "$AS/adhan/adhan.ogg"

if [ -f "$RESRAW/notification.wav" ]; then
  cp "$RESRAW/notification.wav" "$AS/audio/notification.wav"
else
  echo "WARNING: notification.wav not found; skipping copy."
fi

# --------------------------------------------------
# 7/7 — Offline manifest + attribution
# --------------------------------------------------

echo "7/7 — Offline manifest and attribution"

cat > "$AS/OFFLINE_CONTENT.txt" <<'EOT'
YAWMY — Offline Content Bundle

All required content is prepared at build time and copied into the Android APK assets.

Bundled content:
- 604 Madinah Mushaf SVG pages
- 114 Quran Arabic surah JSON files
- Quran page/reference metadata
- Sahih al-Bukhari
- Sahih Muslim
- 40 Hadith collections
- 99 Names of Allah
- Tafseer Muyassar
- 25 Prophet stories
- 25 Prophet quizzes
- 14 Azkar/Dua datasets
- Local Adhan audio
- Local notification sound

The runtime application must use bundled local asset paths for these resources.
Internet access is not required to access the bundled files themselves.
EOT

cat > "$AS/ATTRIBUTIONS_OFFLINE.txt" <<'EOT'
Quran page artwork/data:
- quran-ws/quran-svg
  https://github.com/quran-ws/quran-svg

Islamic datasets:
- Islamic App Data by mohammed-2-5
  https://github.com/mohammed-2-5/islamic-library-data

Adhan:
- Adhan.ogg — Aishatu98 — Wikimedia Commons
  https://commons.wikimedia.org/wiki/File:Adhan.ogg
EOT

echo
echo "=============================================="
echo "OFFLINE ASSETS PREPARED SUCCESSFULLY"
echo "=============================================="
echo
echo "Azkar:          OK"
echo "Hadith:         OK"
echo "Prophet stories: $story_count"
echo "Prophet quizzes: $quiz_count"
echo "Quran surahs:   $QURAN_COUNT"
echo "Mushaf pages:   $MUSHAF_COUNT"
echo "=============================================="
  https://commons.wikimedia.org/wiki/File:Adhan.ogg
EOT

echo 'Offline assets prepared successfully.'
