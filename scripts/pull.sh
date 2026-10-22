#!/usr/bin/env bash
# Runs ON THE LAPTOP. Copy renders/ and build/ from the server checkout, then open the newest file.
# Usage: pull.sh [subpath-under-renders-or-build]   (no argument: both directories)
# Env:   NO_OPEN=1 to skip opening in VS Code, REMOTE=gpubox, REMOTE_REPO=work/game
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE="${REMOTE:-gpubox}"
REMOTE_REPO="${REMOTE_REPO:-work/game}"
cd "$ROOT"
mkdir -p renders build

for d in renders build; do
  # skip directories that do not exist on the server yet (nothing rendered/built)
  ssh "$REMOTE" "test -d $REMOTE_REPO/$d" || continue
  rsync -az --partial --itemize-changes "$REMOTE:$REMOTE_REPO/$d/" "$ROOT/$d/"
done

NEWEST="$(find renders build -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.mp4' -o -name '*.zip' -o -name '*.glb' -o -name '*.blend' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$NEWEST" ]] || { echo "nothing to show yet"; exit 0; }
echo "NEWEST=$ROOT/$NEWEST"
if [[ -z "${NO_OPEN:-}" && "$NEWEST" =~ \.(png|jpg|mp4)$ ]] && command -v code >/dev/null; then
  code -r "$ROOT/$NEWEST" || true
fi
