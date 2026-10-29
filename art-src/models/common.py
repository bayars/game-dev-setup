"""Shared helpers for the 3D model scripts. Runs inside Blender 4.2 (server), never on the laptop.

Each model script: `blender -b --factory-startup --python <name>.py -- <out.glb>`
It builds its scene with the helpers below, then calls finish(path): exports glTF for Godot and renders
a Cycles preview PNG next to it (<out>_preview.png) so the design can be checked by eye.

Conventions: meters, Blender Z up, model front faces -Y (-> +Z in glTF/Godot). Parts are parented to
Empties whose origin is the joint (ArmL, LegL, DoorHinge ...) so Godot can rotate them.
"""
import math
import os
import sys

import bpy
from mathutils import Vector


def out_path():
    return sys.argv[sys.argv.index("--") + 1]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def srgb(hexstr):
    """'#RRGGBB' -> linear RGB tuple (Blender stores linear)."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


_mats = {}


def mat(name, hexcolor, metallic=0.0, roughness=0.65, emission=None, strength=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexcolor), 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = roughness
    if emission:
        b.inputs["Emission Color"].default_value = (*srgb(emission), 1)
        b.inputs["Emission Strength"].default_value = strength
    _mats[name] = m
    return m


def _place(obj, name, material, parent, loc, rot):
    obj.name = name
    if material is not None:
        obj.data.materials.append(material)
    obj.location = loc
    obj.rotation_euler = rot
    if parent is not None:
        obj.parent = parent
    return obj


def _apply_scale(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def _smooth(obj, angle=math.radians(40)):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth_by_angle(angle=angle)


def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if parent is not None:
        o.parent = parent
    return o


def box(name, size, loc, material, parent=None, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = size
    _apply_scale(o)
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width, m.segments, m.limit_method = bevel, 3, "ANGLE"
        _smooth(o)
    return _place(o, name, material, parent, loc, rot)


def cyl(name, radius, height, loc, material, parent=None, verts=24, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height)
    o = bpy.context.active_object
    _smooth(o)
    return _place(o, name, material, parent, loc, rot)


def cone(name, r1, r2, height, loc, material, parent=None, verts=24, rot=(0, 0, 0), flat=False):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=height)
    o = bpy.context.active_object
    if not flat:
        _smooth(o)
    return _place(o, name, material, parent, loc, rot)


def sphere(name, radius, loc, material, parent=None, scale=(1, 1, 1), seg=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=radius)
    o = bpy.context.active_object
    o.scale = scale
    _apply_scale(o)
    _smooth(o)
    return _place(o, name, material, parent, loc, (0, 0, 0))


def torus(name, major, minor, loc, material, parent=None, rot=(0, 0, 0), scale=(1, 1, 1), mseg=32, nseg=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=mseg, minor_segments=nseg)
    o = bpy.context.active_object
    o.scale = scale
    _apply_scale(o)
    _smooth(o, math.radians(60))
    return _place(o, name, material, parent, loc, rot)


def ico(name, radius, loc, material, parent=None, subdiv=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius)
    o = bpy.context.active_object
    o.scale = scale
    _apply_scale(o)
    return _place(o, name, material, parent, loc, (0, 0, 0))


def polygon(name, verts, material, parent=None, thickness=0.2, loc=(0, 0, 0)):
    """One n-gon from `verts` (x, y, z), thickened with a solidify modifier."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [list(range(len(verts)))])
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    m = o.modifiers.new("Solid", "SOLIDIFY")
    m.thickness, m.offset = thickness, 1
    return _place(o, name, material, parent, loc, (0, 0, 0))


def _bounds():
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.name.endswith("-convcolonly"):
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def cpu_only():
    """CYCLES_CPU=1 (models.sh --cpu): render on the server's CPU when the shared P4 has no memory free."""
    return os.environ.get("CYCLES_CPU", "") == "1"


def device():
    return "CPU" if cpu_only() else "GPU"


def _enable_cuda():
    if cpu_only():
        print("Cycles on the CPU (CYCLES_CPU=1)")
        return
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    if not [d for d in prefs.devices if d.type == "CUDA"]:
        print("ERROR: no CUDA device visible to Cycles; not falling back to CPU", file=sys.stderr)
        sys.exit(3)
    for d in prefs.devices:
        d.use = d.type == "CUDA"


def preview(png_path, direction=(-0.7, -1.0, 0.55), size=640, margin=1.25):
    """Cycles preview of the whole scene (not part of the game assets)."""
    scene = bpy.context.scene
    for o in scene.objects:
        if o.name.endswith("-convcolonly"):
            o.hide_render = True  # collision helpers: part of the glTF, not of the picture
    _enable_cuda()
    scene.render.engine = "CYCLES"
    scene.cycles.device = device()
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    lo, hi = _bounds()
    center = (lo + hi) / 2
    extent = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.35, 0.42, 0.55, 1)
    bg.inputs["Strength"].default_value = 0.9
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy, sun.color = 3.5, (1.0, 0.9, 0.75)
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun_obj)
    cam = bpy.data.cameras.new("Cam")
    cam.type, cam.ortho_scale, cam.clip_end = "ORTHO", extent * margin, 200
    cam_obj = bpy.data.objects.new("Cam", cam)
    d = Vector(direction).normalized()
    cam_obj.location = center + d * 60
    cam_obj.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    scene.render.filepath = png_path
    bpy.ops.render.render(write_still=True)


def export_glb(path, **extra):
    """glTF export for Godot (meshes, materials, skeleton and every action that has a fake user)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False, **extra)
    print("EXPORTED", path)


def finish(path, **preview_kwargs):
    export_glb(path)
    preview(path[:-4] + "_preview.png", **preview_kwargs)
