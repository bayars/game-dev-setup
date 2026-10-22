#!/usr/bin/env bash
# Cycles CUDA render. Usage: render.sh <file.blend> <start> <end> [extra args for blender_render.py]
# Extra args: --samples N  --res-percent N
# Output: renders/<blendname>/frame_####.png (repo-relative)
set -euo pipefail

BLENDER=/opt/blender/blender
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# -ge 3 ]] || { echo "usage: render.sh <file.blend> <start> <end> [--samples N] [--res-percent N]" >&2; exit 2; }
BLEND="$1"; START="$2"; END="$3"; shift 3
[[ -f "$ROOT/$BLEND" ]] || { echo "not found: $ROOT/$BLEND (path is relative to the repo root)" >&2; exit 2; }
[[ "$START" =~ ^[0-9]+$ && "$END" =~ ^[0-9]+$ ]] || { echo "start/end must be integers" >&2; exit 2; }
if head -c 40 "$ROOT/$BLEND" | grep -q "git-lfs"; then
  echo "$BLEND is an LFS pointer, not the real file; run 'git lfs pull' on the server checkout" >&2; exit 2
fi

NAME="$(basename "$BLEND" .blend)"
OUT="$ROOT/renders/$NAME"
mkdir -p "$OUT"

exec "$BLENDER" -b "$ROOT/$BLEND" -t "${BLENDER_THREADS:-8}" \
  --python "$ROOT/scripts/blender_render.py" -- \
  --start "$START" --end "$END" --out "$OUT/frame_" "$@"
