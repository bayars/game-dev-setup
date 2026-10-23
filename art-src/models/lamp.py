"""Garden lamp post (about 2.3 m) with a warm glowing lantern."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
iron = mat("Iron", "#23262B", metallic=0.7, roughness=0.45)
glow = mat("LanternGlow", "#FFC070", roughness=0.3, emission="#FFB050", strength=6.0)

root = empty("Lamp")
cyl("Base", 0.17, 0.12, (0, 0, 0.06), iron, root, verts=16)
cyl("Pole", 0.05, 1.9, (0, 0, 1.05), iron, root, verts=12)
box("Cage", (0.34, 0.34, 0.5), (0, 0, 2.2), glow, root, bevel=0.04)
box("CapBox", (0.42, 0.42, 0.05), (0, 0, 2.5), iron, root)
cone("Cap", 0.3, 0.02, 0.22, (0, 0, 2.64), iron, root, verts=4, rot=(0, 0, 0.785398))
box("Foot", (0.42, 0.42, 0.04), (0, 0, 1.95), iron, root)

finish(out_path(), direction=(-0.7, -1.0, 0.2))
