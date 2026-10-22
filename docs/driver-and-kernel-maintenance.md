# Driver and kernel maintenance (gpubox)

Reference for a future, deliberate update. **Default policy: do not update the NVIDIA driver or the kernel.** Claude Code must not do either; it asks the user.

## Why this is frozen

- GPU: Tesla P4 (Pascal). Driver **550.163.01** (CUDA 12.4), installed with the NVIDIA **runfile**, not apt.
- There is **no DKMS**. The kernel module was built for kernel **6.1.0-52-amd64**. Booting any other kernel loads no NVIDIA module, and the GPU disappears until the driver is rebuilt.
- The box is shared (ollama, nginx, docker), so a broken GPU also breaks other services.
- Pascal support ends at the 580 branch; newer branches (590+) drop it. Never jump past 580.

## Current protection (set 2026-10-21)

`apt-mark hold` on:
`linux-image-amd64 linux-headers-amd64 linux-image-6.1.0-52-amd64 linux-headers-6.1.0-52-amd64 linux-headers-6.1.0-52-common linux-kbuild-6.1`
(plus the pre-existing holds on `nvidia-container-toolkit*` and `libnvidia-container*`).

Check any time: `apt-mark showhold`. Preview what an upgrade would do: `sudo apt-get -s dist-upgrade`. Kernel or NVIDIA lines mean a hold was lost.

Side effect: security fixes to the kernel are not applied while held. Acceptable on a LAN box; revisit if it is ever exposed.

## How to update later (user-driven, with a console or IPMI/keyboard available in case of a failed boot)

1. **Decide why.** A new Blender or Godot needing newer CUDA, a kernel security fix, or a reinstall. If nothing forces it, skip.
2. **Back up and note state:** `nvidia-smi`, `uname -r`, `apt-mark showhold`, `ls /boot`, copy the runfile (`NVIDIA-Linux-x86_64-<ver>.run`) somewhere safe. Keep the old kernel in `/boot` (it is not removed).
3. **Stop GPU users:** `sudo systemctl stop ollama`, make sure no render job is running (`/tmp/gpu.lock`).
4. **Kernel only:** `sudo apt-mark unhold <the packages above>`, `sudo apt update && sudo apt install linux-image-amd64 linux-headers-amd64`, then **before rebooting** reinstall the driver for the new kernel (step 5).
5. **Driver build for the new kernel:** install `linux-headers-<new>`, then run the same runfile with `sudo sh NVIDIA-Linux-x86_64-550.163.01.run --kernel-name=<new-kernel-release>` (or rerun normally after booting the new kernel). Prefer installing `dkms` first and passing `--dkms` so future kernels rebuild automatically.
6. **Reboot, verify:** `nvidia-smi`, `cat /proc/driver/nvidia/version`, then run the Blender CUDA check and a test render from the pipeline.
7. **Re-hold** the new kernel packages and update this document and `CLAUDE.md` (driver and kernel versions).
8. **Rollback:** pick the previous kernel in GRUB (`6.1.0-52-amd64` stays installed); if the driver is the problem, rerun the old runfile.

## Driver upgrade (staying on Pascal-supported branches)

- Allowed range: 550.x to 580.x only. Use the Pascal-supported release from NVIDIA's archive, runfile install as above.
- Never install `nvidia-driver` from Debian apt on top of the runfile install; the two conflict.
- After upgrade re-verify Blender (CUDA device list shows the P4) and ffmpeg NVENC.

## Claude Code rules

- Never run `apt upgrade`, `apt full-upgrade`, `apt-mark unhold`, the NVIDIA installer, or reboot the server without an explicit user request in the same conversation.
- If a job fails with "no CUDA device" or `nvidia-smi` errors, check `uname -r` against `6.1.0-52-amd64` and report; do not attempt a fix.

## Change log

| Date | Change |
|---|---|
| 2026-10-21 | Baseline audit; kernel packages put on hold; document created |
