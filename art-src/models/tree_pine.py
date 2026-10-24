"""Low-poly pine tree (about 4.5 m). The invisible trunk collider is picked up by Godot (-convcolonly)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
bark = mat("Bark", "#5B3A22", roughness=0.95)
leaf_a = mat("PineA", "#1F5A34", roughness=0.9)
leaf_b = mat("PineB", "#2A6E3C", roughness=0.9)
leaf_c = mat("PineC", "#378448", roughness=0.9)

root = empty("TreePine")
cyl("Trunk", 0.2, 1.4, (0, 0, 0.7), bark, root, verts=10)
cone("Tier1", 1.35, 0.15, 1.7, (0, 0, 1.9), leaf_a, root, verts=9, flat=True)
cone("Tier2", 1.05, 0.12, 1.5, (0, 0, 2.7), leaf_b, root, verts=9, flat=True)
cone("Tier3", 0.75, 0.0, 1.4, (0, 0, 3.5), leaf_c, root, verts=9, flat=True)
cyl("Trunk-convcolonly", 0.32, 2.2, (0, 0, 1.1), None, root, verts=8)

finish(out_path(), direction=(-0.7, -1.0, 0.25))
