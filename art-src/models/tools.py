"""Hand tools and fitting parts for the install view of Off the Books, plus one icon per item.

Each item is a root Empty `T_<id>` whose origin is where a hand grips it; the handle runs along Z with
the working end up (+Z) or forward (-Y). Icons: `tools_icon_<id>.png` (transparent, 160 px, Cycles),
shown in the equipment tray. The ids match `Install.EQUIPMENT` in godot-house/scripts/install.gd.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import common
from common import *

reset()

YELLOW = mat("ToolYellow", "#E8B321", roughness=0.4)
BLACK = mat("ToolBlack", "#202124", roughness=0.55)
GRIP = mat("Grip", "#2E3A2F", roughness=0.85)
RED = mat("ToolRed", "#C2382B", roughness=0.4)
BLUE = mat("ToolBlue", "#2F67B1", roughness=0.4)
STEEL = mat("Steel", "#C9CED4", metallic=0.9, roughness=0.25)
WOOD = mat("Handle", "#C08A55", roughness=0.6)
RUBBER = mat("Rubber", "#3A3C40", roughness=0.9)
WHITE = mat("Bucket", "#F0EEE8", roughness=0.5)
MUD = mat("Mud", "#E9E6DD", roughness=0.95)
TAPE = mat("PaperTape", "#EDE3C8", roughness=0.9)
GYPSUM = mat("Gypsum", "#E6E4DE", roughness=0.95)
LAMINATE = mat("Laminate", "#A87A4E", roughness=0.45)
FOAM = mat("Underlay", "#8E9AA0", roughness=0.9)
PLATE = mat("SwitchPlate", "#F4F3EF", roughness=0.3)
BUBBLE = mat("Bubble", "#9FE07A", roughness=0.1, emission="#7FD35A", strength=0.6)
COPPER = mat("Copper", "#C27A4A", metallic=0.9, roughness=0.35)
WALNUT = mat("Walnut", "#6B4A33", roughness=0.5)

items = {}


def item(name):
    root = empty("T_" + name)
    items[name] = root
    return root


r = item("drill")
box("Body", (0.06, 0.24, 0.08), (0, -0.07, 0.14), YELLOW, r, bevel=0.025)
cyl("Grip", 0.026, 0.14, (0, 0, 0.03), GRIP, r, verts=16)
box("Battery", (0.075, 0.11, 0.05), (0, 0.01, -0.06), BLACK, r, bevel=0.015)
cyl("Chuck", 0.022, 0.05, (0, -0.21, 0.15), BLACK, r, verts=16, rot=(math.pi / 2, 0, 0))
cyl("Bit", 0.004, 0.07, (0, -0.27, 0.15), STEEL, r, verts=8, rot=(math.pi / 2, 0, 0))
box("Trigger", (0.016, 0.02, 0.03), (0, -0.03, 0.09), BLACK, r, bevel=0.005)

r = item("hammer")
cyl("Handle", 0.016, 0.3, (0, 0, 0.05), WOOD, r, verts=12)
box("Head", (0.03, 0.13, 0.035), (0, -0.01, 0.21), STEEL, r, bevel=0.008)
cone("Claw", 0.016, 0.006, 0.06, (0, 0.07, 0.215), STEEL, r, verts=8, rot=(-math.pi / 2, 0, 0))

r = item("screwdriver")
cyl("Grip", 0.017, 0.11, (0, 0, 0), RED, r, verts=12)
cyl("Shaft", 0.0045, 0.14, (0, 0, 0.12), STEEL, r, verts=8)
cone("Tip", 0.0045, 0.0015, 0.015, (0, 0, 0.195), STEEL, r, verts=6)

r = item("tape")
cyl("Case", 0.04, 0.035, (0, 0, 0.0), YELLOW, r, verts=24, rot=(math.pi / 2, 0, 0))
box("Belt", (0.026, 0.12, 0.002), (0, -0.09, -0.03), YELLOW, r)
box("Hook", (0.028, 0.004, 0.012), (0, -0.15, -0.025), STEEL, r)
box("Lock", (0.012, 0.02, 0.01), (0, -0.01, 0.042), BLACK, r, bevel=0.003)

r = item("knife")
box("Body", (0.022, 0.13, 0.03), (0, 0, 0), YELLOW, r, bevel=0.009)
box("Blade", (0.003, 0.04, 0.016), (0, -0.08, 0.002), STEEL, r)
box("Slider", (0.01, 0.02, 0.008), (0, 0.0, 0.018), BLACK, r, bevel=0.003)

r = item("level")
box("Bar", (0.03, 0.6, 0.06), (0, -0.2, 0.03), BLUE, r, bevel=0.008)
box("Vial", (0.032, 0.06, 0.018), (0, -0.2, 0.03), BUBBLE, r, bevel=0.006)

r = item("taping")                    # taping knife with a dab of joint compound
cyl("Handle", 0.014, 0.11, (0, 0, 0), BLACK, r, verts=12)
box("Blade", (0.15, 0.003, 0.09), (0, 0, 0.1), STEEL, r, bevel=0.002)
box("Mud", (0.12, 0.006, 0.025), (0, -0.004, 0.13), MUD, r, bevel=0.003)

r = item("mud")
cone("Bucket", 0.12, 0.14, 0.24, (0, 0, 0.12), WHITE, r, verts=28)
cyl("Compound", 0.135, 0.01, (0, 0, 0.235), MUD, r, verts=28)
torus("Bail", 0.13, 0.005, (0, 0, 0.24), STEEL, r, rot=(math.pi / 2, 0, 0), mseg=24, nseg=6)

r = item("mallet")
cyl("Handle", 0.014, 0.26, (0, 0, 0.04), WOOD, r, verts=12)
cyl("Head", 0.04, 0.11, (0, 0, 0.19), RUBBER, r, verts=20, rot=(0, math.pi / 2, 0))

r = item("wrench")
box("Handle", (0.012, 0.03, 0.2), (0, 0, 0.0), STEEL, r, bevel=0.005)
torus("Ring", 0.022, 0.008, (0, 0, 0.12), STEEL, r, rot=(0, math.pi / 2, 0), mseg=20, nseg=6)
box("Jaw", (0.014, 0.05, 0.03), (0, 0, -0.11), STEEL, r, bevel=0.006)

r = item("stripper")
for sx in (-1, 1):
    box("Grip", (0.016, 0.022, 0.11), (sx * 0.014, 0, 0), RED, r, bevel=0.006, rot=(0, sx * 0.08, 0))
box("Jaws", (0.03, 0.012, 0.07), (0, 0, 0.09), STEEL, r, bevel=0.004)

r = item("allen")
box("Long", (0.006, 0.006, 0.1), (0, 0, 0.0), BLACK, r)
box("Short", (0.006, 0.035, 0.006), (0, -0.016, 0.05), BLACK, r)

# fitting parts (shown in the tray; the game places the real piece in the scene)
r = item("sheet")
box("Sheet", (0.24, 0.012, 0.48), (0, 0, 0.0), GYPSUM, r, bevel=0.004)
r = item("planks")
for i in range(3):
    box("Plank", (0.4, 0.07, 0.012), (0.01 * i, 0.0, i * 0.014), LAMINATE, r, bevel=0.003)
r = item("underlay")
cyl("Roll", 0.05, 0.3, (0, 0, 0), FOAM, r, verts=20, rot=(0, math.pi / 2, 0))
r = item("plate")
box("Plate", (0.075, 0.012, 0.12), (0, 0, 0), PLATE, r, bevel=0.005)
for sz in (-1, 1):
    cyl("Socket", 0.02, 0.006, (0, -0.008, sz * 0.03), PLATE, r, verts=16, rot=(math.pi / 2, 0, 0))
r = item("wires")
for i, m in enumerate((COPPER, BLACK, WHITE)):
    cyl("Wire", 0.004, 0.2, (-0.012 + i * 0.012, 0, 0), m, r, verts=8, rot=(0.25 * (i - 1), 0, 0))
r = item("legs")
for i in range(4):
    cone("Leg", 0.02, 0.014, 0.2, (i * 0.05, 0, 0), WALNUT, r, verts=12)

# ---------------------------------------------------------------- export (at the origin) and icons
export_glb(out_path())

scene = bpy.context.scene
common._enable_cuda()
scene.render.engine = "CYCLES"
scene.cycles.device = "GPU"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 160
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.color_mode = "RGBA"
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.8, 0.82, 0.86, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy, sun.color = 3.0, (1.0, 0.95, 0.88)
so = bpy.data.objects.new("Sun", sun)
so.rotation_euler = (math.radians(40), 0, math.radians(-30))
scene.collection.objects.link(so)
cam = bpy.data.cameras.new("Cam")
cam.type = "ORTHO"
co = bpy.data.objects.new("Cam", cam)
scene.collection.objects.link(co)
scene.camera = co
out_dir = os.path.dirname(out_path())


def descendants(o):
    out = [o]
    for c in o.children:
        out += descendants(c)
    return out


for name, root in items.items():
    parts = descendants(root)
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in parts
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in parts:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) / 2
    d = Vector((-0.9, -1.0, 0.7)).normalized()
    co.location = center + d * 5
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = (hi - lo).length * 1.08
    scene.render.filepath = os.path.join(out_dir, f"tools_icon_{name}.png")
    bpy.ops.render.render(write_still=True)
print("TOOLS_DONE")
