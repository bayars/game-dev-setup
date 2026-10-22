"""Run inside Blender: render a frame range with Cycles on the CUDA device only.

Exits non-zero if no CUDA device is found (no silent CPU fallback).
Usage: blender -b file.blend --python blender_render.py -- --start 1 --end 1 --out /path/frame_
"""
import argparse
import sys

import bpy


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--start", type=int, required=True)
    p.add_argument("--end", type=int, required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--samples", type=int)
    p.add_argument("--res-percent", type=int)
    return p.parse_args(argv)


def enable_cuda_only():
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    cuda = [d for d in prefs.devices if d.type == "CUDA"]
    print("DEVICES", [(d.name, d.type) for d in prefs.devices])
    if not cuda:
        print("ERROR: no CUDA device visible to Cycles; not falling back to CPU", file=sys.stderr)
        sys.exit(3)
    for d in prefs.devices:
        d.use = d.type == "CUDA"  # also disables CPU and the (unusable) OPTIX entry
    return cuda


def main():
    a = parse_args()
    cuda = enable_cuda_only()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"
    if a.samples:
        scene.cycles.samples = a.samples
    if a.res_percent:
        scene.render.resolution_percentage = a.res_percent
    scene.frame_start, scene.frame_end = a.start, a.end
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = a.out
    print(f"RENDER device={cuda[0].name} frames={a.start}-{a.end} samples={scene.cycles.samples} "
          f"res={scene.render.resolution_x}x{scene.render.resolution_y}@{scene.render.resolution_percentage}%")
    bpy.ops.render.render(animation=True)
    print("RENDER_DONE")


main()
