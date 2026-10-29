class_name Dialogue
extends PanelContainer
## Speaker lines at the bottom of the screen. `play(lines)` queues [speaker, text] pairs and returns when
## all are shown; lines advance on their own (by length) or with Enter. `bark()` shows one short line
## without blocking. `speaking` tells the scene who is talking (they play the talk clip).

signal line_done
signal speaking(who: String)

var fast := false           # self-test: every line lasts one frame
var _speaker: Label
var _text: Label
var _next: HBoxContainer
var _skip := false
var _style: StyleBoxFlat

func _ready() -> void:
	name = "Dialogue"
	custom_minimum_size = Vector2(720, 0)
	anchor_left = 0.5            # bottom centre, growing upward with its content
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -360
	offset_right = 360
	offset_top = -84
	offset_bottom = -84
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_style = UiTheme.panel(UiTheme.BG, UiTheme.RADIUS, 16)
	_style.border_width_left = 4
	add_theme_stylebox_override("panel", _style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_speaker = UiTheme.label("", UiTheme.BODY)
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_speaker)
	_next = UiTheme.key_hint("Enter", "next", UiTheme.CAPTION)
	_next.modulate.a = 0.7
	head.add_child(_next)
	_text = UiTheme.label("", UiTheme.TITLE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	visible = false

func play(lines: Array) -> void:
	for l in lines:
		_show(l[0], l[1], true)
		var hold := 0.0 if fast else 1.6 + 0.045 * String(l[1]).length()
		var t := 0.0
		_skip = false
		while t < hold and not _skip:
			await get_tree().process_frame
			if not get_tree().paused:
				t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		if fast:
			await get_tree().process_frame
	visible = false
	speaking.emit("")
	line_done.emit()

func bark(speaker: String, text: String, seconds := 3.0) -> void:
	_show(speaker, text, false)
	await get_tree().create_timer(0.05 if fast else seconds * Engine.time_scale).timeout
	if _text.text == text:
		visible = false
		speaking.emit("")

func _show(speaker: String, text: String, skippable: bool) -> void:
	var c := UiTheme.person_color(speaker)
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", c)
	_style.border_color = c
	_text.text = text
	_next.visible = skippable
	visible = true
	speaking.emit(speaker)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ENTER:
		_skip = true
		get_viewport().set_input_as_handled()
