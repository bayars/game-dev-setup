class_name Actor
extends CharacterBody3D
## A person in the house: the rigged person model, navigation (click-to-move, orders, schedules) and
## direct steering (WASD for the controlled brother). Walk/run playback follows the real speed.

signal arrived

const WALK_SPEED := 2.2
const RUN_SPEED := 4.2
const WALK_NATURAL := 1.75   # m/s that one pass of the walk clip covers at speed_scale 1
const RUN_NATURAL := 4.6
const ACCEL := 12.0
const GRAVITY := 20.0

var display_name := ""
var controlled := false
var steer := Vector2.ZERO      # world xz direction for direct control (WASD); overrides navigation
var running := false
var model: Node3D
var agent: NavigationAgent3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _going := false

func setup(model_scene: PackedScene, who: String, jacket: Color, pants: Color, gfx: Graphics) -> void:
	display_name = who
	collision_layer = 2      # people: collide with the house (layer 1) but not with each other,
	collision_mask = 1       # so nobody gets stuck in a 1.2 m doorway
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)

	model = model_scene.instantiate()
	add_child(model)
	gfx.style_person(model)
	_tint(jacket, pants)
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim:
		_anim.play("idle")

	agent = NavigationAgent3D.new()
	agent.radius = 0.35
	agent.height = 1.8
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.45
	add_child(agent)

	var label := Label3D.new()             # name tag, readable from the high camera
	label.text = who
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.006
	label.position.y = 2.15
	add_child(label)

	_ring = MeshInstance3D.new()           # selection ring under the controlled brother
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.85, 0.3)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.75, 0.2)
	rm.emission_energy_multiplier = 1.5
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = rm
	_ring.scale.y = 0.2
	_ring.position.y = 0.03
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

func set_controlled(on: bool) -> void:
	controlled = on
	_ring.visible = on
	if not on:
		steer = Vector2.ZERO

func go_to(p: Vector3) -> void:
	agent.target_position = p
	_going = true

func stop() -> void:
	_going = false

func is_going() -> bool:
	return _going

func room() -> String:
	return House.room_at(global_position)

func _tint(jacket: Color, pants: Color) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null:
				continue
			var n := src.resource_name
			var c: Variant = null
			if n == "Jacket":
				c = jacket
			elif n == "JacketDark":
				c = jacket.darkened(0.3)
			elif n == "Pants":
				c = pants
			if c != null:
				var m := src.duplicate() as BaseMaterial3D
				m.albedo_color = c
				mi.set_surface_override_material(s, m)

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if steer.length() > 0.05:
		dir = Vector3(steer.x, 0, steer.y).limit_length(1.0)
		_going = false
	elif _going:
		if agent.is_navigation_finished():
			_going = false
			arrived.emit()
		else:
			var to := agent.get_next_path_position() - global_position
			to.y = 0.0
			dir = to.normalized()
	var speed := RUN_SPEED if running else WALK_SPEED
	var want := dir * speed
	velocity.x = move_toward(velocity.x, want.x, ACCEL * delta * speed)
	velocity.z = move_toward(velocity.z, want.z, ACCEL * delta * speed)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	var planar := Vector2(velocity.x, velocity.z)
	if planar.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(planar.x, planar.y), 10.0 * delta)
	_animate(planar.length())

func _animate(planar: float) -> void:
	if _anim == null:
		return
	var clip := "idle"
	var scale := 1.0
	if planar > 0.15:
		clip = "run" if running else "walk"
		scale = planar / (RUN_NATURAL if running else WALK_NATURAL)
	if _anim.current_animation != clip:
		_anim.play(clip, 0.25)
	_anim.speed_scale = clampf(scale, 0.3, 2.0)
