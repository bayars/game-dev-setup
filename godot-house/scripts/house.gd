class_name House
extends NavigationRegion3D
## The house, built in code: two floors, rounded walls and floors, furniture from the Blender props
## (assets/models/house_props.glb), and its navigation mesh.
## Coordinates are metres: x to the east, z to the south, y up. The front door is on the south side; the
## van parks on the driveway in front of the garage. The upper floor (y = UP) is reached by the stairs in
## the east room; it is hidden while the camera follows someone downstairs.
##
## Walls are separate pieces so the isometric camera can cut away the ones between it and the player
## (see update_cutaway and shaders/wall.gdshader).

const H := 2.7          # wall height
const T := 0.15         # wall thickness
const DOOR_H := 2.1
const SLAB := 0.2       # the upper floor: 2.7 .. 2.9
const UP := H + SLAB
const ROUND := 0.035    # edge radius of walls and floors

## [name, rect on the floor plane, level]. A name may cover several rects (the L-shaped upstairs hall).
const ROOMS := [
	["Work room", Rect2(0, 0, 9, 7), 0],
	["Hallway", Rect2(9, 0, 2, 12), 0],
	["Bathroom", Rect2(11, 0, 5, 4), 0],
	["Rose's room", Rect2(11, 4, 5, 4), 0],
	["Stairs", Rect2(11, 8, 5, 4), 0],
	["Garage", Rect2(0, 7, 9, 5), 0],
	["Daniel's room", Rect2(0, 0, 9, 6), 1],
	["Upstairs hall", Rect2(9, 0, 2, 12), 1],
	["Upstairs hall", Rect2(4.5, 6, 4.5, 1.5), 1],
	["Sofia's room", Rect2(0, 6, 4.5, 6), 1],
	["Parents' room", Rect2(4.5, 7.5, 4.5, 4.5), 1],
	["Upstairs bathroom", Rect2(11, 0, 5, 4), 1],
	["Storage", Rect2(11, 4, 5, 4), 1],
	["Landing", Rect2(11, 8, 5, 4), 1],
]

const FLOOR_LOOK := {
	"Work room": ["wood", Color(1, 1, 1)],
	"Hallway": ["wood", Color(0.8, 0.75, 0.7)],
	"Bathroom": ["stone", Color(1.1, 1.1, 1.15)],
	"Rose's room": ["wood", Color(0.75, 0.6, 0.5)],
	"Stairs": ["wood", Color(0.8, 0.75, 0.7)],
	"Garage": ["stone", Color(0.75, 0.75, 0.75)],
	"Daniel's room": ["wood", Color(0.9, 0.85, 0.8)],
	"Upstairs hall": ["wood", Color(0.8, 0.75, 0.7)],
	"Sofia's room": ["wood", Color(0.95, 0.8, 0.75)],
	"Parents' room": ["wood", Color(0.7, 0.6, 0.55)],
	"Upstairs bathroom": ["stone", Color(1.1, 1.1, 1.15)],
	"Storage": ["wood", Color(0.6, 0.55, 0.5)],
	"Landing": ["wood", Color(0.8, 0.75, 0.7)],
}

## The stairs: a straight flight in the east room rising westwards along z = STAIR_Z0..STAIR_Z1, from
## x = STAIR_X0 on the ground floor to x = STAIR_X1 at the upper floor (through the upper hall wall).
const STAIR_X0 := 15.0
const STAIR_X1 := 11.0
const STAIR_Z0 := 10.9
const STAIR_Z1 := 11.9
const STEPS := 16

## [from, to, openings, level, height]: each opening is [offset from `from` along the wall, width].
const WALLS := [
	[Vector2(0, 0), Vector2(16, 0), [], 0],
	[Vector2(16, 0), Vector2(16, 12), [], 0],
	[Vector2(16, 12), Vector2(0, 12), [[5.4, 1.2], [10.0, 4.0]], 0],   # front door, garage door
	[Vector2(0, 12), Vector2(0, 0), [], 0],
	[Vector2(0, 7), Vector2(9, 7), [], 0],
	[Vector2(9, 0), Vector2(9, 12), [[2.0, 1.2], [9.0, 1.2]], 0],      # work room, garage
	[Vector2(11, 0), Vector2(11, 12), [[1.5, 1.2], [5.5, 1.2], [9.5, 1.2]], 0],
	[Vector2(11, 4), Vector2(16, 4), [], 0],
	[Vector2(11, 8), Vector2(16, 8), [], 0],
	[Vector2(11.2, 10.85), Vector2(15.05, 10.85), [], 0, 1.0],        # side of the flight: you step on at the end only

	[Vector2(0, 0), Vector2(16, 0), [], 1],
	[Vector2(16, 0), Vector2(16, 12), [], 1],
	[Vector2(16, 12), Vector2(0, 12), [], 1],
	[Vector2(0, 12), Vector2(0, 0), [], 1],
	[Vector2(0, 6), Vector2(4.5, 6), [], 1],
	[Vector2(4.5, 6), Vector2(9, 6), [], 1],
	[Vector2(4.5, 7.5), Vector2(9, 7.5), [], 1],
	[Vector2(4.5, 6), Vector2(4.5, 12), [[0.15, 1.2]], 1],             # Sofia's door off the hall
	[Vector2(9, 0), Vector2(9, 12), [[2.0, 1.2], [6.0, 1.5], [9.5, 1.2]], 1],
	[Vector2(11, 0), Vector2(11, 12), [[1.5, 1.2], [5.5, 1.2], [8.6, 1.2], [10.8, 1.15]], 1],   # ..., landing, top of the stairs
	[Vector2(11, 4), Vector2(16, 4), [], 1],
	[Vector2(11, 8), Vector2(16, 8), [], 1],
	[Vector2(11.15, 10.85), Vector2(16, 10.85), [], 1, 1.0],          # railing along the stairwell
]

const PROPS := preload("res://assets/models/house_props.glb")

## [prop, position, yaw (degrees), solid]. Props face +z at yaw 0.
const FURNITURE := [
	["Counter", Vector3(1.95, 0, 0.39), 0, true],
	["CounterShort", Vector3(4.25, 0, 0.39), 0, true],
	["Fridge", Vector3(6.0, 0, 0.43), 0, true],
	["ToolBag", Vector3(7.8, 0, 6.3), 0, true],
	["Shelves", Vector3(0.4, 0, 9.0), 90, true],
	["Workbench", Vector3(7.6, 0, 7.45), 0, true],
	["Tub", Vector3(15.05, 0, 0.5), 0, true],
	["Basin", Vector3(12.2, 0, 0.3), 0, true],
	["Toilet", Vector3(15.6, 0, 3.2), -90, true],
	["Bed", Vector3(15.3, 0, 5.15), 0, true],
	["Armchair", Vector3(12.0, 0, 7.3), 180, true],
	["Rug", Vector3(13.6, 0, 6.0), 0, false],
	["Van", Vector3(4.0, 0, 16.6), 0, true],

	["Bed", Vector3(0.7, UP, 1.2), 0, true],
	["Desk", Vector3(3.6, UP, 0.4), 0, true],
	["Wardrobe", Vector3(6.4, UP, 0.4), 0, true],
	["Rug", Vector3(3.8, UP, 3.4), 0, false],
	["Bed", Vector3(0.7, UP, 7.2), 0, true],
	["Desk", Vector3(2.4, UP, 11.6), 180, true],
	["Wardrobe", Vector3(3.8, UP, 11.6), 180, true],
	["BedDouble", Vector3(6.6, UP, 8.75), 0, true],
	["Dresser", Vector3(8.5, UP, 11.65), 180, true],
	["Tub", Vector3(15.05, UP, 0.5), 0, true],
	["Basin", Vector3(12.2, UP, 0.3), 0, true],
	["Toilet", Vector3(15.6, UP, 3.2), -90, true],
	["Shelves", Vector3(13.5, UP, 4.35), 0, true],
]

var walls: Array[Dictionary] = []    # {mesh, a: Vector2, b: Vector2, cut: float, level: int}
var upper: Node3D                    # everything on the upper floor (hidden while you are downstairs)
var level_shown := 0
var _gfx: Graphics
var _wall_mat: ShaderMaterial
var _props_root: Node

func build(gfx: Graphics) -> void:
	_gfx = gfx
	_props_root = PROPS.instantiate()
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = load("res://shaders/wall.gdshader")
	_wall_mat.set_shader_parameter("albedo_tex", gfx.tex("plaster", "albedo"))
	_wall_mat.set_shader_parameter("tint", Color(1.08, 1.06, 1.02))
	_wall_mat.set_shader_parameter("height", H)
	upper = Node3D.new()
	upper.name = "Upper"
	upper.visible = false                       # level_shown starts at the ground floor
	add_child(upper)

	_static_box(self, Vector3(60, 1, 60), Vector3(8, -0.5, 6), gfx.pbr("grass", 3.0), 0.0)   # the yard
	for r in ROOMS:
		var rect: Rect2 = r[1]
		var look: Array = FLOOR_LOOK[r[0]]
		var mat := gfx.pbr(look[0], 1.3, look[1])
		if r[2] == 0:
			var f := _static_box(self, Vector3(rect.size.x, 0.04, rect.size.y), Vector3(rect.get_center().x, 0.02, rect.get_center().y), mat)
			_thicken(f, 0.5)
		elif r[0] == "Landing":
			_slab_with_hole(rect, Rect2(STAIR_X1, STAIR_Z0, STAIR_X0 - STAIR_X1, STAIR_Z1 - STAIR_Z0), mat)
		else:
			_thicken(_static_box(upper, Vector3(rect.size.x, SLAB, rect.size.y), Vector3(rect.get_center().x, H + SLAB / 2, rect.get_center().y), mat), 0.25)
	_static_box(self, Vector3(5, 0.03, 9), Vector3(4, 0.015, 16.5), gfx.pbr("stone", 2.5, Color(0.6, 0.6, 0.62)))  # driveway
	for w in WALLS:
		_wall(w[0], w[1], w[2], w[3], w[4] if w.size() > 4 else H)
	_stairs()
	for f in FURNITURE:
		var at: Vector3 = f[1]
		if at.y == 0.0:
			at.y = 0.04                         # on top of the ground floor boards
		prop(f[0], at, f[2], f[3])

## A copy of a Blender prop placed in the house. Solid props get a box collider around their mesh.
func prop(prop_name: String, at: Vector3, yaw_deg := 0.0, solid := true, parent: Node = null) -> Node3D:
	var src := _props_root.get_node_or_null("P_" + prop_name) as Node3D
	if src == null:
		push_error("no prop P_%s in house_props.glb" % prop_name)
		return Node3D.new()
	var node := src.duplicate() as Node3D
	node.transform = Transform3D.IDENTITY
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.name = prop_name
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw_deg)
	holder.add_child(node)
	if solid:
		var box := _local_aabb(node)
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box.size
		shape.shape = b
		shape.position = box.get_center()
		holder.add_child(shape)
	if parent == null:
		parent = upper if at.y > H else self
	parent.add_child(holder)
	return holder

static func _local_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != node and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Bakes the navigation mesh from the static colliders. Call it one physics frame after build(): before
## that the bodies' transforms are not in the physics server yet and everything bakes at the origin.
func bake_nav() -> void:
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.cell_size = 0.1           # matches navigation/3d/default_cell_size in project.godot
	navigation_mesh.cell_height = 0.1
	navigation_mesh.agent_radius = 0.3        # 1.2 m doorways stay 0.6 m wide after erosion
	navigation_mesh.agent_height = 1.8
	navigation_mesh.agent_max_climb = 0.2
	navigation_mesh.agent_max_slope = 40.0    # the stair ramp is 36 degrees
	navigation_mesh.filter_baking_aabb = AABB(Vector3(-6, -1, -6), Vector3(28, 8, 28))
	bake_navigation_mesh(false)

## New solid furniture (the assembled couch and table): bake again in the background so paths go around it.
func rebake() -> void:
	if navigation_mesh == null:
		return
	if is_baking():                            # one more pass once this one is done
		if not bake_finished.is_connected(rebake):
			bake_finished.connect(rebake, CONNECT_ONE_SHOT)
		return
	bake_navigation_mesh(true)

## True once the navigation map contains the baked region (region updates are asynchronous).
func nav_ready() -> bool:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	return NavigationServer3D.map_get_closest_point(map, Vector3(10, 0, 14)).distance_to(Vector3(10, 0, 14)) < 1.0

static func level_of(p: Vector3) -> int:
	return 1 if p.y > UP * 0.5 else 0

## Name of the room that contains `p`, or "Outside".
static func room_at(p: Vector3) -> String:
	var lvl := level_of(p)
	for r in ROOMS:
		if r[2] == lvl and (r[1] as Rect2).has_point(Vector2(p.x, p.z)):
			return r[0]
	if Rect2(STAIR_X1, STAIR_Z0, STAIR_X0 - STAIR_X1, STAIR_Z1 - STAIR_Z0).has_point(Vector2(p.x, p.z)):
		return "Stairs"
	return "Outside"

static func room_center(room: String) -> Vector3:
	for r in ROOMS:
		if r[0] == room:
			var c := (r[1] as Rect2).get_center()
			return Vector3(c.x, UP if r[2] == 1 else 0.0, c.y)
	return Vector3.ZERO

## Shows the upper floor only while the camera follows someone up there, and lowers every wall of that
## floor that lies on the camera side of `focus`. `toward_camera` is the horizontal direction from the
## focus to the camera.
func update_cutaway(focus: Vector3, toward_camera: Vector2, delta: float) -> void:
	var lvl := level_of(focus + Vector3(0, 0.6, 0))
	if lvl != level_shown:
		level_shown = lvl
		upper.visible = lvl == 1
	var f := Vector2(focus.x, focus.z)
	for w in walls:
		var want := 0.0
		if w.level == lvl:
			var cp := Geometry2D.get_closest_point_to_segment(f, w.a, w.b)
			var rel := cp - f
			want = 1.0 if rel.dot(toward_camera) > 0.25 and rel.length() < 16.0 else 0.0
		w.cut = move_toward(w.cut, want, delta * 4.0)
		(w.mesh as MeshInstance3D).set_instance_shader_parameter("cut", w.cut)

func cut_count() -> int:
	var n := 0
	for w in walls:
		if w.cut > 0.5:
			n += 1
	return n

# ---------------------------------------------------------------- building blocks

func _wall(a: Vector2, b: Vector2, openings: Array, lvl: int, height: float) -> void:
	var dir := (b - a).normalized()
	var pos := 0.0
	var sorted := openings.duplicate()
	sorted.sort_custom(func(x, y): return x[0] < y[0])
	for o in sorted:
		_wall_piece(a + dir * pos, a + dir * o[0], 0.0, height, lvl)
		_wall_piece(a + dir * o[0], a + dir * (o[0] + o[1]), DOOR_H, height, lvl)   # lintel over the opening
		pos = o[0] + o[1]
	_wall_piece(a + dir * pos, b, 0.0, height, lvl)

func _wall_piece(a: Vector2, b: Vector2, y0: float, y1: float, lvl: int) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var base := UP if lvl == 1 else 0.0
	var mid := (a + b) / 2.0
	var body := StaticBody3D.new()
	body.position = Vector3(mid.x, base + (y0 + y1) / 2.0, mid.y)
	body.rotation.y = atan2(-(b.y - a.y), b.x - a.x)
	var size := Vector3(length + T, y1 - y0, T)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = RoundBox.mesh(size, ROUND)
	mi.material_override = _wall_mat
	mi.set_instance_shader_parameter("base", base)
	body.add_child(mi)
	(upper if lvl == 1 else self as Node).add_child(body)
	walls.append({"mesh": mi, "a": a, "b": b, "cut": 0.0, "level": lvl})

func _static_box(parent: Node, size: Vector3, pos: Vector3, material: Material, radius := ROUND) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	if radius > 0.0:
		mi.mesh = RoundBox.mesh(size, radius)
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	mi.material_override = material
	body.add_child(mi)
	parent.add_child(body)
	return body

## Makes a floor's collider `extra` metres deeper below its surface (the drawn floor stays as it is), so a
## falling ragdoll cannot pass through a thin board.
func _thicken(body: StaticBody3D, extra: float) -> void:
	var cs := body.get_child(0) as CollisionShape3D
	var box := (cs.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size.y += extra
	cs.shape = box
	cs.position.y -= extra / 2.0

## An upper-floor slab over `rect` with the stairwell `hole` left open.
func _slab_with_hole(rect: Rect2, hole: Rect2, material: Material) -> void:
	var parts := [
		Rect2(rect.position.x, rect.position.y, rect.size.x, hole.position.y - rect.position.y),
		Rect2(rect.position.x, hole.end.y, rect.size.x, rect.end.y - hole.end.y),
		Rect2(hole.end.x, hole.position.y, rect.end.x - hole.end.x, hole.size.y),
	]
	for p in parts:
		if p.size.x > 0.01 and p.size.y > 0.01:
			_thicken(_static_box(upper, Vector3(p.size.x, SLAB, p.size.y), Vector3(p.get_center().x, H + SLAB / 2, p.get_center().y), material), 0.25)

## Rounded steps to look at, and one smooth ramp underneath to walk on (and to bake the navmesh from).
func _stairs() -> void:
	var timber := _gfx.pbr("wood", 1.0, Color(1.1, 0.95, 0.8))
	var run := (STAIR_X0 - STAIR_X1) / STEPS
	var rise := UP / STEPS
	var width := STAIR_Z1 - STAIR_Z0
	var zc := (STAIR_Z0 + STAIR_Z1) / 2.0
	for i in STEPS:
		var top := rise * (i + 1)
		var mi := MeshInstance3D.new()
		mi.mesh = RoundBox.mesh(Vector3(run + 0.02, top, width), 0.025)
		mi.material_override = timber
		mi.position = Vector3(STAIR_X0 - run * (i + 0.5), top / 2.0, zc)
		add_child(mi)
	var length := Vector2(STAIR_X0 - STAIR_X1, UP).length() + 0.6   # runs 0.6 m on into the floor at the bottom
	var angle := atan2(UP, STAIR_X0 - STAIR_X1)
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.1, width)
	shape.shape = box
	ramp.add_child(shape)
	ramp.rotation.z = -angle                  # rises towards -x
	var mid := Vector3((STAIR_X0 + STAIR_X1) / 2.0, UP / 2.0, zc) + Vector3(cos(angle), -sin(angle), 0) * 0.3
	ramp.position = mid - Vector3(sin(angle), cos(angle), 0) * 0.05   # top face on the line of the step nosings
	add_child(ramp)
