class_name House
extends NavigationRegion3D
## Greybox of the house (ground floor), built in code, and its navigation mesh.
## Coordinates are metres on the floor plane: x to the east, z to the south. The front door is on the
## south side; the van parks on the driveway in front of the garage.
##
## Walls are separate pieces so the isometric camera can cut away the ones between it and the player
## (see update_cutaway and shaders/wall.gdshader).

const H := 2.7          # wall height
const T := 0.15         # wall thickness
const DOOR_H := 2.1

const ROOMS := {
	"Work room": Rect2(0, 0, 9, 7),
	"Hallway": Rect2(9, 0, 2, 12),
	"Bathroom": Rect2(11, 0, 5, 4),
	"Rose's room": Rect2(11, 4, 5, 4),
	"Stairs": Rect2(11, 8, 5, 4),
	"Garage": Rect2(0, 7, 9, 5),
}

## [from, to, openings]: each opening is [offset from `from` along the wall, width], all in metres.
const WALLS := [
	[Vector2(0, 0), Vector2(16, 0), []],
	[Vector2(16, 0), Vector2(16, 12), []],
	[Vector2(16, 12), Vector2(0, 12), [[5.4, 1.2], [10.0, 4.0]]],   # front door, garage door
	[Vector2(0, 12), Vector2(0, 0), []],
	[Vector2(0, 7), Vector2(9, 7), []],
	[Vector2(9, 0), Vector2(9, 12), [[2.0, 1.2], [9.0, 1.2]]],      # work room, garage
	[Vector2(11, 0), Vector2(11, 12), [[1.5, 1.2], [5.5, 1.2], [9.5, 1.2]]],
	[Vector2(11, 4), Vector2(16, 4), []],
	[Vector2(11, 8), Vector2(16, 8), []],
]

const FLOORS := {
	"Work room": ["wood", Color(1, 1, 1)],
	"Hallway": ["wood", Color(0.8, 0.75, 0.7)],
	"Bathroom": ["stone", Color(1.1, 1.1, 1.15)],
	"Rose's room": ["wood", Color(0.75, 0.6, 0.5)],
	"Stairs": ["wood", Color(0.8, 0.75, 0.7)],
	"Garage": ["stone", Color(0.75, 0.75, 0.75)],
}

var walls: Array[Dictionary] = []    # {mesh, a: Vector2, b: Vector2, cut: float}
var _gfx: Graphics
var _wall_mat: ShaderMaterial

func build(gfx: Graphics) -> void:
	_gfx = gfx
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = load("res://shaders/wall.gdshader")
	_wall_mat.set_shader_parameter("albedo_tex", gfx.tex("plaster", "albedo"))
	_wall_mat.set_shader_parameter("tint", Color(1.08, 1.06, 1.02))
	_wall_mat.set_shader_parameter("height", H)

	_static_box(Vector3(60, 1, 60), Vector3(8, -0.5, 6), gfx.pbr("grass", 3.0))   # the yard
	for room in ROOMS:
		var r: Rect2 = ROOMS[room]
		var f: Array = FLOORS[room]
		_static_box(Vector3(r.size.x, 0.04, r.size.y), Vector3(r.get_center().x, 0.02, r.get_center().y),
			gfx.pbr(f[0], 1.3, f[1]))
	_static_box(Vector3(5, 0.03, 9), Vector3(4, 0.015, 16.5), gfx.pbr("stone", 2.5, Color(0.6, 0.6, 0.62)))  # driveway
	for w in WALLS:
		_wall(w[0], w[1], w[2])
	_props()


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
	navigation_mesh.filter_baking_aabb = AABB(Vector3(-6, -1, -6), Vector3(28, 4, 28))
	bake_navigation_mesh(false)

## True once the navigation map contains the baked region (region updates are asynchronous).
func nav_ready() -> bool:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	return NavigationServer3D.map_get_closest_point(map, Vector3(10, 0, 14)).distance_to(Vector3(10, 0, 14)) < 1.0

## Name of the room that contains `p`, or "Outside".
static func room_at(p: Vector3) -> String:
	for room in ROOMS:
		if (ROOMS[room] as Rect2).has_point(Vector2(p.x, p.z)):
			return room
	return "Outside"

static func room_center(room: String) -> Vector3:
	var c := (ROOMS[room] as Rect2).get_center()
	return Vector3(c.x, 0, c.y)

## Lowers every wall that lies on the camera side of `focus` (the controlled character).
## `toward_camera` is the horizontal direction from the focus to the camera.
func update_cutaway(focus: Vector3, toward_camera: Vector2, delta: float) -> void:
	var f := Vector2(focus.x, focus.z)
	for w in walls:
		var cp := Geometry2D.get_closest_point_to_segment(f, w.a, w.b)
		var rel := cp - f
		var want := 1.0 if rel.dot(toward_camera) > 0.25 and rel.length() < 16.0 else 0.0
		w.cut = move_toward(w.cut, want, delta * 4.0)
		(w.mesh as MeshInstance3D).set_instance_shader_parameter("cut", w.cut)

func cut_count() -> int:
	var n := 0
	for w in walls:
		if w.cut > 0.5:
			n += 1
	return n

# ---------------------------------------------------------------- building blocks

func _wall(a: Vector2, b: Vector2, openings: Array) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var pos := 0.0
	var sorted := openings.duplicate()
	sorted.sort_custom(func(x, y): return x[0] < y[0])
	for o in sorted:
		_wall_piece(a + dir * pos, a + dir * o[0], 0.0, H)
		_wall_piece(a + dir * o[0], a + dir * (o[0] + o[1]), DOOR_H, H)   # lintel over the opening
		pos = o[0] + o[1]
	_wall_piece(a + dir * pos, b, 0.0, H)

func _wall_piece(a: Vector2, b: Vector2, y0: float, y1: float) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var mid := (a + b) / 2.0
	var body := StaticBody3D.new()
	body.position = Vector3(mid.x, (y0 + y1) / 2.0, mid.y)
	body.rotation.y = atan2(-(b.y - a.y), b.x - a.x)
	var size := Vector3(length + T, y1 - y0, T)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _wall_mat
	body.add_child(mi)
	add_child(body)
	walls.append({"mesh": mi, "a": a, "b": b, "cut": 0.0})

func _static_box(size: Vector3, pos: Vector3, material: Material, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	add_child(body)
	return body

func _flat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

## Greybox furniture and the job site. Sizes are real-world so later art can replace them one by one.
func _props() -> void:
	var counter := _flat(Color(0.85, 0.83, 0.78))
	var dark := _flat(Color(0.25, 0.25, 0.27))
	var timber := _gfx.pbr("wood", 1.0, Color(1.25, 1.15, 0.95))
	var board := _flat(Color(0.88, 0.88, 0.86), 0.95)
	var fabric := _flat(Color(0.35, 0.42, 0.55), 1.0)
	var porcelain := _flat(Color(0.95, 0.96, 0.97), 0.3)

	# work room: kitchen run along the north wall, the gap for the dishwasher, the new partition (studs only)
	_static_box(Vector3(3.6, 0.9, 0.62), Vector3(1.95, 0.45, 0.39), counter)
	_static_box(Vector3(0.6, 0.9, 0.62), Vector3(5.1, 0.45, 0.39), _flat(Color(0.55, 0.45, 0.35)))   # dishwasher gap (box)
	_static_box(Vector3(0.75, 1.9, 0.7), Vector3(6.0, 0.95, 0.43), _flat(Color(0.8, 0.82, 0.84), 0.4))  # fridge
	for i in 9:
		_static_box(Vector3(0.09, 2.6, 0.045), Vector3(6.4, 1.3, 2.4 + i * 0.4), timber, PI / 2)       # studs
	_static_box(Vector3(0.09, 0.05, 3.3), Vector3(6.4, 0.025, 4.0), timber)                           # bottom plate
	_static_box(Vector3(1.22, 0.6, 2.44), Vector3(3.0, 0.3, 5.6), board)       # drywall stack
	_static_box(Vector3(2.1, 0.8, 0.95), Vector3(1.6, 0.4, 2.6), _flat(Color(0.65, 0.55, 0.4)))  # couch, still boxed
	_static_box(Vector3(0.5, 0.35, 0.3), Vector3(7.8, 0.175, 6.2), dark)        # tool bag

	# garage
	_static_box(Vector3(0.6, 1.8, 3.0), Vector3(0.45, 0.9, 9.0), dark)          # shelves
	_static_box(Vector3(1.8, 0.9, 0.7), Vector3(7.6, 0.45, 7.6), timber)        # workbench

	# bathroom
	_static_box(Vector3(1.7, 0.6, 0.8), Vector3(15.0, 0.3, 0.55), porcelain)    # tub
	_static_box(Vector3(0.45, 0.85, 0.4), Vector3(12.2, 0.42, 0.35), porcelain) # sink
	_static_box(Vector3(0.4, 0.45, 0.65), Vector3(15.5, 0.22, 3.2), porcelain)  # toilet

	# Rose's room
	_static_box(Vector3(1.0, 0.5, 2.0), Vector3(15.0, 0.25, 5.3), fabric)       # bed
	_static_box(Vector3(0.6, 0.9, 0.6), Vector3(12.0, 0.45, 7.3), _flat(Color(0.5, 0.3, 0.25)))  # armchair

	# stairs (to the upper floor, not walkable yet)
	for i in 8:
		_static_box(Vector3(1.0, 0.2 * (i + 1), 0.28), Vector3(15.3, 0.1 * (i + 1), 11.6 - i * 0.28), timber)

	# the brothers' van on the driveway
	_static_box(Vector3(2.0, 2.0, 4.8), Vector3(4.0, 1.05, 16.5), _flat(Color(0.82, 0.82, 0.8), 0.4))
