#!/usr/bin/env bash
# Runs ON THE LAPTOP. Build Linux and Windows on the server and store the zips in releases/ (Git LFS).
# Usage: release.sh <project_dir> <version>     e.g. release.sh godot-3d 0.1.0
# Needs a clean feature branch (delegate.sh pushes it). Commit releases/ afterwards.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ $# -eq 2 ]] || { sed -n '2,4p' "$0" >&2; exit 2; }
PROJECT_DIR="$1"; VERSION="$2"
[[ -f "$PROJECT_DIR/project.godot" ]] || { echo "no project at $PROJECT_DIR" >&2; exit 2; }
NAME="$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$PROJECT_DIR/project.godot" | head -1 | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
mkdir -p releases

for platform in linux windows; do
  NO_OPEN=1 "$ROOT/scripts/delegate.sh" "build_$platform" "$PROJECT_DIR"
  cp "build/$NAME-$platform.zip" "releases/$NAME-$VERSION-$platform.zip"
  echo "RELEASE releases/$NAME-$VERSION-$platform.zip"
done
