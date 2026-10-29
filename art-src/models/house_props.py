"""Furniture, fittings and job-site props for Off the Books, all with rounded (bevelled) edges.

Each prop is a root Empty named `P_<Name>` with its origin on the floor at the centre of its footprint and
its front facing -Y (+Z in Godot). The game instantiates props by name (house.gd `prop()`), so the grid
layout here only matters for the preview picture. Sizes are real-world metres.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector

from common import *

reset()

FABRIC = mat("Fabric", "#5B6C8E", roughness=0.95)
FABRIC_DK = mat("FabricDark", "#46546F", roughness=0.95)
CUSHION = mat("Cushion", "#6E80A4", roughness=0.95)
OAK = mat("Oak", "#B48A5C", roughness=0.55)
WALNUT = mat("Walnut", "#6B4A33", roughness=0.5)
PINE = mat("Pine", "#D7B98A", roughness=0.7)
CARD = mat("Cardboard", "#B08D60", roughness=0.9)
CARD_DK = mat("CardboardEdge", "#977650", roughness=0.9)
TAPE = mat("PackTape", "#C9A56E", roughness=0.35)
LABEL = mat("Label", "#EDE9E0", roughness=0.8)
STEEL = mat("Steel", "#C6CBD1", metallic=0.8, roughness=0.3)
DARK = mat("DarkPlastic", "#2B2D31", roughness=0.5)
WHITE = mat("Enamel", "#F1F0EC", roughness=0.25)
PORCELAIN = mat("Porcelain", "#F6F7F8", roughness=0.15)
COUNTER = mat("Cabinet", "#E3DED3", roughness=0.5)
STONE_TOP = mat("Worktop", "#4D4B48", roughness=0.35)
GYPSUM = mat("Gypsum", "#E6E4DE", roughness=0.95)
PAPER = mat("GypsumPaper", "#D9D2C2", roughness=0.95)
LAMINATE = mat("Laminate", "#A87A4E", roughness=0.45)
FOAM = mat("Underlay", "#8E9AA0", roughness=0.9)
VAN = mat("VanPaint", "#D9DAD6", metallic=0.3, roughness=0.3)
GLASS = mat("Glass", "#1E2630", metallic=0.2, roughness=0.08)
TYRE = mat("Tyre", "#1A1A1C", roughness=0.85)
RIM = mat("Rim", "#9DA3AA", metallic=0.8, roughness=0.3)
LIGHT = mat("Headlight", "#FFF6E0", roughness=0.1, emission="#FFF2D0", strength=1.5)
RUST = mat("Toolbag", "#8A3B22", roughness=0.85)
BLANKET = mat("Blanket", "#9C6B5A", roughness=0.95)
SHEET = mat("BedSheet", "#ECE8E0", roughness=0.9)
RED = mat("Accent", "#B0432F", roughness=0.6)
PLATE = mat("SwitchPlate", "#F4F3EF", roughness=0.3)
COPPER = mat("Copper", "#C27A4A", metallic=0.9, roughness=0.35)

_props = []


def prop(name):
    """Start a prop: a root Empty placed on the preview grid."""
    i = len(_props)
    root = empty("P_" + name, loc=((i % 7) * 3.2, (i // 7) * 3.4, 0))
    _props.append(root)
    return root


def legs(root, w, d, h, r, material, inset=0.06, taper=0.8):
    for sx in (-1, 1):
        for sy in (-1, 1):
            cone("Leg", r, r * taper, h, (sx * (w / 2 - inset), sy * (d / 2 - inset), h / 2), material, root, verts=16)


# ---------------------------------------------------------------- living room / kitchen
r = prop("Couch")
box("Base", (2.0, 0.88, 0.26), (0, 0.02, 0.27), FABRIC_DK, r, bevel=0.06)
for i in range(3):
    box("Seat", (0.6, 0.66, 0.15), (-0.62 + i * 0.62, -0.07, 0.47), CUSHION, r, bevel=0.06)
    box("BackCushion", (0.6, 0.18, 0.42), (-0.62 + i * 0.62, 0.27, 0.68), CUSHION, r, bevel=0.07, rot=(-0.18, 0, 0))
box("Back", (2.0, 0.2, 0.62), (0, 0.36, 0.55), FABRIC, r, bevel=0.08)
for sx in (-1, 1):
    box("Arm", (0.18, 0.86, 0.58), (sx * 0.98, 0.02, 0.43), FABRIC, r, bevel=0.08)
legs(r, 1.9, 0.78, 0.14, 0.025, WALNUT)

r = prop("CouchLegless")              # the couch out of its box, before the legs are on
box("Base", (2.0, 0.88, 0.26), (0, 0.02, 0.13), FABRIC_DK, r, bevel=0.06)
for i in range(3):
    box("Seat", (0.6, 0.66, 0.15), (-0.62 + i * 0.62, -0.07, 0.33), CUSHION, r, bevel=0.06)
box("Back", (2.0, 0.2, 0.62), (0, 0.36, 0.41), FABRIC, r, bevel=0.08)
for sx in (-1, 1):
    box("Arm", (0.18, 0.86, 0.58), (sx * 0.98, 0.02, 0.29), FABRIC, r, bevel=0.08)

r = prop("CouchBox")
box("Box", (2.1, 0.95, 0.8), (0, 0, 0.4), CARD, r, bevel=0.035)
box("Tape", (2.12, 0.08, 0.81), (0, 0, 0.4), TAPE, r, bevel=0.01)
box("Label", (0.4, 0.01, 0.25), (0.6, -0.476, 0.45), LABEL, r)
box("Arrow", (0.08, 0.01, 0.18), (-0.7, -0.476, 0.5), CARD_DK, r)

r = prop("Table")
box("Top", (1.1, 0.6, 0.045), (0, 0, 0.43), OAK, r, bevel=0.02)
box("Shelf", (0.95, 0.45, 0.025), (0, 0, 0.14), OAK, r, bevel=0.01)
legs(r, 1.1, 0.6, 0.41, 0.026, WALNUT, inset=0.08, taper=0.7)

r = prop("TableTop")                  # flat-pack table top waiting for its legs
box("Top", (1.1, 0.6, 0.045), (0, 0, 0.03), OAK, r, bevel=0.02)

r = prop("Leg")                       # one loose leg (couch or table), lying down
cone("Leg", 0.026, 0.018, 0.41, (0, 0, 0.026), WALNUT, r, verts=16, rot=(0, math.pi / 2, 0))

r = prop("Dishwasher")
box("Body", (0.6, 0.58, 0.82), (0, 0.01, 0.43), STEEL, r, bevel=0.02)
box("Door", (0.58, 0.03, 0.66), (0, -0.285, 0.39), STEEL, r, bevel=0.015)
box("Panel", (0.58, 0.035, 0.1), (0, -0.287, 0.78), DARK, r, bevel=0.012)
cyl("Handle", 0.012, 0.4, (0, -0.32, 0.68), STEEL, r, verts=12, rot=(0, math.pi / 2, 0))
box("Plinth", (0.56, 0.5, 0.08), (0, 0.03, 0.04), DARK, r, bevel=0.01)
for i in range(3):
    sphere("Led", 0.008, (0.15 + i * 0.03, -0.306, 0.78), LIGHT, r, seg=8, rings=6)

r = prop("DishwasherBox")
box("Box", (0.66, 0.66, 0.88), (0, 0, 0.44), CARD, r, bevel=0.03)
box("Tape", (0.67, 0.07, 0.885), (0, 0, 0.44), TAPE, r, bevel=0.01)
box("Label", (0.3, 0.01, 0.2), (0, -0.331, 0.55), LABEL, r)

r = prop("Fridge")
box("Body", (0.72, 0.68, 1.88), (0, 0, 0.95), WHITE, r, bevel=0.05)
box("Gap", (0.7, 0.012, 0.012), (0, -0.341, 1.25), DARK, r)
for z, hgt in ((1.6, 0.5), (0.75, 0.6)):
    cyl("Handle", 0.014, hgt, (-0.28, -0.37, z), STEEL, r, verts=12)

for name, width in (("Counter", 3.6), ("CounterShort", 1.0)):
    r = prop(name)
    box("Carcass", (width, 0.58, 0.82), (0, 0.02, 0.45), COUNTER, r, bevel=0.015)
    box("Kick", (width - 0.04, 0.5, 0.1), (0, 0.06, 0.05), DARK, r, bevel=0.01)
    box("Top", (width + 0.02, 0.64, 0.04), (0, 0, 0.88), STONE_TOP, r, bevel=0.015)
    doors = max(1, round(width / 0.6))
    dw = width / doors
    for i in range(doors):
        x = -width / 2 + dw * (i + 0.5)
        box("Door", (dw - 0.02, 0.02, 0.68), (x, -0.275, 0.46), COUNTER, r, bevel=0.012)
        cyl("Pull", 0.009, 0.12, (x + dw * 0.32, -0.295, 0.68), STEEL, r, verts=10)
    if width > 2:
        box("Sink", (0.7, 0.42, 0.03), (-0.6, -0.01, 0.9), STEEL, r, bevel=0.06)
        cyl("Tap", 0.016, 0.3, (-0.6, 0.22, 1.03), STEEL, r, verts=12)
        torus("Spout", 0.09, 0.014, (-0.6, 0.13, 1.18), STEEL, r, rot=(math.pi / 2, 0, math.pi / 2), mseg=24, nseg=8)

r = prop("ToolBag")
box("Bag", (0.5, 0.28, 0.3), (0, 0, 0.15), RUST, r, bevel=0.06)
torus("Handle", 0.13, 0.016, (0, 0, 0.32), DARK, r, rot=(math.pi / 2, 0, 0), mseg=24, nseg=8)
box("Strip", (0.51, 0.29, 0.03), (0, 0, 0.24), DARK, r, bevel=0.01)

# ---------------------------------------------------------------- job site
r = prop("Stud")                      # 45 x 90 mm, 2.6 m, standing
box("Stud", (0.045, 0.09, 2.6), (0, 0, 1.3), PINE, r, bevel=0.006)

r = prop("Plate")                     # bottom/top plate, 1 m long along X (scaled in Godot)
box("Plate", (1.0, 0.09, 0.045), (0, 0, 0.0225), PINE, r, bevel=0.006)

r = prop("DrywallSheet")              # 1.2 x 2.4 m, 12.5 mm; front face -Y, standing
box("Core", (1.2, 0.0125, 2.4), (0, 0, 1.2), GYPSUM, r, bevel=0.004)
box("Back", (1.19, 0.002, 2.39), (0, 0.0066, 1.2), PAPER, r)

r = prop("DrywallStack")
for i in range(8):
    box("Sheet", (2.44, 1.22, 0.07), (0.01 * (i % 3), 0.008 * (i % 2), 0.035 + i * 0.072), GYPSUM, r, bevel=0.012)
box("Pallet", (2.3, 1.1, 0.06), (0, 0, -0.03), PINE, r, bevel=0.01)

r = prop("Plank")                     # laminate plank 1.2 m x 0.19 m, lying
box("Plank", (1.2, 0.19, 0.01), (0, 0, 0.005), LAMINATE, r, bevel=0.003)

r = prop("PlankStack")
for i in range(6):
    box("Plank", (1.2, 0.19, 0.01), (0.02 * (i % 2), 0.2 * (i % 2), 0.005 + i * 0.011), LAMINATE, r, bevel=0.003)
box("Pack", (1.22, 0.4, 0.03), (0, 0.1, 0.08), CARD, r, bevel=0.008)

r = prop("UnderlayRoll")
cyl("Roll", 0.11, 1.0, (0, 0, 0.11), FOAM, r, verts=24, rot=(0, math.pi / 2, 0))

r = prop("Underlay")                  # rolled-out foam, 1 m x 1 m (scaled in Godot)
box("Sheet", (1.0, 1.0, 0.004), (0, 0, 0.002), FOAM, r, bevel=0.001)

r = prop("Outlet")                    # wall plate with a double socket; back face on the wall (+Y)
box("Plate", (0.15, 0.012, 0.085), (0, -0.006, 0), PLATE, r, bevel=0.005)
for sx in (-1, 1):
    cyl("Socket", 0.022, 0.006, (sx * 0.036, -0.013, 0), PLATE, r, verts=20, rot=(math.pi / 2, 0, 0))
    for hx in (-1, 1):
        cyl("Hole", 0.0035, 0.004, (sx * 0.036 + hx * 0.009, -0.016, 0), DARK, r, verts=8, rot=(math.pi / 2, 0, 0))

r = prop("WallBox")                   # empty junction box with three wires hanging out
box("Box", (0.07, 0.04, 0.07), (0, -0.02, 0), DARK, r, bevel=0.006)
for i, c in enumerate((COPPER, DARK, WHITE)):
    cyl("Wire", 0.003, 0.09, (-0.015 + i * 0.015, -0.045, -0.02), c, r, verts=6, rot=(0.6, 0, 0))

# ---------------------------------------------------------------- other rooms
r = prop("Bed")
box("Frame", (1.05, 2.05, 0.28), (0, 0, 0.2), WALNUT, r, bevel=0.04)
box("Mattress", (0.98, 1.96, 0.18), (0, 0, 0.42), SHEET, r, bevel=0.07)
box("Blanket", (1.02, 1.3, 0.05), (0, -0.3, 0.52), BLANKET, r, bevel=0.025)
box("Pillow", (0.6, 0.35, 0.12), (0, 0.75, 0.56), SHEET, r, bevel=0.05)
box("Headboard", (1.05, 0.08, 0.95), (0, 1.0, 0.48), WALNUT, r, bevel=0.035)

r = prop("BedDouble")
box("Frame", (1.65, 2.1, 0.28), (0, 0, 0.2), OAK, r, bevel=0.04)
box("Mattress", (1.58, 2.0, 0.2), (0, 0, 0.43), SHEET, r, bevel=0.08)
box("Blanket", (1.62, 1.35, 0.05), (0, -0.3, 0.54), FABRIC, r, bevel=0.025)
for sx in (-1, 1):
    box("Pillow", (0.62, 0.36, 0.13), (sx * 0.38, 0.75, 0.58), SHEET, r, bevel=0.05)
box("Headboard", (1.65, 0.08, 1.0), (0, 1.03, 0.5), OAK, r, bevel=0.035)

r = prop("Armchair")
box("Base", (0.8, 0.8, 0.3), (0, 0, 0.27), BLANKET, r, bevel=0.07)
box("Seat", (0.56, 0.6, 0.12), (0, -0.05, 0.46), BLANKET, r, bevel=0.05)
box("Back", (0.8, 0.18, 0.55), (0, 0.32, 0.6), BLANKET, r, bevel=0.08)
for sx in (-1, 1):
    box("Arm", (0.14, 0.78, 0.48), (sx * 0.34, 0, 0.42), BLANKET, r, bevel=0.06)
legs(r, 0.72, 0.72, 0.12, 0.022, WALNUT)

r = prop("Tub")
box("Outer", (1.7, 0.78, 0.58), (0, 0, 0.29), PORCELAIN, r, bevel=0.09)
box("Water", (1.48, 0.56, 0.02), (0, 0, 0.5), mat("TubInside", "#DCE3E8", roughness=0.1), r, bevel=0.2)
cyl("Tap", 0.018, 0.16, (0.7, 0.3, 0.66), STEEL, r, verts=12)

r = prop("Basin")
box("Vanity", (0.6, 0.45, 0.78), (0, 0, 0.39), COUNTER, r, bevel=0.03)
box("Bowl", (0.58, 0.46, 0.08), (0, -0.01, 0.82), PORCELAIN, r, bevel=0.035)
cyl("Tap", 0.014, 0.16, (0, 0.15, 0.92), STEEL, r, verts=12)
box("Mirror", (0.5, 0.02, 0.6), (0, 0.22, 1.45), GLASS, r, bevel=0.02)

r = prop("Toilet")
cyl("Pedestal", 0.15, 0.36, (0, -0.05, 0.18), PORCELAIN, r, verts=24)
sphere("Bowl", 0.2, (0, -0.12, 0.36), PORCELAIN, r, scale=(1.0, 1.3, 0.45))
box("Tank", (0.38, 0.18, 0.36), (0, 0.2, 0.62), PORCELAIN, r, bevel=0.04)
box("Seat", (0.36, 0.44, 0.03), (0, -0.12, 0.45), WHITE, r, bevel=0.012)

r = prop("Shelves")
for sx in (-1, 1):
    box("Upright", (0.04, 0.5, 1.8), (sx * 1.38, 0, 0.9), DARK, r, bevel=0.01)
for i in range(4):
    box("Shelf", (2.8, 0.5, 0.03), (0, 0, 0.3 + i * 0.48), STEEL, r, bevel=0.008)
for i, (x, z, w) in enumerate(((-0.9, 0.34, 0.5), (0.2, 0.34, 0.6), (-0.4, 0.82, 0.45), (0.8, 1.3, 0.5), (-1.0, 1.3, 0.4))):
    box("Crate", (w, 0.4, 0.3), (x, 0, z + 0.15), CARD if i % 2 else RED, r, bevel=0.03)

r = prop("Workbench")
box("Top", (1.8, 0.7, 0.06), (0, 0, 0.88), PINE, r, bevel=0.015)
box("Shelf", (1.7, 0.6, 0.03), (0, 0, 0.2), PINE, r, bevel=0.01)
legs(r, 1.8, 0.7, 0.85, 0.035, PINE, inset=0.07, taper=1.0)
box("Vise", (0.18, 0.14, 0.1), (0.75, -0.3, 0.96), mat("Vise", "#2F5D8A", metallic=0.5, roughness=0.4), r, bevel=0.02)

r = prop("Desk")
box("Top", (1.2, 0.6, 0.035), (0, 0, 0.74), OAK, r, bevel=0.015)
box("Drawers", (0.4, 0.55, 0.6), (0.38, 0, 0.42), WHITE, r, bevel=0.02)
legs(r, 1.2, 0.6, 0.72, 0.02, STEEL, inset=0.05, taper=1.0)
box("Laptop", (0.34, 0.24, 0.02), (-0.2, -0.05, 0.77), DARK, r, bevel=0.008)

r = prop("Wardrobe")
box("Body", (1.2, 0.58, 2.0), (0, 0, 1.0), WHITE, r, bevel=0.03)
box("Split", (0.008, 0.012, 1.9), (0, -0.29, 1.0), DARK, r)
for sx in (-1, 1):
    cyl("Knob", 0.012, 0.2, (sx * 0.06, -0.31, 1.05), STEEL, r, verts=10)

r = prop("Rug")
box("Rug", (2.0, 1.4, 0.012), (0, 0, 0.006), mat("Rug", "#7A5A6E", roughness=1.0), r, bevel=0.005)

r = prop("Dresser")
box("Body", (1.0, 0.45, 0.85), (0, 0, 0.45), WALNUT, r, bevel=0.025)
for i in range(3):
    box("Drawer", (0.94, 0.02, 0.24), (0, -0.226, 0.2 + i * 0.27), OAK, r, bevel=0.01)
legs(r, 1.0, 0.45, 0.05, 0.02, DARK)

r = prop("Van")                       # long axis Y, cab at +Y (towards the house)
box("Body", (2.0, 4.6, 1.75), (0, 0, 1.15), VAN, r, bevel=0.22)
box("Bonnet", (1.94, 0.9, 0.7), (0, 2.25, 0.75), VAN, r, bevel=0.2)
box("Windscreen", (1.8, 0.05, 0.62), (0, 2.18, 1.55), GLASS, r, bevel=0.05, rot=(-0.45, 0, 0))
for sx in (-1, 1):
    box("SideWindow", (0.04, 0.8, 0.5), (sx * 1.0, 1.5, 1.6), GLASS, r, bevel=0.03)
    box("Light", (0.32, 0.05, 0.14), (sx * 0.68, 2.7, 0.88), LIGHT, r, bevel=0.03)
    box("Mirror", (0.08, 0.14, 0.12), (sx * 1.1, 1.85, 1.45), DARK, r, bevel=0.03)
    for y in (1.6, -1.45):
        cyl("Tyre", 0.36, 0.26, (sx * 0.9, y, 0.36), TYRE, r, verts=28, rot=(0, math.pi / 2, 0))
        cyl("Rim", 0.2, 0.27, (sx * 0.9, y, 0.36), RIM, r, verts=20, rot=(0, math.pi / 2, 0))
box("Bumper", (2.04, 0.18, 0.2), (0, 2.72, 0.42), DARK, r, bevel=0.06)
box("RearBumper", (2.04, 0.18, 0.2), (0, -2.32, 0.42), DARK, r, bevel=0.06)
box("Stripe", (2.02, 3.0, 0.14), (0, -0.3, 1.1), mat("VanStripe", "#3B6EA5", roughness=0.4), r, bevel=0.05)

# ---------------------------------------------------------------- export (props at the origin) and preview
grid = {o.name: o.location.copy() for o in _props}
for o in _props:
    o.location = (0, 0, 0)
export_glb(out_path())
for o in _props:
    o.location = grid[o.name]
preview(out_path()[:-4] + "_preview.png", direction=(-0.6, -1.0, 0.75), size=1400, margin=1.05)
print("PROPS_DONE")
