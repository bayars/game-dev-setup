"""Hover drone: glossy blue rounded body, glowing cyan eyes, fins and antenna. Bobs and blinks."""
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
add_camera(scene, ortho_scale=2.85, direction=(0, -1, 0.35))

paint = material("DronePaint", (0.03, 0.28, 0.95), metallic=0.35, roughness=0.18, Coat_Weight=1.0)
paint_dark = material("DroneDark", (0.02, 0.10, 0.45), metallic=0.5, roughness=0.3)
glass = material("Visor", (0.01, 0.015, 0.03), metallic=0.0, roughness=0.05, Coat_Weight=1.0)
eye_glow = material("EyeGlow", (0.0, 0.2, 0.25), roughness=0.3, emission=(0.2, 0.95, 1.0), emission_strength=7.0)
tip_glow = material("TipGlow", (0.3, 0.0, 0.2), roughness=0.3, emission=(1.0, 0.2, 0.8), emission_strength=6.0)
pivot = new_pivot(scene)


def box(name, size, loc, mat, bevel_w, seg=5):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.location = loc
    assign(o, mat)
    bevel(o, bevel_w, seg)
    smooth(o)
    return parent_to(o, pivot)


box("Body", (1.45, 1.2, 1.2), (0, 0, 0), paint, 0.26, 6)
box("Visor", (1.12, 0.16, 0.6), (0, -0.58, 0.1), glass, 0.09, 4)
eye_l = box("EyeL", (0.24, 0.05, 0.3), (-0.27, -0.67, 0.1), eye_glow, 0.05, 3)
eye_r = box("EyeR", (0.24, 0.05, 0.3), (0.27, -0.67, 0.1), eye_glow, 0.05, 3)
box("FinL", (0.28, 0.6, 0.42), (-0.86, 0.0, -0.12), paint_dark, 0.08, 4)
box("FinR", (0.28, 0.6, 0.42), (0.86, 0.0, -0.12), paint_dark, 0.08, 4)
box("Belly", (1.0, 0.9, 0.2), (0, 0, -0.62), paint_dark, 0.06, 3)

bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.035, depth=0.4)
ant = assign(bpy.context.active_object, paint_dark)
ant.location = (0.35, 0.1, 0.78)
parent_to(ant, pivot)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.09)
ant_tip = assign(bpy.context.active_object, tip_glow)
ant_tip.location = (0.35, 0.1, 1.0)
parent_to(ant_tip, pivot)


def pose(t):
    a = t * 2 * math.pi
    pivot.location = (0, 0, 0.07 * math.sin(a))
    pivot.rotation_euler = (0.04 * math.sin(a + 1.0), 0, 0.05 * math.sin(a))
    blink = 0.15 if int(round(t * 8)) == 5 else 1.0  # one dim frame per loop
    eye_l.scale[2] = eye_r.scale[2] = 0.3 * blink
    set_emission(eye_glow, 7.0 + 2.0 * math.sin(a))
    set_emission(tip_glow, 5.0 + 3.0 * math.sin(a * 2))


render_cycle(scene, args.out, pose)
