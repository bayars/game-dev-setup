"""Cottage with a hinged red front door and a cosy furnished interior (8 x 6 m, ridge about 5.4 m).

The door is parented to the Empty `DoorHinge` (origin on the hinge) so Godot can swing it.
Front faces -Y (+Z in Godot). `HouseBlock-convcolonly` becomes the collision box in Godot.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()

W, D, H, T = 8.0, 6.0, 3.0, 0.25   # width (x), depth (y), wall height, wall thickness
Z0 = 0.06                          # top of the stone plinth = floor level
TOP = Z0 + H                       # top of the walls
DOOR_W, DOOR_H = 1.1, 2.2

wall = mat("Wall", "#E9D8B4", roughness=0.9)
trim = mat("Trim", "#F6F1E7", roughness=0.7)
roof = mat("Roof", "#9C3F25", roughness=0.8)
roof_dark = mat("RoofRidge", "#6E2A18", roughness=0.8)
stone = mat("Stone", "#8C8A84", roughness=0.95)
brick = mat("Brick", "#A5503A", roughness=0.95)
door_red = mat("DoorRed", "#B3261E", roughness=0.5)
brass = mat("Brass", "#D8A93A", metallic=1.0, roughness=0.3)
wood_floor = mat("Floor", "#A9753F", roughness=0.7)
glass_glow = mat("WindowGlow", "#FFD79A", roughness=0.2, emission="#FFB45A", strength=3.5)
lamp_glow = mat("LampGlow", "#FFE0A8", roughness=0.3, emission="#FFC06A", strength=5.0)
porch_glow = mat("PorchGlow", "#FFE0A8", roughness=0.3, emission="#FFC06A", strength=7.0)
rug_mat = mat("Rug", "#C4523A", roughness=1.0)
sofa_green = mat("Armchair", "#3E7A5B", roughness=0.9)
wood_dark = mat("WoodDark", "#5A3A22", roughness=0.7)
mat_book = [mat(f"Book{i}", c, roughness=0.8) for i, c in enumerate(
    ["#B33A3A", "#2F6DB5", "#E0B040", "#3A8A5A", "#7A3FA0", "#D9772B"])]
mat_mat = mat("Doormat", "#6B5238", roughness=1.0)

root = empty("House")

# --- shell -------------------------------------------------------------------------------
box("Plinth", (W + 0.5, D + 0.5, Z0), (0, 0, Z0 / 2), stone, root)
box("Floor", (W - 2 * T, D - 2 * T, 0.04), (0, 0, Z0 + 0.02), wood_floor, root)
box("WallBack", (W, T, H), (0, D / 2 - T / 2, Z0 + H / 2), wall, root)
box("WallLeft", (T, D - 2 * T, H), (-(W / 2 - T / 2), 0, Z0 + H / 2), wall, root)
box("WallRight", (T, D - 2 * T, H), (W / 2 - T / 2, 0, Z0 + H / 2), wall, root)
fy = -D / 2 + T / 2                # front wall centre line (y)
seg_w = W / 2 - DOOR_W / 2
box("WallFrontL", (seg_w, T, H), (-(W / 2 - seg_w / 2), fy, Z0 + H / 2), wall, root)
box("WallFrontR", (seg_w, T, H), (W / 2 - seg_w / 2, fy, Z0 + H / 2), wall, root)
box("WallFrontTop", (DOOR_W, T, H - DOOR_H), (0, fy, Z0 + DOOR_H + (H - DOOR_H) / 2), wall, root)
box("Ceiling", (W - 2 * T, D - 2 * T, 0.1), (0, 0, TOP - 0.05), trim, root)

# --- roof: gable with the ridge along Y, slopes toward +-X -------------------------------
slope = math.radians(30)
rise = (W / 2) * math.tan(slope)
ridge_z = TOP + rise
roof_len = (W / 2 + 0.45) / math.cos(slope)
for sx in (-1, 1):
    cx = sx * (roof_len / 2) * math.cos(slope)
    cz = ridge_z + 0.07 - (roof_len / 2) * math.sin(slope)
    box("Roof" + ("L" if sx < 0 else "R"), (roof_len, D + 0.8, 0.14), (cx, 0, cz), roof, root,
        rot=(0, sx * slope, 0))
box("RidgeCap", (0.35, D + 0.85, 0.16), (0, 0, ridge_z + 0.09), roof_dark, root, rot=(0, 0, 0))
for gy, nm in ((-D / 2, "GableFront"), (D / 2 - T, "GableBack")):
    polygon(nm, [(-W / 2, gy, TOP), (W / 2, gy, TOP), (0, gy, ridge_z)], wall, root, thickness=T)
# the polygons solidify along the face normal; make sure they cover the wall thickness either way
# (a thin cream gable front/back is fine visually)

box("Chimney", (0.75, 0.75, 2.3), (2.3, 1.1, TOP + 1.75), brick, root)
box("ChimneyCap", (0.95, 0.95, 0.12), (2.3, 1.1, TOP + 2.95), stone, root)

# --- door --------------------------------------------------------------------------------
box("FrameL", (0.1, T + 0.07, DOOR_H + 0.1), (-(DOOR_W / 2 + 0.05), fy - 0.02, Z0 + DOOR_H / 2 + 0.05), trim, root)
box("FrameR", (0.1, T + 0.07, DOOR_H + 0.1), (DOOR_W / 2 + 0.05, fy - 0.02, Z0 + DOOR_H / 2 + 0.05), trim, root)
box("FrameTop", (DOOR_W + 0.3, T + 0.07, 0.12), (0, fy - 0.02, Z0 + DOOR_H + 0.1), trim, root)
hinge = empty("DoorHinge", (-DOOR_W / 2, fy + 0.02, Z0 + 0.02), root)
box("Door", (DOOR_W - 0.04, 0.07, DOOR_H - 0.06), ((DOOR_W - 0.04) / 2, 0, (DOOR_H - 0.06) / 2), door_red, hinge, bevel=0.015)
for i, zz in enumerate((0.55, 1.55)):   # raised panels
    box(f"DoorPanel{i}", (0.66, 0.02, 0.7), (DOOR_W / 2 - 0.02, -0.045, zz + 0.1), door_red, hinge, bevel=0.01)
sphere("Knob", 0.045, (DOOR_W - 0.2, -0.085, 1.05), brass, hinge)
sphere("KnobIn", 0.045, (DOOR_W - 0.2, 0.085, 1.05), brass, hinge)
box("Doormat", (0.9, 0.6, 0.02), (0, -D / 2 - 0.3, Z0 + 0.01), mat_mat, root)

# --- windows (lit warm glass) -------------------------------------------------------------
wy = -D / 2
for sx in (-1, 1):
    wx = sx * 2.35
    box(f"WinFrame{sx}", (1.3, 0.08, 1.3), (wx, wy - 0.04, Z0 + 1.65), trim, root)
    box(f"WinGlass{sx}", (1.08, 0.04, 1.08), (wx, wy - 0.095, Z0 + 1.65), glass_glow, root)
    box(f"WinBarH{sx}", (1.1, 0.05, 0.06), (wx, wy - 0.12, Z0 + 1.65), trim, root)
    box(f"WinBarV{sx}", (0.06, 0.05, 1.1), (wx, wy - 0.12, Z0 + 1.65), trim, root)
    box(f"WinSill{sx}", (1.5, 0.18, 0.07), (wx, wy - 0.1, Z0 + 0.95), trim, root)
    box(f"ShutterL{sx}", (0.28, 0.04, 1.3), (wx - 0.8, wy - 0.05, Z0 + 1.65), roof_dark, root)
    box(f"ShutterR{sx}", (0.28, 0.04, 1.3), (wx + 0.8, wy - 0.05, Z0 + 1.65), roof_dark, root)
# round attic window in the front gable
cyl("AtticFrame", 0.4, 0.08, (0, wy - 0.04, TOP + 0.95), trim, root, rot=(math.pi / 2, 0, 0))
cyl("AtticGlass", 0.32, 0.06, (0, wy - 0.09, TOP + 0.95), glass_glow, root, rot=(math.pi / 2, 0, 0))

# --- porch ---------------------------------------------------------------------------------
for sx in (-1, 1):
    cyl(f"PorchPost{sx}", 0.07, 2.55, (sx * 1.25, -D / 2 - 0.85, Z0 + 1.275), trim, root, verts=12)
box("PorchRoof", (3.1, 1.5, 0.1), (0, -D / 2 - 0.65, Z0 + 2.62), roof, root, rot=(0.14, 0, 0))
box("PorchBeam", (2.7, 0.12, 0.14), (0, -D / 2 - 0.85, Z0 + 2.5), trim, root)
sphere("PorchLight", 0.1, (0, -D / 2 - 0.35, Z0 + 2.38), porch_glow, root)
box("PorchSlab", (3.0, 1.3, 0.04), (0, -D / 2 - 0.65, Z0 + 0.02), stone, root)

# --- interior: a warm little room ---------------------------------------------------------
box("Rug", (2.6, 1.8, 0.02), (0, -0.7, Z0 + 0.05), rug_mat, root)
box("TableTop", (1.0, 0.7, 0.06), (-2.7, 1.9, Z0 + 0.78), wood_dark, root, bevel=0.015)
for lx in (-0.42, 0.42):
    for ly in (-0.27, 0.27):
        box("TableLeg", (0.06, 0.06, 0.74), (-2.7 + lx, 1.9 + ly, Z0 + 0.39), wood_dark, root)
cyl("LampBase", 0.07, 0.05, (-2.7, 1.9, Z0 + 0.84), wood_dark, root, verts=12)
cone("LampShade", 0.19, 0.11, 0.24, (-2.7, 1.9, Z0 + 1.0), lamp_glow, root, verts=16)
box("ChairSeat", (0.95, 0.85, 0.42), (2.65, 1.95, Z0 + 0.25), sofa_green, root, bevel=0.07)
box("ChairBack", (0.95, 0.2, 0.62), (2.65, 2.4, Z0 + 0.7), sofa_green, root, bevel=0.07)
box("ChairArmL", (0.16, 0.8, 0.28), (2.15, 1.95, Z0 + 0.52), sofa_green, root, bevel=0.05)
box("ChairArmR", (0.16, 0.8, 0.28), (3.15, 1.95, Z0 + 0.52), sofa_green, root, bevel=0.05)
box("ShelfFrame", (2.2, 0.3, 2.0), (0, D / 2 - T - 0.15, Z0 + 1.02), wood_dark, root)
for i in range(6):
    box(f"Book{i}", (0.12, 0.2, 0.3 + 0.03 * (i % 3)), (-0.55 + i * 0.2, D / 2 - T - 0.22, Z0 + 1.15), mat_book[i], root)
for i in range(5):
    box(f"BookUp{i}", (0.12, 0.2, 0.34), (0.1 + i * 0.2, D / 2 - T - 0.22, Z0 + 1.65), mat_book[(i + 2) % 6], root)
cyl("Pot", 0.18, 0.32, (-3.3, -1.9, Z0 + 0.18), brick, root, verts=14)
ico("Plant", 0.34, (-3.3, -1.9, Z0 + 0.62), mat("Plant", "#3F8A45", roughness=0.9), root, subdiv=2)

# --- collision -----------------------------------------------------------------------------
box("HouseBlock-convcolonly", (W + 0.3, D + 0.3, H + 1.0), (0, 0, (H + 1.0) / 2), None, root)

finish(out_path(), direction=(-0.8, -1.0, 0.55), margin=1.35)
