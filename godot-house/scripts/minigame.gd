class_name Minigame
extends PanelContainer
## Work minigame shown at the bottom of the screen. A job is a list of steps of three kinds:
##   {type = "timing", hits = 5, label = "..."}   press E/Space while the marker is in the green zone;
##                                                 a miss is loud (emits `missed`)
##   {type = "hold", seconds = 3.0, label = "..."} hold E/Space until the bar is full
##   {type = "sequence", keys = ["1", "3", "2"], names = {"1": "Black", ...}, label = "..."}
##                                                 press the number keys in the shown order
## Esc cancels. `auto_solve()` finishes at once (self-test).

signal finished
signal cancelled
signal missed

const ZONE := Vector2(0.42, 0.6)

var steps: Array = []
var _i := 0
var _t := 0.0              # timing: marker phase; hold: filled seconds
var _count := 0            # timing hits / sequence position
var _title: Label
var _info: Label
var _bar: Control
var _active := false

func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	anchor_left = 0.5            # bottom centre, growing upward with its content
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -260
	offset_right = 260
	offset_top = -90
	offset_bottom = -90
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.88)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	box.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	box.add_child(_info)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	visible = false

func start(job_title: String, job_steps: Array) -> void:
	_title.text = job_title
	steps = job_steps
	_i = 0
	_begin_step()
	visible = true
	_active = true

func is_active() -> bool:
	return _active

func auto_solve() -> void:
	_close()
	finished.emit()

func _begin_step() -> void:
	_t = 0.0
	_count = 0
	_update_info()

func _step() -> Dictionary:
	return steps[_i]

func _update_info() -> void:
	var s := _step()
	var head := "Step %d/%d: %s\n" % [_i + 1, steps.size(), s.label]
	match s.type:
		"timing":
			_info.text = head + "Press E when the marker is in the green zone  (%d/%d)   Misses are loud." % [_count, s.hits]
		"hold":
			_info.text = head + "Hold E"
		"sequence":
			var parts := PackedStringArray()
			for k in s.keys.size():
				var key: String = s.keys[k]
				var mark := "[x]" if k < _count else "[ ]"
				parts.append("%s %s=%s" % [mark, key, s.names[key]])
			_info.text = head + "Press in order:  " + "   ".join(parts)
	_bar.queue_redraw()

func _next_step() -> void:
	_i += 1
	if _i >= steps.size():
		_close()
		finished.emit()
	else:
		_begin_step()

func _close() -> void:
	_active = false
	visible = false

func _process(delta: float) -> void:
	if not _active:
		return
	var s := _step()
	match s.type:
		"timing":
			_t += delta * 0.9
			_bar.queue_redraw()
		"hold":
			if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE):
				_t += delta
				_bar.queue_redraw()
				if _t >= float(s.seconds):
					_next_step()

func _marker() -> float:
	return pingpong(_t, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var s := _step()
	var key: Key = event.physical_keycode
	if key == KEY_ESCAPE:
		_close()
		cancelled.emit()
	elif s.type == "timing" and (key == KEY_E or key == KEY_SPACE):
		var m := _marker()
		if m >= ZONE.x and m <= ZONE.y:
			_count += 1
			if _count >= int(s.hits):
				_next_step()
				get_viewport().set_input_as_handled()
				return
		else:
			missed.emit()
		_update_info()
	elif s.type == "sequence" and key >= KEY_1 and key <= KEY_9:
		var want: String = s.keys[_count]
		if str(key - KEY_0) == want:
			_count += 1
			if _count >= s.keys.size():
				_next_step()
				get_viewport().set_input_as_handled()
				return
		else:
			_count = 0      # wrong wire: start this connection again
			missed.emit()
		_update_info()
	get_viewport().set_input_as_handled()

func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 0, w, h), Color(0.18, 0.19, 0.22))
	if not _active:
		return
	var s := _step()
	match s.type:
		"timing":
			_bar.draw_rect(Rect2(w * ZONE.x, 0, w * (ZONE.y - ZONE.x), h), Color(0.25, 0.65, 0.3))
			_bar.draw_rect(Rect2(w * _marker() - 3, -3, 6, h + 6), Color(1, 0.92, 0.5))
		"hold":
			_bar.draw_rect(Rect2(0, 0, w * clampf(_t / float(s.seconds), 0, 1), h), Color(0.3, 0.55, 0.85))
		"sequence":
			_bar.draw_rect(Rect2(0, 0, w * float(_count) / s.keys.size(), h), Color(0.75, 0.6, 0.25))
