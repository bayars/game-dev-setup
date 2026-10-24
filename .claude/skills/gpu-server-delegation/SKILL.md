---
name: gpu-server-delegation
description: Use when building or testing the game project and a step needs a GPU or heavy compute (Blender renders, glTF export, baking, Godot headless export, ffmpeg encoding). Delegates those jobs to the home GPU server over SSH and brings back results. Keep light work (code, scripts, git) local.
---

# GPU server delegation

## Setup (verified 2026-10-21)

- Server SSH alias: `gpubox` (10.0.0.224, user `safa`, key `~/.ssh/gpubox`, same LAN)
- Server checkout: `~/work/game` (disposable clone of `github.com/bayars/game-dev-setup`; read-only deploy key). Logs: `~/work/logs`.
- Blender `/opt/blender/blender` 4.2.23 LTS. Godot `/opt/godot/godot` 4.7.2-stable (laptop has the same at `~/.local/bin/godot`). Call them by absolute path; `~/bin` is not on the non-interactive PATH.
- GPU: Tesla P4 (Pascal, 8 GB, CUDA only, **no OptiX**, passive cooling). Driver 550.163.01 (runfile, no DKMS), kernel 6.1.0-52 on `apt-mark hold`. Never upgrade or remove either.
- The server is shared: ollama keeps about 0.7 GB of VRAM; there is 9.5 GB RAM and no swap. Keep scenes small.
- Laptop has no GPU, and its Blender is 3.4.1: never render with it and never save `.blend` files with it.

## Local vs. server

Local: editing GDScript, Python, shell, docs; git; linting; viewing results in VS Code.
Server: Cycles renders and baking, glTF export, Godot headless export, ffmpeg encode, anything over ~30 s or needing CUDA.

## Procedure (one command)

From a **clean, committed feature branch** on the laptop:

```
scripts/delegate.sh [--detach] <job> [args]
```

It pushes the branch, syncs the server checkout to that exact commit, runs the job under `flock` + `timeout` (refuses above 80C), then rsyncs `renders/` and `build/` back and opens the newest image.

| Job | Command | Output (laptop, gitignored) |
|---|---|---|
| render | `scripts/delegate.sh render art-src/x.blend <start> <end> [--samples N] [--res-percent N]` | `renders/x/frame_####.png` |
| export_gltf | `scripts/delegate.sh export_gltf art-src/x.blend [out.glb]` | `build/gltf/x.glb` |
| sprites | `scripts/delegate.sh sprites [player\|hazard\|coin\|background\|all] [size]` | `build/sprites/<name>_sheet.png`, `background.png` |
| models | `scripts/delegate.sh models [name|all]` | `build/models/<name>.glb` plus `<name>_preview.png` (look at it) |
| build_linux / build_windows | `scripts/delegate.sh build_linux [project_dir]` | `build/<name>-<platform>.zip` |
| encode | `scripts/delegate.sh encode renders/x/frame_%04d.png renders/x.mp4` | NVENC with libx264 fallback |
| gen_test_blend | `scripts/delegate.sh gen_test_blend` | `renders/_gen/test.blend` |

- Paths in job arguments are relative to the repo root.
- Use `--detach` for anything that may run more than a minute or two; delegate polls the log until the `EXIT=` line.
- Do not wrap it in your own `ssh`, `tmux`, `rsync` or `flock`; the scripts already do. Hand-run `ssh gpubox` commands are for read-only diagnosis (logs, `nvidia-smi`).

Report back: job, branch and commit, output path (open the image), and any warnings from the log (the log path is printed as `LOG=`).

Release zips: `scripts/release.sh <project_dir> <version>` (stored in `releases/` via Git LFS; the server never downloads them).

Assets for the game (`.glb`, textures) are moved into `godot/assets/` on the laptop and committed there; the server never pushes. The laptop is the only place that writes work branches.

## First-time sanity check

`ssh gpubox true && ssh gpubox nvidia-smi -L` should print the P4. If SSH fails, report it; do not change SSH config or keys.

## Rules

- The server checkout is disposable. Never hand-edit files there. Fix locally, push, rerun.
- One GPU job at a time (the scripts hold `/tmp/gpu.lock`; exit 75 means another job is running: wait, do not delete the lock).
- Cycles must use the CUDA device only. If it finds none (exit 3) stop and report the device list; never fall back to CPU silently. If `nvidia-smi` or CUDA fails, compare `uname -r` with `6.1.0-52-amd64` and report.
- Exit 4 means the GPU is above the temperature limit: stop and tell the user. Do not raise `MAX_TEMP`.
- Never touch NVIDIA drivers, the kernel, apt holds or system settings on the server. No `apt upgrade`, no reboot, no `apt-mark unhold`. See `docs/driver-and-kernel-maintenance.md`.
- Delete nothing on the server outside `~/work/game` and `~/work/logs`; ask first for deleting results.
- Do not commit renders or builds. Git LFS is only for source art (`*.blend *.psd *.exr`); anything over 1 MB must be LFS. GitHub LFS free quota is 1 GB storage and 1 GB/month bandwidth, so do not commit large generated files and check `git lfs ls-files` before adding assets.
- Keep Blender, Godot and driver versions as pinned. If a task needs different ones, ask the user.
- Never use `pkill -f` on the server (it kills your own SSH session); use `pkill -x <name>`.

## When something fails

1. Read the last 40-100 lines of the log (`ssh gpubox "tail -n 80 <LOG path>"`), not just the exit code.
2. Classify using the exit code: 2 usage or missing file; 3 no CUDA device (or dirty server checkout when it comes from the sync step); 4 too hot; 75 busy; other = the job's own error. Also consider out of VRAM (8 GB minus ollama: lower tile size, samples or texture size) and missing dependency.
3. Script bug: fix locally, commit, rerun. Environment problem: report the exact error and stop; do not improvise system changes.
4. After two failures with the same error, stop and summarize instead of looping.

## Known pitfalls

- Cycles lists a `Tesla P4` as OPTIX too; `blender_render.py` already enables only CUDA.
- Adaptive sampling makes trivial scenes finish early; irrelevant for real scenes, but turn it off when benchmarking heat.
- Server stage-1 sync fails if the checkout has tracked local changes (someone edited it by hand); report it, do not reset it silently.
