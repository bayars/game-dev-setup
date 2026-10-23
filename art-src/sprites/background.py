"""960x540 space background: navy-violet-teal nebula and a two-layer starfield, via an emission plane."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from common import *

args = parse_args(default_samples=24)
scene = reset_scene()
setup_render(scene, 960, 540, args.samples, transparent=False, denoise=False)
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)

bpy.ops.mesh.primitive_plane_add(size=1.0)
plane = bpy.context.active_object
plane.scale = (16, 9, 1)
bpy.ops.object.transform_apply(scale=True)  # object coords == world units (16 x 9)

m = bpy.data.materials.new("Space")
m.use_nodes = True
nt = m.node_tree
nt.nodes.clear()
N = nt.nodes.new
L = nt.links.new
coord = N("ShaderNodeTexCoord")


def noise(scale, detail, rough, offset):
    mp = N("ShaderNodeMapping")
    mp.inputs["Location"].default_value = offset
    n = N("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    L(coord.outputs["Object"], mp.inputs["Vector"])
    L(mp.outputs["Vector"], n.inputs["Vector"])
    return n


def ramp(stops):
    r = N("ShaderNodeValToRGB")
    while len(r.color_ramp.elements) < len(stops):
        r.color_ramp.elements.new(0.5)
    for el, (pos, col) in zip(r.color_ramp.elements, stops):
        el.position = pos
        el.color = (*col, 1)
    return r


neb = noise(0.32, 10.0, 0.58, (3.0, 1.0, 0.0))
neb_r = ramp([(0.34, (0.004, 0.006, 0.03)), (0.52, (0.035, 0.015, 0.11)),
              (0.68, (0.15, 0.04, 0.27)), (0.86, (0.035, 0.30, 0.42))])
L(neb.outputs["Fac"], neb_r.inputs["Fac"])

mask = noise(0.18, 4.0, 0.5, (-5.0, 2.0, 0.0))  # patchy: nebula fades out in places
mask_r = ramp([(0.35, (0, 0, 0)), (0.7, (1, 1, 1))])
L(mask.outputs["Fac"], mask_r.inputs["Fac"])
neb_mul = N("ShaderNodeMix")
neb_mul.data_type = "RGBA"
neb_mul.blend_type = "MULTIPLY"
neb_mul.inputs["Factor"].default_value = 1.0
L(neb_r.outputs["Color"], neb_mul.inputs["A"])
L(mask_r.outputs["Color"], neb_mul.inputs["B"])


def stars(scale, near, far, strength, seed):
    v = N("ShaderNodeTexVoronoi")
    v.voronoi_dimensions = "4D"  # must be set before the W input exists
    v.inputs["Scale"].default_value = scale
    v.inputs["W"].default_value = seed
    L(coord.outputs["Object"], v.inputs["Vector"])
    mr = N("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = near
    mr.inputs["From Max"].default_value = far
    L(v.outputs["Distance"], mr.inputs["Value"])
    sep = N("ShaderNodeSeparateColor")
    L(v.outputs["Color"], sep.inputs["Color"])
    mul = N("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    L(mr.outputs["Result"], mul.inputs[0])
    L(sep.outputs["Red"], mul.inputs[1])
    gain = N("ShaderNodeMath")
    gain.operation = "MULTIPLY"
    gain.inputs[1].default_value = strength
    L(mul.outputs[0], gain.inputs[0])
    return gain


small = stars(5.0, 0.16, 0.04, 3.0, 1.3)
big = stars(1.6, 0.09, 0.02, 7.0, 4.1)
star_sum = N("ShaderNodeMath")
star_sum.operation = "ADD"
L(small.outputs[0], star_sum.inputs[0])
L(big.outputs[0], star_sum.inputs[1])
star_col = N("ShaderNodeMix")
star_col.data_type = "RGBA"
star_col.inputs["A"].default_value = (0.75, 0.85, 1.0, 1)
star_col.inputs["B"].default_value = (1.0, 0.95, 0.8, 1)
star_col.inputs["Factor"].default_value = 0.35
star_emit = N("ShaderNodeMix")
star_emit.data_type = "RGBA"
star_emit.blend_type = "MULTIPLY"
star_emit.inputs["Factor"].default_value = 1.0
L(star_col.outputs["Result"], star_emit.inputs["A"])
# multiply colour by scalar star brightness through a Math->Combine path
comb = N("ShaderNodeCombineColor")
for ch in ("Red", "Green", "Blue"):
    L(star_sum.outputs[0], comb.inputs[ch])
L(comb.outputs["Color"], star_emit.inputs["B"])

total = N("ShaderNodeMix")
total.data_type = "RGBA"
total.blend_type = "ADD"
total.inputs["Factor"].default_value = 1.0
L(neb_mul.outputs["Result"], total.inputs["A"])
L(star_emit.outputs["Result"], total.inputs["B"])
emit = N("ShaderNodeEmission")
L(total.outputs["Result"], emit.inputs["Color"])
out = N("ShaderNodeOutputMaterial")
L(emit.outputs[0], out.inputs["Surface"])
plane.data.materials.append(m)

cam = bpy.data.cameras.new("Cam")
cam.type = "ORTHO"
cam.ortho_scale = 16
cam_obj = bpy.data.objects.new("Cam", cam)
cam_obj.location = (0, 0, 5)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

os.makedirs(args.out, exist_ok=True)
scene.render.filepath = os.path.join(args.out, "background.png")
bpy.ops.render.render(write_still=True)
print("FRAMES_DONE", args.out)
