class_name Cinematic
extends CanvasLayer
## Cut-scenes: letterbox bars, a camera of its own moved from shot to shot, fades to black, title cards and
## the investigation's check rows. Every move is awaited, so a story reads top to bottom:
##   cine.begin(world, game_camera); await cine.shot(eye, look, 3.0); await cine.fade(1.0, 0.8); cine.finish()
## `fast` (self-tests) makes every move and pause nearly instant.

const BAR := 74.0

var fast := false
var active := false
var camera: Camera3D
var _look := Vector3.ZERO
var _game_cam: Camera3D
var _top: ColorRect
var _bottom: ColorRect
var _black: ColorRect
var _card: VBoxContainer
var _card_title: Label
var _card_lines: Label
var _beats: VBoxContainer
var _beats_panel: PanelContainer

func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)
	_top = _bar(root, true)
	_bottom = _bar(root, false)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_black)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 14)
	_card.custom_minimum_size = Vector2(720, 0)
	center.add_child(_card)
	_card_title = UiTheme.label("", UiTheme.HEADLINE + 8, UiTheme.TEXT)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_title)
	_card_lines = UiTheme.label("", UiTheme.TITLE, UiTheme.MUTED)
	_card_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_card_lines)
	_card.modulate.a = 0.0
	_beats_panel = PanelContainer.new()
	_beats_panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.055, 0.07, 0.9), 12, 18))
	_beats_panel.anchor_left = 1.0
	_beats_panel.anchor_right = 1.0
	_beats_panel.offset_left = -470
	_beats_panel.offset_right = -24
	_beats_panel.offset_top = BAR + 20
	_beats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_beats_panel)
	_beats = VBoxContainer.new()
	_beats.add_theme_constant_override("separation", 10)
	_beats_panel.add_child(_beats)
	_beats_panel.visible = false

func _bar(root: Control, top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.anchor_right = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		r.offset_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
		r.offset_top = 0.0
	root.add_child(r)
	return r

func _t(seconds: float) -> float:
	return 0.02 if fast else seconds

## Takes over the view from `game_cam` (the letterbox bars slide in).
func begin(world: Node3D, game_cam: Camera3D) -> void:
	active = true
	_game_cam = game_cam
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.far = 200.0
	world.add_child(camera)
	camera.global_transform = game_cam.global_transform
	_look = game_cam.global_position - game_cam.global_basis.z * 10.0
	camera.current = true
	var t := create_tween().set_parallel(true)
	t.tween_property(_top, "offset_bottom", BAR, _t(0.6))
	t.tween_property(_bottom, "offset_top", -BAR, _t(0.6))

## Back to the game camera.
func finish() -> void:
	active = false
	var t := create_tween().set_parallel(true)
	t.tween_property(_top, "offset_bottom", 0.0, _t(0.5))
	t.tween_property(_bottom, "offset_top", 0.0, _t(0.5))
	if _game_cam:
		_game_cam.current = true
	if camera:
		camera.queue_free()
		camera = null
	_beats_panel.visible = false

## Moves the camera to look at `look` from `eye` over `seconds` (eased).
func shot(eye: Vector3, look: Vector3, seconds: float) -> void:
	var from_eye := camera.global_position
	var from_look := _look
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(k: float):
		_place(from_eye.lerp(eye, k), from_look.lerp(look, k)), 0.0, 1.0, _t(seconds))
	await t.finished

## Jumps straight to a view.
func cut(eye: Vector3, look: Vector3) -> void:
	_place(eye, look)

func _place(eye: Vector3, look: Vector3) -> void:
	if camera == null:
		return
	_look = look
	camera.global_position = eye
	if eye.distance_to(look) > 0.01:
		camera.look_at(look, Vector3.UP)

func wait(seconds: float) -> void:
	await get_tree().create_timer(_t(seconds), false).timeout

## Fades the screen to black (`to` 1) or back (`to` 0).
func fade(to: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_black, "color:a", to, _t(seconds))
	await t.finished

func is_black() -> bool:
	return _black.color.a > 0.5

## A centred title card (over black, or over the scene) for `seconds`.
func card(title: String, lines: String, seconds: float) -> void:
	_card_title.text = title
	_card_lines.text = lines
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, _t(0.6))
	t.tween_interval(_t(seconds))
	t.tween_property(_card, "modulate:a", 0.0, _t(0.6))
	await t.finished

## One investigation check as a row on the right: name, PASS / FAIL and the detective's reasons.
func beat(name: String, ok: bool, major: bool, lines: Array) -> void:
	_beats_panel.visible = true
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var n := UiTheme.label(name, UiTheme.TITLE)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var verdict := "PASS" if ok else ("FAIL" if major else "DOUBT")
	head.add_child(UiTheme.label(verdict, UiTheme.TITLE, UiTheme.OK if ok else (UiTheme.DANGER if major else UiTheme.ACCENT)))
	row.add_child(head)
	for l in lines:
		var t := UiTheme.label(l, UiTheme.CAPTION + 1, UiTheme.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 400
		row.add_child(t)
	row.modulate.a = 0.0
	_beats.add_child(row)
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, _t(0.5))
	await tw.finished

func clear_beats() -> void:
	for c in _beats.get_children():
		c.queue_free()
	_beats_panel.visible = false
