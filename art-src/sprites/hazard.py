"""Spiked mine: dark metal body, hot red eye and spike tips. Rolls in the image plane, glow pulses."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from common import *
from mathutils import Vector

args = parse_args()
scene = reset_scene()
setup_render(scene, args.size, args.size, args.samples)
standard_lighting(scene)
add_camera(scene, ortho_scale=2.95, direction=(0, -1, 0.15))

metal = material("MineMetal", (0.07, 0.075, 0.085), metallic=1.0, roughness=0.3)
plate = material("MinePlate", (0.16, 0.17, 0.20), metallic=1.0, roughness=0.45)
glow = material("MineGlow", (0.2, 0.02, 0.01), roughness=0.4, emission=(1.0, 0.12, 0.05), emission_strength=5.0)
pivot = new_pivot(scene)  # rolls around the camera axis (Y)

R = 0.66
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=R)
body = assign(bpy.context.active_object, metal)
smooth(body)
parent_to(body, pivot)

# 12 spikes on the icosahedron's vertices, glowing tips
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
dirs = [v.co.normalized() for v in bpy.context.active_object.data.vertices]
bpy.data.objects.remove(bpy.context.active_object)
for d in dirs:
    quat = Vector((0, 0, 1)).rotation_difference(d)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.17, radius2=0.03, depth=0.55)
    spike = assign(bpy.context.active_object, plate)
    spike.rotation_mode = "QUATERNION"
    spike.rotation_quaternion = quat
    spike.location = d * (R + 0.22)
    smooth(spike)
    parent_to(spike, pivot)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.075)
    tip = assign(bpy.context.active_object, glow)
    tip.location = d * (R + 0.52)
    parent_to(tip, pivot)

# belt ring and the eye that always faces the camera
bpy.ops.mesh.primitive_torus_add(major_radius=R * 0.98, minor_radius=0.045, major_segments=64, minor_segments=12)
belt = assign(bpy.context.active_object, plate)
belt.rotation_euler = (math.pi / 2, 0, 0)
parent_to(belt, pivot)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.23)
eye = assign(bpy.context.active_object, glow)
eye.location = (0, -R * 0.93, 0)
eye.scale = (1, 0.45, 1)
parent_to(eye, pivot)


def pose(t):
    pivot.rotation_euler = (0, -t * 2 * math.pi, 0)
    set_emission(glow, 5.0 + 4.0 * math.sin(t * 2 * math.pi))


render_cycle(scene, args.out, pose)
