class_name Dialogue
extends PanelContainer
## Speaker lines at the bottom of the screen. `play(lines)` queues [speaker, text] pairs and returns when
## all are shown; lines advance on their own (by length) or with Enter. `bark()` shows one
## short line without blocking.

signal line_done

const COLORS := {
	"Nico": Color(0.5, 0.85, 0.9), "Tomas": Color(0.95, 0.55, 0.45), "Linda": Color(0.8, 0.65, 0.95),
	"Daniel": Color(0.7, 0.9, 0.5), "Rose": Color(0.95, 0.85, 0.6),
}

var fast := false           # self-test: every line lasts one frame
var _speaker: Label
var _text: Label
var _skip := false

func _ready() -> void:
	custom_minimum_size = Vector2(760, 0)
	anchor_left = 0.5            # bottom centre, growing upward with its content
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -380
	offset_right = 380
	offset_top = -40
	offset_bottom = -40
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 20)
	box.add_child(_speaker)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	visible = false

func play(lines: Array) -> void:
	for l in lines:
		_show(l[0], l[1])
		var hold := 0.0 if fast else 1.6 + 0.045 * String(l[1]).length()
		var t := 0.0
		_skip = false
		while t < hold and not _skip:
			await get_tree().process_frame
			t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		if fast:
			await get_tree().process_frame
	visible = false
	line_done.emit()

func bark(speaker: String, text: String, seconds := 3.0) -> void:
	_show(speaker, text)
	await get_tree().create_timer(0.05 if fast else seconds * Engine.time_scale).timeout
	if _text.text == text:
		visible = false

func _show(speaker: String, text: String) -> void:
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", COLORS.get(speaker, Color(1, 1, 1)))
	_text.text = text
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ENTER:
		_skip = true
		get_viewport().set_input_as_handled()
