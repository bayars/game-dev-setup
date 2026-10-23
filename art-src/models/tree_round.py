"""Low-poly round tree (about 4 m): trunk and clumped faceted foliage."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
bark = mat("Bark2", "#6B4A2E", roughness=0.95)
leaf_a = mat("LeafA", "#4C9A3E", roughness=0.9)
leaf_b = mat("LeafB", "#5FB04A", roughness=0.9)
leaf_c = mat("LeafC", "#3E8636", roughness=0.9)

root = empty("TreeRound")
cyl("Trunk", 0.22, 2.0, (0, 0, 1.0), bark, root, verts=10)
ico("Crown", 1.45, (0, 0, 3.0), leaf_a, root, subdiv=2, scale=(1.0, 1.0, 0.9))
ico("Clump1", 0.95, (0.85, 0.35, 2.6), leaf_b, root, subdiv=2)
ico("Clump2", 0.9, (-0.8, -0.4, 2.7), leaf_c, root, subdiv=2)
ico("Clump3", 0.8, (0.1, -0.85, 3.5), leaf_b, root, subdiv=2)
cyl("Trunk-convcolonly", 0.34, 2.4, (0, 0, 1.2), None, root, verts=8)

finish(out_path(), direction=(-0.7, -1.0, 0.25))
