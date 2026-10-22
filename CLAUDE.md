# Game project

Hobby game (2D or 3D, undecided). Laptop is the control plane (no GPU); heavy work runs on the GPU server `gpubox` per the `gpu-server-delegation` skill (`.claude/skills/`).

## Pinned versions (do not change without asking)

| Component | Version |
|---|---|
| Blender (server) | 4.2.23 LTS, `/opt/blender` |
| Godot | 4.7.2-stable (laptop and server must match), `/opt/godot` on server |
| NVIDIA driver (server) | 550.163.01, runfile install, frozen |
| Kernel (server) | 6.1.0-52-amd64, held (see `docs/driver-and-kernel-maintenance.md`) |
| GPU | Tesla P4, ~7.5 GiB VRAM, CUDA only, passive, shared with ollama |

Known mismatch: laptop Blender is 3.4.1. Do not open or save `.blend` files with it; use the server's 4.2.23 for anything that writes `.blend`.

## Layout

`godot/` Godot project; `art-src/` .blend and raw textures (LFS); `scripts/` pipeline scripts; `docs/` server baseline and maintenance; `renders/`, `build/` gitignored.

## Rules

- Work on feature branches; never push to `main`; review diffs before merging.
- Never edit files on the server by hand. Fix locally, push, rerun.
- GPU or heavy jobs go through the skill. Never touch NVIDIA drivers, kernel, apt holds, or run `apt upgrade` on the server.
- Do not commit renders or builds. Git LFS only for source art (`*.blend *.psd *.exr`).
- Server: `ssh gpubox` (10.0.0.224, user `safa`, key `~/.ssh/gpubox`). Repo checkout at `~/work/game`, logs in `~/work/logs`.
- Stop and summarize after two identical failures.

## Status

See `docs/server-baseline.md`. Pipeline scripts (`scripts/`) are added in Phase 3.
