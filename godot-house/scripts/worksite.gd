class_name Worksite
extends Node3D
## What the day's work looks like in the house, before, during and after: the loose studs that stand up
## one by one, the drywall sheets lifted onto them, screws, tape and mud, the outlet, the laminate, the
## dishwasher and the couch and table coming out of their boxes.
##
## A job is a list of steps (Day1). Each step has hotspots (`spots`) the brother works on, one after the
## other; `apply(job, step, i, t)` shows the result of hotspot i (t < 1 while a held step is in progress).
## Everything is placed in house coordinates; the ground floor surface is at y = FLOOR.

const FLOOR := 0.04
const WALL_X := 6.4                        # the new partition, studs every 0.4 m from z 2.4 to 5.6
const STUD_Z0 := 2.4
const STUDS := 9
const SHEET_FACE := WALL_X + 0.045 + 0.008 # the east face of the drywall (the side the camera sees)
const SHEETS := [[2.35, 1.2], [3.55, 1.2], [4.75, 0.9]]   # [z start, width]: two full sheets and a cut one
const STACK_X := 8.9                       # the sheets lean on the east wall, on their long edge
const STACK_Z := 4.5                       # .. from here to STACK_Z + 2.4
const STACK_LEAN := 0.14                   # radians off vertical
const LAMINATE := Rect2(7.4, 3.3, 1.2, 1.33)  # x, z: seven rows of planks by the window
const OUTLET := Vector3(7.6, 0.35, 0.08)
const DISHWASHER_IN := Vector3(5.1, FLOOR, 0.38)
const DISHWASHER_OUT := 0.85               # pulled out this far while the hoses go on
const COUCH_AT := Vector3(2.0, FLOOR, 2.7)
const TABLE_AT := Vector3(2.0, FLOOR, 3.8)     # coffee table in front of the couch
const MEASURE_Y := House.UP + 1.0

var house: House
var gfx: Graphics
var _studs: Array[Node3D] = []
var _sheets: Array[Node3D] = []
var _screws: Array[Node3D] = []
var _tape: Array[MeshInstance3D] = []
var _planks: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _bits := {}                            # named single pieces: "underlay", "outlet", "dishwasher", ...
var _frame: CollisionShape3D               # the partition blocks the way once its studs stand
var _dark: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _mud_mat: StandardMaterial3D
var _plaster: Material
var carry_props := {}                      # job id -> the boxed load (a Carryable) once main hands it over

func setup(h: House, g: Graphics) -> void:
	house = h
	gfx = g
	_dark = _flat(Color(0.12, 0.12, 0.13), 0.4, 0.6)
	_tape_mat = _flat(Color(0.93, 0.89, 0.78), 0.9)
	_mud_mat = _flat(Color(0.95, 0.94, 0.9), 0.95)
	_plaster = gfx.pbr("plaster", 2.2, Color(1.08, 1.06, 1.02))

	# the partition: a bottom plate on the floor (you can step over it) and the studs lying in a pile; the
	# collider for the whole frame comes on when the first stud stands
	var plate := house.prop("Plate", Vector3(WALL_X, FLOOR, STUD_Z0 + 1.6), 90, false, self)
	plate.scale.x = 3.3
	_frame = _collider(Vector3(0.1, 2.6, 3.3), Vector3(WALL_X, 1.3, STUD_Z0 + 1.6))
	_frame.disabled = true
	for i in STUDS:
		var s := house.prop("Stud", _stud_pile(i), 0, false, self)
		s.rotation = Vector3(-PI / 2, 0, 0)
		_studs.append(s)
	# four drywall sheets leaning on the east wall; the front three go up, the last stays as a spare
	for k in 4:
		var sh := house.prop("DrywallSheet", Vector3.ZERO, 0, false, self)
		sh.transform = _stack_pose(k)
		if k > 0:
			_sheets.append(sh)
	_sheets.reverse()                       # _sheets[0] is the front one, lifted first
	_collider(Vector3(0.3, 1.2, 2.4), Vector3(STACK_X - 0.12, 0.6, STACK_Z + 1.2))
	var wall_box := house.prop("WallBox", OUTLET, 0, false, self)
	_bits["wallbox"] = wall_box

## Where the hotspots of a step are.
func spots(job: String, step: int) -> Array:
	match job + ":" + str(step):
		"studs:0": return [Vector3(WALL_X, 0.12, STUD_Z0 + 1.6)]
		"studs:1": return range(STUDS).map(func(i): return Vector3(WALL_X, 0.25, STUD_Z0 + i * 0.4))
		"studs:2": return [Vector3(WALL_X, 2.55, STUD_Z0 + 1.6)]
		"drywall:0": return [_stack_pose(3).origin + Vector3(-0.04, 0.35, 1.2)]
		"drywall:1": return SHEETS.map(func(s): return Vector3(SHEET_FACE, 1.3, s[0] + s[1] / 2.0))
		"drywall:2": return range(STUDS).map(func(i): return Vector3(SHEET_FACE + 0.02, 1.3, STUD_Z0 + i * 0.4))
		"drywall:3": return [Vector3(SHEET_FACE + 0.02, 1.3, 3.55), Vector3(SHEET_FACE + 0.02, 1.3, 4.75)]
		"drywall:4": return [Vector3(SHEET_FACE + 0.02, 1.3, 4.0)]
		"wiring:0": return [OUTLET + Vector3(0, 0.05, 0.06)]
		"wiring:1": return [OUTLET + Vector3(0.5, 0.2, 0.08), OUTLET + Vector3(-0.5, 0.2, 0.08), OUTLET + Vector3(0, 0.2, 0.08)]   # earth, live, neutral: not left to right
		"wiring:2": return [OUTLET + Vector3(0, 0, 0.05)]
		"flooring:0": return [Vector3(LAMINATE.get_center().x, FLOOR + 0.05, LAMINATE.get_center().y)]
		"flooring:1": return range(7).map(func(k): return _plank_pos(k) + Vector3(0, 0.03, 0))
		"flooring:2": return [Vector3(LAMINATE.get_center().x, FLOOR + 0.05, LAMINATE.get_center().y)]
		"dishwasher:0": return [Vector3(5.1, 0.95, 0.75)]
		"dishwasher:1": return [Vector3(4.92, 0.15, 0.36), Vector3(5.3, 0.15, 0.36)]
		"dishwasher:2": return [DISHWASHER_IN + Vector3(0, 0.9, DISHWASHER_OUT)]
		"assemble:0": return [COUCH_AT + Vector3(0, 0.85, 0)]
		"assemble:1": return _corners(COUCH_AT + Vector3(0, 0.74, 0), 0.92, 0.33)
		"assemble:2": return _corners(TABLE_AT + Vector3(0, 0.06, 0), 0.47, 0.22)
		"measure:0": return [Vector3(0.25, MEASURE_Y, 3.0), Vector3(8.75, MEASURE_Y, 3.0), Vector3(4.5, MEASURE_Y, 0.2), Vector3(4.5, MEASURE_Y, 5.8)]
	return []

## Names and colours for steps where the order matters (shown next to the hotspots).
func labels(job: String, step: int) -> Array:
	if job == "wiring" and step == 1:
		return [["Earth", Color(0.85, 0.55, 0.3)], ["Live", Color(0.25, 0.25, 0.28)], ["Neutral", Color(0.95, 0.95, 0.92)]]
	return []

## Show the result of hotspot `i` of a step. Held steps call this every frame with t rising to 1.
func apply(job: String, step: int, i: int, t := 1.0) -> void:
	match job + ":" + str(step):
		"studs:0":
			if t >= 1.0:
				for k in STUDS:
					_box(Vector3(0.1, 0.004, 0.012), Vector3(WALL_X, FLOOR + 0.047, STUD_Z0 + k * 0.4), _dark)
		"studs:1":
			if _frame.disabled:
				_frame.disabled = false
				house.rebake()
			var s := _studs[i]
			_tween(s, Vector3(WALL_X, FLOOR + 0.045, STUD_Z0 + i * 0.4), Quaternion.from_euler(Vector3(0, PI / 2, 0)), 0.45)
			_screw(Vector3(WALL_X - 0.05, FLOOR + 0.07, STUD_Z0 + i * 0.4), Vector3.LEFT)
		"studs:2":
			if t >= 1.0 and not _bits.has("topplate"):
				var p := house.prop("Plate", Vector3(WALL_X, FLOOR + 2.645, STUD_Z0 + 1.6), 90, false, self)
				p.scale.x = 3.3
				_bits["topplate"] = p
		"drywall:0":
			pass                                # scoring the sheet: the animation says it all
		"drywall:1":
			var sh := _sheets[i]
			var z0: float = SHEETS[i][0]
			var w: float = SHEETS[i][1]
			sh.scale = Vector3(w / 1.2, 2.6 / 2.4, 1.0)
			_tween(sh, Vector3(SHEET_FACE, FLOOR + 0.02, z0 + w / 2.0), Quaternion.from_euler(Vector3(0, PI / 2, 0)), 0.8)
		"drywall:2":
			for y in [0.35, 1.3, 2.25]:
				_screws.append(_screw(Vector3(SHEET_FACE + 0.007, FLOOR + y, STUD_Z0 + i * 0.4), Vector3.RIGHT))
		"drywall:3":
			var seam: float = [3.55, 4.75][i]
			_tape.append(_box(Vector3(0.003, 2.55, 0.05), Vector3(SHEET_FACE + 0.008, FLOOR + 1.3, seam), _tape_mat))
		"drywall:4":
			for strip in _tape:                 # the mud spreads over the seams, then the wall is finished
				strip.material_override = _mud_mat
				strip.scale.z = 1.0 + 3.0 * t
			if t >= 1.0:
				for sh in _sheets:
					for mi in sh.find_children("*", "MeshInstance3D", true, false):
						(mi as MeshInstance3D).material_override = _plaster
				for n in _screws + _tape:
					n.visible = false
		"wiring:0":
			pass
		"wiring:1":
			var c: Color = labels("wiring", 1)[i][1]
			var wire := _box(Vector3(0.006, 0.006, 0.05), OUTLET + Vector3(-0.02 + i * 0.02, 0.0, 0.03), _flat(c, 0.5))
			wire.name = "Wire%d" % i
		"wiring:2":
			if not _bits.has("outlet"):
				(_bits["wallbox"] as Node3D).visible = false
				_bits["outlet"] = house.prop("Outlet", OUTLET + Vector3(0, 0, -0.005), 0, false, self)
		"flooring:0":
			if not _bits.has("underlay"):
				var u := house.prop("Underlay", Vector3(LAMINATE.position.x + LAMINATE.size.x / 2.0, FLOOR + 0.001, LAMINATE.position.y), 0, false, self)
				_bits["underlay"] = u
			var und := _bits["underlay"] as Node3D
			und.scale = Vector3(LAMINATE.size.x, 1, LAMINATE.size.y * t)
			und.position.z = LAMINATE.position.y + LAMINATE.size.y * t / 2.0
		"flooring:1":
			var p := house.prop("Plank", _plank_pos(i) + Vector3(0, 0.25, 0), 0, false, self)
			_tween(p, _plank_pos(i), p.quaternion, 0.3)
			_planks.append(p)
		"flooring:2":
			pass
		"dishwasher:0":
			if t >= 1.0 and not _bits.has("dishwasher"):
				_hide_load("dishwasher_in")
				_bits["dishwasher"] = house.prop("Dishwasher", DISHWASHER_IN + Vector3(0, 0, DISHWASHER_OUT), 0, false, self)
		"dishwasher:1":
			var hose := _box(Vector3(0.03, 0.03, 0.5), spots("dishwasher", 1)[i] + Vector3(0, -0.08, 0.3), _dark)
			hose.name = "Hose%d" % i
		"dishwasher:2":
			var d := _bits.get("dishwasher") as Node3D
			if d:
				d.position = DISHWASHER_IN + Vector3(0, 0, DISHWASHER_OUT * (1.0 - t))
			if t >= 1.0:
				for k in 2:
					var hose := find_child("Hose%d" % k, false, false)
					if hose:
						hose.queue_free()
		"assemble:0":
			if t >= 1.0 and not _bits.has("couch"):
				_hide_load("couch_in")
				var c := house.prop("CouchLegless", COUCH_AT + Vector3(0, 0.72, 0), 0, false, self)
				c.rotation.x = PI                    # upside down: the legs go on its base
				_bits["couch"] = c
				_bits["tabletop"] = house.prop("TableTop", TABLE_AT, 0, false, self)
				for k in 8:
					_legs.append(house.prop("Leg", COUCH_AT + Vector3(1.3 + (k % 4) * 0.12, 0, 1.3 + (k / 4) * 0.5), 0, false, self))
		"assemble:1":
			_use_leg()
			_stub(spots("assemble", 1)[i] + Vector3(0, 0.07, 0), 0.14)
			if i == 3:
				(_bits["couch"] as Node3D).queue_free()
				_clear_stubs()
				_bits["couch"] = house.prop("Couch", COUCH_AT, 0, true, house)
				house.rebake()
		"assemble:2":
			_use_leg()
			_stub(spots("assemble", 2)[i] + Vector3(0, 0.18, 0), 0.38)
			if i == 3:
				(_bits["tabletop"] as Node3D).queue_free()
				_clear_stubs()
				_bits["table"] = house.prop("Table", TABLE_AT, 0, true, house)
				house.rebake()
		"measure:0":
			_box(Vector3(0.03, 0.12, 0.03), spots("measure", 0)[i], _flat(Color(1.0, 0.8, 0.2), 0.5))

## Puts a whole job in its finished state (the other brother working on his own, the self-test).
func finish(job: String, steps: Array) -> void:
	for s in steps.size():
		var n := spots(job, s).size()
		for i in n:
			apply(job, s, i, 1.0)

## Which clip a brother plays for a tool used at `spot` height (relative to the floor he stands on).
static func anim_for(tool: String, height: float) -> String:
	match tool:
		"sheet": return "lift"
		"hammer": return "hammer"
		"mallet", "planks", "underlay": return "kneel"
	if height < 0.7:
		return "wire"
	return "drill"

# ---------------------------------------------------------------- helpers

## A sheet leaning on the east wall: `k` 0 is against the wall, higher k further out. The sheet's 2.4 m
## runs along the wall (z), its 1.2 m width stands up, tipped STACK_LEAN towards the wall.
func _stack_pose(k: int) -> Transform3D:
	var up := Vector3(sin(STACK_LEAN), cos(STACK_LEAN), 0)
	var b := Basis(up, Vector3(0, 0, 1), up.cross(Vector3(0, 0, 1)))
	var mid := Vector3(STACK_X - 0.6 * sin(STACK_LEAN) - 0.02 - k * 0.02, FLOOR + 0.6 * cos(STACK_LEAN), STACK_Z)
	return Transform3D(b, mid)

## A solid box under the house node (the navigation mesh is baked from the house's children).
func _collider(size: Vector3, at: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = at
	body.add_child(shape)
	house.add_child(body)
	return shape

func _stud_pile(i: int) -> Vector3:
	return Vector3(7.25 + (i % 3) * 0.11, FLOOR + 0.025 + (i / 3) * 0.047, 2.0)

func _plank_pos(k: int) -> Vector3:
	return Vector3(LAMINATE.get_center().x, FLOOR + 0.006, LAMINATE.position.y + 0.19 * (k + 0.5))

func _corners(c: Vector3, dx: float, dz: float) -> Array:
	return [c + Vector3(-dx, 0, -dz), c + Vector3(dx, 0, -dz), c + Vector3(dx, 0, dz), c + Vector3(-dx, 0, dz)]

## A bolted-on leg standing up from the upturned couch or table until it is turned over.
func _stub(at: Vector3, length: float) -> void:
	var leg := _box(Vector3(0.05, length, 0.05), at, _flat(Color(0.25, 0.18, 0.12), 0.6))
	leg.add_to_group("leg_stubs")

func _clear_stubs() -> void:
	for n in get_tree().get_nodes_in_group("leg_stubs"):
		n.queue_free()

func _use_leg() -> void:
	if not _legs.is_empty():
		_legs.pop_back().queue_free()

func _hide_load(job_id: String) -> void:
	var load := carry_props.get(job_id) as Node3D
	if load:
		load.visible = false

func _tween(n: Node3D, to: Vector3, rot: Quaternion, seconds: float) -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "position", to, seconds)
	t.tween_property(n, "quaternion", rot, seconds)

func _screw(at: Vector3, facing: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.007
	c.bottom_radius = 0.007
	c.height = 0.004
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = _dark
	mi.position = at
	mi.rotation = Vector3(0, 0, PI / 2) if absf(facing.x) > 0.5 else Vector3(PI / 2, 0, 0)
	add_child(mi)
	return mi

func _box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RoundBox.mesh(size, minf(0.01, minf(size.x, minf(size.y, size.z)) * 0.45), 2)
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _flat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m
