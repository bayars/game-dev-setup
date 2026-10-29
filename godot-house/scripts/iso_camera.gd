class_name IsoCamera
extends Node3D
## Isometric-style camera on the 3D scene: a long lens high above at 45 degrees, following a target.
## Q/R rotate in 90-degree steps, the mouse wheel zooms. `focus_on` moves in close on a point (the install
## view) with its own zoom range; `release` goes back to following the target.

const PITCH := -40.0
const FOV := 24.0

var target: Node3D
var distance := 26.0
var floor_y := 0.0                 # height of the floor the controlled brother is on (mouse picking)
var _focus: Variant = null         # Vector3 while focused on a job
var _saved_distance := 26.0
var _dist := 26.0                  # what is shown; eases towards `distance`
var yaw_index := 0
var camera: Camera3D
var _yaw := deg_to_rad(45.0)

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 200.0
	camera.current = true
	add_child(camera)
	_place()

func rotate_step(steps: int) -> void:
	yaw_index = posmod(yaw_index + steps, 4)

func zoom(factor: float) -> void:
	if _focus != null:
		distance = clampf(distance * factor, 3.0, 16.0)
	else:
		distance = clampf(distance * factor, 12.0, 48.0)

func focus_on(p: Vector3, dist: float) -> void:
	if _focus == null:
		_saved_distance = distance
	_focus = p
	distance = dist

func release() -> void:
	if _focus != null:
		_focus = null
		distance = _saved_distance

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
	_yaw = lerp_angle(_yaw, deg_to_rad(45.0 + 90.0 * yaw_index), 1.0 - exp(-8.0 * delta))
	_place()

func _place() -> void:
	rotation = Vector3(0, _yaw, 0)
	if camera:
		camera.position = Vector3(0, 0, _dist).rotated(Vector3.RIGHT, deg_to_rad(PITCH))
		camera.rotation = Vector3(deg_to_rad(PITCH), 0, 0)

func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 0.9, 0)
	_dist = distance
