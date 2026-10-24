#!/usr/bin/env bash
# Bake seamless PBR texture sets with Cycles. Usage: textures.sh [name ...]   (default: all recipes)
# Output: build/textures/<name>_{albedo,normal,rough}.png plus contact sheets (sheet_albedo.png, sheet_normal.png).
# Copy the PNGs you want into godot-3d/assets/textures/ on the laptop and commit.
set -euo pipefail

BLENDER=/opt/blender/blender
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/textures"
mkdir -p "$OUT"
"$BLENDER" -b --factory-startup --python "$ROOT/art-src/textures/pbr.py" -- "$OUT" "$@"
for k in albedo normal; do
  rm -f "$OUT/sheet_$k.png"
  ffmpeg -hide_banner -loglevel error -y -framerate 1 -pattern_type glob -i "$OUT/[a-z]*_$k.png" \
    -vf scale=256:256,tile=5x2 -frames:v 1 "$OUT/sheet_$k.png"
done
echo "TEXTURES_DONE"
