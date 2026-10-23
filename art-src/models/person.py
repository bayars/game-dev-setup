"""The walker: a stylised person (about 1.8 m) with a scarf and backpack, built from rigid parts.

Joints are Empties at the pivot: Head, ArmL, ArmR, LegL, LegR. Godot swings them for the walk cycle.
Faces -Y in Blender (+Z in Godot).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
skin = mat("Skin", "#E9B58F", roughness=0.7)
hair = mat("Hair", "#3A2418", roughness=0.8)
jacket = mat("Jacket", "#1F8F96", roughness=0.75)
scarf = mat("Scarf", "#E8A820", roughness=0.9)
pants = mat("Pants", "#2B3550", roughness=0.8)
shoe = mat("Shoe", "#3B2A22", roughness=0.6)
pack = mat("Pack", "#8A4B22", roughness=0.85)
strap = mat("Strap", "#5A3015", roughness=0.9)
dark = mat("EyeDark", "#15110F", roughness=0.4)

root = empty("Person")
box("Torso", (0.44, 0.25, 0.58), (0, 0, 1.2), jacket, root, bevel=0.07)
box("Pelvis", (0.40, 0.23, 0.24), (0, 0, 0.93), pants, root, bevel=0.05)
box("Scarf", (0.46, 0.28, 0.10), (0, 0, 1.52), scarf, root, bevel=0.04)
box("ScarfTail", (0.10, 0.04, 0.34), (-0.12, -0.15, 1.38), scarf, root, bevel=0.015)
box("Backpack", (0.34, 0.15, 0.44), (0, 0.20, 1.22), pack, root, bevel=0.05)
box("PackFlap", (0.34, 0.17, 0.14), (0, 0.205, 1.36), strap, root, bevel=0.04)
box("StrapL", (0.05, 0.27, 0.05), (-0.13, 0.0, 1.38), strap, root)
box("StrapR", (0.05, 0.27, 0.05), (0.13, 0.0, 1.38), strap, root)

head = empty("Head", (0, 0, 1.58), root)
sphere("Skull", 0.135, (0, 0, 0.12), skin, head)
sphere("Hair", 0.145, (0, 0.025, 0.145), hair, head, scale=(1.0, 1.0, 0.92))
sphere("EyeL", 0.02, (-0.05, -0.12, 0.115), dark, head)
sphere("EyeR", 0.02, (0.05, -0.12, 0.115), dark, head)
sphere("Nose", 0.02, (0, -0.135, 0.085), skin, head)

for side, sx in (("L", -1), ("R", 1)):
    arm = empty("Arm" + side, (sx * 0.28, 0, 1.45), root)
    box("Sleeve" + side, (0.11, 0.11, 0.42), (0, 0, -0.21), jacket, arm, bevel=0.04)
    box("Forearm" + side, (0.09, 0.09, 0.2), (0, 0, -0.48), skin, arm, bevel=0.03)
    sphere("Hand" + side, 0.055, (0, 0, -0.6), skin, arm)
    leg = empty("Leg" + side, (sx * 0.1, 0, 0.9), root)
    box("Trouser" + side, (0.16, 0.16, 0.74), (0, 0, -0.37), pants, leg, bevel=0.05)
    box("Shoe" + side, (0.17, 0.3, 0.11), (0, -0.05, -0.845), shoe, leg, bevel=0.04)

finish(out_path(), direction=(-0.45, -1.0, 0.3))
