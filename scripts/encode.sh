#!/usr/bin/env bash
# ffmpeg encode. Usage: encode.sh <in> <out.mp4>
# Both paths are relative to the repo root. Tries NVENC (P4 supports H.264), falls back to libx264.
# Image sequences: pass a pattern, e.g. renders/test/frame_%04d.png (framerate via FPS, default 30).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# -eq 2 ]] || { echo "usage: encode.sh <in> <out.mp4>" >&2; exit 2; }
IN="$ROOT/$1"; OUT="$ROOT/$2"
mkdir -p "$(dirname "$OUT")"

if [[ "$1" == *%* ]]; then INPUT=(-framerate "${FPS:-30}" -i "$IN"); else [[ -f "$IN" ]] || { echo "not found: $IN" >&2; exit 2; }; INPUT=(-i "$IN"); fi

if ffmpeg -hide_banner -y "${INPUT[@]}" -c:v h264_nvenc -preset p5 -pix_fmt yuv420p "$OUT"; then
  echo "ENCODE_DONE encoder=h264_nvenc $2"
else
  echo "NOTICE: NVENC failed, falling back to libx264 (CPU)" >&2
  ffmpeg -hide_banner -y "${INPUT[@]}" -c:v libx264 -crf 18 -pix_fmt yuv420p "$OUT"
  echo "ENCODE_DONE encoder=libx264 $2"
fi
