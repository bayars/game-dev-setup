class_name Player
extends CharacterBody3D
## The walker: WASD/arrows relative to the camera (Shift runs), mouse orbits the camera.
## The person model is a rigged glTF with animations: idle, walk, run (all looping) and open_door.
## Walk/run playback speed follows the real movement speed so the feet do not slide.

const WALK_SPEED := 2.4
const RUN_SPEED := 4.6
const WALK_NATURAL := 1.75   # m/s one pass of the walk clip covers at speed_scale 1
const RUN_NATURAL := 4.6
const ACCEL := 14.0
const GRAVITY := 20.0
const MOUSE_SENS := 0.003

## x: right, y: back (so walking forward is y = -1). The main script sets this in the self-test.
var move_input := Vector2.ZERO
var run := false
var frozen := false
var cam_yaw := 0.0

var model: Node3D
var _anim: AnimationPlayer
var _action := false     # a one-shot action (open_door) is playing
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
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim:
		_anim.play("idle")

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

func has_animation(clip: String) -> bool:
	return _anim != null and _anim.has_animation(clip)

## Plays a one-shot clip (e.g. "open_door") and returns its length in seconds.
func play_action(clip: String) -> float:
	if not has_animation(clip):
		return 0.0
	_action = true
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.25)
	return _anim.get_animation(clip).length

func end_action() -> void:
	_action = false

func _animate(_delta: float) -> void:
	if _anim == null or _action:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var clip := "idle"
	var scale := 1.0
	if planar > 0.15:
		if run or Input.is_physical_key_pressed(KEY_SHIFT):
			clip = "run"
			scale = planar / RUN_NATURAL
		else:
			clip = "walk"
			scale = planar / WALK_NATURAL
	if _anim.current_animation != clip:
		_anim.play(clip, 0.25)
	_anim.speed_scale = clampf(scale, 0.3, 2.0)
