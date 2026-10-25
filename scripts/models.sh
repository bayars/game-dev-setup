#!/usr/bin/env bash
# Build 3D models with Blender and export glTF. Usage: models.sh [--cpu] [--sheets=all|clip,clip] [name...|all]
# Each art-src/models/<name>.py builds its own scene. Output: build/models/<name>.glb
# person_<id> builds person.py with the people.py profile <id> (the Off the Books cast); --sheets also renders
# 8-frame pose sheets of those clips (build/models/person_<id>_<clip>_sheet.png).
# --cpu renders previews and icons with Cycles on the CPU (when ollama holds the shared P4's memory).
# Move the .glb files into the game project (e.g. godot-3d/assets/models/) on the laptop and commit.
set -euo pipefail

BLENDER=/opt/blender/blender
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMES=(person house tree_pine tree_round lamp house_props tools
       person_nico person_tomas person_daniel person_linda person_robert person_sofia person_rose
       person_hale person_officer)
SHEETS=""
CPU=""
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --sheets=*) SHEETS="${1#--sheets=}" ;;
    --cpu) CPU=1 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
[[ $# -eq 0 || "$1" == "all" ]] || NAMES=("$@")
mkdir -p "$ROOT/build/models"

for n in "${NAMES[@]}"; do
  script="$ROOT/art-src/models/$n.py"
  profile=""
  if [[ "$n" == person_* ]]; then script="$ROOT/art-src/models/person.py"; profile="${n#person_}"; fi
  [[ -f "$script" ]] || { echo "no such model script: art-src/models/$n.py" >&2; exit 2; }
  PERSON_PROFILE="$profile" PERSON_SHEETS="$SHEETS" CYCLES_CPU="$CPU" \
    "$BLENDER" -b --factory-startup --python "$script" -- "$ROOT/build/models/$n.glb"
  [[ -s "$ROOT/build/models/$n.glb" ]] || { echo "export produced no file for $n" >&2; exit 1; }
  if [[ "$n" == "person" ]]; then   # tile the 8-frame pose previews into one sheet per animation
    for a in walk run idle door; do
      ffmpeg -nostdin -hide_banner -loglevel error -y -start_number 0 -framerate 1 -i "$ROOT/build/models/person_${a}_%d.png" \
        -vf tile=8x1 -frames:v 1 "$ROOT/build/models/person_${a}_sheet.png"
    done
  fi
  if [[ "$n" == person_* ]]; then  # one 8-frame sheet per rendered clip
    for f in "$ROOT"/build/models/"${n}"_*_0.png; do
      [[ -e "$f" ]] || continue
      a="${f%_0.png}"
      ffmpeg -nostdin -hide_banner -loglevel error -y -start_number 0 -framerate 1 -i "${a}_%d.png" \
        -vf tile=8x1 -frames:v 1 "${a}_sheet.png"
    done
  fi
  if [[ "$n" == "tools" ]]; then    # contact sheet of the tray icons
    ffmpeg -nostdin -hide_banner -loglevel error -y -pattern_type glob -i "$ROOT/build/models/tools_icon_*.png" \
      -vf tile=7x3 -frames:v 1 "$ROOT/build/models/tools_sheet.png"
  fi
  echo "MODEL_DONE $n"
done
