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

## Git access

- Laptop pushes with a dedicated write deploy key `~/.ssh/github_game` (set in this repo's `core.sshCommand`).
- Server fetches with a read-only deploy key via the `github-game` SSH alias (`~/.ssh/github_game_deploy` on the server). It cannot push.
- `~/.ssh/gpubox` is only for logging in to the server.

## Pipeline (details in `docs/pipeline.md`)

Normal path for any GPU job, from a clean feature branch on the laptop: `scripts/delegate.sh <job> [args]`
(pushes, runs `remote_run.sh` on the server, pulls results into `renders/` and `build/`).

## Game: Dodger (2D one-screen arcade, Godot)

Start screen (Space/Enter). Move the blue square (WASD/arrows), collect yellow coins (+10), avoid red squares: 3 lives, 1 s invulnerability after a hit. Score = 10 per coin + seconds survived. Best score is saved to `user://highscore.cfg` (not written during `--selftest`). Space/Enter restarts. Art is Blender-made: sprite scenes are Python scripts in `art-src/sprites/` (`player`, `hazard`, `coin`, `background`, shared `common.py`), rendered on the server with `scripts/delegate.sh sprites [name|all] [size]` (final sheets use size 96; 256 for design previews). Output `build/sprites/*_sheet.png` (8 frames, 1 row) and `background.png` is copied into `godot/assets/sprites/` and committed from the laptop. Sprites display at scale 0.5.
- Run: `godot --path godot` (editor: `godot --path godot -e`)
- Screenshots without a window: `xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver opengl3 --write-movie out.png --fixed-fps 30 --quit-after 240 -- --autostart`
- Headless loop check: `godot --headless --path godot -- --selftest` prints `SELFTEST_OK` (also works on the exported binary: `game.x86_64 --headless -- --selftest`)
- Layout: `godot/scenes/` (`main.tscn`, `faller.tscn`), `godot/scripts/` (`main.gd` loop, `player.gd`, `faller.gd`). Input uses physical key checks (no InputMap yet). `-- --autostart` skips the start screen.

## Game 2: Walk Home (3D story, `godot-3d/`)

A person walks up a path at dusk to a house and opens the door (WASD, mouse look, Shift run, E to open). Title, two story lines, objective, "Welcome home", end card (R again, Esc quit).
- All models are Blender scripts in `art-src/models/` (`person`, `house`, `tree_pine`, `tree_round`, `lamp`, shared `common.py`), built and exported on the server: `scripts/delegate.sh models [name|all]` -> `build/models/<name>.glb` (+ `<name>_preview.png`, a Cycles preview on the P4). Move the `.glb` into `godot-3d/assets/models/` on the laptop and commit. Joints are Empties (`ArmL`, `LegL`, `Head`, `DoorHinge` ...); `-convcolonly` objects become collision shapes in Godot.
- The world, story state machine and UI are built in code: `godot-3d/scripts/main.gd` (`Phase` enum TITLE, WALK, AT_DOOR, OPENING, END) and `player.gd`.
- Headless check: `godot --headless --path godot-3d -- --selftest` plays the whole story fast and prints `SELFTEST_OK`. `-- --autoplay` plays it at normal speed; `--start-z=-2` spawns near the house (quick screenshots, see the xvfb recipe above).
- Pitfall: point lights placed within ~1 m of a wall blow it out to white; keep them away or use emissive materials.

## Releases

`scripts/release.sh <project_dir> <version>` (e.g. `godot-3d 0.1.0`) builds Linux and Windows on the server and copies the zips to `releases/<name>-<version>-<platform>.zip`, stored in Git LFS (`releases/*.zip`). Commit them from the laptop. The server checkout excludes `releases/*` from LFS fetches. Windows builds are only checked structurally (PE header); they cannot be run on this machine.
Builds: `scripts/delegate.sh build_linux [project_dir]` / `build_windows [project_dir]` (default project_dir `godot` = Dodger), output `build/<config/name lowercased>-<platform>.zip`.

## Status

See `docs/server-baseline.md`. Phase 3 scripts live in `scripts/`.
