extends Node3D
## "Off the Books". Day 1, the first job (tutorial), and day 2 (Story2: the accident, the cover-up, the
## police). Design: docs/game3-design.md
##
## Controls: left click / WASD move, Shift run, E interact (start a job, lift or put down a load), Tab
## switch brother, right click send the other brother there, F the other brother follows / waits, H call
## him over, J fold the job list, F1 controls, Q/R rotate the view, mouse wheel zoom, G graphics, Esc stop
## working / quit. In the install view: 1-9 or click picks a tool, click a glowing spot to work on it
## (hold the button on held steps), wheel zooms, Esc steps back.
## Flags (after `--`): --day=1|2, --case=<accident id>, --selftest (plays the day, prints SELFTEST_OK /
## SELFTEST_FAIL; day 2 takes --plan=clean|trail|truth|early|caught), --quality=<level>

const START_MINUTE := 8 * 60.0          # 08:00
const MINUTES_PER_SECOND := 0.2         # one game minute every five seconds: a morning is about 20 minutes
const REACH := 1.5                      # how close you must stand to a job or a load
const AUTO_SECONDS := 24.0              # the other brother doing a job alone takes this long
const SOLO_SPEED := 0.42                # carrying alone: slow ...
const PAIR_SPEED := 0.9                 # ... together: nearly walking pace
const DRAG_NOISE := 10.0                # metres a solo carry can be heard
const BANG_NOISE := 7.0                 # a hammer where none is needed, a wrong wire

signal noise_made(at: Vector3, radius: float, what: String, heard: Array)

var gfx: Graphics
var house: House
var site: Worksite
var cam: IsoCamera
var hud: Hud
var install: Install
var nico: Actor
var tomas: Actor
var linda: Npc
var daniel: Npc
var rose: Npc
var sofia: Npc
var robert: Npc
var residents: Array[Npc] = []
var day := 1
var story: Story2                      # day 2
var sfx: Sfx
var cutscene := false                  # a cut-scene or a choice: no walking, no jobs
var current: Actor
var follow := true                     # the brother you are not controlling follows you
var minute := START_MINUTE
var jobs := {}
var cash := 0
var day_over := false

var _carry: Carryable
var _loads: Array[Carryable] = []
var _noise_timer := 0.0
var _auto_job: Job                     # what the other brother is doing on his own
var _auto_units := 0                   # how many of its hotspots he has finished
var _dialogue: Dialogue
var _selftest := false
var _scripted := false                 # self-test or play-test: no keyboard steering
var _follow_timer := 0.0
var _nav_ok := false
var _hints_shown := {}
var _rings := {}                       # job id -> floor ring at its station (or its delivery spot)
var _board_dirty := true

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_selftest = "--selftest" in args
	_scripted = _selftest or "--playtest" in args
	Game.load_save()
	day = Game.day
	var forced := ""
	for a in args:
		if a.begins_with("--quality="):
			forced = a.substr(10)
		elif a.begins_with("--day="):
			day = int(a.substr(6))
		elif a.begins_with("--case="):
			Game.case_id = a.substr(7)
	sfx = Sfx.new()
	add_child(sfx)
	Actor.sfx = sfx
	sfx.loop("room_loop", true, -10.0)
	sfx.loop("yard_loop", true, -16.0)
	sfx.loop("music_day_loop", true, -12.0, false)

	gfx = Graphics.new()
	add_child(gfx)
	gfx.build_environment(self)
	_tune_lighting()
	gfx.load_level(forced if forced != "" else ("low" if _selftest else ""), not _selftest)

	house = House.new()
	add_child(house)
	house.build(gfx)
	get_tree().physics_frame.connect(house.bake_nav, CONNECT_ONE_SHOT)
	_add_lamps()
	site = Worksite.new() if day == 1 else Worksite2.new()
	add_child(site)
	site.setup(house, gfx)

	nico = _spawn(Actor.new(), "Nico", Vector3(10.0, 0.05, 14.0))
	tomas = _spawn(Actor.new(), "Tomas", Vector3(11.2, 0.05, 14.6))
	linda = _spawn(Npc.new(), "Linda", Vector3(9.8, 0.05, 10.5)) as Npc
	daniel = _spawn(Npc.new(), "Daniel", Vector3(3.5, 0.05, 4.4)) as Npc
	rose = _spawn(Npc.new(), "Rose", Vector3(12.2, 0.05, 6.6)) as Npc
	sofia = _spawn(Npc.new(), "Sofia", House.room_center("Sofia's room") + Vector3(0, 0.05, 0)) as Npc
	sofia.idle_clip = "phone"          # in her room on her phone all morning
	sofia.hearing = 0.6
	residents = [linda, daniel, rose, sofia]
	linda.hearing = 1.2
	linda.wander = [Vector3(2.5, 0, 1.3), Vector3(10.0, 0, 5.0), House.room_center("Rose's room"), Vector3(10.0, 0, 10.5)]
	daniel.wander = [Vector3(3.5, 0, 4.6), Vector3(4.8, 0, 3.0), Vector3(7.0, 0, 6.4), Vector3(2.4, 0, 5.0)]
	rose.hearing = 0.8
	rose.speed_search = 0.7

	if day == 1:
		var couch := _carryable("boxed couch", "CouchBox", Vector3(0.95, 0.8, 2.1), 90, Vector3(6.6, Worksite.FLOOR, 14.4))
		var dishwasher := _carryable("dishwasher", "DishwasherBox", Vector3(0.66, 0.88, 0.66), 0, Vector3(6.6, Worksite.FLOOR, 17.4))
		jobs = Day1.jobs(couch, dishwasher)
		site.carry_props = {"couch_in": couch, "dishwasher_in": dishwasher}
	else:
		robert = _spawn(Npc.new(), "Robert", Vector3(9.6, 0.05, 9.6)) as Npc
		residents.append(robert)
		daniel.global_position = Vector3(10.4, 0.05, 10.6)
		daniel.wander = []
		linda.global_position = Vector3(9.9, 0.05, 11.2)
		linda.wander = [Vector3(2.5, 0, 1.3), Vector3(4.6, 0, 1.4), Vector3(2.0, 0, 4.2), House.room_center("Rose's room")]
		jobs = Day2.jobs()
	_add_rings()

	cam = IsoCamera.new()
	add_child(cam)
	hud = Hud.new()
	add_child(hud)
	hud.send_job.connect(send_to_job)
	hud.switch_brother.connect(switch_brother)
	hud.toggle_follow.connect(toggle_follow)
	hud.call_brother.connect(call_brother)
	hud.restart.connect(func(): get_tree().reload_current_scene())
	hud.quit.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_dialogue = Dialogue.new()
	hud.add_ui(_dialogue)
	_dialogue.speaking.connect(func(who: String):
		for a in [nico, tomas] + residents:
			a.talking = a.display_name == who)
	install = Install.new()
	add_child(install)
	install.finished.connect(_on_install_finished)
	install.cancelled.connect(_on_install_cancelled)
	install.mistake.connect(func(at: Vector3, loud: bool, what: String):
		if loud:
			make_noise(at, BANG_NOISE, what))
	install.changed.connect(func(): hud.show_install(install))
	install.sfx = sfx
	install.safe_rect = hud.install_safe_rect
	install.people = [nico, tomas] + residents
	_update_rings()
	hud.tool_picked.connect(install.select)
	hud.end_action.connect(_on_end_action)
	if day == 2:
		story = Story2.new()
		add_child(story)
		story.setup(self)
		hud.order.connect(func(kind: String): story.cover.order(kind))

	_control(nico)
	cam.snap_to_target()
	gfx.changed.connect(func(n: String): hud.toast("Graphics: %s   (G to change)" % n, 2.5))
	if _selftest:
		Engine.time_scale = 4.0
		_dialogue.fast = true
		if day == 2:
			var t := Day2Selftest.new(self, args)
			add_child(t)
			t.run()
		else:
			_run_selftest()
	elif "--playtest" in args:
		Engine.time_scale = 2.0
		_dialogue.fast = true
		var pt := Playtest.new(self, args)
		add_child(pt)
		pt.run()
	elif day == 2:
		story.start()
	else:
		_intro()

func _tune_lighting() -> void:
	# afternoon instead of the Walk Home sunset; no outdoor fog in a house
	gfx.sun.rotation_degrees = Vector3(-52, 30, 0)
	gfx.sun.light_color = Color(1.0, 0.93, 0.82)
	gfx.sun.light_energy = 1.6
	gfx.sun.directional_shadow_max_distance = 60.0
	gfx.env.volumetric_fog_density = 0.0
	gfx.env.fog_density = 0.0005

func _add_lamps() -> void:
	var seen := {}
	for r in House.ROOMS:
		if seen.has(r[0]):
			continue
		seen[r[0]] = true
		var l := OmniLight3D.new()
		l.position = House.room_center(r[0]) + Vector3(0, 2.4, 0)
		l.light_color = Color(1.0, 0.82, 0.62)
		l.light_energy = 0.6
		l.omni_range = 6.0
		l.shadow_enabled = true
		(house.upper if r[2] == 1 else self as Node).add_child(l)

func _spawn(a: Actor, who: String, at: Vector3) -> Actor:
	add_child(a)
	a.position = at
	a.setup(who, gfx)
	return a

func _carryable(what: String, prop: String, footprint: Vector3, yaw: float, at: Vector3) -> Carryable:
	var c := Carryable.new()
	add_child(c)
	c.position = at
	c.setup(what, house, prop, footprint, yaw)
	_loads.append(c)
	return c

## Soft rounded rings on the floor: where each open job is done, and where each load goes.
func _add_rings() -> void:
	for job in jobs.values():
		if _rings.has(job.id) or job.auto_only:
			continue
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var big: bool = job.carry != null
		torus.inner_radius = 0.62 if big else 0.36
		torus.outer_radius = 0.7 if big else 0.42
		torus.rings = 48
		ring.mesh = torus
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.76, 0.36, 0.55)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale.y = 0.1
		var at: Vector3 = job.carry_target if big else job.station
		ring.position = at + Vector3(0, Worksite.FLOOR + 0.02, 0)
		(house.upper if at.y > House.H else self as Node).add_child(ring)
		_rings[job.id] = ring

# ---------------------------------------------------------------- control

func _control(a: Actor) -> void:
	if current:
		current.set_controlled(false)
	current = a
	a.set_controlled(true)
	if _auto_job != null and a == _auto_worker():
		_stop_auto()                              # you took over: he stops working on his own
	if not a.busy:
		a.stop()
	cam.target = a
	_board_dirty = true

func other() -> Actor:
	return tomas if current == nico else nico

func _auto_worker() -> Actor:
	return other()

func switch_brother() -> void:
	if _carry != null or install.is_active():
		hud.toast("Finish what you are doing first.", 2.5)
		return
	_control(other())

func order_go(p: Vector3) -> void:
	if other().busy:
		return
	follow = false
	_stop_auto()
	other().go_to(p)
	_dialogue.bark(other().display_name, "On my way.", 1.5)

func toggle_follow() -> void:
	follow = not follow
	_stop_auto()
	if not follow:
		other().stop()
	_dialogue.bark(other().display_name, "Right behind you." if follow else "I'll wait here.", 1.5)
	_board_dirty = true

func call_brother() -> void:
	if other().busy:
		return
	follow = true
	_stop_auto()
	other().go_to(current.global_position)
	_dialogue.bark(other().display_name, "Coming.", 1.2)
	_board_dirty = true

## Job list button: send the other brother to a job. Jobs he can do alone he starts on his own; for a
## two-person job he goes and waits to hold; carrying he refuses alone.
func send_to_job(job: Job) -> void:
	var o := other()
	if job.done or o.busy:
		return
	if job.carry != null:
		_dialogue.bark(o.display_name, "Alone? It's too heavy, and they'd hear me drag it. Call me over and we lift it together.", 3.5)
		return
	if story and story.job_locked(job):
		_dialogue.bark(o.display_name, "Daniel wants to help you with that one. I'll take another." if story.phase == Story2.Phase.MORNING else "Not that one. I can't go near it.", 3.0)
		return
	if not job.available(jobs):
		_dialogue.bark(o.display_name, "That has to wait, the other job comes first.", 2.5)
		return
	follow = false
	_stop_auto()
	o.go_to(job.station + Vector3(0.0, 0, 1.0 if job.needs_two else 0.0))
	if job.solo_ok():
		_auto_job = job
		_auto_units = 0
		_dialogue.bark(o.display_name, "I'll %s." % job.title.to_lower(), 2.0)
	else:
		_dialogue.bark(o.display_name, "I'll hold it. Come and start when you're ready.", 2.0)
	_board_dirty = true

func _stop_auto() -> void:
	if _auto_job != null:
		_auto_worker().work("", "")
	_auto_job = null

# ---------------------------------------------------------------- interaction

func interact() -> void:
	if day_over or cutscene or current.busy or install.is_active():
		return
	if story and story.phase == Story2.Phase.COVERUP and _carry == null and story.cover.interact(current):
		return
	if _carry != null and _carry.lead() == current:
		put_down()
		return
	var job := _nearest_job()
	var load := _nearest_load()
	if load != null and (job == null or current.global_position.distance_to(load.global_position) < current.global_position.distance_to(job.station)):
		pick_up(load)
	elif job != null:
		start_job(job)

func _nearest_job() -> Job:
	var best: Job = null
	var best_d := REACH
	for job in jobs.values():
		if job.carry != null or not job.available(jobs) or job == _auto_job or job.auto_only:
			continue
		if absf(current.global_position.y - job.station.y) > 1.2:
			continue
		var d := Vector2(current.global_position.x - job.station.x, current.global_position.z - job.station.z).length()
		if d < best_d:
			best_d = d
			best = job
	return best

func _nearest_load() -> Carryable:
	for job in jobs.values():
		if job.carry != null and not job.done and not job.carry.is_carried():
			if current.global_position.distance_to(job.carry.global_position) < REACH + 0.5:
				return job.carry
	return null

func _pair_ready() -> bool:
	var helper := other()
	return not helper.busy and helper.global_position.distance_to(current.global_position) < 3.0

func pick_up(c: Carryable) -> void:
	var helper := other()
	var pair := _pair_ready()
	_carry = c
	c.carriers = [current]
	if pair:
		c.carriers.append(helper)
		helper.stop()
		helper.lead = current
		helper.lead_gap = 1.7
		_stop_auto()
	for a in c.carriers:
		a.speed_mul = PAIR_SPEED if pair else SOLO_SPEED
		a.carrying = "pair" if pair else "solo"
	c.lift()
	if story:
		story.cover.carry_started(c)
	_show_hint_once("pair_carry" if pair else "solo_carry")

func put_down() -> void:
	var c := _carry
	var lead_pos := c.lead().global_position
	for a in c.carriers:
		a.speed_mul = 1.0
		a.lead = null
		a.carrying = ""
	c.carriers = []
	c.global_position.y = lead_pos.y
	sfx.loop("drag_loop", false)
	_carry = null
	if not _load_fits(c, c.global_position, c.rotation.y):      # in a doorway: set it down where it fits
		var found := false
		for turn in [0.0, PI / 2, PI / 4, -PI / 4]:              # turned a little, then further out
			for r in [0.3, 0.7, 1.1, 1.6]:
				for k in 12:
					var p: Vector3 = lead_pos + Vector3(cos(k * TAU / 12), 0, sin(k * TAU / 12)) * r
					if not found and _load_fits(c, p, c.rotation.y + turn):
						c.global_position = Vector3(p.x, lead_pos.y, p.z)
						c.rotation.y += turn
						found = true
	c.drop()
	if story:
		story.cover.carry_ended(c)
	for job in jobs.values():
		var near_load := Vector2(c.position.x - job.carry_target.x, c.position.z - job.carry_target.z).length() < 1.7
		var near_lead := Vector2(lead_pos.x - job.carry_target.x, lead_pos.z - job.carry_target.z).length() < 1.4
		if job.carry == c and (near_load or near_lead):
			c.position = job.carry_target + Vector3(0, Worksite.FLOOR, 0)
			c.rotation = Vector3.ZERO
			complete_job(job)

## True if a load of `c`'s size stands at `at` (turned `yaw`) without going into a wall or furniture.
func _load_fits(c: Carryable, at: Vector3, yaw: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(c.size.x - 0.06, c.size.y - 0.12, c.size.z - 0.06)
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, c.size.y / 2.0 + 0.08, 0))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func start_job(job: Job) -> void:
	var helper: Actor = null
	if job.needs_two:
		helper = other()
		if story and story.helper_for(job):
			helper = story.helper_for(job)        # Daniel holds instead: he comes over to his post himself
		elif helper.global_position.distance_to(job.station) > 2.4 or helper.is_going():
			_show_hint_once("needs_two", true)
			_dialogue.bark(current.display_name, "%s, I need you to hold this." % helper.display_name, 2.0)
			return
		helper.busy = true
	if _auto_job == job:
		_stop_auto()
	current.busy = true
	current.stop()
	if helper:
		_take_pair_posts(job, helper)
		_board_dirty = true
	elif follow and not other().busy and other().global_position.distance_to(current.global_position) < 4.0:
		_step_aside(other(), job)
	install.start(job, current, helper, site, cam)
	_update_rings()
	_show_hint_once("install")

## Two-person jobs: the worker stands at the station, the helper 1.2 m to the side along the work
## (on whichever side he already is), both facing it, so they never overlap in the close-up.
func _take_pair_posts(job: Job, helper: Actor) -> void:
	var work := Vector3.ZERO
	var n := 0
	for s in job.steps.size():
		if job.steps[s].has("at"):              # done elsewhere (the sheet stack)
			continue
		for p in site.spots(job.id, s):
			work += p
			n += 1
	work = work / maxf(1.0, n)
	var to_work := Vector3(work.x - job.station.x, 0, work.z - job.station.z).normalized()
	var side := Vector3(-to_work.z, 0, to_work.x)
	if side.dot(helper.global_position - job.station) < 0.0:
		side = -side
	var floor_y := job.station.y + Worksite.FLOOR
	current.take_post(Vector3(job.station.x, floor_y, job.station.z), work)
	var spot := job.station + side * 1.2
	helper.take_post(Vector3(spot.x, floor_y, spot.z), work + side * 1.2)

## The brother who is not needed steps back from the work instead of standing in the camera's way.
func _step_aside(a: Actor, job: Job) -> void:
	var work := Vector3.ZERO
	var spots: Array = site.spots(job.id, 0)
	for p in spots:
		work += p
	work /= maxf(1.0, spots.size())
	var away := Vector3(job.station.x - work.x, 0, job.station.z - work.z).normalized().rotated(Vector3.UP, 0.8)
	var map := get_world_3d().navigation_map
	var spot := NavigationServer3D.map_get_closest_point(map, job.station + away * 2.0 + Vector3(0, 0.2, 0))
	a.go_to(spot)

func _on_install_finished(job: Job) -> void:
	_release_install(job)
	complete_job(job)

func _on_install_cancelled(job: Job) -> void:
	_release_install(job)
	_update_rings()

func _release_install(job: Job) -> void:
	current.busy = false
	if job.needs_two:
		other().busy = false
		_board_dirty = true

func complete_job(job: Job) -> void:
	if job.done:
		return
	job.done = true
	cash += job.pay
	_update_rings()
	_board_dirty = true
	var lines: Dictionary = Day1.DANIEL_LINES if day == 1 else Day2.DANIEL_LINES
	if lines.has(job.id) and not daniel.limp:
		_dialogue.bark("Daniel", lines[job.id], 3.0)
	if day == 1 and jobs.values().all(func(j): return j.done):
		_end_day()

## Something loud happened: a ring spreads on the floor and every resident in range remembers it.
## Returns the residents who heard it.
func make_noise(at: Vector3, radius: float, what: String) -> Array:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.3, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(at.x, floorf(at.y / House.UP + 0.3) * House.UP + 0.08, at.z)
	ring.scale = Vector3(0.3, 0.05, 0.3)
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.9)
	t.tween_property(m, "albedo_color:a", 0.0, 0.9)
	t.chain().tween_callback(ring.queue_free)
	var heard := []
	for r in residents:
		if r.hear(at, radius, what, minute, House.room_at(at + Vector3(0, 0.3, 0))):
			heard.append(r)
	noise_made.emit(at, radius, what, heard)
	sfx.play("ring", at, -8.0)
	if "phone" in what:
		sfx.play("phone", at, 0.0)
	return heard

# ---------------------------------------------------------------- input and loop

func _unhandled_input(event: InputEvent) -> void:
	if cutscene and not (event is InputEventKey and event.physical_keycode in [KEY_ESCAPE, KEY_F1, KEY_G]):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				interact()
			KEY_P:
				if story and story.phase == Story2.Phase.COVERUP:
					story.cover.phone(current)
			KEY_L:
				if story and story.phase == Story2.Phase.COVERUP and not current.busy and not cutscene:
					story.cover.lift(current)
			KEY_K:
				if story and story.phase == Story2.Phase.COVERUP:
					story.cover.order("keep_busy")
			KEY_C:
				if story and story.phase == Story2.Phase.COVERUP:
					story.cover.order("tidy")
			KEY_TAB:
				switch_brother()
			KEY_F:
				toggle_follow()
			KEY_H:
				call_brother()
			KEY_J:
				hud.toggle_jobs()
			KEY_F1:
				hud.toggle_help()
			KEY_Q:
				cam.rotate_step(-1)
			KEY_R:
				if day_over:
					get_tree().reload_current_scene()
				else:
					cam.rotate_step(1)
			KEY_N:
				if day_over:
					Game.day = 2
					get_tree().reload_current_scene()
			KEY_M:
				if day_over:
					get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_G:
				gfx.cycle()
			KEY_ESCAPE:
				if hud.help_visible():
					hud.toggle_help()
				else:
					hud.show_pause(true)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var p: Variant = cam.floor_point(event.position)
				if p != null and not day_over:
					if event.button_index == MOUSE_BUTTON_LEFT:
						if not current.busy:
							current.go_to(p)
					else:
						order_go(p)
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom(1.1)

func _process(delta: float) -> void:
	minute += delta * MINUTES_PER_SECOND
	hud.set_status("%02d:%02d" % [int(minute) / 60 % 24, int(minute) % 60], current.room(), cash)
	if not _nav_ok:
		_nav_ok = house.nav_ready()
		if not _nav_ok:
			return
	for r in residents:
		r.tick(minute, delta)

	if story:
		story.tick(delta)
	if not _scripted and not cutscene:
		var input := Vector2(
			float(_down(KEY_D, KEY_RIGHT)) - float(_down(KEY_A, KEY_LEFT)),
			float(_down(KEY_S, KEY_DOWN)) - float(_down(KEY_W, KEY_UP)))
		current.steer = cam.to_world(input.normalized()) if input != Vector2.ZERO and not current.busy else Vector2.ZERO
		current.running = Input.is_physical_key_pressed(KEY_SHIFT) and _carry == null
	elif cutscene:
		current.steer = Vector2.ZERO

	_update_carry(delta)
	_update_follow(delta)
	_update_auto_work(delta)
	_update_prompt()
	cam.floor_y = House.UP if House.level_of(current.global_position + Vector3(0, 0.6, 0)) == 1 else 0.0
	var focus := current.global_position
	if cam.is_focused():                     # the install view: cut the walls in front of the work
		focus = Vector3(cam.look_point().x, current.global_position.y, cam.look_point().z)
	house.update_cutaway(focus, cam.toward_camera(), delta)
	for a in [nico, tomas] + residents:      # people upstairs vanish with the upper floor; name tags show
		var level := House.level_of(a.global_position + Vector3(0, 0.6, 0))   # only on the floor in view
		a.visible = level <= house.level_shown
		a.show_tag(level == house.level_shown and not install.is_active())
	if _board_dirty:
		_board_dirty = false
		_refresh_board()

func _update_carry(delta: float) -> void:
	if _carry == null:
		return
	var lead := _carry.lead()
	var fwd := lead.forward()
	if _carry.carriers.size() == 1:
		# pushed along the floor in front of him, never into a wall: it comes closer where there is no room
		var reach := 0.45 + _carry.size.z / 2.0
		var at := lead.global_position + fwd * reach
		while reach > 0.1 and not _load_fits(_carry, at, lead.model.rotation.y):
			reach -= 0.1
			at = lead.global_position + fwd * reach
		_carry.global_position = at + Vector3(0, 0.02, 0)
		sfx.loop("drag_loop", lead.is_moving(), -4.0)
		if lead.is_moving():
			_noise_timer -= delta
			if _noise_timer <= 0.0:
				_noise_timer = 0.8
				make_noise(_carry.global_position, DRAG_NOISE, "something heavy being dragged")
	else:
		_carry.global_position = (lead.global_position + _carry.carriers[1].global_position) * 0.5 + Vector3(0, _carry.carry_height, 0)
	_carry.rotation.y = lead.model.rotation.y

func _update_follow(delta: float) -> void:
	_follow_timer -= delta
	var o := other()
	if not follow or o.busy or o.lead != null or _auto_job != null or _follow_timer > 0.0 or install.is_active():
		return
	_follow_timer = 0.5
	if o.global_position.distance_to(current.global_position) > 2.2:
		o.go_to(current.global_position)
	elif o.is_going():
		o.stop()

## The other brother working alone: the job's hotspots get done one by one over AUTO_SECONDS, with the
## right clip and tool for each step.
func _update_auto_work(delta: float) -> void:
	var job := _auto_job
	if job == null:
		return
	var w := _auto_worker()
	if job.done:
		_stop_auto()
		return
	if w.is_going() or w.global_position.distance_to(job.station) > 1.4:
		return
	var units := []
	for s in job.steps.size():
		for i in site.spots(job.id, s).size():
			units.append([s, i])
	job.progress += delta / AUTO_SECONDS
	var due := mini(units.size(), int(job.progress * units.size()))
	while _auto_units < due:
		var u: Array = units[_auto_units]
		site.apply(job.id, u[0], u[1], 1.0)
		var tool_id: String = job.steps[u[0]].tool
		if Install.TOOL_SOUND.has(tool_id):
			sfx.play(Install.TOOL_SOUND[tool_id], site.spots(job.id, u[0])[u[1]], -8.0)
		_auto_units += 1
	var cur: Array = units[mini(_auto_units, units.size() - 1)]
	var spot: Vector3 = site.spots(job.id, cur[0])[cur[1]]
	var tool: String = job.steps[cur[0]].tool
	w.face(spot)
	w.work(Worksite.anim_for(tool, spot.y - w.global_position.y), tool)
	_board_dirty = _board_dirty or Engine.get_process_frames() % 20 == 0
	if job.progress >= 1.0 and job.auto_only:   # keeping the work going: round again
		job.progress = 0.0
		_auto_units = 0
	elif job.progress >= 1.0:
		_stop_auto()
		complete_job(job)
		_dialogue.bark(w.display_name, "Done with that one.", 1.5)

func _update_prompt() -> void:
	var extra: Array = story.cover.prompt(current) if story and story.phase == Story2.Phase.COVERUP else []
	if day_over or install.is_active() or cutscene or hud.end_visible():
		hud.set_prompt("", "")
	elif not extra.is_empty():
		hud.set_prompt(extra[0], extra[1], extra[2] if extra.size() > 2 else "", extra[3] if extra.size() > 3 else "")
	elif _carry != null:
		hud.set_prompt("E", "Put down the %s" % _carry.label)
	else:
		var job := _nearest_job()
		var load := _nearest_load()
		if load != null:
			if _pair_ready():
				hud.set_prompt("E", "Lift the %s together" % load.label)
			else:
				hud.set_prompt("E", "Lift the %s alone  (slow and loud;  H calls %s)" % [load.label, other().display_name])
		elif job != null:
			hud.set_prompt("E", job.title + ("  (needs %s to hold)" % other().display_name if job.needs_two else ""))
		else:
			hud.set_prompt("", "")

## Floor rings mark the open jobs; they are hidden in the install view, where the hotspots take over.
func _update_rings() -> void:
	for job in jobs.values():
		var ring: Node3D = _rings.get(job.id)
		if ring:
			ring.visible = job.available(jobs) and not install.is_active()

func _refresh_board() -> void:
	var o := other()
	var doing := "Following you" if follow else "Waiting"
	var task: String = story.cover.task_text() if story and story.phase == Story2.Phase.COVERUP else ""
	if task != "":
		doing = task
	elif _auto_job != null:
		doing = "Working: " + _auto_job.title.to_lower()
	elif o.busy:
		doing = "Holding"
	elif o.lead != null:
		doing = "Carrying"
	if not story or story.phase < Story2.Phase.COVERUP:
		hud.set_jobs(jobs, o.display_name, _auto_job)
	hud.set_brothers(current.display_name, o.display_name, doing, follow)

## Keys on the day 2 ending card.
func _on_end_action(key: String) -> void:
	match key:
		"R":
			Game.case_id = story.case.id
			get_tree().reload_current_scene()
		"N":
			Game.case_id = ""
			get_tree().reload_current_scene()
		"M":
			Game.case_id = ""
			get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _down(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

func _show_hint_once(key: String, again := false) -> void:
	if _hints_shown.has(key) and not again:
		return
	_hints_shown[key] = true
	hud.toast(Day1.HINTS[key])

# ---------------------------------------------------------------- story

func _intro() -> void:
	while not _nav_ok:
		await get_tree().process_frame
	linda.go_to(Vector3(10.0, 0, 12.6))
	await _dialogue.play(Day1.INTRO)
	_show_hint_once("start")

func _end_day() -> void:
	day_over = true
	if _carry != null:
		put_down()
	linda.wander = []
	linda.go_to(current.global_position + Vector3(1.2, 0, 0))
	await get_tree().create_timer(1.5).timeout
	await _dialogue.play(Day1.PAY_LINES)
	var seen := []
	for r in residents:
		for line in Npc.summarize(r.noticed):
			seen.append([r.display_name, line])
	Game.day2_unlocked = true
	Game.save()
	hud.show_end("Day 1 done", cash, seen,
		"Noise is remembered. Tomorrow, carry heavy things together." if not seen.is_empty() else "Good, quiet work.",
		[["N", "Day 2"], ["R", "Play day 1 again"], ["M", "Main menu"]])

# ---------------------------------------------------------------- self-test

func _wait_arrival(a: Actor, seconds: float) -> bool:
	var waited := 0.0                       # game time, so slow rendering (movie capture) does not time out
	while a.is_going() and waited < seconds:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return not a.is_going()

func _walk(a: Actor, p: Vector3) -> bool:
	a.go_to(p)
	await get_tree().physics_frame
	return await _wait_arrival(a, 60.0)

func _wait_game(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()

func _heard_count() -> int:
	var n := 0
	for r in residents:
		n += r.noticed.size()
	return n

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

## Plays one job in the install view the way a player does: wrong tool first, then the right one, every
## hotspot, held steps with E down.
func _play_install(job: Job) -> String:
	while install.is_active():
		var s := install.current()
		var step := install.step
		if install.selected == "":
			install.select("hammer" if s.tool != "hammer" else "tape")
			if s.kind == "hold":
				_key(KEY_E, true)
			else:
				install.use_spot(0)
			for f in 3:                                   # the held key must be seen by a frame or two
				await get_tree().process_frame
			_key(KEY_E, false)
			if not install.message_bad:
				return "a wrong tool was not refused (%s step %d)" % [job.id, step]
		install.select(s.tool)
		if s.kind == "hold":
			_key(KEY_E, true)
			var waited := 0.0
			while install.is_active() and install.step == step and waited < 20.0:
				await get_tree().physics_frame
				waited += get_physics_process_delta_time()
			_key(KEY_E, false)
		else:
			if s.kind == "order" and install.progress().y > 1:
				install.use_spot(1)                       # out of order: a mistake, nothing connects
				if install.progress().x != 0:
					return "wiring accepted the wrong order"
			for i in install.progress().y:
				install.use_spot(i)
				var t := 0.0
				while install.is_active() and install.step == step and install.progress().x <= i and t < 10.0:
					await get_tree().physics_frame
					t += get_physics_process_delta_time()
		if install.is_active() and install.step == step:
			return "step %d of %s did not finish (%s, %s)" % [step, job.id, install.progress(), install.message]
		install.selected = ""
	return ""

func _run_selftest() -> void:
	while not _nav_ok:
		await get_tree().physics_frame
	await _dialogue.play(Day1.INTRO)

	# 1. alone: the dishwasher is slow and loud
	order_go(Vector3(5.0, 0, 9.5))                       # Tomas into the garage, out of reach
	await _wait_arrival(tomas, 40.0)
	await _walk(nico, jobs.dishwasher_in.carry.global_position + Vector3(-1.0, 0, 0))
	interact()
	if _carry == null or _carry.carriers.size() != 1:
		return _fail("could not lift the dishwasher alone (nico %s, box %s)" % [nico.global_position, jobs.dishwasher_in.carry.global_position])
	if nico.carrying != "solo":
		return _fail("solo carry clip not set")
	await _walk(nico, Day1.DISHWASHER_TARGET + Vector3(0, 0, 1.1))
	interact()
	if not jobs.dishwasher_in.done:
		return _fail("dishwasher not delivered (it is at %s)" % jobs.dishwasher_in.carry.global_position)
	if _heard_count() == 0:
		return _fail("nobody heard the solo carry")

	# 2. together: the couch is fast and quiet
	call_brother()
	await _walk(nico, jobs.couch_in.carry.global_position + Vector3(-1.0, 0, 0))
	var waited := 0.0
	while tomas.global_position.distance_to(nico.global_position) > 2.6 and waited < 40.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	var heard := _heard_count()
	interact()
	if _carry == null or _carry.carriers.size() != 2:
		return _fail("could not lift the couch together (Tomas %.1f m away)" % tomas.global_position.distance_to(nico.global_position))
	if tomas.carrying != "pair":
		return _fail("pair carry clip not set")
	await _walk(nico, Day1.COUCH_TARGET + Vector3(0, 0, 1.2))
	interact()
	if not jobs.couch_in.done:
		return _fail("couch not delivered (it is at %s, Nico %s, Tomas %s, next %s)" % [jobs.couch_in.carry.global_position, nico.global_position, tomas.global_position, nico.agent.get_next_path_position()])
	if _heard_count() != heard:
		return _fail("the pair carry made noise")

	# 3. Tomas lays the floor on his own while Nico does the rest; wiring is played like a player would
	send_to_job(jobs.flooring)
	for id in ["studs", "wiring", "drywall", "dishwasher", "assemble", "measure"]:
		var job: Job = jobs[id]
		if job.needs_two:
			while not jobs.flooring.done:                # he finishes the floor first
				await get_tree().physics_frame
			send_to_job(job)
			await _wait_arrival(tomas, 40.0)
		if not await _walk(nico, job.station):
			return _fail("Nico could not reach %s at %s (stuck at %s)" % [id, job.station, nico.global_position])
		interact()
		if not install.is_active():
			return _fail("job %s did not start (Nico at %s)" % [id, nico.global_position])
		if id == "wiring" or id == "drywall":
			var err: String = await _play_install(job)
			if err != "":
				return _fail(err)
		else:
			await _wait_game(2.0)                       # let the install view show (screen captures)
			install.auto_solve()
		if not job.done:
			return _fail("job %s not done" % id)
		if id == "drywall" and not site._sheets.all(func(s): return s.visible):
			return _fail("drywall sheets not on the wall")
	if not jobs.flooring.done:
		await _wait_game(AUTO_SECONDS)
	while not hud.end_visible():
		await get_tree().process_frame
	var total := 0
	for job in jobs.values():
		total += job.pay
	if cash != total:
		return _fail("pay %d, expected %d" % [cash, total])
	print("SELFTEST_OK day1 cash=$%d noticed=%d (%s)" % [cash, _heard_count(), linda.noticed])
	get_tree().quit(0)

func _fail(why: String) -> void:
	print("SELFTEST_FAIL " + why)
	get_tree().quit(1)
