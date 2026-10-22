# Server baseline: gpubox (10.0.0.224)

Audited read-only on 2026-10-21 over `ssh gpubox` (user `safa`, key `~/.ssh/gpubox`).

## Facts

| Item | Value |
|---|---|
| OS / kernel | Debian 12 (bookworm), 6.1.0-52-amd64 |
| Hostname | `main` (shared server, not a dedicated render box) |
| GPU | Tesla P4, 7680 MiB usable, idle 50C / 24 W, fan N/A (passive) |
| Driver | **550.163.01** (CUDA 12.4), installed with the **NVIDIA runfile** (`/usr/bin/nvidia-installer` present), not via apt; no DKMS |
| Driver apt packages | none (only `nvidia-container-toolkit` and `libnvidia-container*`, already on hold) |
| CPU / RAM / swap | 10 cores / 9.5 GiB (about 5 GiB available) / no swap |
| Disk | `/` 125 GB, 31 GB free, ext4 on `sdb1`, `/opt` is on `/` |
| Present tools | git, git-lfs, tmux, rsync, ffmpeg, flock, xz, gcc |
| Missing | blender, godot, nvcc (not needed for Cycles) |
| sudo | passwordless for `safa` |
| sshd | `PermitRootLogin prohibit-password`; `PasswordAuthentication` not set (default yes); the account password the user tried was rejected, key login works |
| unattended-upgrades | not installed |
| Other workloads | `ollama` (systemd, using ~720 MiB VRAM for an embedding model), nginx, docker (containerd), various tarballs in `~` |

## Differences from the plan

1. **Driver is 550, not 580.** The web plan's "580 branch" is wrong for this box. 550.163.01 supports Pascal and CUDA 12.4, which is enough for Blender 4.2 Cycles CUDA. Pin 550.163.01 in `CLAUDE.md`. Do not upgrade.
2. **`apt-mark hold` does not protect this driver.** It was installed by runfile, so there is no package to hold. The real risk is a kernel upgrade: the module is built for 6.1.0-52 with no DKMS, so a new kernel would boot without the GPU driver. Mitigation (done 2026-10-21): kernel packages are on `apt-mark hold`; see `driver-and-kernel-maintenance.md`.
3. **The GPU is shared with ollama.** About 720 MiB VRAM is in use and ollama keeps models loaded (it showed "27 minutes from now" unload time). Cycles scenes get roughly 6.9 GiB, and a big render plus ollama's load could OOM either side. The delegation scripts should log `nvidia-smi` memory before a job.
4. **RAM is 9.5 GiB with no swap** and other services run on it, so Blender memory-heavy scenes may hit the OOM killer. Keep scenes small and cap Blender threads if needed.
5. **31 GB free disk.** Blender (about 0.4 GB) and Godot with templates (about 1.5 GB) fit, but renders and the repo must stay small. `remote_run.sh` should prune old logs.
6. **sudo is passwordless for `safa`.** The plan said "give sudo commands to the user"; keep that as policy anyway, and tell me if you would rather I run `/opt` setup myself.
7. Docker works for root/docker group only (`safa` is not in the `docker` group). Not needed.

## Phase 2 results (2026-10-21)

Installed over SSH as `safa` (sudo used only to create and chown `/opt/blender` and `/opt/godot`); no driver, kernel or apt changes.

| Item | Result |
|---|---|
| Blender | 4.2.23 LTS in `/opt/blender`, symlink `~/bin/blender`; tarball sha256 verified; no missing shared libraries, so the extra apt libs were not needed |
| Godot | 4.7.2-stable (`4.7.2.stable.official.ed1daf0bf`) in `/opt/godot` (`/opt/godot/godot`), sha512 verified; export templates in `~/.local/share/godot/export_templates/4.7.2.stable/` (Linux and Windows included) |
| Laptop Godot | same version, `~/.local/bin/godot` (`~/.local/opt/godot-4.7.2`) |
| Downloads | still in `~/work/dl` on the server (about 1.6 GB); delete when you approve |
| Cycles devices | `Tesla P4` CUDA, `Tesla P4` OPTIX, and the CPU. **Enable only the CUDA entry**; OptiX needs RTX hardware. |
| Load test | 1080p, 30000 samples, adaptive sampling off: GPU 99%, 46 W, 1475 MiB used, no throttling. Temperature rose 53C to 67C and levelled off over about 3 minutes; back to 63C idle after. Well under the 80C limit |

Notes for the scripts:
- Cycles adaptive sampling ends trivial scenes in seconds, so benchmarks need it off.
- Never use `pkill -f` on the server with a pattern that also appears in the SSH command line; it kills the session. Use `pgrep -x` / `pkill -x blender`.
- `~/bin` is not on the PATH for non-interactive SSH; scripts must call `/opt/blender/blender` and `/opt/godot/godot` by absolute path.
