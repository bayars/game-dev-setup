"""Seamless PBR texture sets baked with Cycles on the GPU. Runs inside Blender 4.2 (server).

`blender -b --factory-startup --python pbr.py -- <out_dir> [name ...]`
For every material this writes <name>_albedo.png, <name>_normal.png (tangent space, +Y up = Godot default)
and <name>_rough.png at 1024 px, each tiling perfectly.

Seamless trick: every noise is sampled on a 4D torus (cos/sin of u and v as the four coordinates), so the
texture wraps in both directions with no blending. Different radii per axis give stretched grain (wood, bark).
Patterns made of whole cells (brick, planks) use integer counts per tile for the same reason.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
import common  # noqa: E402

SIZE = 1024
TAU = 2 * math.pi


class B:
    """Tiny node-graph builder: every method returns an output socket."""

    def __init__(self, nt):
        self.nt = nt
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["UV"], sep.inputs[0])
        self.uvv = tc.outputs["UV"]
        self.u, self.v = sep.outputs["X"], sep.outputs["Y"]
        self._circ = {}

    def link(self, out, inp):
        self.nt.links.new(out, inp)

    def math(self, op, a, b=None, clamp=False):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation, n.use_clamp = op, clamp
        for i, x in enumerate((a, b)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                self.link(x, n.inputs[i])
        return n.outputs[0]

    def ramp(self, fac, stops):
        n = self.nt.nodes.new("ShaderNodeValToRGB")
        els = n.color_ramp.elements
        while len(els) < len(stops):
            els.new(0.5)
        for e, (pos, hexc) in zip(els, stops):
            e.position = pos
            e.color = (*common.srgb(hexc), 1)
        self.link(fac, n.inputs["Fac"])
        return n.outputs["Color"]

    def mix(self, fac, a, b):
        n = self.nt.nodes.new("ShaderNodeMixRGB")
        for i, x in ((1, a), (2, b)):
            if isinstance(x, str):
                n.inputs[i].default_value = (*common.srgb(x), 1)
            else:
                self.link(x, n.inputs[i])
        if isinstance(fac, (int, float)):
            n.inputs[0].default_value = fac
        else:
            self.link(fac, n.inputs[0])
        return n.outputs["Color"]

    def bw(self, color):
        n = self.nt.nodes.new("ShaderNodeRGBToBW")
        self.link(color, n.inputs[0])
        return n.outputs[0]

    def _circle(self, axis, k):
        key = (axis, k)
        if key not in self._circ:
            c = self.u if axis == "u" else self.v
            ang = self.math("MULTIPLY", c, TAU)
            self._circ[key] = (self.math("MULTIPLY", self.math("COSINE", ang), k),
                               self.math("MULTIPLY", self.math("SINE", ang), k))
        return self._circ[key]

    def _torus(self, node, ku, kv):
        cu, su = self._circle("u", ku)
        cv, sv = self._circle("v", kv)
        comb = self.nt.nodes.new("ShaderNodeCombineXYZ")
        self.link(cu, comb.inputs["X"])
        self.link(su, comb.inputs["Y"])
        self.link(cv, comb.inputs["Z"])
        self.link(comb.outputs[0], node.inputs["Vector"])
        self.link(sv, node.inputs["W"])

    def noise(self, ku, kv=None, detail=4.0, rough=0.5, distortion=0.0):
        n = self.nt.nodes.new("ShaderNodeTexNoise")
        n.noise_dimensions = "4D"
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distortion
        self._torus(n, ku, ku if kv is None else kv)
        return n.outputs["Fac"]

    def voronoi(self, k, rand=1.0):
        n = self.nt.nodes.new("ShaderNodeTexVoronoi")
        n.voronoi_dimensions = "4D"
        n.feature = "F1"
        n.inputs["Randomness"].default_value = rand
        n.inputs["Scale"].default_value = 1.0
        self._torus(n, k, k)
        return n.outputs["Distance"], n.outputs["Color"]

    def brick(self, scale, c1, c2, mortar, msize=0.02, width=0.5, height=0.25, offset=0.5, bias=0.0):
        n = self.nt.nodes.new("ShaderNodeTexBrick")
        n.offset, n.offset_frequency = offset, 2
        n.squash, n.squash_frequency = 1.0, 2
        for name, val in (("Color1", c1), ("Color2", c2), ("Mortar", mortar)):
            n.inputs[name].default_value = (*common.srgb(val), 1)
        n.inputs["Scale"].default_value = scale
        n.inputs["Mortar Size"].default_value = msize
        n.inputs["Mortar Smooth"].default_value = 0.1
        n.inputs["Bias"].default_value = bias
        n.inputs["Brick Width"].default_value = width
        n.inputs["Row Height"].default_value = height
        self.link(self.uvv, n.inputs["Vector"])
        return n.outputs["Color"], n.outputs["Fac"]


def stretch(b, x, lo, hi):
    """Remap a noise value (usually 0.3..0.7) to 0..1."""
    n = b.nt.nodes.new("ShaderNodeMapRange")
    n.clamp = True
    n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = lo, hi
    b.link(x, n.inputs["Value"])
    return n.outputs["Result"]


def combine(b, *terms):
    """Weighted sum of (socket, weight) pairs."""
    acc = None
    for s, w in terms:
        t = b.math("MULTIPLY", s, w)
        acc = t if acc is None else b.math("ADD", acc, t)
    return acc


# ------------------------------------------------------------------------------ material recipes
# each returns dict(color, rough (socket or float), height, strength, distance)

def grass(b):
    big, mid, fine = b.noise(3, detail=6), b.noise(14, detail=5), b.noise(45, detail=2)
    leaf = b.ramp(combine(b, (stretch(b, mid, 0.3, 0.7), 0.6), (stretch(b, fine, 0.25, 0.75), 0.4)),
                  [(0.0, "#12240C"), (0.45, "#264A16"), (0.8, "#3F6D20"), (1.0, "#5C8630")])
    dry = b.ramp(stretch(b, mid, 0.3, 0.7), [(0.0, "#5A4D26"), (1.0, "#7C6A33")])
    col = b.mix(stretch(b, big, 0.60, 0.74), leaf, dry)
    h = combine(b, (stretch(b, fine, 0.2, 0.8), 0.6), (stretch(b, mid, 0.3, 0.7), 0.4))
    return dict(color=col, rough=0.95, height=h, strength=1.0, distance=0.012)


def path(b):
    d, c = b.voronoi(4.2)
    pebble = b.math("SUBTRACT", 1.0, stretch(b, d, 0.22, 0.78))          # 1 on the pebble, 0 in the crevice
    tone = b.ramp(b.bw(c), [(0.0, "#6B5C48"), (0.4, "#9A8A70"), (0.75, "#B7A78C"), (1.0, "#7C7A74")])
    dirt = b.ramp(b.noise(30, detail=4), [(0.0, "#3B3026"), (1.0, "#5C4C3A")])
    col = b.mix(stretch(b, pebble, 0.05, 0.5), dirt, tone)
    h = combine(b, (pebble, 0.8), (b.noise(60, detail=2), 0.2))
    return dict(color=col, rough=b.ramp(pebble, [(0.0, "#F0F0F0"), (1.0, "#C8C8C8")]), height=h,
                strength=1.0, distance=0.02)


def plaster(b):
    blotch, grain, big = b.noise(3, detail=3), b.noise(70, detail=3), b.noise(1.4, detail=2)
    col = b.mix(stretch(b, blotch, 0.35, 0.65), "#D6BE92", "#E4D0A6")
    col = b.mix(combine(b, (stretch(b, big, 0.4, 0.6), 0.5)), col, "#B7A078")
    col = b.mix(combine(b, (stretch(b, grain, 0.3, 0.7), 0.18)), col, "#9C8863")
    h = combine(b, (stretch(b, grain, 0.2, 0.8), 0.55), (stretch(b, blotch, 0.3, 0.7), 0.45))
    return dict(color=col, rough=0.9, height=h, strength=0.6, distance=0.004)


def roof(b):
    tile, fac = b.brick(3.0, "#B04A2C", "#8E3822", "#34170F", msize=0.025, width=0.5, height=0.25, offset=0.5)
    rowv = b.math("FRACT", b.math("MULTIPLY", b.v, 12.0))               # 12 rows per tile
    drop = b.math("SUBTRACT", 1.0, rowv)                                  # shadow under each row's lower edge
    n = b.noise(6, detail=4)
    streak = b.noise(ku=3, kv=18, detail=3) if False else b.noise(3, 18, detail=3)
    col = b.mix(combine(b, (stretch(b, n, 0.35, 0.65), 0.35)), tile, "#5A3322")
    col = b.mix(combine(b, (stretch(b, streak, 0.5, 0.75), 0.4)), col, "#3C3A30")
    col = b.mix(combine(b, (b.math("POWER", drop, 3.0), 0.55)), col, "#22100A")
    h = combine(b, (fac, 0.55), (rowv, 0.45))
    return dict(color=col, rough=0.78, height=h, strength=1.0, distance=0.03)


def stone(b):
    d, c = b.voronoi(2.6, rand=0.9)
    face = stretch(b, d, 0.0, 0.7)
    fine, mid = b.noise(55, detail=5), b.noise(9, detail=4)
    tone = b.ramp(b.bw(c), [(0.0, "#6F6C66"), (0.5, "#8F8C85"), (1.0, "#A5A29A")])
    col = b.mix(combine(b, (stretch(b, fine, 0.3, 0.7), 0.35)), tone, "#4F4D49")
    col = b.mix(combine(b, (stretch(b, mid, 0.55, 0.75), 0.35)), col, "#53603F")    # moss
    seam = b.math("POWER", face, 2.0)
    col = b.mix(combine(b, (seam, 0.7)), col, "#2E2D2A")
    h = combine(b, (b.math("SUBTRACT", 1.0, face), 0.5), (stretch(b, fine, 0.2, 0.8), 0.5))
    return dict(color=col, rough=0.93, height=h, strength=1.0, distance=0.03)


def brick(b):
    col, fac = b.brick(4.0, "#A24E38", "#8A3F2E", "#BDB2A0", msize=0.03, width=0.5, height=0.25, offset=0.5)
    n, fine = b.noise(5, detail=4), b.noise(60, detail=3)
    col = b.mix(combine(b, (stretch(b, n, 0.35, 0.65), 0.4)), col, "#5C2C20")
    col = b.mix(combine(b, (stretch(b, fine, 0.3, 0.7), 0.25)), col, "#3A241C")
    h = combine(b, (fac, 0.7), (stretch(b, fine, 0.2, 0.8), 0.3))
    return dict(color=col, rough=0.92, height=h, strength=1.0, distance=0.02)


def wood(b):
    # five vertical planks per tile
    idx = b.math("FLOOR", b.math("MULTIPLY", b.u, 5.0))
    nw = b.nt.nodes.new("ShaderNodeTexWhiteNoise")
    nw.noise_dimensions = "1D"
    b.link(idx, nw.inputs["W"])
    rnd = b.bw(nw.outputs["Color"])
    cell = b.math("FRACT", b.math("MULTIPLY", b.u, 5.0))
    gap = b.math("SUBTRACT", 1.0, stretch(b, b.math("MINIMUM", cell, b.math("SUBTRACT", 1.0, cell)), 0.0, 0.025))
    grain = b.noise(40, 2, detail=6, rough=0.62, distortion=0.4)
    rings = b.math("PINGPONG", b.math("MULTIPLY", grain, 14.0), 1.0)
    base = b.ramp(combine(b, (stretch(b, grain, 0.3, 0.7), 0.7), (rings, 0.3)),
                  [(0.0, "#4A2C16"), (0.5, "#7A4A26"), (1.0, "#A8703C")])
    col = b.mix(combine(b, (rnd, 0.5)), base, "#5E3A1E")
    col = b.mix(combine(b, (gap, 1.0)), col, "#150C06")
    h = b.math("SUBTRACT", combine(b, (grain, 0.5), (rings, 0.2)), b.math("MULTIPLY", gap, 0.6))
    return dict(color=col, rough=b.ramp(grain, [(0.0, "#A0A0A0"), (1.0, "#D8D8D8")]), height=h,
                strength=0.7, distance=0.006)


def bark(b):
    ridge = b.noise(14, 1.6, detail=8, rough=0.7, distortion=0.5)
    fine = b.noise(50, 4, detail=4)
    r = stretch(b, ridge, 0.3, 0.7)
    col = b.ramp(combine(b, (r, 0.8), (stretch(b, fine, 0.3, 0.7), 0.2)),
                 [(0.0, "#1E130C"), (0.5, "#4B3322"), (1.0, "#7D5E40")])
    return dict(color=col, rough=0.97, height=combine(b, (r, 0.85), (fine, 0.15)), strength=1.4, distance=0.04)


def foliage(b):
    """Neutral (grey-green) leafy variation; the game tints it with each tree's colour."""
    clump, leaf, fine = b.noise(6, detail=5), b.noise(26, detail=4), b.noise(80, detail=2)
    v = combine(b, (stretch(b, clump, 0.3, 0.7), 0.4), (stretch(b, leaf, 0.3, 0.7), 0.45), (stretch(b, fine, 0.3, 0.7), 0.15))
    col = b.ramp(v, [(0.0, "#3E4A35"), (0.5, "#8F9C7E"), (1.0, "#E3EBC8")])
    return dict(color=col, rough=0.85, height=combine(b, (stretch(b, leaf, 0.3, 0.7), 0.7), (stretch(b, fine, 0.3, 0.7), 0.3)),
                strength=1.2, distance=0.03)


RECIPES = dict(grass=grass, path=path, plaster=plaster, roof=roof, stone=stone, brick=brick, wood=wood,
               bark=bark, foliage=foliage)


# ------------------------------------------------------------------------------ baking

def bake(name, out_dir):
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    plane = bpy.context.active_object
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    plane.data.materials.append(m)

    r = RECIPES[name](B(nt))
    nt.links.new(r["color"], bsdf.inputs["Base Color"])
    if isinstance(r["rough"], float):
        bsdf.inputs["Roughness"].default_value = r["rough"]
    else:
        nt.links.new(r["rough"], bsdf.inputs["Roughness"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = r["strength"]
    bump.inputs["Distance"].default_value = r["distance"]
    nt.links.new(r["height"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    for kind, suffix, cs in (("DIFFUSE", "albedo", "sRGB"), ("NORMAL", "normal", "Non-Color"),
                             ("ROUGHNESS", "rough", "Non-Color")):
        img = bpy.data.images.new(f"{name}_{suffix}", SIZE, SIZE)
        img.colorspace_settings.name = cs
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        if kind == "DIFFUSE":
            bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=2)
        else:
            bpy.ops.object.bake(type=kind, margin=2)
        img.filepath_raw = os.path.join(out_dir, f"{name}_{suffix}.png")
        img.file_format = "PNG"
        img.save()
        nt.nodes.remove(node)
        print("BAKED", img.filepath_raw)
    bpy.data.objects.remove(plane)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out_dir, names = argv[0], argv[1:] or list(RECIPES)
    os.makedirs(out_dir, exist_ok=True)
    common.reset()
    scene = bpy.context.scene
    common._enable_cuda()
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
    scene.render.bake.normal_space = "TANGENT"
    scene.render.bake.use_clear = True
    scene.view_settings.view_transform = "Standard"
    for n in names:
        bake(n, out_dir)


main()
