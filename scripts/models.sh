#!/usr/bin/env bash
# Build 3D models with Blender and export glTF. Usage: models.sh [name|all]
# Each art-src/models/<name>.py builds its own scene. Output: build/models/<name>.glb
# Move the .glb files into the game project (e.g. godot-3d/assets/models/) on the laptop and commit.
set -euo pipefail

BLENDER=/opt/blender/blender
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHAT="${1:-all}"
NAMES=(person house tree_pine tree_round lamp)
[[ "$WHAT" == "all" ]] || NAMES=("$WHAT")
mkdir -p "$ROOT/build/models"

for n in "${NAMES[@]}"; do
  [[ -f "$ROOT/art-src/models/$n.py" ]] || { echo "no such model script: art-src/models/$n.py" >&2; exit 2; }
  "$BLENDER" -b --factory-startup --python "$ROOT/art-src/models/$n.py" -- "$ROOT/build/models/$n.glb"
  [[ -s "$ROOT/build/models/$n.glb" ]] || { echo "export produced no file for $n" >&2; exit 1; }
  if [[ "$n" == "person" ]]; then   # tile the 8-frame pose previews into one sheet per animation
    for a in walk run idle door; do
      ffmpeg -hide_banner -loglevel error -y -start_number 0 -framerate 1 -i "$ROOT/build/models/person_${a}_%d.png" \
        -vf tile=8x1 -frames:v 1 "$ROOT/build/models/person_${a}_sheet.png"
    done
  fi
  echo "MODEL_DONE $n"
done
