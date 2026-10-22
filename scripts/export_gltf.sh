#!/usr/bin/env bash
# .blend -> .glb. Usage: export_gltf.sh <file.blend> [out.glb]
# Default output: build/gltf/<name>.glb (gitignored). Pull it, then move into godot/assets/
# and commit from the laptop (the laptop is the only place that writes to work branches).
set -euo pipefail

BLENDER=/opt/blender/blender
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# -ge 1 ]] || { echo "usage: export_gltf.sh <file.blend> [out.glb]" >&2; exit 2; }
BLEND="$1"
[[ -f "$ROOT/$BLEND" ]] || { echo "not found: $ROOT/$BLEND (path is relative to the repo root)" >&2; exit 2; }
NAME="$(basename "$BLEND" .blend)"
OUT="${2:-build/gltf/$NAME.glb}"
mkdir -p "$(dirname "$ROOT/$OUT")"

exec "$BLENDER" -b "$ROOT/$BLEND" --python "$ROOT/scripts/export_gltf.py" -- "$ROOT/$OUT"
