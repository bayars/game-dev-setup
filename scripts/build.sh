#!/usr/bin/env bash
# Godot headless export. Usage: build.sh <linux|windows> [project_dir]   (default project_dir: godot)
# Needs <project_dir>/export_presets.cfg with presets "Linux" and "Windows Desktop".
# Output: build/<name>-<platform>.zip where <name> is config/name from project.godot, lowercased.
set -euo pipefail

GODOT=/opt/godot/godot
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:-}"
PROJECT_DIR="${2:-godot}"
[[ "$PROJECT_DIR" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "bad project dir: $PROJECT_DIR" >&2; exit 2; }
PROJ="$ROOT/$PROJECT_DIR"
[[ -f "$PROJ/project.godot" ]] || { echo "no Godot project: $PROJ/project.godot is missing" >&2; exit 2; }
NAME="$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$PROJ/project.godot" | head -1 | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
[[ -n "$NAME" ]] || NAME="game"
case "$PLATFORM" in
  linux)   PRESET="Linux";           BIN="$NAME.x86_64" ;;
  windows) PRESET="Windows Desktop"; BIN="$NAME.exe" ;;
  *) echo "usage: build.sh <linux|windows> [project_dir]" >&2; exit 2 ;;
esac
[[ -f "$PROJ/export_presets.cfg" ]] || { echo "missing $PROJ/export_presets.cfg (create the '$PRESET' preset in the editor and commit it)" >&2; exit 2; }

STAGE="$ROOT/build/stage-$PLATFORM"
rm -rf "$STAGE"; mkdir -p "$STAGE"

"$GODOT" --headless --path "$PROJ" --import
"$GODOT" --headless --path "$PROJ" --export-release "$PRESET" "$STAGE/$BIN"

(cd "$STAGE" && python3 -c "
import sys, zipfile, pathlib
z = zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED)
for p in sorted(pathlib.Path('.').rglob('*')):
    if p.is_file(): z.write(p)
z.close()" "$ROOT/build/$NAME-$PLATFORM.zip")
rm -rf "$STAGE"
echo "BUILD_DONE build/$NAME-$PLATFORM.zip"
