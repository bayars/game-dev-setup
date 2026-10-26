class_name Story2
extends Node
## Day 2 from the morning to the ending (design: docs/game3-design.md).
##   MORNING   an ordinary working day in Daniel's room; Daniel tags along and helps
##   ACCIDENT  the case's job reaches its step: the zoom cut-scene (softened with Game.soften)
##   CHOICE    tell the truth (an unjust ending, always) or hide where it happened
##   COVERUP   Coverup runs until a resident (or the police) finds him
##   FOUND     the discovery cut-scene, then POLICE: the investigation beat by beat, a last choice when it
##             goes badly (one brother takes the fall), and the ending card

enum Phase { MORNING, ACCIDENT, CHOICE, COVERUP, FOUND, POLICE, END }

var main: Node3D
var case: AccidentCase
var cover: Coverup
var cine: Cinematic
var phase := Phase.MORNING
var result := {}
var ending := ""
var accident_job: Job
var _chatter := 25.0
var _follow := 0.0
var _heard: Array = []

func setup(m: Node3D) -> void:
	main = m
	case = Day2.pick_case(Game.case_id, Game.runs)
	accident_job = main.jobs[case.job_id]
	cine = Cinematic.new()
	main.add_child(cine)
	cover = Coverup.new()
	add_child(cover)
	cover.setup(main, self, case)
	cover.found.connect(_on_found)
	main.install.spot_done.connect(_on_spot_done)
	main.install.started.connect(_on_install_started)

## The morning: the family at the door, Robert off to work, then the job list.
func start() -> void:
	while not main._nav_ok:
		await get_tree().physics_frame
	await main._dialogue.play(Day2.INTRO)
	_robert_leaves()
	main.hud.toast(Day2.HINTS.start, 7.0)

func _robert_leaves() -> void:
	var r: Npc = main.robert
	r.go_to(Vector3(9.4, 0, 17.0))
	await get_tree().create_timer(9.0, false).timeout
	if phase == Phase.MORNING or phase == Phase.ACCIDENT or phase == Phase.CHOICE:
		r.set_away(true)

func tick(delta: float) -> void:
	match phase:
		Phase.MORNING:
			_daniel_tags_along(delta)
		Phase.COVERUP:
			cover.tick(delta)

## Daniel stays near the brother you play, and stands by to help on his job.
func _daniel_tags_along(delta: float) -> void:
	var d: Npc = main.daniel
	_follow -= delta
	if _follow > 0.0 or d.busy:
		return
	_follow = 1.0
	var ins: Install = main.install
	if ins.is_active() and ins.job == accident_job:
		var at := case.daniel_at
		if d.global_position.distance_to(at) > 0.3:
			d.go_to(at)
		else:
			d.face(main.current.global_position)
		return
	var me: Actor = main.current
	if d.global_position.distance_to(me.global_position) > 3.2:
		d.go_to(me.global_position + (d.global_position - me.global_position).normalized() * 1.8)
	_chatter -= 1.0
	if _chatter <= 0.0 and d.global_position.distance_to(me.global_position) < 4.0 and not ins.is_active():
		_chatter = randf_range(30.0, 50.0)
		main._dialogue.bark("Daniel", Day2.CHATTER[randi() % Day2.CHATTER.size()], 3.5)

## Tomas will not take Daniel's job off his hands (Daniel asked to help with that one).
func job_locked(job: Job) -> bool:
	return phase == Phase.MORNING and job == accident_job or phase >= Phase.ACCIDENT and job == accident_job

## Who holds on two-person jobs: on the drywall case Tomas has gone for screws and Daniel holds instead.
func helper_for(job: Job) -> Actor:
	if phase == Phase.MORNING and job == accident_job and case.tomas_away:
		return main.daniel
	return null

func _on_install_started(job: Job) -> void:
	if phase != Phase.MORNING or job != accident_job:
		return
	main.hud.toast(Day2.HINTS.daniel, 4.0)
	if case.tomas_away:
		var t: Actor = main.tomas
		main.follow = false
		main._dialogue.bark("Tomas", "We're out of screws. I'll run down to the van.", 2.5)
		t.go_to(Vector3(5.0, 0, 13.6))

func _on_spot_done(job: Job, step: int, done: int) -> void:
	if phase == Phase.MORNING and job == accident_job and step == case.step and done >= case.after_spots:
		_accident()

# ---------------------------------------------------------------- the accident

func _accident() -> void:
	phase = Phase.ACCIDENT
	main.cutscene = true
	var minute: float = main.minute
	var d: Npc = main.daniel
	var ins: Install = main.install
	var worker: Actor = ins.worker
	ins.cancel()
	d.busy = true
	d.wander = []
	d.stop()
	if d.global_position.distance_to(case.daniel_at) > 0.6:
		d.global_position = case.daniel_at + Vector3(0, 0.05, 0)
	var piece: Node3D = main.site.piece(case.what)
	var room_mid := Vector3(4.5, House.UP, 3.0)
	var away := Vector3(room_mid.x - d.global_position.x, 0, room_mid.z - d.global_position.z).normalized()
	var side := away.cross(Vector3.UP)
	var look := d.global_position + Vector3(0, 1.0, 0)
	_cine_begin()
	cine.cut(look + away * 4.2 + side * 1.4 + Vector3(0, 1.4, 0), look)
	if piece:
		d.face(piece.global_position)
	else:
		d.face(worker.global_position)
	if case.what == "nailgun":
		worker.hold_tool("")
		worker.work("")
		d.face(worker.global_position)
	cine.shot(look + away * 3.6 + side * 1.3 + Vector3(0, 0.9, 0), look + Vector3(0, -0.2, 0), 5.0)
	await main._dialogue.play(case.before)
	# the moment it happens
	match case.what:
		"stud":
			_tip(piece, d.global_position, deg_to_rad(78.0), 0.7)
		"sheet":
			piece.global_transform = Transform3D(Basis.from_euler(Vector3(0, PI / 2, 0)) * Basis.from_scale(Vector3(0.99 / 1.2, 2.6 / 2.4, 1.0)),
				Vector3(Worksite2.X2 - 0.25, House.UP + 0.02, 5.35))
			await cine.wait(0.4)
			_tip(piece, d.global_position, deg_to_rad(72.0), 0.8)
		"nailgun":
			d.hold_tool("nailgun")
			d.work("drill")
			await cine.wait(0.9)
			_flash(d.global_position + Vector3(0, 1.1, 0))
	d.work("react_fall")
	await cine.wait(0.35)
	if Game.soften:
		cine.fade(1.0, 0.12)
	main.sfx.play("impact", d.global_position)
	main.sfx.loop("music_day_loop", false)
	d.go_limp(case.fall)
	_heard = main.make_noise(d.global_position, case.noise_radius, case.noise_what)
	main.sfx.mute_world(true)
	main.sfx.play("heartbeat")
	await cine.wait(2.6)
	if Game.soften:
		await cine.fade(0.0, 1.6)
	var t: Actor = main.tomas
	t.stop()
	t.global_position = Vector3(9.6, House.UP + 0.05, 2.6)
	t.go_to(d.body_position() + Vector3(1.2, 0, 0.6))
	var bp := d.body_position()
	var inward := Vector3(room_mid.x - bp.x, 0, room_mid.z - bp.z).normalized()
	await cine.shot(bp + inward * 2.4 + inward.cross(Vector3.UP) * 0.8 + Vector3(0, 3.2, 0), bp, 4.0)
	await main._dialogue.play(case.after)
	main.sfx.mute_world(false)
	_cine_end()
	_choice(minute)

func _cine_begin() -> void:
	cine.begin(main, main.cam.camera)
	main.hud.set_cinematic(true)
	main._update_rings()
	if cover.active or phase >= Phase.FOUND:
		cover._set_rings(false)

func _cine_end() -> void:
	cine.finish()
	main.hud.set_cinematic(false)

func _tip(n: Node3D, toward: Vector3, angle: float, seconds: float) -> void:
	if n == null:
		return
	var start := n.global_transform
	var dir := Vector3(toward.x - start.origin.x, 0, toward.z - start.origin.z).normalized()
	var axis := Vector3.UP.cross(dir).normalized()
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(a: float):
		n.global_transform = Transform3D(Basis(axis, a) * start.basis, start.origin), 0.0, angle, cine._t(seconds))

func _flash(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.7)
	l.light_energy = 8.0
	l.omni_range = 4.0
	main.add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

# ---------------------------------------------------------------- the choice

func _choice(minute: float) -> void:
	phase = Phase.CHOICE
	await main._dialogue.play(Day2.CHOICE_LINES)
	var pick: int = await main.hud.choose("Daniel is dead.", [
		"Call an ambulance. Tell them what happened.",
		"Nobody can know it happened here.",
	])
	if pick == 0:
		_truth()
		return
	await main._dialogue.play(Day2.COVER_LINES)
	var d: Npc = main.daniel
	main.residents.erase(d)
	var kw := Day2.keep_working()
	main.jobs[kw.id] = kw
	main._add_rings()
	cover.begin(minute, d)
	for r in _heard:
		cover.heard_accident.append([(r as Npc).display_name, minute, Coverup.ACCIDENT_ROOM])
	phase = Phase.COVERUP
	main.sfx.loop("music_tense_loop", true, -10.0, false)
	main.cutscene = false
	main.follow = true
	main._board_dirty = true
	main.hud.toast("Move him out of this room: L lifts him (together if %s is next to you, H calls him; alone you drag him, loud). Set him down at a blue ring and set the scene. E tidies the signs. Send %s to keep working. They will start looking for him soon." % [main.tomas.display_name, main.tomas.display_name], 14.0)

func _truth() -> void:
	_cine_begin()
	await cine.fade(1.0, 1.2)
	ending = "truth"
	result = {"checks": [], "ending": "truth"}
	_end("truth", [])

# ---------------------------------------------------------------- found

func _on_found(by: Npc, caught: bool) -> void:
	if phase != Phase.COVERUP:
		return
	phase = Phase.FOUND
	main.cutscene = true
	cover.active = false
	if main._carry != null:                    # whatever happens now, he is set down
		main.put_down()
	if main.install.is_active():
		main.install.cancel()
	var where := cover.body.where()
	_cine_begin()
	if by:
		by.stop()
		by.face(where)
		var to_body := Vector3(where.x - by.global_position.x, 0, where.z - by.global_position.z).normalized()
		var side := to_body.cross(Vector3.UP)
		var mid := (by.global_position + where) * 0.5 + Vector3(0, 0.7, 0)
		cine.cut(mid + side * 4.2 - to_body * 1.0 + Vector3(0, 2.6, 0), mid)
		await cine.shot(mid + side * 3.2 - to_body * 0.6 + Vector3(0, 1.6, 0), mid, 2.0)
		main._dialogue.bark(by.display_name, "Daniel? ...Daniel! DANIEL!" if not caught else "What are you doing? What are you -- that's Daniel! DANIEL!", 3.0)
		main.sfx.play("stinger")
		for r in main.residents:
			if r != by:
				(r as Npc).gather(where + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
		await cine.wait(3.2)
		await main._dialogue.play([["Linda", "Call an ambulance! Somebody call an ambulance!"]])
	else:
		await cine.card("The police", "Linda reported him missing. Two officers searched the house.", 2.5)
	await cine.fade(1.0, 1.5)
	_police()

# ---------------------------------------------------------------- the police

func _police() -> void:
	phase = Phase.POLICE
	var report := cover.report()
	result = Investigation.judge(report)
	await cine.card("An hour later", "The police walk through the house, room by room.", 3.0)
	var where := cover.body.where()
	var hale := _police_officer("Hale", where, Vector3(1.1, 0, 0.7), "crouch")
	_police_officer("Officer", where, Vector3(-1.8, 0, 1.6), "idle")
	main.nico.global_position = _stand(Vector3(10.0, 0, 5.0))
	main.tomas.global_position = _stand(Vector3(10.2, 0, 6.2))
	cine.cut(where + Vector3(4.0, 4.5, 4.0), where)
	await cine.fade(0.0, 1.2)
	cine.shot(where + Vector3(2.2, 2.2, 2.4), where, 4.0)
	for c in result.checks:
		if c.name == "Tomas":                     # the interview: Hale in front of him
			hale.global_position = _stand(main.tomas.global_position + Vector3(1.1, 0, 0.3))
			hale.idle_clip = "talk"
			hale.face(main.tomas.global_position)
			main.tomas.face(hale.global_position)
			main.tomas.idle_clip = "talk" if c.ok else "search"
		var focus := _focus_for(c.name, report)
		var eye := focus + Vector3(2.4, 2.6, 2.6)
		await cine.shot(eye, focus, 2.2)
		await cine.beat(c.name, c.ok, c.major, c.lines)
		await cine.wait(1.6 + 0.6 * c.lines.size())
	ending = result.ending
	if Investigation.can_take_fall(ending):
		var pick: int = await main.hud.choose("The detectives are coming back to the house. Tomas grabs your arm: \"Let me take it, Nico. You have the family to send money to.\"", [
			"Tell them it was all you. Tomas was never upstairs.",
			"Let Tomas take it.",
			"Say nothing. Wait.",
		])
		if pick == 0:
			ending = "fall_nico"
		elif pick == 1:
			ending = "fall_tomas"
	await cine.fade(1.0, 1.0)
	_end(ending, result.checks)

## A police officer standing by him (`offset` from where he lies), doing `clip`.
func _police_officer(who: String, where: Vector3, offset: Vector3, clip: String) -> Actor:
	var a := Actor.new()
	main.add_child(a)
	a.setup(who, main.gfx)
	a.global_position = _stand(where + offset)
	a.face(where)
	a.idle_clip = clip
	a.show_tag(false)
	return a

## The nearest place to `p` where someone can stand.
func _stand(p: Vector3) -> Vector3:
	var q := NavigationServer3D.map_get_closest_point(main.get_world_3d().navigation_map, p + Vector3(0, 0.2, 0))
	return Vector3(q.x, q.y - 0.15, q.z)

func _focus_for(check: String, report: Dictionary) -> Vector3:
	match check:
		"Trail":
			if not cover.tokens.is_empty():
				return cover.tokens[0].global_position
			return Vector3(4.5, House.UP, 3.0)
		"Work":
			return Vector3(4.5, House.UP, 3.0)
		"Tomas":
			return main.tomas.global_position + Vector3(0, 1.0, 0)
		"Timeline":
			for r in main.residents:
				if (r as Npc).visible:
					return (r as Npc).global_position + Vector3(0, 1.0, 0)
	return cover.body.where()

func _end(id: String, checks: Array) -> void:
	phase = Phase.END
	ending = id
	Game.runs += 1
	Game.day2_done = true                      # from now on the menu offers both days
	Game.save()
	cine.clear_beats()
	cine.fade(0.82, 0.8)                       # the house stays faintly behind the card
	var e: Array = Investigation.ENDINGS[id]
	var lines: Array = Day2.TRUTH if id == "truth" else e[1]
	if id in Investigation.GOT_AWAY:
		main.hud.show_ending(e[0], lines, checks, [["N", "Play a different accident"], ["M", "Main menu"]])
	else:
		main.hud.show_ending(e[0], lines, checks,
			[["R", "Yes, the same morning"], ["N", "Yes, a different accident"], ["M", "No, main menu"]], "Try again?")
	main.hud.set_cover(false)
	finished.emit(id)

signal finished(ending: String)
