class_name IsoCamera
extends Node3D
## The play camera, Diablo-style: one fixed angle (from the south-east, steep, a normal lens) that never
## turns, following the target smoothly; the mouse wheel zooms a little. The install view does not turn
## or jump either: `focus_on` only slides the view onto the work and leans in.

const YAW := 45.0                  # degrees: the house always faces the same way
const PITCH := -55.0
const FOV := 40.0
const NEAR := 9.0                  # zoom range (metres from the look point)
const FAR := 22.0
const NORMAL := 15.0
const WORK_NEAR := 7.5             # the install view leans in at most this close

var target: Node3D
var distance := NORMAL
var floor_y := 0.0                 # height of the floor the controlled brother is on (mouse picking)
var _focus: Variant = null         # Vector3 while focused on a job
var _saved_distance := NORMAL
var _dist := NORMAL                # what is shown; eases towards `distance`
var camera: Camera3D

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 200.0
	camera.current = true
	add_child(camera)
	rotation = Vector3(0, deg_to_rad(YAW), 0)
	_place()

func zoom(factor: float) -> void:
	distance = clampf(distance * factor, WORK_NEAR if _focus != null else NEAR, FAR)

## Slides the view onto `p` from `dist` metres (the same angle as always).
func focus_on(p: Vector3, dist: float) -> void:
	if _focus == null:
		_saved_distance = distance
	_focus = p
	distance = dist

func release() -> void:
	if _focus != null:
		_focus = null
		distance = _saved_distance

## Where to look and from how far so that every point lands inside `safe` (screen pixels), between
## `min_dist` and `max_dist`. Returns [focus, distance].
func fit(points: Array, safe: Rect2, min_dist: float, max_dist: float) -> Array:
	var b := Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(YAW), 0))
	var fwd := -b.z
	var vp := get_viewport().get_visible_rect().size
	var t := tan(deg_to_rad(FOV) / 2.0)
	var aspect := vp.x / vp.y
	var focus := Vector3.ZERO
	for p in points:
		focus += p
	focus /= maxf(1.0, points.size())
	var d := min_dist
	for i in 12:
		var eye := focus - fwd * d
		var box := Rect2()
		for k in points.size():
			var v: Vector3 = points[k] - eye
			var z := v.dot(fwd)
			var px := Vector2((v.dot(b.x) / (z * t * aspect) + 1.0) * 0.5 * vp.x, (1.0 - v.dot(b.y) / (z * t)) * 0.5 * vp.y)
			box = Rect2(px, Vector2.ZERO) if k == 0 else box.expand(px)
		var per_px := 2.0 * d * t / vp.y          # metres per pixel at the focus
		var off := box.get_center() - safe.get_center()
		focus += b.x * off.x * per_px - b.y * off.y * per_px
		var need := maxf(box.size.x / safe.size.x, box.size.y / safe.size.y)
		d = clampf(d * maxf(need, 0.2), min_dist, max_dist)
	return [focus, d]

func is_focused() -> bool:
	return _focus != null

## Horizontal direction from the look point to the camera.
func toward_camera() -> Vector2:
	var y := deg_to_rad(YAW)
	return Vector2(sin(y), cos(y))

## Where the mouse ray hits the floor plane, or null.
func floor_point(screen_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, floor_y).intersects_ray(from, dir)

func _process(delta: float) -> void:
	var goal: Variant = _focus if _focus != null else (target.global_position + Vector3(0, 0.9, 0) if target else null)
	if goal != null:
		global_position = global_position.lerp(goal, 1.0 - exp(-6.0 * delta))
	_dist = lerpf(_dist, distance, 1.0 - exp(-5.0 * delta))
	_place()

## The point the camera looks at (the followed person, or the work in the install view).
func look_point() -> Vector3:
	return global_position

func _place() -> void:
	if camera:
		var pitch := deg_to_rad(PITCH)
		camera.position = Vector3(0, 0, _dist).rotated(Vector3.RIGHT, pitch)
		camera.rotation = Vector3(pitch, 0, 0)

func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 0.9, 0)
	_dist = distance
