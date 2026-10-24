class_name Actor
extends CharacterBody3D
## A person in the house: the rigged person model, navigation (click-to-move, orders, schedules) and
## direct steering (WASD for the controlled brother). Walk/run/carry playback follows the real speed;
## work clips (`work`) and a tool in the right hand (`hold_tool`) come from the install view.

signal arrived

const WALK_SPEED := 2.2
const RUN_SPEED := 4.2
const WALK_NATURAL := 1.75   # m/s that one pass of the walk clip covers at speed_scale 1
const RUN_NATURAL := 4.6
const CARRY_NATURAL := 1.3
const DRAG_NATURAL := 0.75
const TOOLS := preload("res://assets/models/tools.glb")
## How a tool sits in the right hand: the grip (tool Y) across the palm, the working end forward.
static var GRIP := Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(0, 0.07, 0.02))
const ACCEL := 12.0
const GRAVITY := 20.0

var display_name := ""
var controlled := false
var steer := Vector2.ZERO      # world xz direction for direct control (WASD); overrides navigation
var running := false
var busy := false              # in the install view or holding something in place: does not move
var speed_mul := 1.0           # carrying slows you down
var lead: Actor = null         # pair carrying: walk behind this actor at `lead_gap` metres
var lead_gap := 1.6
var carrying := ""              # "", "solo" (pushing it along, loud) or "pair" (lifted together)
var talking := false
var work_anim := ""             # a work clip that overrides walking and idling
var model: Node3D
var agent: NavigationAgent3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _going := false
var _hand: BoneAttachment3D
var _tool: Node3D
var _tool_id := ""
var _tools_src: Node
var _fresh := 0                # physics frames since go_to; the agent needs a frame to compute a path

func setup(model_scene: PackedScene, who: String, jacket: Color, pants: Color, gfx: Graphics) -> void:
	display_name = who
	collision_layer = 2      # people: collide with the house (layer 1) but not with each other,
	collision_mask = 1       # so nobody gets stuck in a 1.2 m doorway
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
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
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		_hand = BoneAttachment3D.new()
		_hand.bone_name = "Hand_R"
		skel.add_child(_hand)

	agent = NavigationAgent3D.new()
	agent.radius = 0.35
	agent.height = 1.8
	agent.path_desired_distance = 0.25  # small: a doorway corner counts as passed only when actually rounded
	agent.path_height_offset = 0.2       # the baked navmesh sits ~0.2 m above the floor
	agent.target_desired_distance = 0.45
	add_child(agent)

	var label := Label3D.new()             # name tag, readable from the high camera
	label.text = who
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 8
	label.fixed_size = true                # same size on screen when the camera moves in
	label.pixel_size = 0.00045
	label.modulate = UiTheme.person_color(who).lightened(0.25)
	label.position.y = 2.1
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

## Play a work clip ("" to go back to walking and idling).
func work(anim: String, tool := "") -> void:
	work_anim = anim
	if tool != _tool_id:
		hold_tool(tool)

## Put a tool from tools.glb in the right hand ("" empties it). Parts (sheet, planks...) stay in the bag.
func hold_tool(id: String) -> void:
	if id == _tool_id or _hand == null:
		return
	_tool_id = id
	if _tool:
		_tool.queue_free()
		_tool = null
	if id == "" or id in ["sheet", "planks", "underlay", "plate"]:
		return
	if _tools_src == null:
		_tools_src = TOOLS.instantiate()
	var src := _tools_src.get_node_or_null("T_" + id) as Node3D
	if src == null:
		return
	_tool = src.duplicate() as Node3D
	_tool.transform = GRIP
	_hand.add_child(_tool)

func tool_in_hand() -> String:
	return _tool_id

func set_controlled(on: bool) -> void:
	controlled = on
	_ring.visible = on
	if not on:
		steer = Vector2.ZERO

func go_to(p: Vector3) -> void:
	agent.target_position = p
	_going = true
	_fresh = 0

func stop() -> void:
	_going = false

func is_going() -> bool:
	return _going

## Horizontal facing direction of the model.
func forward() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))

func face(p: Vector3) -> void:
	var d := p - global_position
	model.rotation.y = atan2(d.x, d.z)

func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.2

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
	if busy:
		pass
	elif lead != null:
		var spot := lead.global_position - lead.forward() * lead_gap
		var to_spot := spot - global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.08:
			dir = to_spot.normalized() * minf(1.0, to_spot.length() * 2.0)
		_going = false
	elif steer.length() > 0.05:
		dir = Vector3(steer.x, 0, steer.y).limit_length(1.0)
		_going = false
	elif _going:
		_fresh += 1
		if _fresh > 2 and agent.is_navigation_finished():
			_going = false
			arrived.emit()
		else:
			var to := agent.get_next_path_position() - global_position
			to.y = 0.0
			dir = to.normalized()
	var speed := (RUN_SPEED if running and speed_mul >= 1.0 else WALK_SPEED) * speed_mul
	var want := dir * speed
	velocity.x = move_toward(velocity.x, want.x, ACCEL * delta * speed)
	velocity.z = move_toward(velocity.z, want.z, ACCEL * delta * speed)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	var planar := Vector2(velocity.x, velocity.z)
	if lead != null:                  # face the lead and the load between you
		var d := lead.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(d.x, d.z), 10.0 * delta)
	elif planar.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(planar.x, planar.y), 10.0 * delta)
	_animate(planar.length())

func _animate(planar: float) -> void:
	if _anim == null:
		return
	var clip := "idle"
	var scale := 1.0
	if work_anim != "":
		clip = work_anim
	elif carrying != "":
		clip = "drag" if carrying == "solo" else "carry"
		scale = planar / (DRAG_NATURAL if carrying == "solo" else CARRY_NATURAL)
	elif planar > 0.15:
		var run_clip := running and speed_mul >= 1.0
		clip = "run" if run_clip else "walk"
		scale = planar / (RUN_NATURAL if run_clip else WALK_NATURAL)
	elif talking:
		clip = "talk"
	if _anim.current_animation != clip:
		_anim.play(clip, 0.25)
	_anim.speed_scale = 0.0 if carrying != "" and planar < 0.15 else clampf(scale, 0.3, 2.0)
