---
name: gpu-server-delegation
description: Use when building or testing the game project and a step needs a GPU or heavy compute (Blender renders, glTF export, baking, Godot headless export, ffmpeg encoding). Delegates those jobs to the home GPU server over SSH and brings back results. Keep light work (code, scripts, git) local.
---

# GPU server delegation

## Setup (fill in once)

- Server SSH alias: `gpubox` (reachable over WireGuard; defined in `~/.ssh/config`)
- Server repo path: `~/work/<project>` (a disposable checkout of the GitLab repo)
- Blender: `/opt/blender/blender` (pinned: 4.2 LTS)
- Godot: `/opt/godot/godot` (pinned: 4.x, same version as laptop)
- GPU: Tesla P4 (Pascal, 8 GB, CUDA only, no OptiX). NVIDIA driver is frozen on the 580 branch. Never upgrade or remove it.
- Laptop has no GPU. Never try to render or run heavy 3D locally.

## What stays local vs. what goes to the server

Local (laptop):
- Writing and editing GDScript, Python, shell scripts, docs
- Git operations, linting, quick unit-level checks
- Viewing results in VS Code

Server (`gpubox`):
- Blender Cycles renders and baking (`blender -b`)
- Blender -> glTF export scripts
- Godot headless exports and builds
- ffmpeg encoding, sprite-sheet or turntable generation
- Any command expected to take more than ~30 seconds or need CUDA

## Procedure for a delegated job

1. **Commit and push** the current work to a feature branch on GitLab. Never delegate uncommitted changes. The server only sees what is pushed.
2. **Run the job on the server** with the helper, which checks out the exact commit and runs the named script:
   `ssh gpubox "~/work/<project>/scripts/remote_run.sh <branch> <job> [args]"`
   For jobs longer than a minute, start them detached and poll:
   `ssh gpubox "tmux new -d -s <job> '<command> > ~/work/logs/<job>.log 2>&1'"`
3. **Poll the log**, do not guess: `ssh gpubox "tail -n 40 ~/work/logs/<job>.log"`. Check whether the process is still running before waiting longer.
4. **Fetch results** back to the laptop into `renders/` or `build/` (both gitignored):
   `rsync -avz gpubox:~/work/<project>/renders/ ./renders/`
   Convert formats VS Code cannot preview (EXR, HDR) to PNG on the server first so they open in the editor.
5. **Report** to the user: what ran, which commit, where the output files are, and any warnings from the log. Open the image path so VS Code can show it.

Assets that must be part of the game (glTF exports, textures) are committed from the server on a branch (via Git LFS) or fetched with rsync and committed from the laptop. Prefer the second unless the user says otherwise, so the laptop remains the only place that writes to main work branches.

## Rules

- The server checkout is disposable. Never hand-edit files there. Fix things locally, push, rerun.
- Run one GPU job at a time. Wrap GPU jobs in `flock /tmp/gpu.lock <command>`.
- Before a long render, run `nvidia-smi` on the server and check temperature. The P4 is passively cooled; if it is above ~80C, stop and tell the user.
- Always set a timeout on jobs (`timeout 2h <command>`) and log to a file.
- Pass exact CUDA settings to Blender (device type CUDA, P4 enabled). If Cycles shows no GPU, stop and report the device list rather than falling back to CPU silently.
- Never touch NVIDIA drivers, apt holds, or system settings on the server.
- Never delete anything outside `~/work/<project>` and `~/work/logs` on the server. Ask first for any deletion of results.
- Do not commit rendered output. Do not commit anything over 1 MB that is not tracked by Git LFS.
- Keep Blender, Godot and driver versions as pinned above. If a task would need a newer one, ask the user.

## Job catalog (put these in `scripts/`)

| Job | Script | What it does |
|---|---|---|
| `render` | `scripts/render.sh <file.blend> <start> <end>` | Cycles render on CUDA to `renders/` |
| `export_gltf` | `scripts/export_gltf.py` | Exports a .blend to .glb into `godot/assets/` |
| `build_linux` | `scripts/build.sh linux` | Godot headless export, zips to `build/` |
| `build_windows` | `scripts/build.sh windows` | Same for Windows |
| `encode` | `scripts/encode.sh <in> <out>` | ffmpeg encode (NVENC if available) |

If a needed script does not exist, write it locally, commit, push, then delegate it.

## When something fails

1. Read the last 40-100 lines of the log, not just the exit code.
2. Classify: CUDA/device problem, out of VRAM (8 GB limit: reduce texture size, tile size, or samples), missing dependency, or script bug.
3. Script bug: fix locally, push, rerun. Environment problem: report to the user with the exact error; do not improvise system changes.
4. After two failed attempts with the same error, stop and summarize instead of looping.

