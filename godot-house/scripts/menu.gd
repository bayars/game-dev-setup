extends Node3D
## The title screen: the house turning slowly at dusk behind the menu. A content warning the first time;
## then Play (day 1) for a new player, Continue (day 2) once day 1 is done, and a choice of either day
## once day 2 has been played to an ending; options (soften the accident close-ups, volume, graphics)
## and quit. Command-line runs (--selftest, --playtest, --day=N) skip
## straight to the game.

var gfx: Graphics
var house: House
var cam: Camera3D
var sfx: Sfx
var _angle := 0.6
var _root: Control
var _main_box: VBoxContainer
var _warning: PanelContainer
var _options: PanelContainer
var _first: Button          # the first way in, focused so arrows and Enter work too
var _understood: Button
var _soften: CheckButton

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in ["--selftest", "--playtest"] or a.begins_with("--day="):
			get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
			return
	Game.load_save()
	gfx = Graphics.new()
	add_child(gfx)
	gfx.build_environment(self)
	gfx.sun.rotation_degrees = Vector3(-14, 60, 0)
	gfx.sun.light_color = Color(1.0, 0.72, 0.5)
	gfx.load_level("", true)
	house = House.new()
	add_child(house)
	house.build(gfx)
	house.upper.visible = true
	cam = Camera3D.new()
	cam.fov = 30
	add_child(cam)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.loop("yard_loop", true, -12.0)
	sfx.loop("music_day_loop", true, -8.0, false)
	_build_ui()
	if not Game.seen_warning and not "--menu-preview" in args:
		_show_warning()
	else:
		_first.grab_focus()

func _exit_tree() -> void:
	RoundBox.clear_cache()

func _process(delta: float) -> void:
	_angle += delta * 0.05
	var centre := Vector3(8, 1.5, 6)
	cam.look_at_from_position(centre + Vector3(sin(_angle) * 26, 15, cos(_angle) * 26), centre)
	house.update_cutaway(Vector3(8, House.UP, 6), Vector2(sin(_angle), cos(_angle)), delta)   # the rooms open to view

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.055, 0.07, 0.88), 16, 28))
	panel.position = Vector2(64, 120)
	panel.custom_minimum_size = Vector2(400, 0)
	_root.add_child(panel)
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	panel.add_child(_main_box)
	_main_box.add_child(UiTheme.label("Off the Books", UiTheme.HEADLINE + 14, UiTheme.TEXT))
	var sub := UiTheme.label("Two brothers. Cash in hand. One house, two days.", UiTheme.BODY, UiTheme.MUTED)
	_main_box.add_child(sub)
	_main_box.add_child(HSeparator.new())
	for s in story_buttons():
		var day: int = s[1]
		var b := _button(s[0], func(): _play(day))
		_main_box.add_child(b)
		if _first == null:
			_first = b
	_main_box.add_child(_button("Options", func(): _options.visible = not _options.visible))
	_main_box.add_child(_button("Quit", func(): get_tree().quit()))
	_main_box.add_child(UiTheme.label("18+  ·  contains death and its concealment", UiTheme.CAPTION, UiTheme.MUTED))

	_options = PanelContainer.new()
	_options.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.055, 0.07, 0.9), 14, 22))
	_options.position = Vector2(500, 120)
	_options.custom_minimum_size = Vector2(380, 0)
	_root.add_child(_options)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	_options.add_child(ov)
	ov.add_child(UiTheme.label("Options", UiTheme.TITLE, UiTheme.ACCENT))
	_soften = CheckButton.new()
	_soften.text = "Soften the accident (cut to black)"
	_soften.button_pressed = Game.soften
	_soften.toggled.connect(func(on: bool):
		Game.soften = on
		Game.save())
	ov.add_child(_soften)
	var vol_row := HBoxContainer.new()
	vol_row.add_child(UiTheme.label("Volume", UiTheme.BODY))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.volume
	vol.custom_minimum_size.x = 220
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.value_changed.connect(func(v: float):
		Game.volume = v
		sfx.set_volume(v)
		Game.save())
	vol_row.add_child(vol)
	ov.add_child(vol_row)
	var gfx_btn := _button("Graphics: " + Graphics.NAMES[gfx.level], func(): pass)
	gfx_btn.pressed.connect(func():
		gfx.cycle()
		gfx_btn.text = "Graphics: " + Graphics.NAMES[gfx.level])
	ov.add_child(gfx_btn)
	_options.visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE   # full screen and on top: it must not take the menu's clicks
	_root.add_child(center)
	_warning = PanelContainer.new()
	_warning.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.04, 0.04, 0.05, 0.97), 16, 32))
	_warning.custom_minimum_size = Vector2(640, 0)
	center.add_child(_warning)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 14)
	_warning.add_child(wv)
	wv.add_child(UiTheme.label("Before you play", UiTheme.HEADLINE, UiTheme.ACCENT))
	var text := UiTheme.label("Off the Books is a story for adults. It shows the accidental death of a teenager, and two undocumented workers who hide what happened because they are sure nobody would believe them.\n\nThe accident is shown in a short close-up. You can soften it (it cuts to black) here or in Options at any time.\n\nThe ways of hiding things in this game are made-up game rules, not real methods.", UiTheme.BODY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 576
	wv.add_child(text)
	var soft := CheckButton.new()
	soft.text = "Soften the accident"
	soft.button_pressed = Game.soften
	soft.toggled.connect(func(on: bool):
		Game.soften = on
		_soften.button_pressed = on)
	wv.add_child(soft)
	_understood = _button("I understand  (Enter)", _accept_warning)
	wv.add_child(_understood)
	_warning.visible = false

func _show_warning() -> void:
	_warning.visible = true
	_main_box.get_parent().visible = false
	_understood.grab_focus()

## The ways into the story, [text, day], from the save: a first-time player only gets day 1, after
## day 1 the story continues with day 2, and once day 2 has been played to an ending either day.
static func story_buttons() -> Array:
	if Game.day2_done:
		return [["Day 1: The first job", 1], ["Day 2: Daniel's room", 2]]
	if Game.day2_unlocked:
		return [["Continue: day 2", 2]]
	return [["Play", 1]]

func _accept_warning() -> void:
	Game.seen_warning = true
	Game.save()
	_warning.visible = false
	_main_box.get_parent().visible = true
	_first.grab_focus()

func _button(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", UiTheme.TITLE)
	b.pressed.connect(func():
		sfx.play("click")
		on.call())
	return b

func _play(day: int) -> void:
	Game.day = day
	Game.case_id = ""
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _warning.visible and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_accept_warning()
		elif event.physical_keycode == KEY_ESCAPE and _options.visible:
			_options.visible = false
