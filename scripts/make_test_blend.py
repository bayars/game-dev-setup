"""Run inside Blender 4.2: build the smoke-test scene (cube, floor, light, camera).

Usage: blender -b --factory-startup --python make_test_blend.py -- /path/test.blend
Kept small and cheap so a smoke render takes seconds.
"""
import os
import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(os.path.dirname(out), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = False
scene.render.resolution_x, scene.render.resolution_y = 512, 512
scene.frame_start = scene.frame_end = 1

bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
bpy.ops.mesh.primitive_cube_add(size=1.5, location=(0, 0, 0.75), rotation=(0, 0, 0.6))
cube = bpy.context.active_object
mat = bpy.data.materials.new("CubeMat")
mat.diffuse_color = (0.8, 0.2, 0.1, 1.0)
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.8, 0.2, 0.1, 1.0)
cube.data.materials.append(mat)

bpy.ops.object.light_add(type="AREA", location=(3, -3, 5))
light = bpy.context.active_object
light.data.energy = 600
light.data.size = 3
light.rotation_euler = (0.9, 0.3, 0.8)

bpy.ops.object.camera_add(location=(5, -5, 3.5), rotation=(1.1, 0, 0.785))
scene.camera = bpy.context.active_object

bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED", out)
