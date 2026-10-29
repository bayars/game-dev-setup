extends SceneTree
## The cast lineup (milestone 3 check): all seven people side by side, every clip on every model, then
## Daniel goes limp and falls as a ragdoll. Prints PEOPLE_OK, or PEOPLE_FAIL with the reasons.
##   godot --headless --path godot-house -s res://tests/people_test.gd
## Watch it: DISPLAY=:0 godot --path godot-house --rendering-driver vulkan -s res://tests/people_test.gd
##   --write-movie out.png --fixed-fps 10 --quit-after 400

const CLIP_SECONDS := 0.8

var root3d: Node3D
var gfx: Graphics
var people: Array[Actor] = []
var fails: Array[String] = []

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root3d = Node3D.new()
	get_root().add_child(root3d)
	gfx = Graphics.new()
	root3d.add_child(gfx)
	gfx.build_environment(root3d)
	gfx.load_level("medium" if DisplayServer.get_name() != "headless" else "low", false)
	gfx.sun.rotation_degrees = Vector3(-40, 25, 0)

	var floor_body := StaticBody3D.new()           # the floor the ragdoll lands on (layer 1, like the house)
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.2, 30)
	fs.shape = box
	fs.position.y = -0.1
	floor_body.add_child(fs)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	mesh.mesh = pm
	mesh.material_override = gfx.pbr("wood", 2.0)
	floor_body.add_child(mesh)
	root3d.add_child(floor_body)

	var names := People.CAST.keys()
	for i in names.size():
		var a := Actor.new()
		root3d.add_child(a)
		a.position = Vector3((i - (names.size() - 1) / 2.0) * 1.1, 0.02, 0)
		a.setup(names[i], gfx)
		a.face(a.position + Vector3(0, 0, 1))
		a.busy = true
		people.append(a)
		var player := a.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for clip in People.CLIPS:
			if player == null or not player.has_animation(clip):
				fails.append("%s has no clip %s" % [names[i], clip])

	var cam := Camera3D.new()
	cam.fov = 30
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 9.5), Vector3(0, 0.9, 0))
	await _run()

func _run() -> void:
	await process_frame
	for clip in People.CLIPS:
		if clip == "limp":
			continue
		for a in people:
			a.work(clip)
		await create_timer(CLIP_SECONDS).timeout
	for a in people:
		a.work("")
	var daniel := people[People.CAST.keys().find("Daniel")]
	daniel.work("react_fall")
	await create_timer(0.8).timeout
	daniel.go_limp(Vector3(0, 0, -4.0))
	var t := 0.0
	var still := 0.0                   # seconds the ragdoll has been at rest
	while t < 8.0 and still < 0.5:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		still = still + 1.0 / Engine.physics_ticks_per_second if t > 1.0 and daniel.ragdoll_settled() else 0.0
		if OS.get_environment("PEOPLE_DEBUG") != "" and int(t * 60) % 30 == 0:
			var pb := daniel.skeleton.find_child("PB_Chest", true, false) as PhysicalBone3D
			print("t=%.1f hips=%s chest=%s sim=%s v=%s" % [t, daniel.body_position(), pb.global_position,
				pb.is_simulating_physics(), pb.linear_velocity])
	var hips := daniel.body_position()
	if not daniel.ragdoll_settled():
		fails.append("the ragdoll did not settle in 8 s")
	if not (hips.y > 0.0 and hips.y < 0.35):
		fails.append("ragdoll hips at height %.2f (expected on the floor)" % hips.y)
	if not hips.is_finite() or Vector2(hips.x, hips.z).distance_to(Vector2(daniel.position.x, daniel.position.z)) > 2.5:
		fails.append("ragdoll flew off to %s" % hips)
	await create_timer(1.0).timeout
	if fails.is_empty():
		print("PEOPLE_OK %d people, %d clips, ragdoll at rest after %.1f s (hips %.2f m)" % [people.size(),
			People.CLIPS.size(), t, hips.y])
	else:
		print("PEOPLE_FAIL ", fails)
	quit(0 if fails.is_empty() else 1)
