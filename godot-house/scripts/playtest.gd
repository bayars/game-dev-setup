class_name Playtest
extends Node
## Automated play-testing of what a player sees and where they can go (`-- --playtest`), on top of the
## scripted self-test. Every check reports what failed and where; the run prints PLAYTEST_OK or
## PLAYTEST_FAIL with the list.
##   install   every hotspot of every step of every job is on screen, outside the HUD panels and not
##             hidden behind a wall or furniture once the camera has moved in
##   posts     both brothers reach their working spots on two-person jobs
##   reach     every room and every job station can be walked to (click to move), without getting stuck
##   wasd      walking into walls and corners with the keys never leaves a person stuck or inside a wall
##   tour      the everyday states (intro, carrying alone and together, help, upstairs, end card): no HUD
##             panel covers another
## `--shots=<dir>` also saves a screenshot per install step (needs a real display).

var main: Node3D
var fails: Array[String] = []
var shots := ""
var _tests: Array = []

func _init(m: Node3D, args: PackedStringArray) -> void:
	main = m
	for a in args:
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--only="):
			_tests = a.substr(7).split(",")

func run() -> void:
	while not main._nav_ok:
		await get_tree().physics_frame
	await _wait(0.5)
	if _wants("install"):
		await _check_install()
	if _wants("reach"):
		await _check_reach()
	if _wants("wasd"):
		await _check_wasd()
	if _wants("tour"):                       # last: it plays the day to its end
		await _tour()
	if fails.is_empty():
		print("PLAYTEST_OK")
	else:
		for f in fails:
			print("  - " + f)
		print("PLAYTEST_FAIL %d problems" % fails.size())
	get_tree().quit(0 if fails.is_empty() else 1)

func _wants(t: String) -> bool:
	return _tests.is_empty() or t in _tests

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func _fail(what: String) -> void:
	fails.append(what)
	print("FAIL " + what)

# ---------------------------------------------------------------- tour

func _shot(name: String) -> void:
	_check_overlaps(name)
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/tour_%s.png" % [shots, name])

## HUD panels that show at the same time must not cover each other.
func _check_overlaps(name: String) -> void:
	var tops: Array = main.hud.top_panels()
	for i in tops.size():
		for k in range(i + 1, tops.size()):
			var a: Control = tops[i]
			var b: Control = tops[k]
			if a.get_global_rect().grow(-2).intersects(b.get_global_rect().grow(-2)):
				_fail("%s: HUD %s overlaps %s" % [name, a.name, b.name])

## The normal play states a first-time player sees, with a screenshot each.
func _tour() -> void:
	var nico: Actor = main.nico
	var tomas: Actor = main.tomas
	var jobs: Dictionary = main.jobs
	main._dialogue.fast = false
	main._dialogue.play(Day1.INTRO)
	await _wait(1.0)
	await _shot("intro")
	main._dialogue._skip = true
	main._dialogue.fast = true
	await _wait(1.0)
	main.order_go(Vector3(5.0, 0, 9.5))
	await _wait(0.5)
	_place(nico, jobs.dishwasher_in.carry.global_position + Vector3(-1.0, 0, 0))
	await _wait(0.5)
	await _shot("near_load")
	main.interact()
	nico.go_to(Vector3(9.0, 0, 13.5))
	await _wait(1.5)
	await _shot("solo_carry")
	main.interact()
	main.call_brother()
	await _walk_check(nico, jobs.couch_in.carry.global_position + Vector3(-1.0, 0, 0), "to the couch")
	await _wait(2.0)
	main.interact()
	nico.go_to(Vector3(10.0, 0, 11.0))
	await _wait(2.5)
	await _shot("pair_carry")
	await _walk_check(nico, Day1.COUCH_TARGET + Vector3(0, 0, 1.2), "carry the couch in")
	main.interact()
	await _wait(1.5)
	await _shot("delivered")
	main.hud.toggle_help()
	await _wait(0.3)
	await _shot("help")
	main.hud.toggle_help()
	await _walk_check(nico, Vector3(4.5, House.UP, 3.0), "upstairs")
	await _wait(1.0)
	await _shot("upstairs")
	await _walk_check(nico, Vector3(7.0, 0, 3.0), "back down")
	for job in jobs.values():
		if not job.done:
			main.site.finish(job.id, job.steps)
			main.complete_job(job)
	var t := 0.0
	while not main.hud.end_visible() and t < 30.0:
		await _wait(0.5)
		t += 0.5
	await _wait(0.5)
	await _shot("end")

# ---------------------------------------------------------------- install view

## Plays every job's install view step by step (the results are applied as a player would see them) and
## checks each hotspot where the camera shows it.
func _check_install() -> void:
	var jobs: Dictionary = main.jobs
	var order: Array = ["studs", "wiring", "drywall", "flooring", "dishwasher_in", "dishwasher", "couch_in", "assemble", "measure"]
	if main.day == 2:
		order = ["closet_studs", "closet_drywall", "skirting", "light"]
		main.story.phase = Story2.Phase.END        # no accident: only the views are checked here
	for id in order:
		var job: Job = jobs[id]
		if job.carry != null:                    # deliver the load where it belongs
			job.carry.position = job.carry_target + Vector3(0, Worksite.FLOOR, 0)
			main.complete_job(job)
			continue
		var me: Actor = main.current
		var helper: Actor = main.other()
		_place(me, job.station)
		if job.needs_two:
			_place(helper, job.station + Vector3(0, 0, 1.0))
		await _wait(0.3)
		main.start_job(job)
		if not main.install.is_active():
			_fail("%s: the install view did not open" % id)
			continue
		if job.needs_two:
			await _wait(1.5)
			for a in [me, helper]:
				if a._post != null:
					_fail("%s: %s never reached his working spot (at %s, spot %s)" % [id, a.display_name, a.global_position, a._post])
			if me.global_position.distance_to(helper.global_position) < 0.7:
				_fail("%s: the brothers stand inside each other" % id)
		while main.install.is_active():
			var step: int = main.install.step
			await _wait(1.6)                     # the camera eases in
			_check_spots(job, step)
			if shots != "":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [shots, id, step])
			var ins: Install = main.install
			for i in ins._spots.size():
				ins._done[i] = true
				main.site.apply(job.id, step, i, 1.0)
			ins._after_spot()
			await _wait(0.2)
		if not job.done:
			_fail("%s: not done after all steps" % id)
		await _wait(0.5)

func _check_spots(job: Job, step: int) -> void:
	var ins: Install = main.install
	var cam: Camera3D = main.cam.camera
	var view := get_viewport().get_visible_rect().grow(-8)
	var blocked: Array[Rect2] = main.hud.blocking_rects()
	for k in ins._spots.size():
		var p: Vector3 = ins._spots[k]
		var where := "%s step %d spot %d %s" % [job.id, step + 1, k, p]
		if cam.is_position_behind(p):
			_fail(where + ": behind the camera")
			continue
		var px := cam.unproject_position(p)
		if not view.has_point(px):
			_fail(where + ": off screen at %s" % px)
			continue
		for r in blocked:
			if r.grow(6).has_point(px):
				_fail(where + ": under a HUD panel %s at %s" % [r, px])
				break
		var hit := _first_hit(cam.global_position, p)
		if hit != "":
			_fail(where + ": hidden behind " + hit)

## The first solid thing between the camera and `p` that is actually drawn there (walls lowered by the
## cutaway only count below their stub), or "" if the view is clear.
func _first_hit(from: Vector3, p: Vector3) -> String:
	var space := main.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for tries in 12:
		var q := PhysicsRayQueryParameters3D.create(from, p, 1, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.25:
			return ""
		var body := hit.collider as Node
		if not _drawn_at(body, hit.position):
			exclude.append(hit.rid)
			continue
		return "%s at %s" % [body.name, (hit.position as Vector3).snapped(Vector3.ONE * 0.01)]
	return ""

func _drawn_at(body: Node, at: Vector3) -> bool:
	var house: House = main.house
	if not body.is_visible_in_tree():
		return false
	for w in house.walls:
		var mi := w.mesh as MeshInstance3D
		if mi.get_parent() == body:
			var base := House.UP if w.level == 1 else 0.0
			var limit := lerpf(House.H + 1.0, 0.35, w.cut)
			return at.y - base <= limit
	var mesh := body.find_child("*", true, false)
	return body.find_children("*", "MeshInstance3D", true, false).size() > 0 or mesh == null

# ---------------------------------------------------------------- walking

func _place(a: Actor, p: Vector3) -> void:
	a.stop()
	a.global_position = Vector3(p.x, p.y + 0.05, p.z)
	a.velocity = Vector3.ZERO

## Walks to `p` with click-to-move; fails if the person stops moving for 3 s on the way.
func _walk_check(a: Actor, p: Vector3, label: String) -> bool:
	a.go_to(p)
	var t := 0.0
	var last := a.global_position
	var still := 0.0
	await get_tree().physics_frame
	while a.is_going() and t < 60.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if a.global_position.distance_to(last) > 0.3:
			last = a.global_position
			still = 0.0
		else:
			still += dt
		if still > 3.0:
			_fail("%s: stuck at %s on the way to %s" % [label, a.global_position.snapped(Vector3.ONE * 0.01), p])
			a.stop()
			return false
	var flat := Vector2(a.global_position.x - p.x, a.global_position.z - p.z).length()
	if flat > 0.8 or absf(a.global_position.y - p.y) > 0.6:
		_fail("%s: ended at %s, not at %s" % [label, a.global_position.snapped(Vector3.ONE * 0.01), p])
		return false
	return true

func _check_reach() -> void:
	var a: Actor = main.current
	main.follow = false
	_place(a, Vector3(10.0, 0.0, 14.0))
	var targets: Array = []
	var seen := {}
	for r in House.ROOMS:
		if seen.has(r[0]):
			continue
		seen[r[0]] = true
		targets.append([r[0], _free_point(House.room_center(r[0]))])
	for job in main.jobs.values():
		if job.carry == null:
			targets.append(["job " + job.id, job.station])
	targets.append(["outside (front)", Vector3(10.0, 0.0, 14.0)])
	for t in targets:
		await _walk_check(a, t[1], "walk to " + t[0])

## The nearest point on the navigation mesh (a room's centre may be under a bed).
func _free_point(p: Vector3) -> Vector3:
	var map := main.get_world_3d().navigation_map
	var q := NavigationServer3D.map_get_closest_point(map, p + Vector3(0, 0.2, 0))
	return Vector3(q.x, p.y, q.z)

## Steers into every wall of every room with the keys (8 directions from the centre), then checks the
## person is not inside a wall and can still walk back.
func _check_wasd() -> void:
	var a: Actor = main.current
	main.follow = false
	var seen := {}
	for r in House.ROOMS:
		if seen.has(r[0]) or r[0] == "Landing":
			continue
		seen[r[0]] = true
		var c := _free_point(House.room_center(r[0]))
		for k in 8:
			_place(a, c)
			await _wait(0.1)
			var ang := k * TAU / 8.0
			a.steer = Vector2(cos(ang), sin(ang))
			await _wait(2.5)
			a.steer = Vector2.ZERO
			await _wait(0.2)
			if _inside_wall(a):
				_fail("keys %s dir %d: %s ended inside a wall at %s" % [r[0], k, a.display_name, a.global_position])
			if House.level_of(a.global_position + Vector3(0, 0.6, 0)) != r[2]:
				_fail("keys %s dir %d: fell to another floor at %s" % [r[0], k, a.global_position])
				continue
			await _walk_check(a, c, "keys %s dir %d, walk back" % [r[0], k])
	_place(a, Vector3(10.0, 0.0, 14.0))

func _inside_wall(a: Actor) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.18
	cap.height = 1.2
	q.shape = cap
	q.transform = Transform3D(Basis(), a.global_position + Vector3(0, 0.9, 0))
	q.collision_mask = 1
	return not main.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
