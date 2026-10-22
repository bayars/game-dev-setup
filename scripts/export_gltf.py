"""Run inside Blender: export the open .blend to a binary glTF (.glb) for Godot.

Usage: blender -b file.blend --python export_gltf.py -- /path/out.glb
"""
import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.export_scene.gltf(
    filepath=out,
    export_format="GLB",
    export_apply=True,        # apply modifiers
    export_yup=True,          # Godot is Y-up
    export_cameras=False,
    export_lights=False,
)
print("EXPORTED", out)
