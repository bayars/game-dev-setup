#!/usr/bin/env bash
# Runs ON THE LAPTOP. One command for a delegated GPU job:
#   check tree is clean -> push the current feature branch -> run the job on the server -> pull results.
# Usage: delegate.sh [--detach] <job> [args...]
#   jobs: render <blend> <start> <end> | export_gltf <blend> [out] | sprites [name|all] [size]
#         | build_linux | build_windows
#         | encode <in> <out> | gen_test_blend
# --detach starts the job in tmux on the server and polls the log (for jobs over a minute or two).
# Env: REMOTE=gpubox  REMOTE_REPO=work/game  TIMEOUT=2h  NO_OPEN=1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE="${REMOTE:-gpubox}"
REMOTE_REPO="${REMOTE_REPO:-work/game}"
cd "$ROOT"

DETACH=()
if [[ "${1:-}" == "--detach" ]]; then DETACH=(--detach); shift; fi
[[ $# -ge 1 ]] || { sed -n '2,10p' "$0" >&2; exit 2; }

BRANCH="$(git branch --show-current)"
[[ -n "$BRANCH" ]] || { echo "detached HEAD; switch to a feature branch first" >&2; exit 2; }
[[ "$BRANCH" != "main" ]] || { echo "refusing to delegate from main; use a feature branch" >&2; exit 2; }
if [[ -n "$(git status --porcelain)" ]]; then
  echo "uncommitted changes; commit first (the server only sees what is pushed):" >&2
  git status --short >&2; exit 2
fi

echo "== push $BRANCH ($(git rev-parse --short HEAD))"
git push --quiet -u origin "$BRANCH"

echo "== sync $REMOTE checkout"
# remote_run.sh may not exist yet on the server (new branch/script), so move the checkout first.
ssh "$REMOTE" "cd ~/$REMOTE_REPO && [ -z \"\$(git status --porcelain --untracked-files=no)\" ] && git fetch --quiet origin $(printf '%q' "$BRANCH") && git checkout --quiet --detach FETCH_HEAD"

ARGS="$(printf '%q ' "$@")"
RUN="TIMEOUT=${TIMEOUT:-2h} ~/$REMOTE_REPO/scripts/remote_run.sh ${DETACH[*]:-} $(printf '%q' "$BRANCH") $ARGS"

set +e
if [[ ${#DETACH[@]} -eq 0 ]]; then
  echo "== run on $REMOTE"
  ssh "$REMOTE" "$RUN"
  RC=$?
else
  OUT="$(ssh "$REMOTE" "$RUN")"; RC=$?
  echo "$OUT"
  LOG="$(sed -n 's/^LOG=//p' <<<"$OUT" | head -1)"
  if [[ $RC -eq 0 && -n "$LOG" ]]; then
    until ssh "$REMOTE" "grep -q '^EXIT=' '$LOG'"; do
      sleep 15; ssh "$REMOTE" "tail -n 1 '$LOG' | cut -c1-160"
    done
    ssh "$REMOTE" "tail -n 40 '$LOG'"
    RC="$(ssh "$REMOTE" "sed -n 's/^EXIT=//p' '$LOG' | tail -1")"
  fi
fi
set -e

echo "== job exit code: $RC"
if [[ "$RC" == "0" ]]; then
  "$ROOT/scripts/pull.sh"
else
  echo "job failed; results not pulled. Read the log on the server (path printed as LOG= above)." >&2
fi
exit "${RC:-1}"
