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
var idle_clip := "idle"         # what this person does standing still (Sofia: "phone")
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
var _post: Variant = null      # take_post: a working spot to step to while busy
var _post_look := Vector3.ZERO
var size := 1.0                # model scale (height / built height); strides scale with it
var skeleton: Skeleton3D
var limp := false              # a ragdoll (go_limp) or a carried body (hold_limp): no walking, no clips
var _shape: CollisionShape3D
var _label: Label3D
var _sim: PhysicalBoneSimulator3D

## `who` is a name in People.CAST: its own model, scaled to its height.
func setup(who: String, gfx: Graphics) -> void:
	display_name = who
	size = People.scale_of(who)
	collision_layer = 2      # people: collide with the house (layer 1) but not with each other,
	collision_mask = 1       # so nobody gets stuck in a 1.2 m doorway
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.75 * size
	_shape.shape = capsule
	_shape.position.y = 0.875 * size
	add_child(_shape)

	model = People.model(who).instantiate()
	model.scale = Vector3.ONE * size
	add_child(model)
	gfx.style_person(model)
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim:
		_anim.play("idle")
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var skel := skeleton
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
	_label = label
	label.text = who
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 8
	label.fixed_size = true                # same size on screen when the camera moves in
	label.pixel_size = 0.00045
	label.modulate = UiTheme.person_color(who).lightened(0.25)
	label.position.y = 2.1 * size
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

## While busy: walk straight to a nearby working spot and face `look` there (pair jobs keep apart).
func take_post(p: Vector3, look: Vector3) -> void:
	_post = p
	_post_look = look
	_going = false

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

func _physics_process(delta: float) -> void:
	if limp:
		return
	var dir := Vector3.ZERO
	if busy:
		if _post != null:             # step over to the assigned working spot, then face the work
			var to_post: Vector3 = _post - global_position
			to_post.y = 0.0
			if to_post.length() > 0.06:
				dir = to_post.normalized() * minf(1.0, to_post.length() * 2.5)
			else:
				_post = null
				face(_post_look)
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
	var clip := idle_clip
	var scale := 1.0
	if work_anim != "":
		clip = work_anim
	elif carrying != "":
		clip = "drag" if carrying == "solo" else "carry"
		scale = planar / ((DRAG_NATURAL if carrying == "solo" else CARRY_NATURAL) * size)
	elif planar > 0.15:
		var run_clip := running and speed_mul >= 1.0
		clip = "run" if run_clip else "walk"
		scale = planar / ((RUN_NATURAL if run_clip else WALK_NATURAL) * size)
	elif talking:
		clip = "talk"
	if _anim.current_animation != clip:
		_anim.play(clip, 0.25)
	_anim.speed_scale = 0.0 if carrying != "" and planar < 0.15 else clampf(scale, 0.3, 2.0)

# ---------------------------------------------------------------- ragdoll

## Ragdoll bones: [bone, child bone that ends it ("" = use `length`), radius, joint, length]. Hands, feet,
## fingers and the face stay as animated (they follow their physical parent).
const RAGDOLL := [
	["Hips", "Spine", 0.13, "", 0.0],
	["Spine", "Chest", 0.12, "cone", 0.0],
	["Chest", "Neck", 0.14, "cone", 0.0],
	["Head", "", 0.1, "cone", 0.2],
	["UpperArm_L", "Forearm_L", 0.045, "cone", 0.0],
	["Forearm_L", "Hand_L", 0.04, "hinge", 0.0],
	["UpperArm_R", "Forearm_R", 0.045, "cone", 0.0],
	["Forearm_R", "Hand_R", 0.04, "hinge", 0.0],
	["UpperLeg_L", "LowerLeg_L", 0.07, "cone", 0.0],
	["LowerLeg_L", "Foot_L", 0.055, "hinge", 0.0],
	["UpperLeg_R", "LowerLeg_R", 0.07, "cone", 0.0],
	["LowerLeg_R", "Foot_R", 0.055, "hinge", 0.0],
]

## Collapse: the clips stop and the body falls under physics (layer 4, collides with the house only),
## pushed by `impulse` at the chest.
func go_limp(impulse := Vector3.ZERO) -> void:
	if skeleton == null or limp:
		return
	limp = true
	busy = true
	work_anim = ""
	hold_tool("")
	velocity = Vector3.ZERO
	_shape.disabled = true
	_label.visible = false
	if _anim:
		_anim.pause()
	if _sim == null:
		_build_ragdoll()
	_sim.active = true
	_sim.physical_bones_start_simulation()
	if impulse != Vector3.ZERO:
		var chest := _sim.find_child("PB_Chest", false, false) as PhysicalBone3D
		if chest:
			chest.apply_central_impulse(impulse)

func show_tag(on: bool) -> void:
	_label.visible = on and not limp

## True once every ragdoll bone has come to rest.
func ragdoll_settled() -> bool:
	if _sim == null:
		return false
	for pb in _sim.get_children():
		if pb is PhysicalBone3D and (pb as PhysicalBone3D).linear_velocity.length() > 0.08:
			return false
	return true

## Where the body is (the hips), whatever the ragdoll did.
func body_position() -> Vector3:
	if _sim != null and limp:
		var hips := _sim.find_child("PB_Hips", false, false) as PhysicalBone3D
		if hips:
			return hips.global_position
	if skeleton == null:
		return global_position
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Hips"))).origin

func _build_ragdoll() -> void:
	_sim = PhysicalBoneSimulator3D.new()
	skeleton.add_child(_sim)
	for spec in RAGDOLL:
		var bone := skeleton.find_bone(spec[0])
		if bone < 0:
			continue
		var head := skeleton.get_bone_global_rest(bone).origin
		var length: float = spec[4]
		if spec[1] != "":
			length = head.distance_to(skeleton.get_bone_global_rest(skeleton.find_bone(spec[1])).origin)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + spec[0]
		pb.bone_name = spec[0]
		pb.collision_layer = 8
		pb.collision_mask = 1
		pb.mass = 2.0 if spec[0] in ["Hips", "Spine", "Chest"] else 1.0
		pb.friction = 0.9
		pb.linear_damp = 0.4
		pb.angular_damp = 3.0
		# the body is centred half way down the bone (bones run along their local +Y)
		pb.body_offset = Transform3D(Basis(), Vector3(0, length / 2.0, 0))
		pb.joint_offset = Transform3D(Basis(), Vector3(0, -length / 2.0, 0))
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = spec[2]
		cap.height = maxf(length + spec[2] * 0.6, spec[2] * 2.0 + 0.01)
		cs.shape = cap
		pb.add_child(cs)
		_sim.add_child(pb)
		match spec[3]:
			"cone":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
				pb.set("joint_constraints/swing_span", 50.0)
				pb.set("joint_constraints/twist_span", 25.0)
			"hinge":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
				pb.set("joint_constraints/angular_limit_enabled", true)
				pb.set("joint_constraints/angular_limit_upper", 0.0)
				pb.set("joint_constraints/angular_limit_lower", -130.0)
			_:
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
