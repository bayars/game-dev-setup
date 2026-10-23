#!/usr/bin/env bash
# Runs ON THE SERVER. Checks out an exact pushed commit and runs one job under
# flock + timeout, logging to ~/work/logs. Usage:
#   remote_run.sh [--detach] <branch> <job> [args...]
# Jobs: render, export_gltf, sprites, models, build_linux, build_windows, encode, gen_test_blend
# Env:  TIMEOUT (default 2h), MAX_TEMP (default 80)
set -euo pipefail

BLENDER=/opt/blender/blender
GODOT=/opt/godot/godot
LOG_DIR="$HOME/work/logs"
LOCK=/tmp/gpu.lock
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DETACH=0
if [[ "${1:-}" == "--detach" ]]; then DETACH=1; shift; fi
[[ $# -ge 2 ]] || { echo "usage: remote_run.sh [--detach] <branch> <job> [args...]" >&2; exit 2; }
BRANCH="$1"; JOB="$2"; shift 2
[[ "$BRANCH" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "bad branch name: $BRANCH" >&2; exit 2; }

cd "$ROOT"

# Stage 1: update to the exact pushed commit, then re-exec so the new scripts run.
if [[ -z "${RR_STAGE2:-}" ]]; then
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "server checkout has tracked changes; refusing (it must stay disposable)" >&2
    git status --short >&2
    exit 3
  fi
  git config lfs.fetchexclude 'releases/*'   # release zips are for the laptop; do not download them here
  git fetch --quiet origin "$BRANCH"
  git checkout --quiet --detach FETCH_HEAD
  export RR_STAGE2=1
  if [[ $DETACH -eq 1 ]]; then exec "$ROOT/scripts/remote_run.sh" --detach "$BRANCH" "$JOB" "$@"; fi
  exec "$ROOT/scripts/remote_run.sh" "$BRANCH" "$JOB" "$@"
fi

SHA="$(git rev-parse --short HEAD)"
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -maxdepth 1 -name '*.log' -mtime +14 -delete
TS="$(date +%Y%m%d-%H%M%S)"
LOG="${RR_LOG:-$LOG_DIR/${JOB}-${SHA}-${TS}.log}"

case "$JOB" in
  render)         CMD=("$ROOT/scripts/render.sh" "$@") ;;
  export_gltf)    CMD=("$ROOT/scripts/export_gltf.sh" "$@") ;;
  models)         CMD=("$ROOT/scripts/models.sh" "$@") ;;
  sprites)        CMD=("$ROOT/scripts/sprites.sh" "$@") ;;
  build_linux)    CMD=("$ROOT/scripts/build.sh" linux "$@") ;;
  build_windows)  CMD=("$ROOT/scripts/build.sh" windows "$@") ;;
  encode)         CMD=("$ROOT/scripts/encode.sh" "$@") ;;
  gen_test_blend) CMD=("$BLENDER" -b --factory-startup --python "$ROOT/scripts/make_test_blend.py" -- "$ROOT/renders/_gen/test.blend") ;;
  *) echo "unknown job: $JOB" >&2; exit 2 ;;
esac

if [[ $DETACH -eq 1 ]]; then
  command -v tmux >/dev/null || { echo "tmux missing" >&2; exit 2; }
  echo "LOG=$LOG"
  : > "$LOG"
  tmux new -d -s "job-${JOB}-${TS}" "RR_STAGE2=1 RR_LOG='$LOG' '$ROOT/scripts/remote_run.sh' '$BRANCH' '$JOB' $(printf '%q ' "$@") >/dev/null 2>&1"
  exit 0
fi

echo "LOG=$LOG"
{
  echo "== job=$JOB branch=$BRANCH commit=$(git rev-parse HEAD) time=$(date -Is)"
  echo "== blender: $("$BLENDER" --version 2>/dev/null | head -1) | godot: $("$GODOT" --headless --version 2>/dev/null | head -1)"
  nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total,utilization.gpu --format=csv,noheader | sed 's/^/== gpu temp,mem used,mem total,util: /'
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | sed 's/^/== gpu app: /' || true
} 2>&1 | tee -a "$LOG"

TEMP="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)"
if (( TEMP > ${MAX_TEMP:-80} )); then
  echo "GPU is ${TEMP}C (limit ${MAX_TEMP:-80}); refusing to start. Let it cool." | tee -a "$LOG" >&2
  echo "EXIT=4" | tee -a "$LOG"
  exit 4
fi

set +e
( flock -n 9 || { echo "another GPU job holds $LOCK; not starting" >&2; exit 75; }
  timeout "${TIMEOUT:-2h}" "${CMD[@]}" ) 9>"$LOCK" 2>&1 | tee -a "$LOG"
RC=${PIPESTATUS[0]}
echo "EXIT=$RC" | tee -a "$LOG"
exit "$RC"
