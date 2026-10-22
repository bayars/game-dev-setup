#!/usr/bin/env bash
# Godot headless export. Usage: build.sh <linux|windows>
# Needs godot/export_presets.cfg with presets named "Linux" and "Windows Desktop" (created in Phase 5).
# Output: build/<project>-<platform>.zip
set -euo pipefail

GODOT=/opt/godot/godot
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:-}"
case "$PLATFORM" in
  linux)   PRESET="Linux";           BIN="game.x86_64" ;;
  windows) PRESET="Windows Desktop"; BIN="game.exe" ;;
  *) echo "usage: build.sh <linux|windows>" >&2; exit 2 ;;
esac

PROJ="$ROOT/godot"
[[ -f "$PROJ/project.godot" ]] || { echo "no Godot project yet: $PROJ/project.godot is missing" >&2; exit 2; }
[[ -f "$PROJ/export_presets.cfg" ]] || { echo "missing $PROJ/export_presets.cfg (create the '$PRESET' preset in the editor and commit it)" >&2; exit 2; }

STAGE="$ROOT/build/stage-$PLATFORM"
rm -rf "$STAGE"; mkdir -p "$STAGE"

"$GODOT" --headless --path "$PROJ" --import
"$GODOT" --headless --path "$PROJ" --export-release "$PRESET" "$STAGE/$BIN"

NAME="$(basename "$ROOT")"
(cd "$STAGE" && python3 -c "
import sys, zipfile, pathlib
z = zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED)
for p in sorted(pathlib.Path('.').rglob('*')):
    if p.is_file(): z.write(p)
z.close()" "$ROOT/build/$NAME-$PLATFORM.zip")
rm -rf "$STAGE"
echo "BUILD_DONE build/$NAME-$PLATFORM.zip"
