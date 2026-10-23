class_name Player
extends CharacterBody3D
## The walker: WASD/arrows relative to the camera (Shift runs), mouse orbits the camera.
## The person model swings its joints (ArmL/ArmR/LegL/LegR/Head) for a procedural walk cycle.

const WALK_SPEED := 3.2
const RUN_SPEED := 5.6
const ACCEL := 14.0
const GRAVITY := 20.0
const MOUSE_SENS := 0.003

## x: right, y: back (so walking forward is y = -1). The main script sets this in the self-test.
var move_input := Vector2.ZERO
var run := false
var frozen := false
var cam_yaw := 0.0

var model: Node3D
var _limbs := {}
var _cycle := 0.0
var _rig: Node3D
var _arm: SpringArm3D

func setup(model_scene: PackedScene) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)

	model = model_scene.instantiate()
	model.rotation.y = PI  # the model faces +Z; start facing the house (-Z)
	add_child(model)
	for joint in ["ArmL", "ArmR", "LegL", "LegR", "Head"]:
		_limbs[joint] = model.find_child(joint, true, false)

	_rig = Node3D.new()
	_rig.top_level = true
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = 4.4
	_arm.margin = 0.35
	_arm.rotation.x = -0.22
	_arm.add_excluded_object(get_rid())
	_rig.add_child(_arm)
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.current = true
	_arm.add_child(camera)
	_rig.global_position = global_position + Vector3(0, 1.5, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * MOUSE_SENS
		_arm.rotation.x = clampf(_arm.rotation.x - event.relative.y * MOUSE_SENS, -1.15, 0.2)

func _read_keys() -> Vector2:
	var v := Vector2(
		float(_down(KEY_D, KEY_RIGHT)) - float(_down(KEY_A, KEY_LEFT)),
		float(_down(KEY_S, KEY_DOWN)) - float(_down(KEY_W, KEY_UP)))
	return v

func _down(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

func _physics_process(delta: float) -> void:
	var input := move_input
	if not frozen and input == Vector2.ZERO:
		input = _read_keys()
	var wants_run := run or Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := RUN_SPEED if wants_run else WALK_SPEED
	var dir := Vector3(input.x, 0.0, input.y)
	if frozen:
		dir = Vector3.ZERO
	dir = (dir.normalized() * minf(input.length(), 1.0)).rotated(Vector3.UP, cam_yaw)

	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * speed)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
	_animate(delta)

func _process(delta: float) -> void:
	_rig.rotation.y = cam_yaw
	var goal := global_position + Vector3(0, 1.5, 0)
	_rig.global_position = _rig.global_position.lerp(goal, 1.0 - exp(-12.0 * delta))

func face_toward(target: Vector3, seconds: float = 0.4) -> void:
	var d := target - global_position
	var tween := create_tween()
	tween.tween_property(model, "rotation:y", atan2(d.x, d.z), seconds)

func _animate(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var amp := clampf(planar / WALK_SPEED, 0.0, 1.6)
	_cycle += planar * delta * 2.3
	var swing := sin(_cycle) * 0.75 * amp
	_set_rot("LegL", swing)
	_set_rot("LegR", -swing)
	_set_rot("ArmL", -swing * 0.8)
	_set_rot("ArmR", swing * 0.8)
	var head: Node3D = _limbs["Head"]
	if head:
		head.rotation.x = sin(_cycle * 2.0) * 0.03 * amp
	model.position.y = absf(sin(_cycle)) * 0.045 * amp

func _set_rot(joint: String, angle: float) -> void:
	var node: Node3D = _limbs[joint]
	if node:
		node.rotation.x = lerpf(node.rotation.x, angle, 0.5)
