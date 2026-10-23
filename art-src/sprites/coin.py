"""Spinning gold coin, 8-frame loop (a 180-degree turn: the coin is symmetric front/back)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from common import *

args = parse_args()
scene = reset_scene()
setup_render(scene, args.size, args.size, args.samples)
standard_lighting(scene)
add_camera(scene, ortho_scale=2.75, direction=(0, -1, 0.3))

gold = material("Gold", (1.0, 0.70, 0.12), metallic=1.0, roughness=0.2)
gold_deep = material("GoldDeep", (0.75, 0.38, 0.05), metallic=1.0, roughness=0.38)
pivot = new_pivot(scene)

bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.0, depth=0.22)
disc = bevel(assign(bpy.context.active_object, gold), 0.05, 4)
disc.rotation_euler = (math.pi / 2, 0, 0)  # axis along Y: faces the camera
smooth(disc)
parent_to(disc, pivot)

# star outline, built as one n-gon (10 points) and thickened with a solidify modifier
verts, pts = [], 5
for i in range(pts * 2):
    r = 0.50 if i % 2 == 0 else 0.22
    a = math.pi / 2 + i * math.pi / pts
    verts.append((r * math.cos(a), r * math.sin(a), 0.0))
star_mesh = bpy.data.meshes.new("Star")
star_mesh.from_pydata(verts, [], [list(range(len(verts)))])
star_mesh.update()

for side in (-1, 1):  # -1 = face toward the camera, +1 = back
    y = side * 0.11
    bpy.ops.mesh.primitive_torus_add(major_radius=0.80, minor_radius=0.055, major_segments=64, minor_segments=16)
    rim = assign(bpy.context.active_object, gold)
    rim.rotation_euler = (math.pi / 2, 0, 0)
    rim.location = (0, y, 0)
    smooth(rim)
    parent_to(rim, pivot)

    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.025, major_segments=64, minor_segments=12)
    groove = assign(bpy.context.active_object, gold_deep)
    groove.rotation_euler = (math.pi / 2, 0, 0)
    groove.location = (0, y * 1.02, 0)
    smooth(groove)
    parent_to(groove, pivot)

    star = bpy.data.objects.new("StarObj", star_mesh.copy())
    scene.collection.objects.link(star)
    assign(star, gold)
    m = star.modifiers.new("Solid", "SOLIDIFY")
    m.thickness = 0.07
    star.rotation_euler = (math.pi / 2, 0, 0)
    star.location = (0, y + side * 0.01, 0)
    parent_to(star, pivot)


def pose(t):
    pivot.rotation_euler = (0, 0, t * math.pi)


render_cycle(scene, args.out, pose)
