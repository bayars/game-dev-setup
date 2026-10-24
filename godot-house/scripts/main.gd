extends Node3D
## "Off the Books": milestone 1 greybox. The house, the isometric camera with wall cutaway, the two
## brothers (Tab switches control, the other one follows or takes orders) and one resident on a schedule.
## Design: docs/game3-design.md
##
## Controls: left click move, WASD move, Shift run, Tab switch brother, right click send the other
## brother there, F the other brother follows / stays, Q/E rotate view, mouse wheel zoom, G graphics.
## Flags (after `--`): --selftest (headless check, prints SELFTEST_OK / SELFTEST_FAIL), --quality=<level>

const PERSON := preload("res://assets/models/person.glb")
const START_MINUTE := 8 * 60.0          # 08:00
const MINUTES_PER_SECOND := 1.0

var gfx: Graphics
var house: House
var cam: IsoCamera
var nico: Actor
var tomas: Actor
var linda: Npc
var current: Actor
var follow := true                     # the brother you are not controlling follows you
var minute := START_MINUTE

var _clock: Label
var _who: Label
var _toast: Label
var _selftest := false
var _follow_timer := 0.0
var _nav_ok := false

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
	linda = _spawn(Npc.new(), "Linda", Color(0.45, 0.3, 0.55), Color(0.2, 0.2, 0.25), Vector3(3.5, 0.05, 4.2)) as Npc
	linda.schedule = [
		[START_MINUTE + 4.0, House.room_center("Hallway") + Vector3(0, 0, 3)],
		[START_MINUTE + 8.0, House.room_center("Rose's room")],
		[START_MINUTE + 60.0, Vector3(3.5, 0, 4.0)],
	]

	cam = IsoCamera.new()
	add_child(cam)
	_build_ui()
	_control(nico)
	cam.snap_to_target()
	gfx.changed.connect(func(n: String): _show_toast("Graphics: %s   (G to change)" % n))
	if _selftest:
		Engine.time_scale = 4.0
		_run_selftest()

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

# ---------------------------------------------------------------- control

func _control(a: Actor) -> void:
	if current:
		current.set_controlled(false)
	current = a
	a.set_controlled(true)
	a.stop()
	cam.target = a
	_who.text = "Playing: %s" % a.display_name

func other() -> Actor:
	return tomas if current == nico else nico

func switch_brother() -> void:
	_control(other())

func order_go(p: Vector3) -> void:
	follow = false
	other().go_to(p)
	_show_toast("%s: \"On my way.\"" % other().display_name)

func toggle_follow() -> void:
	follow = not follow
	if not follow:
		other().stop()
	_show_toast("%s: %s" % [other().display_name, "\"Right behind you.\"" if follow else "\"I'll wait here.\""])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				switch_brother()
			KEY_F:
				toggle_follow()
			KEY_Q:
				cam.rotate_step(-1)
			KEY_E:
				cam.rotate_step(1)
			KEY_G:
				gfx.cycle()
			KEY_ESCAPE:
				get_tree().quit()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var p: Variant = cam.floor_point(event.position)
				if p != null:
					if event.button_index == MOUSE_BUTTON_LEFT:
						current.go_to(p)
					else:
						order_go(p)
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom(1.1)

func _process(delta: float) -> void:
	minute += delta * MINUTES_PER_SECOND
	if not _nav_ok:
		_nav_ok = house.nav_ready()
		if not _nav_ok:
			return
	linda.tick(minute)
	_clock.text = "%02d:%02d   %s" % [int(minute) / 60 % 24, int(minute) % 60, current.room()]

	if not _selftest:
		var input := Vector2(
			float(_down(KEY_D, KEY_RIGHT)) - float(_down(KEY_A, KEY_LEFT)),
			float(_down(KEY_S, KEY_DOWN)) - float(_down(KEY_W, KEY_UP)))
		current.steer = cam.to_world(input.normalized()) if input != Vector2.ZERO else Vector2.ZERO
		current.running = Input.is_physical_key_pressed(KEY_SHIFT)

	_follow_timer -= delta
	if follow and _follow_timer <= 0.0:
		_follow_timer = 0.5
		var o := other()
		if o.global_position.distance_to(current.global_position) > 2.2:
			o.go_to(current.global_position)
		elif o.is_going():
			o.stop()

	house.update_cutaway(current.global_position, cam.toward_camera(), delta)

func _down(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

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
	var help := _label(16, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	help.offset_bottom = -10
	help.modulate.a = 0.8
	help.text = "Click / WASD move   Shift run   Tab switch brother   Right click send him   F follow/stay   Q/E rotate   Wheel zoom   G graphics"
	layer.add_child(help)
	_toast = _label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_toast.offset_bottom = -44
	_toast.modulate.a = 0.0
	layer.add_child(_toast)

func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(2.2)
	t.tween_property(_toast, "modulate:a", 0.0, 0.6)

# ---------------------------------------------------------------- self-test

func _wait_arrival(a: Actor, seconds: float) -> bool:
	var waited := 0.0                       # game time, so slow rendering (movie capture) does not time out
	while a.is_going() and waited < seconds:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return not a.is_going()

func _run_selftest() -> void:
	while not _nav_ok:
		await get_tree().physics_frame
	follow = false
	nico.go_to(Vector3(3.0, 0, 3.6))                  # from the yard, through the front door and hallway
	if not await _wait_arrival(nico, 40.0) or nico.room() != "Work room":
		return _fail("Nico did not reach the work room (at %s, %s)" % [nico.global_position, nico.room()])
	switch_brother()
	if current != tomas or nico.controlled:
		return _fail("Tab switch did not hand control to Tomas")
	switch_brother()
	order_go(Vector3(5.0, 0, 9.5))                     # send Tomas into the garage
	if not await _wait_arrival(tomas, 40.0) or tomas.room() != "Garage":
		return _fail("Tomas did not reach the garage (at %s, %s)" % [tomas.global_position, tomas.room()])
	while minute < START_MINUTE + 18.0:
		await get_tree().process_frame
	if linda.room() != "Rose's room":
		return _fail("Linda did not follow her schedule (in %s)" % linda.room())
	if house.cut_count() == 0:
		return _fail("no wall is cut away in front of the player")
	print("SELFTEST_OK nico=%s tomas=%s linda=%s cut_walls=%d" % [nico.room(), tomas.room(), linda.room(), house.cut_count()])
	get_tree().quit(0)

func _fail(why: String) -> void:
	print("SELFTEST_FAIL " + why)
	get_tree().quit(1)
