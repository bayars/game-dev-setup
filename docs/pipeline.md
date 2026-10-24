# Pipeline

```
laptop                                   gpubox (~/work/game, disposable checkout)
scripts/delegate.sh <job> [args]
  clean tree? feature branch? -> git push
  ssh ------------------------------->  scripts/remote_run.sh <branch> <job> [args]
                                          fetch + detached checkout of the pushed commit
                                          refuse if GPU > 80C; log versions + GPU memory
                                          flock /tmp/gpu.lock + timeout -> scripts/<job>
                                          log: ~/work/logs/<job>-<sha>-<ts>.log (ends with EXIT=<rc>)
  scripts/pull.sh <------- rsync ------  renders/  build/   (gitignored)
```

| Job | Command | Output |
|---|---|---|
| `render` | `delegate.sh render art-src/x.blend 1 1 [--samples N] [--res-percent N]` | `renders/x/frame_0001.png` |
| `export_gltf` | `delegate.sh export_gltf art-src/x.blend [out.glb]` | `build/gltf/x.glb` (move into `godot/assets/` on the laptop and commit) |
| `sprites` | `delegate.sh sprites [player\|hazard\|coin\|background\|all] [size]` | `build/sprites/<name>_sheet.png` (8-frame row), `background.png`; source scripts in `art-src/sprites/` |
| `models` | `delegate.sh models [person\|house\|tree_pine\|tree_round\|lamp\|all]` | `build/models/<name>.glb` and `<name>_preview.png`; sources in `art-src/models/` |
| `build_linux` / `build_windows` | `delegate.sh build_linux [project_dir]` | `build/<name>-<platform>.zip` (needs `<project_dir>/project.godot` and `export_presets.cfg`; default `godot`) |
| `encode` | `delegate.sh encode renders/x/frame_%04d.png renders/x.mp4` | NVENC, libx264 fallback |
| `gen_test_blend` | `delegate.sh gen_test_blend` | `renders/_gen/test.blend` (made with the server's Blender 4.2.23) |

Add `--detach` before the job name for long jobs (runs in tmux on the server, delegate polls the log).

Exit codes from `remote_run.sh`: 2 usage or missing file, 3 server checkout dirty, 4 GPU too hot, 75 another GPU job running, otherwise the job's own code (3 from `blender_render.py` means no CUDA device).

Design notes:
- All binaries are called by absolute path (`/opt/blender/blender`, `/opt/godot/godot`); `~/bin` is not on the non-interactive PATH.
- Generated files never land in tracked folders on the server, so the checkout stays clean and `git checkout` never collides with them.
- Server logs older than 14 days are pruned by `remote_run.sh`.

Releases: `scripts/release.sh <project_dir> <version>` builds both platforms and puts the zips in `releases/` (Git LFS); commit them on the laptop.
