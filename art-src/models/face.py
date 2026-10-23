"""A more realistic head for the person: sculpted face, rigged eyelids, painted skin/eye textures,
shaped ears and strand hair. Runs inside Blender 4.2 (called from person.py).

Head frame: centre HEAD_C (x=0, y=0, z=1.685), front is -Y, character-left is +X.
Proportions follow real anthropometry: head height 0.23 m (chin 1.567 .. crown 1.80), eyes on the
middle line (z = 1.69), nose base 1.637, mouth line 1.614, chin point 1.585, inter-pupil 62 mm,
eye opening 29 mm wide.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HEAD_C = np.array([0.0, 0.0, 1.685])
HEAD_R = np.array([0.074, 0.095, 0.118])      # ellipsoid radii before the features are sculpted in
EYE_X = 0.031
EYE_Z = 1.690
EYE_A, EYE_B = 0.0138, 0.0052                  # half width / half height of the lid opening
EYE_TILT = 0.09                                # outer corner sits a little higher than the inner one
EYEBALL_R = 0.0118
SKIN_SRGB = np.array([226, 174, 139]) / 255.0

# name, x, z (relative to head centre), width_x, width_z, amplitude (m, along the surface normal), mirrored
FEATURES = [
    ("forehead", 0.0, 0.072, 0.045, 0.030, +0.0030, False),
    ("brow_ridge", 0.030, 0.027, 0.028, 0.0090, +0.0058, True),
    ("glabella", 0.0, 0.025, 0.010, 0.0100, +0.0028, False),
    ("socket", 0.033, 0.005, 0.021, 0.0135, -0.0070, True),
    ("temple", 0.066, 0.030, 0.015, 0.0300, -0.0030, True),
    ("under_eye", 0.031, -0.010, 0.016, 0.0060, -0.0022, True),
    ("cheekbone", 0.052, -0.018, 0.026, 0.0170, +0.0062, True),
    ("cheek", 0.043, -0.045, 0.026, 0.0220, +0.0030, True),
    ("nasal_bridge", 0.0, -0.008, 0.0070, 0.0200, +0.0068, False),
    ("nose_tip", 0.0, -0.031, 0.0105, 0.0085, +0.0125, False),
    ("alar", 0.0165, -0.034, 0.0075, 0.0075, +0.0062, True),
    ("nostril", 0.0095, -0.042, 0.0040, 0.0035, -0.0075, True),
    ("nasolabial", 0.027, -0.050, 0.0045, 0.0180, -0.0030, True),
    ("philtrum", 0.0, -0.054, 0.0050, 0.0060, -0.0015, False),
    ("upper_lip", 0.0, -0.063, 0.0150, 0.0055, +0.0050, False),
    ("lower_lip", 0.0, -0.079, 0.0135, 0.0065, +0.0062, False),
    ("mouth_corner", 0.0285, -0.071, 0.0050, 0.0060, -0.0035, True),
    ("mouth_line", 0.0, -0.071, 0.0220, 0.0028, -0.0032, False),
    ("mentolabial", 0.0, -0.089, 0.0140, 0.0045, -0.0035, False),
    ("chin", 0.0, -0.103, 0.0190, 0.0150, +0.0066, False),
    ("jaw", 0.058, -0.080, 0.0200, 0.0160, +0.0042, True),
]


def sstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def g2(dx, dz, sx, sz):
    return np.exp(-((dx / sx) ** 2 + (dz / sz) ** 2))


# ----------------------------------------------------------------------------- helpers
def _activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _link(name, mesh):
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    return o


def _attach(obj, arm):
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = arm
    obj.parent = arm


def _rigid(obj, arm, bone):
    vg = obj.vertex_groups.new(name=bone)
    vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    _attach(obj, arm)


def _mesh_from_bm(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    return mesh


def image_material(name, image, roughness=0.5, **extra):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = roughness
    for k, v in extra.items():
        b.inputs[k.replace("_", " ")].default_value = v
    return m


def make_image(name, arr):
    h, w, _ = arr.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(arr, 0, 1)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    img.update()
    return img


# ----------------------------------------------------------------------------- skin texture
def paint_skin(size=1024):
    """Front-projected face texture: x in [-0.1, 0.1] m, z in [1.56, 1.82] m (matches the head UVs)."""
    S = size
    ys, xs = np.mgrid[0:S, 0:S]
    X = (xs + 0.5) / S * 0.2 - 0.1
    Z = 1.56 + (ys + 0.5) / S * 0.26
    rng = np.random.default_rng(11)
    img = np.ones((S, S, 3)) * SKIN_SRGB

    def blend(mask, color, alpha):
        a = np.clip(mask * alpha, 0, 1)[..., None]
        img[:] = img * (1 - a) + np.array(color) * a

    mott = sum(rng.uniform(.4, 1) * np.sin(rng.uniform(40, 150) * (X * np.cos(t) + Z * np.sin(t)) + rng.uniform(0, 6.3))
               for t in rng.uniform(0, 6.3, 7)) / 7.0
    img *= (1 + 0.035 * mott)[..., None]
    blend(sstep((Z - 1.735) / 0.05), (0.93, 0.74, 0.62), 0.25)                     # lighter forehead
    for s in (1, -1):
        blend(g2(X - s * 0.046, Z - 1.640, 0.026, 0.022), (0.93, 0.50, 0.46), 0.26)  # cheek blush
        blend(g2(X - s * 0.031, Z - 1.675, 0.017, 0.0055), (0.60, 0.43, 0.47), 0.22)  # under-eye shadow
        blend(g2(X - s * 0.031, Z - 1.706, 0.016, 0.0045), (0.80, 0.52, 0.48), 0.20)  # lid colour
        blend(g2(X - s * 0.031, Z - 1.7005, 0.0135, 0.0011), (0.55, 0.34, 0.30), 0.35)  # lid crease
        blend(g2(X - s * 0.0095, Z - 1.6425, 0.0036, 0.0030), (0.30, 0.13, 0.12), 0.75)  # nostrils
        blend(g2(X - s * 0.0185, Z - 1.6505, 0.0070, 0.0065), (0.92, 0.52, 0.47), 0.18)  # nose wings
    blend(g2(X, Z - 1.654, 0.0105, 0.0085), (0.92, 0.50, 0.46), 0.22)                # nose tip
    blend(g2(X, Z - 1.627, 0.015, 0.0057), (0.72, 0.36, 0.37), 0.88)                 # upper lip
    blend(g2(X, Z - 1.6065, 0.0145, 0.0062), (0.79, 0.42, 0.42), 0.88)               # lower lip
    line = np.exp(-((Z - 1.6135) / 0.00085) ** 2) * np.exp(-(X / 0.0230) ** 4)
    blend(line, (0.34, 0.12, 0.13), 0.95)                                             # mouth line
    blend(g2(X, Z - 1.589, 0.012, 0.005), (0.78, 0.55, 0.50), 0.10)                  # chin
    img += rng.normal(0, 0.008, img.shape)                                             # fine grain
    for _ in range(22):                                                                # a few freckles
        fx, fz = rng.uniform(0.018, 0.058) * rng.choice((-1, 1)), rng.uniform(1.655, 1.690)
        blend(g2(X - fx, Z - fz, 0.0010, 0.0010), (0.70, 0.50, 0.38), 0.20)

    # eyebrows: individual hair strokes along an arch, thick at the inner end, tapering outward
    brow = np.zeros((S, S))
    brown = np.array([0.16, 0.09, 0.05])
    for s in (1, -1):
        for _ in range(380):
            t = rng.beta(1.15, 1.6)
            cx = s * (0.013 + 0.041 * t)
            cz = 1.7125 + 0.0095 * math.sin(math.pi * (t * 0.82 + 0.06)) - 0.0035 * t ** 2
            width = 0.0052 * (1 - t) + 0.0016
            px = cx + rng.normal(0, 0.0007)
            pz = cz + rng.uniform(-width / 2, width / 2)
            ang = math.radians(35 - 55 * t + rng.normal(0, 8))   # hairs sweep up, then lie flat outward
            ln = rng.uniform(0.0040, 0.0070)
            for k in np.linspace(0, 1, 9):
                hx = px + s * k * ln * math.cos(ang)
                hz = pz + k * ln * math.sin(ang)
                ix, iz = int((hx + 0.1) / 0.2 * S), int((hz - 1.56) / 0.26 * S)
                if 1 <= ix < S - 1 and 1 <= iz < S - 1:
                    brow[iz - 1:iz + 2, ix - 1:ix + 2] = np.maximum(brow[iz - 1:iz + 2, ix - 1:ix + 2], 0.8)
                    brow[iz, ix] = 1.0
    blend(brow, brown, 0.92)
    return img


# ----------------------------------------------------------------------------- eye texture
def paint_eye(size=512):
    """Azimuthal map of the front hemisphere: centre = pupil, radius 1 = 90 degrees away from the front."""
    S = size
    ys, xs = np.mgrid[0:S, 0:S]
    px = (xs + 0.5) / S * 2 - 1
    py = (ys + 0.5) / S * 2 - 1
    r = np.hypot(px, py)
    beta = np.arctan2(py, px)
    rng = np.random.default_rng(5)
    bins = rng.random(180)
    fib = np.interp(beta % (2 * math.pi), np.linspace(0, 2 * math.pi, 181)[:-1], bins, period=2 * math.pi)
    fib2 = np.interp((beta * 2.3) % (2 * math.pi), np.linspace(0, 2 * math.pi, 181)[:-1], bins[::-1], period=2 * math.pi)
    img = np.ones((S, S, 3)) * np.array([0.94, 0.92, 0.89])                            # sclera
    veins = np.clip(rng.normal(0, 1, (S, S)), 0, None) * sstep((r - 0.42) / 0.5) * 0.06
    img[..., 1] -= veins
    img[..., 2] -= veins * 1.2
    img *= (1 - 0.16 * sstep((r - 0.55) / 0.45))[..., None]                            # shaded toward the rim
    ir = 0.33                                                                          # iris radius
    iris = np.ones((S, S, 3))
    radial = sstep((r - 0.115) / (ir - 0.115))                                         # 0 at pupil, 1 at limbus
    inner = np.array([0.60, 0.40, 0.19])
    outer = np.array([0.30, 0.17, 0.08])
    iris = inner * (1 - radial[..., None]) + outer * radial[..., None]
    iris *= (0.72 + 0.5 * (0.6 * fib + 0.4 * fib2))[..., None]
    iris *= (1 - 0.55 * sstep((r - 0.285) / 0.045))[..., None]                         # dark limbal ring
    in_iris = sstep((ir + 0.006 - r) / 0.012)
    img = img * (1 - in_iris[..., None]) + iris * in_iris[..., None]
    pupil = sstep((0.112 - r) / 0.01)
    img = img * (1 - pupil[..., None]) + np.array([0.02, 0.02, 0.02]) * pupil[..., None]
    return img


# ----------------------------------------------------------------------------- the head
def build_head(arm, skin_img):
    """Sculpt the head mesh, cut the lid openings, add lid thickness, UVs and eyelid weights."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=6, radius=1.0)
    n = len(bm.verts)
    u = np.array([v.co[:] for v in bm.verts])
    A, B, C = HEAD_R
    t = np.clip(-u[:, 2], 0, 1)
    p = np.stack([u[:, 0] * A * (1 - 0.22 * t ** 1.6), u[:, 1] * B * (1 - 0.06 * t), u[:, 2] * C], 1)
    P = p + HEAD_C
    nrm = np.stack([u[:, 0] / A, u[:, 1] / B, u[:, 2] / C], 1)
    nrm /= np.linalg.norm(nrm, axis=1)[:, None]
    wf = sstep((-u[:, 1] - 0.10) / 0.5)
    rz = P[:, 2] - HEAD_C[2]
    ax = np.abs(P[:, 0])
    d = np.zeros(n)
    for _, fx, fz, sx, sz, amp, sym in FEATURES:
        dx = (ax - fx) if sym else (P[:, 0] - fx)
        d += amp * g2(dx, rz - fz, sx, sz)
    P[:, 1] -= wf * d       # forward displacement keeps x/z (and so the painted texture) registered
    # a few Laplacian passes: features are sharper than the mesh can shade cleanly
    bm.verts.index_update()
    ed = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges])
    val = np.bincount(ed.ravel(), minlength=n).astype(float)
    for _ in range(3):
        acc = np.zeros_like(P)
        np.add.at(acc, ed[:, 0], P[ed[:, 1]])
        np.add.at(acc, ed[:, 1], P[ed[:, 0]])
        P = P + 0.5 * (acc / val[:, None] - P)
    for i, v in enumerate(bm.verts):
        v.co = Vector(P[i])

    # eye openings: delete the faces inside a tilted almond around each eye
    def eye_metric(x, z, s):
        """1.0 on the lid opening's outline, <1 inside. Outer corner (away from the nose) sits higher."""
        dxm = s * (x - s * EYE_X)        # positive toward the outer corner
        dz = z - EYE_Z
        c, sn = math.cos(EYE_TILT), math.sin(EYE_TILT)
        lx = dxm * c + dz * sn
        lz = -dxm * sn + dz * c
        return np.sqrt((lx / EYE_A) ** 2 + (lz / EYE_B) ** 2)

    bm.faces.ensure_lookup_table()
    dead = []
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > -0.04:
            continue
        for s in (1, -1):
            if eye_metric(c.x, c.z, s) < 0.98:
                dead.append(f)
                break
    bmesh.ops.delete(bm, geom=dead, context="FACES")

    # lid rim: step the boundary of each opening back into the head to give the lids thickness
    bm.verts.ensure_lookup_table()
    boundary = [v for v in bm.verts if any(len(e.link_faces) == 1 for e in v.link_edges)]
    new_of = {}
    for v in boundary:
        s = 1 if v.co.x > 0 else -1
        cx, cz = s * EYE_X, EYE_Z
        toward = Vector((cx - v.co.x, 0.0, cz - v.co.z))
        toward.normalize()
        new_of[v.index] = bm.verts.new(v.co + Vector((0, 0.0032, 0)) + toward * 0.0010)
    for e in list(bm.edges):
        if len(e.link_faces) == 1 and e.verts[0].index in new_of and e.verts[1].index in new_of:
            a, b = e.verts
            try:
                bm.faces.new((a, b, new_of[b.index], new_of[a.index]))
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    rim_y = np.mean([v.co.y for v in boundary])
    mesh = _mesh_from_bm("HeadMesh", bm)

    # UVs: front planar projection onto the painted texture, clamped at the edges
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    uvs = np.stack([np.clip((co[:, 0] + 0.1) / 0.2, 0, 1), np.clip((co[:, 2] - 1.56) / 0.26, 0, 1)], 1)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    loop_v = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loop_v)
    uv_layer.data.foreach_set("uv", uvs[loop_v].ravel())

    head = _link("Head_mesh", mesh)
    skin_mat = image_material("SkinFace", skin_img, roughness=0.55)
    head.data.materials.append(skin_mat)

    # eyelid weights (upper lid follows LidUp, lower lid follows LidLo, the rest stays on Head)
    gs = {n_: head.vertex_groups.new(name=n_) for n_ in
          ("Head", "LidUp_L", "LidUp_R", "LidLo_L", "LidLo_R")}
    for v in mesh.vertices:
        x, y, z = co[v.index]
        wl = {"L": 0.0, "R": 0.0}
        wlo = {"L": 0.0, "R": 0.0}
        if y < 0.0:
            for s, suf in ((1, "L"), (-1, "R")):
                e = float(eye_metric(x, z, s))
                near = 1.0 - (e - 1.0) / 1.15
                if near > 0:
                    k = float(sstep(near))
                    if z > EYE_Z - 0.0012:
                        wl[suf] = k * float(sstep((z - EYE_Z + 0.0012) / 0.0035))
                    else:
                        wlo[suf] = 0.5 * k * float(sstep((EYE_Z - z - 0.0004) / 0.003))
        total = 0.0
        for suf in ("L", "R"):
            if wl[suf] > 0.003:
                gs[f"LidUp_{suf}"].add([v.index], wl[suf], "REPLACE")
            if wlo[suf] > 0.003:
                gs[f"LidLo_{suf}"].add([v.index], wlo[suf], "REPLACE")
            total += wl[suf] + wlo[suf]
        gs["Head"].add([v.index], max(0.0, 1.0 - total), "REPLACE")
    _attach(head, arm)
    return head, rim_y


# ----------------------------------------------------------------------------- eyes
def build_eyes(arm, eye_y, eye_img, eye_mat_roughness=0.1):
    """Eyeballs (textured, glossy), tear ducts and catch-lights. Returns the eyeball centres."""
    mat = image_material("EyeBall", eye_img, roughness=eye_mat_roughness, Coat_Weight=0.8, Coat_Roughness=0.03)
    pink = bpy.data.materials.new("Caruncle")
    pink.use_nodes = True
    pink.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.30, 0.28, 1)
    pink.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.5
    spark = bpy.data.materials.new("EyeSpark")
    spark.use_nodes = True
    sp = spark.node_tree.nodes["Principled BSDF"]
    sp.inputs["Base Color"].default_value = (1, 1, 1, 1)
    sp.inputs["Emission Color"].default_value = (1, 1, 1, 1)
    sp.inputs["Emission Strength"].default_value = 3.0
    centres = {}
    for s, suf in ((1, "L"), (-1, "R")):
        c = Vector((s * EYE_X, eye_y, EYE_Z))
        centres[suf] = c
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=28, radius=EYEBALL_R)
        for v in bm.verts:
            v.co = v.co + c
        uv_layer = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            for loop in f.loops:
                d = (loop.vert.co - c).normalized()
                alpha = math.acos(max(-1.0, min(1.0, -d.y)))
                r = min(1.0, alpha / (math.pi / 2))
                beta = math.atan2(d.z, d.x)
                loop[uv_layer].uv = (0.5 + 0.5 * r * math.cos(beta), 0.5 + 0.5 * r * math.sin(beta))
        mesh = _mesh_from_bm(f"EyeBall_{suf}", bm)
        o = _link(f"Eyeball_{suf}", mesh)
        o.data.materials.append(mat)
        _rigid(o, arm, f"Eye_{suf}")

        # tear duct at the inner corner and a catch-light on the cornea
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.0021)
        for v in bm.verts:
            v.co = Vector((v.co.x * 1.0, v.co.y * 0.7, v.co.z * 0.9)) + Vector((s * (EYE_X - 0.0125), eye_y - 0.0098, EYE_Z - 0.0006))
        m2 = _mesh_from_bm(f"Caruncle_{suf}", bm)
        o2 = _link(f"Caruncle_{suf}", m2)
        o2.data.materials.append(pink)
        _rigid(o2, arm, "Head")
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.0018)
        for v in bm.verts:
            v.co = Vector((v.co.x, v.co.y * 0.35, v.co.z)) + c + Vector((s * -0.0032, -EYEBALL_R - 0.0004, 0.0037))
        m3 = _mesh_from_bm(f"Spark_{suf}", bm)
        o3 = _link(f"Spark_{suf}", m3)
        o3.data.materials.append(spark)
        _rigid(o3, arm, f"Eye_{suf}")
    return centres


def build_lashes(arm, head, centres):
    """Upper lashes: tapered curved spikes along each upper lid rim, attached to the LidUp bone."""
    mat = bpy.data.materials.new("Lash")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.02, 0.012, 0.008, 1)
    b.inputs["Roughness"].default_value = 0.6
    rng = np.random.default_rng(2)
    co = np.array([v.co[:] for v in head.data.vertices])
    front = co[:, 1] < -0.04
    for s, suf in ((1, "L"), (-1, "R")):
        items = []
        for t in np.linspace(0.10, 0.97, 20):                  # inner corner -> outer corner
            lx = EYE_A * math.cos(math.pi * (1 - t))
            lz = EYE_B * math.sin(math.pi * (1 - t))
            x = s * EYE_X + s * lx
            z = EYE_Z + lz + lx * EYE_TILT
            dist = np.hypot(co[:, 0] - x, co[:, 2] - z)
            dist[~front] = 1e9
            base = Vector(co[int(np.argmin(dist))])
            out = Vector((s * (base.x - s * EYE_X) * s, 0.0, base.z - EYE_Z))
            out = Vector((base.x - s * EYE_X, 0.0, base.z - EYE_Z)).normalized()
            direction = Vector((out.x * 0.55, -0.80, out.z * 0.95 + 0.25)).normalized()
            length = rng.uniform(0.0045, 0.0065) * (0.65 + 0.7 * math.sin(math.pi * t))
            items.append((base, direction, length))
        bm = bmesh.new()
        for base, direction, length in items:
            side = direction.cross(Vector((0, 0, 1))).normalized() * 0.00035
            up = direction.cross(side).normalized() * 0.00035
            ring = [bm.verts.new(base + side), bm.verts.new(base - side * 0.5 + up), bm.verts.new(base - side * 0.5 - up)]
            tip = bm.verts.new(base + direction * length + Vector((0, 0, 1)) * length * 0.35)
            bm.faces.new((ring[0], ring[1], tip))
            bm.faces.new((ring[1], ring[2], tip))
            bm.faces.new((ring[2], ring[0], tip))
            bm.faces.new((ring[2], ring[1], ring[0]))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        o = _link(f"Lashes_{suf}", _mesh_from_bm(f"Lashes_{suf}", bm))
        o.data.materials.append(mat)
        _rigid(o, arm, f"LidUp_{suf}")


# ----------------------------------------------------------------------------- ears
def build_ears(arm, skin_img):
    mat = image_material("SkinEar", skin_img, roughness=0.55)
    for s in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
        for v in bm.verts:
            ux, uy, uz = v.co
            out = max(0.0, ux * s)                           # outward-facing side
            r = math.hypot(uy / 1.0, uz / 1.0)
            ring = math.exp(-((r - 0.80) / 0.13) ** 2)       # helix rim
            bowl = math.exp(-(r / 0.46) ** 2)                # concha
            anti = math.exp(-((r - 0.52) / 0.11) ** 2) * (1 if uz > -0.1 else 0.4)
            h = (0.0035 * ring - 0.0050 * bowl + 0.0018 * anti) * out ** 0.7
            x = ux * 0.0042 + s * h
            y = uy * 0.0185
            z = uz * 0.0300
            if uz < -0.45:                                   # soft lobe, hanging a touch lower
                z -= 0.004 * (-uz - 0.45) * 1.8
            y += 0.28 * z                                    # top of the ear leans back
            x += s * (0.0035 + 0.0085 * max(0.0, y / 0.0185)) # back edge stands off the head
            v.co = Vector((x, y, z)) + Vector((s * 0.0715, 0.012, 1.683))
        o = _link(f"Ear_{'L' if s == 1 else 'R'}", _mesh_from_bm("EarMesh", bm))
        o.data.materials.append(mat)
        uvs = None
        _rigid(o, arm, "Head")
        _front_uv(o)


def _front_uv(obj):
    mesh = obj.data
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    uvs = np.stack([np.clip((co[:, 0] + 0.1) / 0.2, 0, 1), np.clip((co[:, 2] - 1.56) / 0.26, 0, 1)], 1)
    layer = mesh.uv_layers.new(name="UVMap")
    lv = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", lv)
    layer.data.foreach_set("uv", uvs[lv].ravel())


# ----------------------------------------------------------------------------- hair
def _hair_end_theta(phi):
    """Polar angle (from the crown) where hair stops, by azimuth (0 = front, +-pi = back)."""
    a = abs((phi + math.pi) % (2 * math.pi) - math.pi)
    if a < 1.15:
        return 0.86 + 0.30 * (a / 1.15) ** 1.6
    if a < 1.95:
        return 1.16 + 0.14 * (a - 1.15) / 0.8
    return 1.30 + 0.55 * min(1.0, (a - 1.95) / 0.9)


def build_hair(arm, seed=4):
    rng = np.random.default_rng(seed)
    cols = [bpy.data.materials.new(f"Hair{i}") for i in range(3)]
    for m, c, r in zip(cols, ((0.095, 0.050, 0.028), (0.135, 0.075, 0.040), (0.070, 0.038, 0.022)), (0.42, 0.38, 0.45)):
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*c, 1)
        b.inputs["Roughness"].default_value = r
    c0 = HEAD_C + np.array([0.0, 0.003, 0.003])
    R = HEAD_R * np.array([1.095, 1.075, 1.045])

    def surf(theta, phi, lift):
        s = math.sin(theta)
        d = np.array([R[0] * s * math.sin(phi), -R[1] * s * math.cos(phi), R[2] * math.cos(theta)])
        nrm = np.array([d[0] / R[0] ** 2, d[1] / R[1] ** 2, d[2] / R[2] ** 2])
        nrm /= np.linalg.norm(nrm)
        return c0 + d + nrm * lift, nrm

    # scalp shell under the strands (so no skin shows through)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=5, radius=1.0)
    keep_geo = []
    for f in bm.faces:
        c = f.calc_center_median()
        theta = math.acos(max(-1, min(1, c.z)))
        phi = math.atan2(c.x, -c.y)
        if theta > _hair_end_theta(phi) - 0.04:
            keep_geo.append(f)
    bmesh.ops.delete(bm, geom=keep_geo, context="FACES")
    for v in bm.verts:
        d = v.co.copy()
        v.co = Vector(c0 + np.array([d.x * HEAD_R[0] * 1.045, d.y * HEAD_R[1] * 1.035, d.z * HEAD_R[2] * 1.025]))
    cap = _link("HairCap", _mesh_from_bm("HairCapMesh", bm))
    cap.data.materials.append(cols[2])
    _rigid(cap, arm, "Head")

    bm = bmesh.new()
    n_strands = 330
    for i in range(n_strands):
        phi0 = rng.uniform(-math.pi, math.pi)
        layer = rng.random()
        theta0 = rng.uniform(0.0, 0.55) if layer < 0.62 else rng.uniform(0.45, 0.95)
        sweep = (0.55 if phi0 > -0.15 else -0.35) if abs(phi0) < 1.2 else rng.normal(0, 0.15)   # side parting
        phi_end = phi0 + sweep * rng.uniform(0.5, 1.2) + rng.normal(0, 0.12)
        th_end = _hair_end_theta(phi_end) + rng.uniform(-0.05, 0.10)
        if th_end <= theta0 + 0.2:
            continue
        r0 = rng.uniform(0.0036, 0.0058)
        lift0 = rng.uniform(0.0015, 0.0075)
        samples = 9
        centers, normals = [], []
        for k in range(samples):
            t = k / (samples - 1)
            th = theta0 + (th_end - theta0) * t ** 0.9
            ph = phi0 + (phi_end - phi0) * t ** 1.2
            lift = lift0 + 0.0035 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.002 * t
            p, nr = surf(th, ph, lift)
            centers.append(p)
            normals.append(nr)
        ring_verts = []
        for k in range(samples):
            t = k / (samples - 1)
            tangent = (centers[min(k + 1, samples - 1)] - centers[max(k - 1, 0)])
            tangent /= np.linalg.norm(tangent) + 1e-9
            nrm = normals[k]
            side = np.cross(tangent, nrm)
            side /= np.linalg.norm(side) + 1e-9
            rad = r0 * (1.0 - 0.9 * t ** 1.25)
            ring = []
            for a in range(5):
                ang = 2 * math.pi * a / 5
                pos = centers[k] + rad * (math.cos(ang) * nrm * 0.65 + math.sin(ang) * side)
                ring.append(bm.verts.new(Vector(pos)))
            ring_verts.append(ring)
        mat_i = int(rng.integers(0, 3))
        try:
            bm.faces.new(ring_verts[0]).material_index = mat_i
        except ValueError:
            pass
        for k in range(samples - 1):
            for a in range(5):
                f = bm.faces.new((ring_verts[k][a], ring_verts[k][(a + 1) % 5],
                                  ring_verts[k + 1][(a + 1) % 5], ring_verts[k + 1][a]))
                f.material_index = mat_i
                f.smooth = True
        try:
            bm.faces.new(ring_verts[-1]).material_index = mat_i
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new("HairStrands")
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    o = _link("HairStrands", mesh)
    for m in cols:
        o.data.materials.append(m)
    _rigid(o, arm, "Head")
    return o


# ----------------------------------------------------------------------------- entry point
def build(arm):
    """Build the whole head; returns the eyeball centres so the rig can be aligned with them."""
    skin_img = make_image("FaceSkin", paint_skin(1024))
    eye_img = make_image("EyeTex", paint_eye(512))
    head, rim_y = build_head(arm, skin_img)
    centres = build_eyes(arm, rim_y + 0.0100, eye_img)
    build_lashes(arm, head, centres)
    build_ears(arm, skin_img)
    build_hair(arm)
    return centres
