class_name Worksite2
extends Worksite
## Day 2: yesterday's work stands finished downstairs, and today's job is Daniel's room upstairs: a closet
## wall (studs, then drywall), skirting boards nailed along the west wall, and a new ceiling light.
## The pieces the accident cases move (the first stud, the second sheet, the nail gun) are reachable by
## name for the cut-scene (`piece`).

const UP := House.UP
const X2 := 7.6                            # the closet partition, studs from Z2 every GAP2 m
const Z2 := 3.7
const N2 := 6
const GAP2 := 0.42
const FACE2 := X2 - 0.045 - 0.008          # the west face of its drywall (the side the room sees)
const SHEETS2 := [[3.655, 1.2], [4.855, 0.99]]
const SKIRT := [2.7, 3.6, 4.5, 5.4]        # skirting boards along the west wall (z centres)
const LIGHT := Vector3(4.5, UP + 2.5, 3.0) # the ceiling light

var _studs2: Array[Node3D] = []
var _sheets2: Array[Node3D] = []
var _screws2: Array[Node3D] = []
var _tape2: Array[MeshInstance3D] = []
var _frame2: CollisionShape3D

func setup(h: House, g: Graphics) -> void:
	super.setup(h, g)
	var day1 := Day1.jobs(null, null)        # yesterday's jobs, finished
	for id in ["studs", "drywall", "wiring", "flooring", "dishwasher", "assemble"]:
		finish(id, day1[id].steps)
	var plate := house.prop("Plate", Vector3(X2, UP, Z2 + GAP2 * (N2 - 1) / 2.0), 90, false, self)
	plate.scale.x = GAP2 * (N2 - 1) + 0.09
	_frame2 = _collider(Vector3(0.1, 2.6, GAP2 * (N2 - 1) + 0.1), Vector3(X2, UP + 1.3, Z2 + GAP2 * (N2 - 1) / 2.0))
	_frame2.disabled = true
	for i in N2:
		var s := house.prop("Stud", Vector3(5.0 + (i % 3) * 0.11, UP + 0.025 + (i / 3) * 0.047, 5.75), 0, false, self)
		s.rotation = Vector3(-PI / 2, 0, 0)
		_studs2.append(s)
	for k in 3:                              # three sheets lean on the south wall; two go up
		var sh := house.prop("DrywallSheet", Vector3.ZERO, 0, false, self)
		sh.transform = _lean_south(k)
		if k > 0:
			_sheets2.append(sh)
	_sheets2.reverse()
	_collider(Vector3(2.4, 1.2, 0.3), Vector3(3.2, UP + 0.6, 5.8))
	var cable := _box(Vector3(0.012, 0.22, 0.012), LIGHT + Vector3(0, 0.1, 0), _dark)
	_bits["cable"] = cable

## A sheet leaning on the south wall of Daniel's room: its 2.4 m along x from 2.0, tipped towards the wall.
func _lean_south(k: int) -> Transform3D:
	var up := Vector3(0, cos(STACK_LEAN), sin(STACK_LEAN))
	var b := Basis(up, Vector3(1, 0, 0), up.cross(Vector3(1, 0, 0)))
	return Transform3D(b, Vector3(2.0, UP + 0.6 * cos(STACK_LEAN), 5.9 - 0.6 * sin(STACK_LEAN) - k * 0.02))

func spots(job: String, step: int) -> Array:
	var z_mid := Z2 + GAP2 * (N2 - 1) / 2.0
	match job + ":" + str(step):
		"closet_studs:0": return [Vector3(X2, UP + 0.08, z_mid)]
		"closet_studs:1": return range(N2).map(func(i): return Vector3(X2, UP + 0.25, Z2 + i * GAP2))
		"closet_studs:2": return [Vector3(X2, UP + 2.55, z_mid)]
		"closet_drywall:0": return SHEETS2.map(func(s): return Vector3(FACE2, UP + 1.3, s[0] + s[1] / 2.0))
		"closet_drywall:1": return range(N2).map(func(i): return Vector3(FACE2 - 0.02, UP + 1.3, Z2 + i * GAP2))
		"closet_drywall:2": return [Vector3(FACE2 - 0.02, UP + 1.3, SHEETS2[1][0])]
		"closet_drywall:3": return [Vector3(FACE2 - 0.02, UP + 1.3, z_mid)]
		"skirting:0": return [Vector3(0.3, UP + 0.08, 4.0)]
		"skirting:1": return SKIRT.map(func(z): return Vector3(0.12, UP + 0.1, z))
		"light:0": return [LIGHT + Vector3(0, -0.04, 0)]
		"light:1": return [LIGHT + Vector3(0.18, -0.1, 0), LIGHT + Vector3(-0.18, -0.1, 0), LIGHT + Vector3(0, -0.1, 0.18)]
		"light:2": return [LIGHT + Vector3(0, -0.12, 0)]
		"keep_working:0": return [Vector3(2.6, UP + 0.2, 4.9), Vector3(3.4, UP + 0.2, 5.0), Vector3(3.8, UP + 1.0, 5.6), Vector3(2.9, UP + 0.2, 4.1)]
	return super.spots(job, step)

func labels(job: String, step: int) -> Array:
	if job == "light" and step == 1:
		return super.labels("wiring", 1)
	return super.labels(job, step)

func apply(job: String, step: int, i: int, t := 1.0) -> void:
	match job + ":" + str(step):
		"closet_studs:0":
			if t >= 1.0:
				for k in N2:
					_box(Vector3(0.1, 0.004, 0.012), Vector3(X2, UP + 0.047, Z2 + k * GAP2), _dark)
		"closet_studs:1":
			if _frame2.disabled:
				_frame2.disabled = false
				house.rebake()
			_tween(_studs2[i], Vector3(X2, UP + 0.045, Z2 + i * GAP2), Quaternion.from_euler(Vector3(0, PI / 2, 0)), 0.45)
			_screw(Vector3(X2 + 0.05, UP + 0.07, Z2 + i * GAP2), Vector3.RIGHT)
		"closet_studs:2":
			if t >= 1.0 and not _bits.has("topplate2"):
				var p := house.prop("Plate", Vector3(X2, UP + 2.645, Z2 + GAP2 * (N2 - 1) / 2.0), 90, false, self)
				p.scale.x = GAP2 * (N2 - 1) + 0.09
				_bits["topplate2"] = p
		"closet_drywall:0":
			var sh := _sheets2[i]
			var z0: float = SHEETS2[i][0]
			var w: float = SHEETS2[i][1]
			sh.scale = Vector3(w / 1.2, 2.6 / 2.4, 1.0)
			_tween(sh, Vector3(FACE2, UP + 0.02, z0 + w / 2.0), Quaternion.from_euler(Vector3(0, PI / 2, 0)), 0.8)
		"closet_drywall:1":
			for y in [0.35, 1.3, 2.25]:
				_screws2.append(_screw(Vector3(FACE2 - 0.007, UP + y, Z2 + i * GAP2), Vector3.LEFT))
		"closet_drywall:2":
			_tape2.append(_box(Vector3(0.003, 2.55, 0.05), Vector3(FACE2 - 0.008, UP + 1.3, SHEETS2[1][0]), _tape_mat))
		"closet_drywall:3":
			for strip in _tape2:
				strip.material_override = _mud_mat
				strip.scale.z = 1.0 + 3.0 * t
			if t >= 1.0:
				for sh in _sheets2:
					for mi in sh.find_children("*", "MeshInstance3D", true, false):
						(mi as MeshInstance3D).material_override = _plaster
				for n in _screws2 + _tape2:
					n.visible = false
		"skirting:0":
			pass
		"skirting:1":
			var board := _box(Vector3(0.016, 0.1, 0.88), Vector3(0.09, UP + 0.05, SKIRT[i]), _flat(Color(0.93, 0.92, 0.88), 0.6))
			board.name = "Skirting%d" % i
		"light:0", "keep_working:0":
			pass
		"light:1":
			var c: Color = super.labels("wiring", 1)[i][1]
			_box(Vector3(0.006, 0.05, 0.006), LIGHT + Vector3(-0.02 + i * 0.02, -0.04, 0), _flat(c, 0.5))
		"light:2":
			if not _bits.has("lamp"):
				var shade := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.08
				cyl.bottom_radius = 0.22
				cyl.height = 0.18
				shade.mesh = cyl
				shade.material_override = _flat(Color(0.95, 0.92, 0.84), 0.7)
				shade.position = LIGHT + Vector3(0, -0.16, 0)
				add_child(shade)
				var bulb := OmniLight3D.new()
				bulb.light_color = Color(1.0, 0.84, 0.64)
				bulb.light_energy = 0.9
				bulb.omni_range = 5.5
				bulb.position = LIGHT + Vector3(0, -0.3, 0)
				add_child(bulb)
				_bits["lamp"] = shade
		_:
			super.apply(job, step, i, t)

## A named piece for the accident cut-scene: "stud" (the first, not yet fixed at the top), "sheet" (the
## one being lifted second).
func piece(what: String) -> Node3D:
	match what:
		"stud": return _studs2[0]
		"sheet": return _sheets2[1]
	return null
