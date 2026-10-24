extends Node3D
## "Off the Books". Milestone 2: day 1, the first job (tutorial). Design: docs/game3-design.md
##
## Controls: left click / WASD move, Shift run, E interact (start a job, lift or put down a load), Tab
## switch brother, right click send the other brother there, F the other brother follows / stays, H call
## him over, Q/R rotate the view, mouse wheel zoom, G graphics, Esc cancel a job / quit.
## Flags (after `--`): --selftest (plays all of day 1, prints SELFTEST_OK / SELFTEST_FAIL), --quality=<level>

const PERSON := preload("res://assets/models/person.glb")
const START_MINUTE := 8 * 60.0          # 08:00
const MINUTES_PER_SECOND := 1.0
const REACH := 1.5                      # how close you must stand to a job or a load
const AUTO_SECONDS := 24.0              # the other brother doing a job alone takes this long
const SOLO_SPEED := 0.42                # carrying alone: slow ...
const PAIR_SPEED := 0.9                 # ... together: nearly walking pace
const DRAG_NOISE := 10.0                # metres a solo carry can be heard
const BANG_NOISE := 7.0                 # a missed hammer blow / wrong wire

var gfx: Graphics
var house: House
var cam: IsoCamera
var nico: Actor
var tomas: Actor
var linda: Npc
var daniel: Npc
var rose: Npc
var residents: Array[Npc] = []
var current: Actor
var follow := true                     # the brother you are not controlling follows you
var minute := START_MINUTE
var jobs := {}
var cash := 0
var day_over := false

var _carry: Carryable
var _noise_timer := 0.0
var _mg_job: Job
var _auto_job: Job                     # what the other brother is doing on his own
var _minigame: Minigame
var _dialogue: Dialogue
var _clock: Label
var _who: Label
var _prompt: Label
var _hint: Label
var _board: VBoxContainer
var _end: Label
var _selftest := false
var _follow_timer := 0.0
var _nav_ok := false
var _hints_shown := {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_selftest = "--selftest" in args
	var forced := ""
	for a in args:
		if a.begins_with("--quality="):
			forced = a.substr(10)

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

	nico = _spawn(Actor.new(), "Nico", Color(0.11, 0.5, 0.55), Color(0.18, 0.21, 0.32), Vector3(10.0, 0.05, 14.0))
	tomas = _spawn(Actor.new(), "Tomas", Color(0.55, 0.18, 0.14), Color(0.25, 0.24, 0.22), Vector3(11.2, 0.05, 14.6))
	linda = _spawn(Npc.new(), "Linda", Color(0.45, 0.3, 0.55), Color(0.2, 0.2, 0.25), Vector3(9.8, 0.05, 10.5)) as Npc
	daniel = _spawn(Npc.new(), "Daniel", Color(0.75, 0.62, 0.2), Color(0.22, 0.3, 0.45), Vector3(3.5, 0.05, 4.4)) as Npc
	rose = _spawn(Npc.new(), "Rose", Color(0.6, 0.55, 0.5), Color(0.3, 0.27, 0.3), Vector3(12.2, 0.05, 6.6)) as Npc
	residents = [linda, daniel, rose]
	linda.hearing = 1.2
	linda.wander = [Vector3(2.5, 0, 1.3), Vector3(10.0, 0, 5.0), House.room_center("Rose's room"), Vector3(10.0, 0, 10.5)]
	daniel.wander = [Vector3(3.5, 0, 4.4), Vector3(4.8, 0, 3.0), Vector3(7.0, 0, 6.2), Vector3(2.4, 0, 5.4)]
	rose.hearing = 0.8

	var couch := _carryable("Couch (boxed)", Vector3(0.95, 0.8, 2.1), Color(0.66, 0.55, 0.4), Vector3(6.6, 0, 14.4))
	var dishwasher := _carryable("Dishwasher", Vector3(0.62, 0.86, 0.62), Color(0.75, 0.72, 0.62), Vector3(6.6, 0, 17.4))
	jobs = Day1.jobs(couch, dishwasher)
	_add_target_markers()

	cam = IsoCamera.new()
	add_child(cam)
	_build_ui()
	_control(nico)
	cam.snap_to_target()
	gfx.changed.connect(func(n: String): _set_hint("Graphics: %s   (G to change)" % n))
	if _selftest:
		Engine.time_scale = 4.0
		_dialogue.fast = true
		_run_selftest()
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
	for room in House.ROOMS:
		var l := OmniLight3D.new()
		l.position = House.room_center(room) + Vector3(0, 2.4, 0)
		l.light_color = Color(1.0, 0.82, 0.62)
		l.light_energy = 0.6
		l.omni_range = 6.0
		l.shadow_enabled = true
		add_child(l)

func _spawn(a: Actor, who: String, jacket: Color, pants: Color, at: Vector3) -> Actor:
	add_child(a)
	a.position = at
	a.setup(PERSON, who, jacket, pants, gfx)
	return a

func _carryable(what: String, size: Vector3, color: Color, at: Vector3) -> Carryable:
	var c := Carryable.new()
	add_child(c)
	c.position = at
	c.setup(what, size, color)
	return c

## Faint floor marks where the carried loads go.
func _add_target_markers() -> void:
	for job in jobs.values():
		if job.carry == null:
			continue
		var mark := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.2, 1.2)
		mark.mesh = plane
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.8, 0.3, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mark.material_override = m
		mark.position = job.carry_target + Vector3(0, 0.05, 0)
		mark.name = "Mark_" + job.id
		add_child(mark)

# ---------------------------------------------------------------- control

func _control(a: Actor) -> void:
	if current:
		current.set_controlled(false)
	current = a
	a.set_controlled(true)
	if _auto_job != null and a == _auto_worker():
		_auto_job = null                         # you took over: he stops working on his own
	if not a.busy:
		a.stop()
	cam.target = a
	_who.text = "Playing: %s" % a.display_name
	_refresh_board()

func other() -> Actor:
	return tomas if current == nico else nico

func _auto_worker() -> Actor:
	return other()

func switch_brother() -> void:
	if _carry != null or (_minigame and _minigame.is_active()):
		_set_hint("Finish what you are doing first.")
		return
	_control(other())

func order_go(p: Vector3) -> void:
	if other().busy:
		return
	follow = false
	_auto_job = null
	other().go_to(p)
	_dialogue.bark(other().display_name, "On my way.", 1.5)

func toggle_follow() -> void:
	follow = not follow
	_auto_job = null
	if not follow:
		other().stop()
	_dialogue.bark(other().display_name, "Right behind you." if follow else "I'll wait here.", 1.5)

func call_brother() -> void:
	if other().busy:
		return
	follow = true
	_auto_job = null
	other().go_to(current.global_position)
	_dialogue.bark(other().display_name, "Coming.", 1.2)

## Job board button: send the other brother to a job. Jobs he can do alone he starts on his own; for a
## two-person job he goes and waits to hold; carrying he refuses alone.
func send_to_job(job: Job) -> void:
	var o := other()
	if job.done or o.busy:
		return
	if job.carry != null:
		_dialogue.bark(o.display_name, "Alone? It's too heavy, and they'd hear me drag it. Call me over and we lift it together.", 3.5)
		return
	if not job.available(jobs):
		_dialogue.bark(o.display_name, "That has to wait, the other job comes first.", 2.5)
		return
	follow = false
	o.go_to(job.station + Vector3(0.0, 0, 0.6 if job.needs_two else 0.0))
	if job.solo_ok():
		_auto_job = job
		_dialogue.bark(o.display_name, "I'll handle %s." % job.title.to_lower(), 2.0)
	else:
		_auto_job = null
		_dialogue.bark(o.display_name, "I'll hold it. Come and start when you're ready.", 2.0)

# ---------------------------------------------------------------- interaction

func interact() -> void:
	if day_over or current.busy:
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
		if job.carry != null or not job.available(jobs):
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

func pick_up(c: Carryable) -> void:
	var helper := other()
	var pair := not helper.busy and helper.global_position.distance_to(current.global_position) < 3.0
	_carry = c
	c.carriers = [current]
	if pair:
		c.carriers.append(helper)
		helper.stop()
		helper.lead = current
		helper.lead_gap = 1.7
		_auto_job = null
	for a in c.carriers:
		a.speed_mul = PAIR_SPEED if pair else SOLO_SPEED
	_show_hint_once("pair_carry" if pair else "solo_carry")

func put_down() -> void:
	var c := _carry
	var lead_pos := c.lead().global_position
	for a in c.carriers:
		a.speed_mul = 1.0
		a.lead = null
	c.carriers = []
	c.position.y = 0.0
	_carry = null
	for job in jobs.values():
		var near_load := Vector2(c.position.x - job.carry_target.x, c.position.z - job.carry_target.z).length() < 1.7
		var near_lead := Vector2(lead_pos.x - job.carry_target.x, lead_pos.z - job.carry_target.z).length() < 1.4
		if job.carry == c and (near_load or near_lead):
			c.position = job.carry_target
			c.rotation = Vector3.ZERO
			complete_job(job)

func start_job(job: Job) -> void:
	if job.needs_two:
		var helper := other()
		if helper.global_position.distance_to(job.station) > 2.4 or helper.is_going():
			_show_hint_once("needs_two", true)
			_dialogue.bark(current.display_name, "%s, I need you to hold this." % helper.display_name, 2.0)
			return
		helper.busy = true
		helper.face(job.station + Vector3(1, 0, 0))
	if _auto_job == job:
		_auto_job = null
	current.busy = true
	current.stop()
	current.face(job.station + Vector3(1, 0, 0))
	_mg_job = job
	_minigame.start(job.title, job.steps)

func _on_minigame_finished() -> void:
	var job := _mg_job
	_release_mg()
	complete_job(job)

func _release_mg() -> void:
	current.busy = false
	if _mg_job and _mg_job.needs_two:
		other().busy = false
	_mg_job = null

func complete_job(job: Job) -> void:
	if job.done:
		return
	job.done = true
	cash += job.pay
	var mark := get_node_or_null("Mark_" + job.id)
	if mark:
		mark.queue_free()
	_refresh_board()
	if Day1.DANIEL_LINES.has(job.id):
		_dialogue.bark("Daniel", Day1.DANIEL_LINES[job.id], 3.0)
	if jobs.values().all(func(j): return j.done):
		_end_day()

## Something loud happened: a ring spreads on the floor and every resident in range remembers it.
func make_noise(at: Vector3, radius: float, what: String) -> void:
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
	ring.position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.3, 0.05, 0.3)
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.9)
	t.tween_property(m, "albedo_color:a", 0.0, 0.9)
	t.chain().tween_callback(ring.queue_free)
	for r in residents:
		r.hear(at, radius, what, minute, House.room_at(at))

# ---------------------------------------------------------------- input and loop

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				interact()
			KEY_TAB:
				switch_brother()
			KEY_F:
				toggle_follow()
			KEY_H:
				call_brother()
			KEY_Q:
				cam.rotate_step(-1)
			KEY_R:
				if day_over:
					get_tree().reload_current_scene()
				else:
					cam.rotate_step(1)
			KEY_G:
				gfx.cycle()
			KEY_ESCAPE:
				get_tree().quit()
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
	_clock.text = "%02d:%02d   %s     $%d" % [int(minute) / 60 % 24, int(minute) % 60, current.room(), cash]
	if not _nav_ok:
		_nav_ok = house.nav_ready()
		if not _nav_ok:
			return
	for r in residents:
		r.tick(minute, delta)

	if not _selftest:
		var input := Vector2(
			float(_down(KEY_D, KEY_RIGHT)) - float(_down(KEY_A, KEY_LEFT)),
			float(_down(KEY_S, KEY_DOWN)) - float(_down(KEY_W, KEY_UP)))
		current.steer = cam.to_world(input.normalized()) if input != Vector2.ZERO and not current.busy else Vector2.ZERO
		current.running = Input.is_physical_key_pressed(KEY_SHIFT)

	_update_carry(delta)
	_update_follow(delta)
	_update_auto_work(delta)
	_update_prompt()
	house.update_cutaway(current.global_position, cam.toward_camera(), delta)

func _update_carry(delta: float) -> void:
	if _carry == null:
		return
	var lead := _carry.lead()
	var fwd := lead.forward()
	if _carry.carriers.size() == 1:
		_carry.global_position = lead.global_position + fwd * 0.8 + Vector3(0, 0.05, 0)   # dragged along the floor
		if lead.is_moving():
			_noise_timer -= delta
			if _noise_timer <= 0.0:
				_noise_timer = 0.8
				make_noise(_carry.global_position, DRAG_NOISE, "something heavy being dragged")
	else:
		_carry.global_position = (lead.global_position + _carry.carriers[1].global_position) * 0.5 + Vector3(0, 0.35, 0)
	_carry.rotation.y = lead.model.rotation.y

func _update_follow(delta: float) -> void:
	_follow_timer -= delta
	var o := other()
	if not follow or o.busy or o.lead != null or _auto_job != null or _follow_timer > 0.0:
		return
	_follow_timer = 0.5
	if o.global_position.distance_to(current.global_position) > 2.2:
		o.go_to(current.global_position)
	elif o.is_going():
		o.stop()

func _update_auto_work(delta: float) -> void:
	var job := _auto_job
	if job == null:
		return
	var w := _auto_worker()
	if job.done:
		_auto_job = null
		return
	if w.is_going() or w.global_position.distance_to(job.station) > 1.4:
		return
	w.face(job.station + Vector3(1, 0, 0))
	job.progress += delta / AUTO_SECONDS
	_refresh_board()
	if job.progress >= 1.0:
		_auto_job = null
		complete_job(job)
		_dialogue.bark(w.display_name, "Done with that one.", 1.5)

func _update_prompt() -> void:
	var text := ""
	if day_over or (_minigame and _minigame.is_active()):
		text = ""
	elif _carry != null:
		text = "E: put down the %s" % _carry.label.to_lower()
	else:
		var job := _nearest_job()
		var load := _nearest_load()
		if load != null:
			var pair := other().global_position.distance_to(current.global_position) < 3.0 and not other().busy
			text = "E: lift the %s %s" % [load.label.to_lower(), "together" if pair else "alone (slow and loud; H calls %s)" % other().display_name]
		elif job != null:
			text = "E: %s%s" % [job.title.to_lower(), "  (needs %s to hold)" % other().display_name if job.needs_two else ""]
	_prompt.text = text

func _down(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

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
	var seen := PackedStringArray()
	for r in residents:
		for n in r.noticed:
			seen.append("%s: %s" % [r.display_name, n])
	var text := "DAY 1 DONE\n\nCash from Linda: $%d\n\n" % cash
	if seen.is_empty():
		text += "Nobody noticed anything unusual. Good, quiet work."
	else:
		text += "What the family noticed today:\n  " + "\n  ".join(seen)
		text += "\n\nNoise is remembered. Tomorrow, carry heavy things together."
	text += "\n\nR: play day 1 again      (day 2 comes in the next milestone)"
	_end.text = text
	_end.visible = true

# ---------------------------------------------------------------- UI

func _label(size: int, halign: HorizontalAlignment, valign: VerticalAlignment) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font_size = size
	s.outline_size = maxi(4, size / 6)
	s.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = s
	l.horizontal_alignment = halign
	l.vertical_alignment = valign
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_clock = _label(24, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_clock.offset_left = 20
	_clock.offset_top = 14
	layer.add_child(_clock)
	_who = _label(24, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	_who.offset_right = -20
	_who.offset_top = 14
	layer.add_child(_who)
	var help := _label(15, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	help.offset_bottom = -8
	help.modulate.a = 0.8
	help.text = "Click/WASD move   E use   Tab switch brother   Right click send him   F follow/stay   H call him   Q/R rotate   Wheel zoom   G graphics"
	layer.add_child(help)
	_prompt = _label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_prompt.offset_bottom = -34
	_prompt.label_settings.font_color = Color(1, 0.9, 0.55)
	layer.add_child(_prompt)
	_hint = _label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_hint.offset_top = 60
	_hint.offset_left = 520      # right of the job board
	_hint.offset_right = -40
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate.a = 0.0
	layer.add_child(_hint)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 52)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.72)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_board = VBoxContainer.new()
	panel.add_child(_board)

	_minigame = Minigame.new()
	layer.add_child(_minigame)
	_minigame.finished.connect(_on_minigame_finished)
	_minigame.cancelled.connect(_release_mg)
	_minigame.missed.connect(func(): make_noise(current.global_position, BANG_NOISE, "a loud bang"))
	_dialogue = Dialogue.new()
	layer.add_child(_dialogue)

	_end = _label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_end.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0, 0, 0, 0.78)
	_end.add_theme_stylebox_override("normal", dim)
	_end.visible = false
	layer.add_child(_end)

func _refresh_board() -> void:
	if _board == null:
		return
	for c in _board.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "JOB BOARD  (living room + kitchen)"
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_board.add_child(head)
	for job in jobs.values():
		var row := HBoxContainer.new()
		var l := Label.new()
		var mark := "[x]" if job.done else ("[%d%%]" % int(job.progress * 100) if job.progress > 0 else "[ ]")
		l.text = "%s %s" % [mark, job.title]
		l.custom_minimum_size.x = 330
		if job.done:
			l.modulate = Color(0.6, 0.9, 0.6)
		elif not job.available(jobs):
			l.modulate = Color(0.6, 0.6, 0.6)
		row.add_child(l)
		if not job.done and job.carry == null:
			var b := Button.new()
			b.text = "Send %s" % other().display_name
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(send_to_job.bind(job))
			row.add_child(b)
		_board.add_child(row)

func _set_hint(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(5.0)
	t.tween_property(_hint, "modulate:a", 0.0, 0.8)

func _show_hint_once(key: String, again := false) -> void:
	if _hints_shown.has(key) and not again:
		return
	_hints_shown[key] = true
	_set_hint(Day1.HINTS[key])

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

func _heard_count() -> int:
	var n := 0
	for r in residents:
		n += r.noticed.size()
	return n

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
		return _fail("could not lift the dishwasher alone (nico %s, box %s, hit %s %s)" % [nico.global_position, jobs.dishwasher_in.carry.global_position, nico.get_last_slide_collision().get_collider().get_parent().name if nico.get_last_slide_collision() else "none", nico.get_last_slide_collision().get_collider().position if nico.get_last_slide_collision() else ""])
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
		return _fail("could not lift the couch together (Tomas %.1f m away at %s, going=%s, nico %s next=%s target=%s vel=%s busy=%s lead=%s mul=%s)" % [tomas.global_position.distance_to(nico.global_position), tomas.global_position, tomas.is_going(), nico.global_position, nico.agent.get_next_path_position(), nico.agent.target_position, nico.velocity, nico.busy, nico.lead, nico.speed_mul])
	await _walk(nico, Day1.COUCH_TARGET + Vector3(0, 0, 1.2))
	interact()
	if not jobs.couch_in.done:
		return _fail("couch not delivered (it is at %s)" % jobs.couch_in.carry.global_position)
	if _heard_count() != heard:
		return _fail("the pair carry made noise")

	# 3. Tomas lays the floor on his own while Nico does the rest
	send_to_job(jobs.flooring)
	for id in ["studs", "drywall", "wiring", "dishwasher", "assemble"]:
		var job: Job = jobs[id]
		if job.needs_two:
			while not jobs.flooring.done:                # he finishes the floor first
				await get_tree().physics_frame
			send_to_job(job)
			await _wait_arrival(tomas, 40.0)
		await _walk(nico, job.station)
		interact()
		if not _minigame.is_active():
			return _fail("job %s did not start (Nico at %s)" % [id, nico.global_position])
		await get_tree().create_timer(3.0).timeout      # let the minigame show (screen captures)
		_minigame.auto_solve()
		if not job.done:
			return _fail("job %s not done" % id)
	while not jobs.flooring.done:
		await get_tree().physics_frame
	while not _end.visible:
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
