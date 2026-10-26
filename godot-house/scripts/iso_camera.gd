class_name IsoCamera
extends Node3D
## Isometric-style camera on the 3D scene: a long lens high above at 45 degrees, following a target.
## The view never turns (the house always faces the same way); the mouse wheel zooms. `focus_on` moves in close on a point (the install
## view) with its own zoom range; `release` goes back to following the target.

const PITCH := -40.0
const FOV := 24.0
const MAX_FIT := 24.0              # the install view backs off at most this far to show every hotspot

var target: Node3D
var distance := 26.0
var floor_y := 0.0                 # height of the floor the controlled brother is on (mouse picking)
var _focus: Variant = null         # Vector3 while focused on a job
var _focus_yaw: Variant = null     # radians: the install view looks at the work from its open side
var _focus_pitch: Variant = null
var _pitch := deg_to_rad(PITCH)
var _saved_distance := 26.0
var _dist := 26.0                  # what is shown; eases towards `distance`
var camera: Camera3D
var _yaw := deg_to_rad(45.0)

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 200.0
	camera.current = true
	add_child(camera)
	_place()

func zoom(factor: float) -> void:
	if _focus != null:
		distance = clampf(distance * factor, 3.0, MAX_FIT)
	else:
		distance = clampf(distance * factor, 12.0, 48.0)

## Moves in on `p` from `dist` metres; `yaw` and `pitch` (radians) turn the view for it, NAN keeps the
## normal isometric angle.
func focus_on(p: Vector3, dist: float, yaw := NAN, pitch := NAN) -> void:
	if _focus == null:
		_saved_distance = distance
	_focus = p
	distance = dist
	_focus_yaw = null if is_nan(yaw) else yaw
	_focus_pitch = null if is_nan(pitch) else pitch

func release() -> void:
	if _focus != null:
		_focus = null
		_focus_yaw = null
		_focus_pitch = null
		distance = _saved_distance

## Where to look and from how far so that every point lands inside `safe` (screen pixels) when seen from
## `yaw` and `pitch` (radians). Returns [focus, distance].
func fit(points: Array, yaw: float, pitch: float, safe: Rect2, min_dist: float) -> Array:
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
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
		d = clampf(d * maxf(need, 0.2), min_dist, MAX_FIT)
	return [focus, d]

func is_focused() -> bool:
	return _focus != null

## Horizontal direction from the target to the camera.
func toward_camera() -> Vector2:
	return Vector2(sin(_yaw), cos(_yaw))

## Camera-relative movement: input x right, y back -> world xz direction.
func to_world(input: Vector2) -> Vector2:
	var fwd := -toward_camera()
	var right := Vector2(cos(_yaw), -sin(_yaw))
	return right * input.x - fwd * input.y

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
	var yaw_goal: float = _focus_yaw if _focus != null and _focus_yaw != null else deg_to_rad(45.0)
	var pitch_goal: float = _focus_pitch if _focus != null and _focus_pitch != null else deg_to_rad(PITCH)
	_yaw = lerp_angle(_yaw, yaw_goal, 1.0 - exp(-6.0 * delta))
	_pitch = lerpf(_pitch, pitch_goal, 1.0 - exp(-6.0 * delta))
	_place()

## The point the camera looks at (the followed person, or the work in the install view).
func look_point() -> Vector3:
	return global_position

func _place() -> void:
	rotation = Vector3(0, _yaw, 0)
	if camera:
		camera.position = Vector3(0, 0, _dist).rotated(Vector3.RIGHT, _pitch)
		camera.rotation = Vector3(_pitch, 0, 0)

func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 0.9, 0)
	_dist = distance
