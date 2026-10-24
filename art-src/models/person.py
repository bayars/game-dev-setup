"""The walker: a rigged, animated stylised person (about 1.78 m).

Build order: skeleton -> smooth skinned body (Skin modifier on a stick figure: torso, limbs, hands with
fingers) -> clothes zones -> auto weights -> head (face.py: sculpted face, rigged eyelids, eyes, ears, strand hair) -> clothes details and shoes
-> actions (idle_loop, walk_loop, run_loop, open_door) -> glTF export -> pose-sheet previews.

Left/right are the character's own: Left is +X. The character faces -Y (+Z in glTF/Godot).
Bones: Hips Spine Chest Neck Head Eye_L/R LidUp_L/R LidLo_L/R Clavicle/UpperArm/Forearm/Hand _L/_R and
UpperLeg/LowerLeg/Foot/Toes _L/_R. Actions that end in `_loop` loop in Godot.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import common
from common import *

# "walker" (Walk Home: scarf and backpack) or "worker" (Off the Books: tool belt, no backpack); set by worker.py
VARIANT = os.environ.get("PERSON_VARIANT", "walker")

reset()
scene = bpy.context.scene
scene.render.fps = 30

# --------------------------------------------------------------------------- materials
SKIN = mat("Skin", "#E2AE8B", roughness=0.55)
JACKET = mat("Jacket", "#1C8D95", roughness=0.85)
JACKET_DK = mat("JacketDark", "#14666C", roughness=0.8)
PANTS = mat("Pants", "#2D3652", roughness=0.85)
SHOE = mat("Shoe", "#3B2A22", roughness=0.5)
SOLE = mat("Sole", "#ECE7DC", roughness=0.8)
LACE = mat("Lace", "#F5F2EA", roughness=0.7)
HAIR = mat("Hair", "#2A160B", roughness=0.45)
SCARF = mat("Scarf", "#E8A31F", roughness=0.9)
SCARF_DK = mat("ScarfStripe", "#B8741A", roughness=0.9)
PACK = mat("Pack", "#8C4B22", roughness=0.85)
STRAP = mat("Strap", "#52301A", roughness=0.9)
ZIP = mat("Zip", "#C9CED4", metallic=1.0, roughness=0.35)
WHITE = mat("EyeWhite", "#F6F6F2", roughness=0.25)
IRIS = mat("Iris", "#4B2D18", roughness=0.25)
PUPIL = mat("Pupil", "#050505", roughness=0.2)
SPARK = mat("EyeSpark", "#FFFFFF", roughness=0.1, emission="#FFFFFF", strength=3.0)
LASH = mat("Lash", "#1A0E08", roughness=0.6)
LIP = mat("Lip", "#A84C4A", roughness=0.5)

# --------------------------------------------------------------------------- skeleton
BONES = [
    ("Hips", (0, 0, .93), (0, 0, 1.05), None),
    ("Spine", (0, 0, 1.05), (0, 0, 1.25), "Hips"),
    ("Chest", (0, 0, 1.25), (0, 0, 1.45), "Spine"),
    ("Neck", (0, 0, 1.45), (0, 0, 1.58), "Chest"),
    ("Head", (0, 0, 1.58), (0, 0, 1.80), "Neck"),
]
for sx, suf in ((1, "L"), (-1, "R")):
    BONES += [
        (f"Clavicle_{suf}", (sx * .03, 0, 1.43), (sx * .17, 0, 1.43), "Chest"),
        (f"UpperArm_{suf}", (sx * .17, 0, 1.43), (sx * .32, 0, 1.17), f"Clavicle_{suf}"),
        (f"Forearm_{suf}", (sx * .32, 0, 1.17), (sx * .44, -.03, .93), f"UpperArm_{suf}"),
        (f"Hand_{suf}", (sx * .44, -.03, .93), (sx * .48, -.04, .76), f"Forearm_{suf}"),
        (f"UpperLeg_{suf}", (sx * .10, 0, .905), (sx * .10, 0, .50), "Hips"),
        (f"LowerLeg_{suf}", (sx * .10, 0, .50), (sx * .10, 0, .09), f"UpperLeg_{suf}"),
        (f"Foot_{suf}", (sx * .10, 0, .09), (sx * .10, -.14, .035), f"LowerLeg_{suf}"),
        (f"Toes_{suf}", (sx * .10, -.14, .035), (sx * .10, -.22, .02), f"Foot_{suf}"),
        (f"Eye_{suf}", (sx * .031, -.078, 1.690), (sx * .031, -.078, 1.702), "Head"),
        (f"LidUp_{suf}", (sx * .031, -.078, 1.690), (sx * .031, -.078, 1.700), "Head"),
        (f"LidLo_{suf}", (sx * .031, -.078, 1.690), (sx * .031, -.078, 1.700), "Head"),
    ]

arm_data = bpy.data.armatures.new("PersonRig")
arm = bpy.data.objects.new("Person", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, head, tail, parent in BONES:
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
arm_data.display_type = "STICK"


# --------------------------------------------------------------------------- helpers
def seg_dist(p, a, b):
    a, b, p = Vector(a), Vector(b), Vector(p)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def make_object(name, mesh):
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    return o


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def finalize(obj):
    """Apply modifiers so the object can be joined and weighted."""
    activate(obj)
    if obj.type != "MESH" or obj.modifiers:
        bpy.ops.object.convert(target="MESH")
    return obj


def join(objs, name):
    objs = [finalize(o) for o in objs]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def bind_rigid(objs, bone, name):
    """Join `objs` into one mesh weighted 100% to `bone` (a rigid part of the skeleton)."""
    o = join(objs, name)
    vg = o.vertex_groups.new(name=bone)
    vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    m = o.modifiers.new("Armature", "ARMATURE")
    m.object = arm
    o.parent = arm
    return o


def torus(name, major, minor, loc, material, rot=(0, 0, 0), scale=(1, 1, 1), mseg=32, nseg=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=mseg, minor_segments=nseg)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(60))
    o.name = name
    o.data.materials.append(material)
    o.location = loc
    o.rotation_euler = rot
    return o


def aligned_rot(direction):
    """Euler that turns the +Z axis of a primitive onto `direction`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_euler()


# --------------------------------------------------------------------------- body (Skin modifier)
verts, radii, edges = [], [], []


def V(x, y, z, r):
    verts.append((x, y, z))
    radii.append(r)
    return len(verts) - 1


def E(a, b):
    edges.append((a, b))


pel = V(0, 0, .93, .155)
wst = V(0, 0, 1.10, .14)
che = V(0, 0, 1.28, .16)
upc = V(0, 0, 1.42, .165)
nk0 = V(0, 0, 1.50, .055)
nk1 = V(0, 0, 1.585, .05)
E(pel, wst); E(wst, che); E(che, upc); E(upc, nk0); E(nk0, nk1)

hand_tips = {}
for sx in (1, -1):
    sh = V(sx * .17, 0, 1.43, .056)
    ua = V(sx * .245, 0, 1.30, .05)
    el = V(sx * .32, 0, 1.17, .042)
    fa = V(sx * .38, -.015, 1.05, .037)
    wr = V(sx * .44, -.03, .93, .029)
    E(upc, sh); E(sh, ua); E(ua, el); E(el, fa); E(fa, wr)
    w = Vector((sx * .44, -.03, .93))
    d = Vector((sx * .04, -.01, -.17)).normalized()
    palm = V(*(w + d * .05), .027)
    pend_pos = w + d * .095
    pend = V(*pend_pos, .023)
    E(wr, palm); E(palm, pend)
    tips = []
    for oy, ln in ((-.022, .074), (-.007, .082), (.008, .078), (.022, .062)):   # index, middle, ring, little
        base = pend_pos + Vector((0, oy, 0))
        tip = base + d * ln + Vector((-sx * .013, -.006, 0))
        fb = V(*base, .0095)
        ft = V(*tip, .0075)
        E(pend, fb); E(fb, ft)
        tips.append(tip)
    tb = (w + d * .04) + Vector((-sx * .004, -.026, 0))
    tt = tb + Vector((-sx * .006, -.04, -.036))
    t0 = V(*tb, .0125)
    t1 = V(*tt, .0085)
    E(palm, t0); E(t0, t1)
    hand_tips[sx] = (w, d, tips)

    hp = V(sx * .10, 0, .905, .092)
    th = V(sx * .10, 0, .72, .082)
    kn = V(sx * .10, .005, .50, .056)
    cf = V(sx * .10, .012, .33, .055)
    an = V(sx * .10, 0, .10, .038)
    E(pel, hp); E(hp, th); E(th, kn); E(kn, cf); E(cf, an)

mesh = bpy.data.meshes.new("BodyMesh")
mesh.from_pydata(verts, edges, [])
body = make_object("Body", mesh)
skin_mod = body.modifiers.new("Skin", "SKIN")
skin_mod.use_smooth_shade = True
skin_mod.branch_smoothing = 0.6
for i, r in enumerate(radii):
    body.data.skin_vertices[0].data[i].radius = (r, r)
body.data.skin_vertices[0].data[pel].use_root = True
sub = body.modifiers.new("Subsurf", "SUBSURF")
sub.levels = sub.render_levels = 2
finalize(body)

# torso and pelvis are wider than deep: flatten front-back (skin radii are isotropic)
for v in body.data.vertices:
    x, y, z = v.co
    if abs(x) < .24 and .88 < z < 1.53:
        edge = min(1.0, (0.24 - abs(x)) / 0.05, (z - .88) / .06, (1.53 - z) / .05)
        v.co.y = y * (1.0 - 0.24 * edge)
        v.co.x = x * (1.0 + 0.10 * edge)
body.data.update()

# --- clothing zones: nearest body segment decides skin / jacket / pants
SEGS = [((0, 0, .93), (0, 0, 1.42), 1), ((0, 0, 1.49), (0, 0, 1.6), 0)]
for sx in (1, -1):
    w, d, tips = hand_tips[sx]
    SEGS += [((sx * .17, 0, 1.43), (sx * .32, 0, 1.17), 1), ((sx * .32, 0, 1.17), (sx * .44, -.03, .93), 1),
             (tuple(w + d * .012), tuple(w + d * .19), 0)]
    SEGS += [((sx * .10, 0, .905), (sx * .10, 0, .5), 2), ((sx * .10, 0, .5), (sx * .10, 0, .1), 2)]
body.data.materials.append(SKIN)
body.data.materials.append(JACKET)
body.data.materials.append(PANTS)
for poly in body.data.polygons:
    c = poly.center
    best = min(SEGS, key=lambda s: seg_dist(c, s[0], s[1]))
    idx = best[2]
    if idx == 1 and best[0] == (0, 0, .93) and c.z < .92:
        idx = 2
    poly.material_index = idx
    poly.use_smooth = True

# --- auto weights (eyes are not deforming the body)
FACE_BONES = [f"{n}_{suf}" for n in ("Eye", "LidUp", "LidLo") for suf in ("L", "R")]
for n in FACE_BONES:
    arm_data.bones[n].use_deform = False
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
for n in FACE_BONES:
    arm_data.bones[n].use_deform = True

# any vertex the heat solver missed goes to the nearest bone
missing = 0
bone_segs = {b[0]: (b[1], b[2]) for b in BONES}
for v in body.data.vertices:
    if not any(g.weight > 0.001 for g in v.groups):
        missing += 1
        nearest = min((n for n in bone_segs if n not in FACE_BONES), key=lambda n: seg_dist(v.co, *bone_segs[n]))
        vg = body.vertex_groups.get(nearest) or body.vertex_groups.new(name=nearest)
        vg.add([v.index], 1.0, "REPLACE")
print("BODY verts", len(body.data.vertices), "unweighted fixed", missing)

# --------------------------------------------------------------------------- head and face (face.py)
import face

eye_centres = face.build(arm)
# the eye and eyelid bones pivot on the real eyeball centres
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for suf, c in eye_centres.items():
    for name, up in ((f"Eye_{suf}", .012), (f"LidUp_{suf}", .010), (f"LidLo_{suf}", .010)):
        eb = arm_data.edit_bones[name]
        eb.head = c
        eb.tail = c + Vector((0, 0, up))
bpy.ops.object.mode_set(mode="OBJECT")

# --------------------------------------------------------------------------- clothes details
# collar, scarf (two wraps, knot, tail), zipper, pockets, hem, cuffs: rigid on Chest/Hips/forearms
chest_parts = [
    torus("Collar", .078, .02, (0, .005, 1.505), JACKET_DK, scale=(1.05, .95, .65)),
    box("Zipper", (.012, .006, .36), Vector((0, -.123, 1.245)), ZIP, bevel=.002),
    box("ZipPull", (.018, .008, .03), Vector((0, -.127, 1.425)), ZIP, bevel=.003),
    box("PocketL", (.075, .014, .085), Vector((.09, -.106, 1.06)), JACKET_DK, bevel=.006, rot=(.1, 0, .12)),
    box("PocketR", (.075, .014, .085), Vector((-.09, -.106, 1.06)), JACKET_DK, bevel=.006, rot=(.1, 0, -.12)),
    box("PocketFlapL", (.08, .016, .022), Vector((.09, -.108, 1.1)), JACKET_DK, bevel=.005, rot=(.1, 0, .12)),
    box("PocketFlapR", (.08, .016, .022), Vector((-.09, -.108, 1.1)), JACKET_DK, bevel=.005, rot=(.1, 0, -.12)),
]
if VARIANT == "walker":
    chest_parts += [
        torus("ScarfWrap1", .082, .026, (0, 0, 1.545), SCARF, scale=(1.0, .95, .85)),
        torus("ScarfWrap2", .088, .024, (0, -.004, 1.51), SCARF_DK, rot=(.18, 0, 0), scale=(1.0, .95, .85)),
        sphere("ScarfKnot", .036, Vector((.05, -.088, 1.505)), SCARF, scale=(1.0, .8, 1.0)),
        box("ScarfTail", (.075, .016, .3), Vector((.058, -.108, 1.345)), SCARF, bevel=.006, rot=(.06, 0, -.07)),
        box("ScarfTailStripe", (.075, .018, .03), Vector((.058, -.108, 1.23)), SCARF_DK, bevel=.004, rot=(.06, 0, -.07)),
        box("ScarfTail2", (.07, .016, .22), Vector((.025, -.104, 1.395)), SCARF, bevel=.006, rot=(.1, 0, .12)),
        # backpack and straps
        box("Backpack", (.31, .15, .40), Vector((0, .18, 1.24)), PACK, bevel=.05),
        box("PackFlap", (.31, .16, .12), Vector((0, .185, 1.4)), STRAP, bevel=.04),
        box("PackPocket", (.22, .05, .17), Vector((0, .27, 1.17)), PACK, bevel=.03),
        box("PackBuckle", (.03, .012, .04), Vector((0, .27, 1.31)), ZIP, bevel=.003),
        box("PackRoll", (.3, .07, .07), Vector((0, .175, 1.05)), STRAP, bevel=.03),
    ]
    for sx in (1, -1):
        chest_parts += [
            box("StrapTop", (.045, .22, .012), Vector((sx * .105, .005, 1.50)), STRAP, bevel=.003, rot=(.0, 0, 0)),
            box("StrapFront", (.045, .012, .3), Vector((sx * .105, -.112, 1.35)), STRAP, bevel=.003),
            box("StrapBack", (.045, .012, .26), Vector((sx * .105, .108, 1.36)), STRAP, bevel=.003),
            box("StrapLow", (.045, .02, .1), Vector((sx * .105, .128, 1.215)), STRAP, bevel=.003),
        ]
bind_rigid(chest_parts, "Chest", "Chest_parts")

hips_parts = [torus("Hem", .162, .014, (0, 0, .935), JACKET_DK, scale=(1.0, .76, 1.0), mseg=48),
              torus("Belt", .158, .012, (0, 0, .91), STRAP, scale=(1.0, .76, 1.0), mseg=48)]
if VARIANT == "worker":
    # tool belt: wide leather belt, two rounded pouches on the hips, a tape measure clipped at the back
    hips_parts += [torus("ToolBelt", .166, .022, (0, 0, .905), STRAP, scale=(1.0, .78, 1.6), mseg=48)]
    for sx in (1, -1):
        hips_parts += [
            box("Pouch", (.06, .13, .15), Vector((sx * .175, -.02, .83)), PACK, bevel=.025, rot=(0, sx * .08, 0)),
            box("PouchFlap", (.064, .135, .035), Vector((sx * .178, -.02, .9)), STRAP, bevel=.012),
            cyl("PouchTool", .009, .1, Vector((sx * .18, -.06, .93)), ZIP, verts=8),
        ]
    hips_parts += [cyl("BeltTape", .032, .028, Vector((0, .135, .88)), mat("TapeCase", "#E2B21C", roughness=.4),
                       rot=(math.pi / 2, 0, 0))]
bind_rigid(hips_parts, "Hips", "Hips_parts")

for sx, suf in ((1, "L"), (-1, "R")):
    w, d, tips = hand_tips[sx]
    cuff = torus(f"Cuff_{suf}", .037, .0125, tuple(w + Vector((0, 0, .012))), JACKET_DK,
                 rot=aligned_rot((sx * .12, -.03, -.24)))
    bind_rigid([cuff], f"Forearm_{suf}", f"Cuff_{suf}_part")

# shoes: upper, toe cap, sole, laces, heel on the Foot bones
for sx, suf in ((1, "L"), (-1, "R")):
    x = sx * .10
    sp_ = [box("ShoeUpper", (.098, .27, .085), (x, -.045, .065), SHOE, bevel=.03),
           box("ShoeAnkle", (.085, .1, .1), (x, .02, .12), SHOE, bevel=.03),
           sphere("ToeCap", .05, (x, -.14, .055), SHOE, scale=(.92, 1.0, .7)),
           box("ShoeSole", (.103, .285, .026), (x, -.047, .013), SOLE, bevel=.008),
           box("Heel", (.09, .06, .03), (x, .06, .032), SOLE, bevel=.008),
           box("Tongue", (.05, .07, .02), (x, -.025, .122), SHOE, bevel=.006, rot=(-.5, 0, 0))]
    for i in range(3):
        sp_.append(box("Lace", (.062, .012, .008), (x, -.07 + i * .03, .112 + i * .005), LACE, bevel=.002))
    bind_rigid(sp_, f"Foot_{suf}", f"Shoe_{suf}_parts")

# --------------------------------------------------------------------------- animation
FPS = 30


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def clamp01(x):
    return max(0.0, min(1.0, x))


def reset_pose():
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)


class Pose:
    """Accumulates world-axis rotations (radians) per bone; XYZ order, X applied first."""

    def __init__(self):
        self.rot = {}
        self.loc = {}
        self.scale = {}

    def r(self, bone, x=0.0, y=0.0, z=0.0):
        a = self.rot.get(bone, (0.0, 0.0, 0.0))
        self.rot[bone] = (a[0] + x, a[1] + y, a[2] + z)

    def l(self, bone, x=0.0, y=0.0, z=0.0):
        a = self.loc.get(bone, (0.0, 0.0, 0.0))
        self.loc[bone] = (a[0] + x, a[1] + y, a[2] + z)

    def s(self, bone, x=1.0, y=1.0, z=1.0):
        self.scale[bone] = (x, y, z)


def apply_pose(p, frame):
    reset_pose()
    for name, e in p.rot.items():
        pb = arm.pose.bones[name]
        r3 = pb.bone.matrix_local.to_3x3()
        pb.rotation_quaternion = (r3.inverted() @ Euler(e, "XYZ").to_matrix() @ r3).to_quaternion()
    for name, d in p.loc.items():
        pb = arm.pose.bones[name]
        pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(d)
    for name, s in p.scale.items():
        arm.pose.bones[name].scale = s
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "Hips":
            pb.keyframe_insert("location", frame=frame)


def make_action(name, frames, fn, loop=True):
    act = bpy.data.actions.new(name)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    last = frames + 1 if loop else frames
    for f in range(last):
        t = (f % frames) / frames if loop else f / (frames - 1)
        apply_pose(fn(t), f)
    act.use_fake_user = True
    if loop:
        act.use_frame_range = True
        act.frame_start, act.frame_end = 0, frames - 1
    return act


ARM_IN = 0.34   # relaxed arms hang closer to the body than the modelling A-pose


def blink(p, t, at, width=0.05):
    """Close both eyes with the eyelid bones around cycle phase `at`."""
    d = abs(((t - at + 0.5) % 1.0) - 0.5)
    k = 1.0 - smooth(d / width)
    for suf in ("L", "R"):
        p.r(f"LidUp_{suf}", x=0.64 * k)
        p.r(f"LidLo_{suf}", x=-0.16 * k)


def idle(t):
    p = Pose()
    a = 2 * math.pi * t
    breath = math.sin(a)
    p.r("Chest", x=.02 + .016 * breath)
    p.r("Spine", x=.012 + .006 * breath)
    p.r("Neck", x=-.02 - .01 * breath)
    p.r("Head", x=-.012 + .02 * math.sin(a + 1.0), z=.045 * math.sin(a))
    p.r("Clavicle_L", z=.02 * breath)
    p.r("Clavicle_R", z=-.02 * breath)
    p.l("Hips", x=.012 * math.sin(a), z=-.006 + .004 * breath)
    p.r("Hips", y=.02 * math.sin(a), z=.02 * math.sin(a + .5))
    p.r("UpperArm_L", x=.05 * math.sin(a + .5), y=ARM_IN)
    p.r("UpperArm_R", x=-.04 * math.sin(a + 1.2), y=-ARM_IN)
    p.r("Forearm_L", x=-.14 - .02 * breath)
    p.r("Forearm_R", x=-.16 - .02 * breath)
    p.r("Hand_L", x=-.06)
    p.r("Hand_R", x=-.06)
    p.r("UpperLeg_L", x=-.01, z=.04)
    p.r("UpperLeg_R", x=.0, z=-.04)
    p.r("LowerLeg_L", x=.03)
    p.r("LowerLeg_R", x=.025)
    blink(p, t, .62)
    return p


def gait(p, phi, swing, flex, arm_swing, arm_flex, lean, bob, yaw, hip_roll, speed_gain=1.0):
    """Shared walk/run pose for cycle phase phi (radians)."""
    for suf, ph in (("L", phi), ("R", phi + math.pi)):
        s, c = math.sin(ph), math.cos(ph)
        hip = -swing * s - 0.03
        knee = 0.08 + flex * max(0.0, c) ** 2 + .3 * flex * max(0.0, -s) ** 3
        foot = -(hip + knee) - .25 * max(0.0, s) ** 3 + .55 * max(0.0, -s) ** 3 * speed_gain
        p.r(f"UpperLeg_{suf}", x=hip, z=.035 if suf == "L" else -.035)
        p.r(f"LowerLeg_{suf}", x=knee)
        p.r(f"Foot_{suf}", x=foot)
        p.r(f"Toes_{suf}", x=.3 * max(0.0, -s) ** 3)
        # arms swing opposite to the leg on the same side
        side = 1.0 if suf == "L" else -1.0
        asw = arm_swing * s
        p.r(f"UpperArm_{suf}", x=asw, y=side * ARM_IN * (1.0 if arm_flex < .6 else .35))
        p.r(f"Forearm_{suf}", x=-(arm_flex * .6 + arm_flex * .6 * max(0.0, -s)))
        p.r(f"Hand_{suf}", x=-.1)
        p.r(f"Clavicle_{suf}", z=side * .025 * s)
    p.l("Hips", x=.014 * math.sin(phi), z=bob * math.cos(2 * phi) - bob * .5)
    p.r("Hips", x=lean * .5, y=hip_roll * math.cos(phi), z=-yaw * math.sin(phi))
    p.r("Spine", x=lean * .3, y=-hip_roll * .5 * math.cos(phi), z=yaw * .55 * math.sin(phi))
    p.r("Chest", x=lean * .3, z=yaw * .6 * math.sin(phi))
    p.r("Neck", x=-lean * .25, z=-yaw * .3 * math.sin(phi))
    p.r("Head", x=-lean * .35 + .015 * math.cos(2 * phi), z=-yaw * .25 * math.sin(phi))


def walk(t):
    p = Pose()
    gait(p, 2 * math.pi * t, swing=.52, flex=.72, arm_swing=.42, arm_flex=.42, lean=.07, bob=.03, yaw=.10,
         hip_roll=.035)
    blink(p, t, .8)
    return p


def run(t):
    p = Pose()
    gait(p, 2 * math.pi * t, swing=.85, flex=1.25, arm_swing=.85, arm_flex=1.35, lean=.24, bob=.055, yaw=.16,
         hip_roll=.03, speed_gain=1.4)
    return p


def open_door(t):
    """Stops, reaches the right hand to the knob, pushes, and leaves the arm out (blends back to idle)."""
    p = idle(t * 0.4)
    reach = smooth(t / 0.30) * (1.0 - smooth((t - 0.92) / 0.08) * 0.15)
    push = smooth((t - 0.45) / 0.35)
    lean = .10 * reach + .06 * push
    p.r("Hips", x=lean * .4, z=.05 * reach)
    p.l("Hips", y=-.04 * push, z=-.015 * reach)
    p.r("Spine", x=lean * .5, z=.06 * reach)
    p.r("Chest", x=lean * .5, z=.07 * reach)
    p.r("Neck", x=.05 * reach)
    p.r("Head", x=.10 * reach, z=-.05 * reach)
    # right arm: forward and slightly in, elbow flexing as it pushes
    p.r("Clavicle_R", z=-.04 * reach)
    p.r("UpperArm_R", x=-.86 * reach - .16 * push, y=ARM_IN * reach, z=.46 * reach)
    p.r("Forearm_R", x=-.55 * reach + .25 * push)
    p.r("Hand_R", x=-.22 * reach)
    # left arm drifts forward a little for balance
    p.r("UpperArm_L", x=-.25 * reach)
    p.r("Forearm_L", x=-.2 * reach)
    # a small step in on the right leg while pushing
    p.r("UpperLeg_R", x=-.18 * push)
    p.r("LowerLeg_R", x=.12 * push)
    p.r("Foot_R", x=.06 * push)
    p.r("UpperLeg_L", x=.05 * push)
    return p


# ---- work and carry clips (Off the Books). Arms: negative X swings forward/up; a right arm swings in
# with +Z, a left arm with -Z. Child rotations add to the parent's (a knee bend is relative to the thigh).


def arms_out(p, suf, fwd, inward, elbow, hand=0.0, spread=0.0):
    side = 1.0 if suf == "L" else -1.0
    p.r(f"UpperArm_{suf}", x=-fwd, y=side * ARM_IN * (1.0 - spread), z=-side * inward)
    p.r(f"Forearm_{suf}", x=-elbow)
    p.r(f"Hand_{suf}", x=hand)


def carry(t):
    """Walking with a heavy load held low in front with both hands (pair carry)."""
    p = Pose()
    phi = 2 * math.pi * t
    gait(p, phi, swing=.42, flex=.6, arm_swing=0.0, arm_flex=0.0, lean=.1, bob=.025, yaw=.04, hip_roll=.04)
    for suf in ("L", "R"):
        p.rot[f"UpperArm_{suf}"] = (0.0, 0.0, 0.0)
        p.rot[f"Forearm_{suf}"] = (0.0, 0.0, 0.0)
        arms_out(p, suf, .55 + .03 * math.sin(2 * phi), .32, .95, hand=.15)
        p.r(f"Clavicle_{suf}", y=.08 if suf == "L" else -.08)
    p.r("Spine", x=-.05)
    p.r("Chest", x=-.06)
    blink(p, t, .3)
    return p


def drag(t):
    """Pushing and dragging a heavy load alone: bent over, short heavy steps, arms reaching low."""
    p = Pose()
    phi = 2 * math.pi * t
    gait(p, phi, swing=.3, flex=.55, arm_swing=0.0, arm_flex=0.0, lean=.55, bob=.02, yaw=.03, hip_roll=.05)
    heave = .5 + .5 * math.sin(2 * phi)
    for suf in ("L", "R"):
        p.rot[f"UpperArm_{suf}"] = (0.0, 0.0, 0.0)
        p.rot[f"Forearm_{suf}"] = (0.0, 0.0, 0.0)
        arms_out(p, suf, .75 + .1 * heave, .22, .35 + .1 * heave, hand=.3)
    p.r("UpperLeg_L", x=-.08)
    p.r("UpperLeg_R", x=-.08)
    p.r("LowerLeg_L", x=.16)
    p.r("LowerLeg_R", x=.16)
    p.l("Hips", z=-.05)
    p.r("Head", x=-.25)
    blink(p, t, .6)
    return p


def stance(p, t, crouch=0.0):
    """Feet apart, knees a little bent, weight shifting slowly (base for standing work)."""
    a = 2 * math.pi * t
    p.r("UpperLeg_L", x=-.08 - crouch, z=.1)
    p.r("UpperLeg_R", x=.06 - crouch, z=-.1)
    p.r("LowerLeg_L", x=.14 + crouch * 2)
    p.r("LowerLeg_R", x=.1 + crouch * 2)
    p.r("Foot_L", x=-.06 - crouch)
    p.r("Foot_R", x=-.16 - crouch)
    p.l("Hips", x=.01 * math.sin(a), z=-.02 - crouch * .18)
    p.r("Chest", x=.02 * math.sin(a))


def hammer(t):
    """Left hand steadies, right arm lifts the hammer and strikes at chest height."""
    p = Pose()
    stance(p, t)
    up = smooth(t / .5) * (1.0 - smooth((t - .56) / .1))
    hit = math.exp(-((t - .66) / .04) ** 2)
    p.r("Spine", x=.1, z=-.06)
    p.r("Chest", x=.06 + .03 * hit, z=-.08 + .05 * up)
    p.r("Head", x=.08)
    arms_out(p, "L", 1.15, .45, .7, hand=-.1)
    arms_out(p, "R", .8 + .75 * up, .35 - .1 * up, .55 + 1.15 * up, hand=.35 * up - .2 * hit)
    p.r("Clavicle_R", y=-.1 * up)
    blink(p, t, .2)
    return p


def drill(t, low=False):
    """Both hands on a drill or screwdriver held at chest height against a wall, pushing in pulses."""
    p = Pose()
    stance(p, t)
    a = 2 * math.pi * t
    push = .5 + .5 * math.sin(a * 2)
    buzz = .012 * math.sin(a * 24)
    p.r("Spine", x=.12 + .04 * push)
    p.r("Chest", x=.05 + buzz, z=-.05)
    p.r("Head", x=.04)
    arms_out(p, "R", 1.25 + .08 * push, .42, .85 - .2 * push, hand=-.15 + buzz * 4)
    arms_out(p, "L", 1.1 + .06 * push, .5, .95 - .15 * push, hand=-.1)
    blink(p, t, .7)
    return p


def lift(t):
    """Holding a big sheet up against the studs: arms raised in front, braced, a slow sway."""
    p = Pose()
    stance(p, t, crouch=.05)
    a = 2 * math.pi * t
    sway = math.sin(a)
    p.r("Spine", x=-.04, z=.03 * sway)
    p.r("Chest", x=-.06)
    p.r("Neck", x=-.08)
    p.r("Head", x=-.16)
    arms_out(p, "L", 2.05 + .05 * sway, .25, .55, hand=.5, spread=.3)
    arms_out(p, "R", 2.05 - .05 * sway, .25, .55, hand=.5, spread=.3)
    blink(p, t, .45)
    return p


def kneel_base(p):
    """One knee down: left foot planted in front, right knee on the floor."""
    p.l("Hips", y=.06, z=-.47)
    p.r("UpperLeg_L", x=-1.45, z=.06)
    p.r("LowerLeg_L", x=1.5)
    p.r("Foot_L", x=-.05)
    p.r("UpperLeg_R", x=-.08, z=-.05)
    p.r("LowerLeg_R", x=1.62)
    p.r("Foot_R", x=.55)
    p.r("Toes_R", x=-.6)


def kneel(t):
    """Kneeling floor work: the right hand taps (mallet on the planks), the left presses the floor."""
    p = Pose()
    kneel_base(p)
    tap = abs(math.sin(2 * math.pi * t * 2))
    p.r("Spine", x=.42)
    p.r("Chest", x=.25)
    p.r("Head", x=.12)
    arms_out(p, "L", .55, .3, .25, hand=.2)
    arms_out(p, "R", .55 + .35 * tap, .3, .55 + .4 * tap, hand=-.1)
    blink(p, t, .5)
    return p


def wire(t):
    """Kneeling at an outlet near the floor: both hands forward at low height, small twists."""
    p = Pose()
    kneel_base(p)
    a = 2 * math.pi * t
    twist = math.sin(a * 3)
    p.r("Spine", x=.22)
    p.r("Chest", x=.1)
    p.r("Head", x=.12)
    arms_out(p, "R", 1.05, .45, .7, hand=.12 * twist)
    arms_out(p, "L", 1.0, .5, .8, hand=-.08)
    p.r("Forearm_R", y=.25 * twist)
    blink(p, t, .2)
    return p


def talk(t):
    """Idle with the right hand gesturing and small nods."""
    p = idle(t)
    a = 2 * math.pi * t
    g = smooth((math.sin(a * 2) + 1) / 2)
    p.r("UpperArm_R", x=-.35 - .12 * g, z=.15)
    p.r("Forearm_R", x=-.9 - .2 * g, y=-.3 * g)
    p.r("Hand_R", x=.2, z=.2 * g)
    p.r("Head", x=.05 * math.sin(a * 3), z=.04 * math.sin(a * 2))
    return p


act_idle = make_action("idle_loop", 90, idle, True)
act_walk = make_action("walk_loop", 33, walk, True)
act_run = make_action("run_loop", 21, run, True)
act_door = make_action("open_door", 54, open_door, False)
WORK_ACTIONS = [("carry", 36, carry), ("drag", 48, drag), ("hammer", 30, hammer), ("drill", 40, drill),
                ("lift", 72, lift), ("kneel", 40, kneel), ("wire", 54, wire), ("talk", 90, talk)]
work_acts = {n: make_action(n + "_loop", f, fn, True) for n, f, fn in WORK_ACTIONS}
arm.animation_data.action = act_idle
bpy.ops.object.mode_set(mode="OBJECT")

# --------------------------------------------------------------------------- export and previews
out = out_path()
common.export_glb(out)


def setup_preview():
    common._enable_cuda()
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 256
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.5, 0.62, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy, sun.color = 3.2, (1.0, 0.92, 0.8)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(so)
    cam = bpy.data.cameras.new("Cam")
    cam.type, cam.ortho_scale, cam.clip_end = "ORTHO", 2.25, 100
    co = bpy.data.objects.new("Cam", cam)
    scene.collection.objects.link(co)
    scene.camera = co
    return co


def aim(cam_obj, direction, center=(0, 0, .9)):
    d = Vector(direction).normalized()
    cam_obj.location = Vector(center) + d * 12
    cam_obj.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def pose_sheet(action, frames, prefix, direction, center=(0, 0, .9)):
    arm.animation_data.action = action
    aim(cam, direction, center)
    for i, f in enumerate(frames):
        scene.frame_set(f)
        scene.render.filepath = os.path.join(os.path.dirname(out), f"person_{prefix}_{i}.png")
        bpy.ops.render.render(write_still=True)


for o in scene.objects:
    if o.type == "ARMATURE":
        o.hide_render = True
cam = setup_preview()
if VARIANT == "worker":
    prefix = os.path.basename(out)[:-4]
    for n, frames, _fn in WORK_ACTIONS:
        arm.animation_data.action = work_acts[n]
        for i in range(8):
            scene.frame_set(int(i * frames / 8))
            aim(cam, (-1.0, -0.7, 0.25), (0, 0, .75))
            scene.render.filepath = os.path.join(os.path.dirname(out), f"{prefix}_{n}_{i}.png")
            bpy.ops.render.render(write_still=True)
    arm.animation_data.action = act_idle
    scene.frame_set(0)
    aim(cam, (-0.35, -1.0, 0.15), (0, 0, 0.9))
    scene.render.filepath = out[:-4] + "_preview.png"
    bpy.ops.render.render(write_still=True)
else:
    pose_sheet(act_walk, [0, 4, 8, 12, 16, 20, 24, 28], "walk", (1.0, 0.0, 0.08))
    pose_sheet(act_run, [0, 3, 5, 8, 10, 13, 15, 18], "run", (1.0, 0.0, 0.08))
    pose_sheet(act_idle, [0, 12, 24, 36, 48, 60, 72, 84], "idle", (-0.5, -1.0, 0.2), (0, 0, 0.92))
    pose_sheet(act_door, [0, 6, 12, 18, 24, 32, 42, 53], "door", (-1.0, -0.8, 0.25), (-0.1, -0.1, 0.95))
    arm.animation_data.action = act_idle
    scene.frame_set(0)
    aim(cam, (-0.35, -1.0, 0.15), (0, 0, 0.9))
    cam.data.ortho_scale = 2.1
    scene.render.filepath = out[:-4] + "_preview.png"
    bpy.ops.render.render(write_still=True)
    # close-ups of the face: front, three-quarter, side, and mid-blink
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.cycles.samples = 110
    cam.data.ortho_scale = 0.30
    for name, direction in (("front", (0, -1, 0.02)), ("34", (-0.6, -1, 0.05)), ("side", (-1, -0.1, 0.0))):
        aim(cam, direction, (0, -0.045, 1.675))
        scene.render.filepath = os.path.join(os.path.dirname(out), f"person_face_{name}.png")
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = act_idle
    scene.frame_set(56)
    aim(cam, (-0.25, -1, 0.05), (0, -0.045, 1.675))
    scene.render.filepath = os.path.join(os.path.dirname(out), "person_face_blink.png")
    bpy.ops.render.render(write_still=True)
print("PERSON_DONE")
