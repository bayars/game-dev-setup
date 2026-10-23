"""Shared helpers for the sprite scripts. Runs inside Blender 4.2 (server), never on the laptop.

Each sprite script: `blender -b --factory-startup --python <name>.py -- <out_dir> [--size N] [--samples N]`
Frames are written to <out_dir>/frame_NN.png; scripts/sprites.sh tiles them into a sheet.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

FRAMES = 8


def parse_args(default_size=64, default_samples=128):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("out")
    p.add_argument("--size", type=int, default=default_size)
    p.add_argument("--samples", type=int, default=default_samples)
    return p.parse_args(argv)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def enable_cuda_only():
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    if not [d for d in prefs.devices if d.type == "CUDA"]:
        print("ERROR: no CUDA device visible to Cycles; not falling back to CPU", file=sys.stderr)
        sys.exit(3)
    for d in prefs.devices:
        d.use = d.type == "CUDA"


def setup_render(scene, width, height, samples, transparent=True, denoise=True):
    enable_cuda_only()
    r = scene.render
    r.engine = "CYCLES"
    scene.cycles.device = "GPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = denoise
    if denoise:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    r.film_transparent = transparent
    r.resolution_x, r.resolution_y, r.resolution_percentage = width, height, 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"


def add_camera(scene, ortho_scale, direction=(0, -1, 0.35), distance=12.0):
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    data.clip_end = 100
    cam = bpy.data.objects.new("Cam", data)
    scene.collection.objects.link(cam)
    d = Vector(direction).normalized()
    cam.location = d * distance
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    return cam


def add_area_light(scene, name, location, energy, color=(1, 1, 1), size=3.0):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.size = energy, color, size
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = (-Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)
    return obj


def studio_world(scene, top=(0.30, 0.42, 0.70), bottom=(0.015, 0.015, 0.035)):
    """Vertical gradient world: gives metals and gloss something to reflect."""
    w = bpy.data.worlds.new("World")
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    norm = nt.nodes.new("ShaderNodeVectorMath")
    norm.operation = "NORMALIZE"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mad = nt.nodes.new("ShaderNodeMath")
    mad.operation = "MULTIPLY_ADD"
    mad.inputs[1].default_value = 0.5
    mad.inputs[2].default_value = 0.5
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*bottom, 1)
    ramp.color_ramp.elements[1].color = (*top, 1)
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(coord.outputs["Object"], norm.inputs[0])
    nt.links.new(norm.outputs[0], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mad.inputs[0])
    nt.links.new(mad.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs[0], out.inputs[0])


def standard_lighting(scene):
    studio_world(scene)
    add_area_light(scene, "Key", (-4, -5, 6), 700, (1.0, 0.95, 0.88), 4)
    add_area_light(scene, "Rim", (5, 4, 3), 500, (0.45, 0.8, 1.0), 3)
    add_area_light(scene, "Fill", (4, -4, -1), 160, (0.8, 0.55, 1.0), 4)


def material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0, **extra):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = roughness
    if emission is not None:
        b.inputs["Emission Color"].default_value = (*emission, 1)
        b.inputs["Emission Strength"].default_value = emission_strength
    for key, value in extra.items():
        b.inputs[key.replace("_", " ")].default_value = value
    return m


def set_emission(mat, strength):
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = strength


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def smooth(obj, angle=math.radians(35)):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth_by_angle(angle=angle)


def bevel(obj, width, segments=4):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width, m.segments = width, segments
    m.limit_method = "ANGLE"
    return obj


def parent_to(obj, parent):
    obj.parent = parent
    return obj


def new_pivot(scene, name="Pivot"):
    p = bpy.data.objects.new(name, None)
    scene.collection.objects.link(p)
    return p


def render_cycle(scene, out_dir, setter, frames=FRAMES):
    """Render `frames` frames; setter(t) poses the scene for t in [0, 1)."""
    os.makedirs(out_dir, exist_ok=True)
    for i in range(frames):
        setter(i / frames)
        bpy.context.view_layer.update()
        scene.render.filepath = os.path.join(out_dir, f"frame_{i:02d}.png")
        bpy.ops.render.render(write_still=True)
    print("FRAMES_DONE", out_dir)
