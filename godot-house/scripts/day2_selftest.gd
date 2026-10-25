class_name Day2Selftest
extends Node
## Plays day 2 the way a player would and checks where it ends (`--selftest --day=2 --case=<id> --plan=<p>`):
##   clean   tidy every sign, carry him together to a scenario that explains the injury, set it up, keep
##           Tomas working, and wait for the family to find him: the police rule it an accident
##   trail   the same, but the accident's own piece is left where it happened: "The trail"
##   truth   tell the truth at the choice: the unjust truth card
##   early   do nothing after the choice: he is found in his room ("Found too early")
##   caught  a resident walks into the brothers carrying him: "Caught in the act"
## Prints SELFTEST_OK day2 ... ending=<id>, or SELFTEST_FAIL with the reason.

const EXPECT := {"clean": "clean", "trail": "trail", "truth": "truth", "early": "found_early", "caught": "caught"}

var main: Node3D
var plan := "clean"
var shots := ""                            # --shots=<dir>: real-time run, a screenshot every 1.5 s
var story: Story2
var _deadline := 0.0

func _init(m: Node3D, args: PackedStringArray) -> void:
	main = m
	for a in args:
		if a.begins_with("--plan="):
			plan = a.substr(7)
		elif a.begins_with("--shots="):
			shots = a.substr(8)

func run() -> void:
	story = main.story
	story.cine.fast = shots == ""
	_watch_hud()
	if shots != "":
		Engine.time_scale = 1.5
		main._dialogue.fast = false
		_capture()
	while not main._nav_ok:
		await get_tree().physics_frame
	await story.start()
	var case := story.case
	# an ordinary job first: the light, played through the install view
	_log("morning: the light")
	var err := await _do_job(main.jobs.light, true)
	if err != "":
		return _fail(err)
	if not main.jobs.light.done:
		return _fail("the light job did not finish")
	# then the job the accident happens in
	if case.job_id == "closet_drywall":
		err = await _do_job(main.jobs.closet_studs, false)
		if err != "":
			return _fail(err)
	_log("the accident job")
	var job: Job = story.accident_job
	main.daniel.global_position = case.daniel_at + Vector3(0, 0.05, 0)
	if job.needs_two and not case.tomas_away:
		main.call_brother()
	err = await _do_job(job, true)
	if err != "" and story.phase == Story2.Phase.MORNING:
		return _fail(err)
	if story.phase == Story2.Phase.MORNING:
		return _fail("the accident did not happen during %s" % job.id)
	if not await _until(func(): return main.hud.choosing(), 60.0):
		return _fail("no choice after the accident (phase %d)" % story.phase)
	if not main.daniel.limp:
		return _fail("Daniel is not lying down after the accident")
	_log("choice")
	main.hud.chosen.emit(0 if plan == "truth" else 1)
	if plan != "truth":
		if not await _until(func(): return story.phase == Story2.Phase.COVERUP, 60.0):
			return _fail("the cover-up did not begin")
		if story.cover.tokens.size() != case.tokens.size():
			return _fail("%d signs at the scene, expected %d" % [story.cover.tokens.size(), case.tokens.size()])
		_log("cover-up")

		if plan == "early":
			_trace(main.nico, story.cover.body)
		match plan:
			"clean", "trail":
				err = await _cover_up(plan == "clean")
			"caught":
				err = await _caught()
		if err != "":
			return _fail(err)
	_log("waiting for the end, body %s" % (story.cover.body.where() if story.cover.body else Vector3.ZERO))
	while story.phase == Story2.Phase.COVERUP:      # keep Tomas working until someone finds him
		if main._auto_job == null and main.other() == main.tomas and not main.tomas.busy and main._carry == null:
			for other_job in main.jobs.values():
				if other_job.available(main.jobs) and other_job.solo_ok() and not story.job_locked(other_job):
					main.send_to_job(other_job)
					break
		await _wait(2.0)
	if story.cover.body:
		_log("found by %s, body %s (%s)" % [story.cover.found_by, story.cover.body.where(), House.room_at(story.cover.body.where())])
	if not await _until(func(): return story.phase == Story2.Phase.END or (story.phase == Story2.Phase.POLICE and main.hud.choosing()), 900.0):
		return _fail("no ending (phase %d, found by '%s')" % [story.phase, story.cover.found_by])
	if story.phase == Story2.Phase.POLICE:           # the last choice: say nothing, keep the verdict
		main.hud.chosen.emit(2)
		await _until(func(): return story.phase == Story2.Phase.END, 60.0)
	_log("ended: %s, work %d/%d minutes, stress %.0f, auto job %s" % [story.ending, story.cover._work_minutes, story.cover._minutes, story.cover.stress, main._auto_job.id if main._auto_job else "-"])
	var want: String = EXPECT[plan]
	if story.ending != want:
		var why := []
		for c in story.result.get("checks", []):
			if not c.ok:
				why.append("%s: %s" % [c.name, "; ".join(c.lines)])
		return _fail("ending %s, expected %s (%s)" % [story.ending, want, " | ".join(why)])
	if not main.hud.end_visible():
		return _fail("no ending card")
	if not _overlaps.is_empty():
		return _fail("HUD panels overlap: " + ", ".join(_overlaps.keys()))
	print("SELFTEST_OK day2 case=%s plan=%s ending=%s found_by=%s minutes=%d" % [case.id, plan, story.ending,
		story.cover.found_by, int(main.minute - story.cover.t0)])
	get_tree().quit(0)

## Walks to a job and plays its install view (every step, the right tool, every hotspot), or solves it
## outright with `play` false. Stops quietly when the accident takes over.
func _do_job(job: Job, play: bool) -> String:
	if not await _walk(main.current, job.station):
		return "could not reach %s (at %s)" % [job.id, main.current.global_position]
	if job.needs_two and story.helper_for(job) == null:
		await _until(func(): return main.other().global_position.distance_to(job.station) < 2.4 and not main.other().is_going(), 30.0)
	main.interact()
	if not main.install.is_active():
		return "%s did not start" % job.id
	if not play:
		main.install.auto_solve()
		return ""
	var ins: Install = main.install
	while ins.is_active():
		var s := ins.current()
		var step := ins.step
		ins.select(s.tool)
		if s.kind == "hold":
			_key(KEY_E, true)
			await _until(func(): return not ins.is_active() or ins.step != step, 20.0)
			_key(KEY_E, false)
		else:
			for i in ins.progress().y:
				if not ins.is_active() or ins.step != step:
					break
				ins.use_spot(i)
				await _until(func(): return not ins.is_active() or ins.step != step or ins.progress().x > i, 10.0)
		if ins.is_active() and ins.step == step:
			return "step %d of %s did not finish" % [step, job.id]
	return ""

## The cover-up, played well (or leaving the accident's own piece behind when `tidy_main` is false).
func _cover_up(tidy_main: bool) -> String:
	var cover := story.cover
	var nico: Actor = main.nico
	for job in main.jobs.values():              # Tomas keeps working while Nico tidies
		if job.available(main.jobs) and job.solo_ok() and not story.job_locked(job):
			main.send_to_job(job)
			break
	# what belongs to the accident: take the nail gun, tidy the rest
	for t in cover.tokens.duplicate():
		if t.main and not tidy_main and t.item == "":
			continue
		var off := Vector3(t.global_position.x - cover.body.where().x, 0, t.global_position.z - cover.body.where().z).normalized()
		if not await _walk(nico, t.global_position + off * 0.25):
			return "could not reach %s" % t.label.to_lower()
		main.interact()
		var tid: int = t.get_instance_id()
		if not await _until(func(): return not cover.tokens.any(func(x): return x.get_instance_id() == tid), 20.0):
			return "could not tidy %s (prompt %s)" % [t.label.to_lower(), cover.prompt(nico)]
	# carry him together to a place that explains it
	var sc: StageScenario = null
	for s in cover.scenarios:
		if story.case.injury in s.explains and (sc == null or s.id in ["stairs", "storage_nailgun"]):
			sc = s
	_log("signs tidied")
	main.call_brother()
	var body := cover.body
	if not await _walk(nico, _beside(body)):
		return "could not get to Daniel"
	await _until(func(): return main._pair_ready(), 20.0)
	_key(KEY_L, true)
	await get_tree().process_frame
	_key(KEY_L, false)
	await get_tree().process_frame
	if main._carry != body or body.carriers.size() != 2:
		return "could not lift him together (carry %s, prompt %s, pair %s, tomas %s busy %s, body %s, nico %s)" % [main._carry, cover.prompt(nico), main._pair_ready(), main.tomas.global_position, main.tomas.busy, body.where(), nico.global_position]
	_log("lifted: nico %s tomas %s load %s body %s" % [nico.global_position, main.tomas.global_position, body.global_position, body.where()])
	_trace(nico, body)
	if not await _walk(nico, sc.mark):
		return "could not carry him to %s (stuck at %s)" % [sc.title, nico.global_position]
	main.interact()
	if main._carry != null:
		return "could not put him down"
	await _wait(1.0)
	if cover.staged != sc:
		return "he was put down at %s but not staged as %s (staged %s)" % [body.where(), sc.title, cover.staged]
	_log("staged at %s, body %s" % [sc.id, body.where()])
	for spec in sc.setup:
		if not tidy_main and spec.needs != "":
			continue                            # the trail: the nail gun stays in the bag
		if not await _walk(nico, spec.at):
			return "could not reach the setup spot for %s" % spec.text
		main.interact()
		if not await _until(func(): return spec.id in cover.setup_done.get(sc.id, []), 20.0):
			return "could not set up: %s (prompt %s)" % [spec.text, cover.prompt(nico)]
	# Tomas keeps the house sounding like work
	for job in main.jobs.values():
		if not job.done and job.solo_ok() and job.available(main.jobs) and not story.job_locked(job):
			main.send_to_job(job)
			_log("Tomas sent to " + job.id)
			break
	await _walk(nico, Vector3(10.0, House.UP, 5.0))
	return ""

## Lifting him together while Linda walks in.
func _caught() -> String:
	var cover := story.cover
	for t in cover.tokens.duplicate():          # the nail gun lies by his hand: take it first
		if t.item != "":
			await _walk(main.nico, t.global_position)
			main.interact()
			await _until(func(): return cover.items.has(main.nico), 10.0)
	main.call_brother()
	if not await _walk(main.nico, _beside(cover.body)):
		return "could not get to Daniel"
	await _until(func(): return main._pair_ready(), 20.0)
	_key(KEY_L, true)
	await get_tree().process_frame
	_key(KEY_L, false)
	await get_tree().process_frame
	if main._carry != cover.body:
		return "could not lift him (prompt %s, pair %s, nico %s, body %s)" % [cover.prompt(main.nico), main._pair_ready(), main.nico.global_position, cover.body.where()]
	var linda: Npc = main.linda
	linda.global_position = main.nico.global_position + Vector3(1.2, 0.05, 0.4)
	linda.search(["Daniel's room"])
	return ""

## A spot next to him on the side away from the signs (so E lifts him, not a sign).
func _beside(body: BodyLoad) -> Vector3:
	var p := body.where()
	var away := Vector3.ZERO
	for t in story.cover.tokens:
		away += Vector3(p.x - t.global_position.x, 0, p.z - t.global_position.z).normalized()
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	var spot := p + away.normalized() * 0.8
	var map: RID = main.get_world_3d().navigation_map
	var q := NavigationServer3D.map_get_closest_point(map, spot + Vector3(0, 0.2, 0))
	return Vector3(q.x, p.y, q.z)

func _trace(nico: Actor, body: BodyLoad) -> void:
	for k in 8:
		await _wait(2.0)
		_log("carrying: nico %s tomas %s load %s body %s" % [nico.global_position.snapped(Vector3.ONE * 0.01), main.tomas.global_position.snapped(Vector3.ONE * 0.01), body.global_position.snapped(Vector3.ONE * 0.01), body.where().snapped(Vector3.ONE * 0.01)])

var _overlaps := {}

## Every half second: no two HUD panels on screen may cover each other.
func _watch_hud() -> void:
	while true:
		await get_tree().create_timer(0.5, true, false, true).timeout
		var tops: Array = main.hud.top_panels()
		for i in tops.size():
			for k in range(i + 1, tops.size()):
				var a: Control = tops[i]
				var b: Control = tops[k]
				if a.get_global_rect().grow(-2).intersects(b.get_global_rect().grow(-2)):
					_overlaps["%s/%s (phase %d)" % [a.name, b.name, story.phase]] = true

func _capture() -> void:
	var k := 0
	while true:
		await get_tree().create_timer(1.5 / Engine.time_scale, true, false, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/d2_%03d_p%d.png" % [shots, k, story.phase])
		k += 1

func _log(what: String) -> void:
	print("D2 %6.1fs  phase %d  %s" % [Time.get_ticks_msec() / 1000.0, story.phase, what])

func _walk(a: Actor, p: Vector3) -> bool:
	a.go_to(p)
	await get_tree().physics_frame
	var t := 0.0
	while a.is_going() and t < 90.0 and story.phase != Story2.Phase.END:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return Vector2(a.global_position.x - p.x, a.global_position.z - p.z).length() < 1.0

func _until(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while not cond.call() and t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return cond.call()

func _wait(seconds: float) -> void:
	await _until(func(): return false, seconds)

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _fail(why: String) -> void:
	print("SELFTEST_FAIL day2 case=%s plan=%s: %s" % [story.case.id if story else "?", plan, why])
	get_tree().quit(1)
