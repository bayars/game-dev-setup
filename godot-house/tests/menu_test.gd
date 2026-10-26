extends SceneTree
## The title screen with the mouse: every button is the control under the pointer at its centre (nothing
## invisible on top), a click on the content warning's button closes it, and a click on Options opens
## the options panel. Prints MENU_OK, or MENU_FAIL with the reasons.
##   godot --headless --path godot-house -s res://tests/menu_test.gd

var menu: Node
var fails: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	get_root().size = Vector2i(1280, 720)      # the headless window is 64x64: clicks would land outside it
	menu =load("res://scenes/menu.tscn").instantiate()
	get_root().add_child(menu)
	await _frames(3)
	var warning: Control = menu._warning
	if not warning.visible:                    # seen before on this machine: show it again for the test
		menu._show_warning()
		await _frames(2)
	await _click(_button_named("I understand"))
	if warning.visible:
		fails.append("a click on 'I understand' did not close the content warning")
		menu._accept_warning()
		await _frames(2)
	for b in _buttons():
		if b.is_visible_in_tree():
			await _hover(b)
			var under := get_root().gui_get_hovered_control()
			if under != b:
				fails.append("'%s' is covered by %s" % [b.text, under.get_path() if under else "nothing"])
	var options: Control = menu._options
	await _click(_button_named("Options"))
	if not options.visible:
		fails.append("a click on Options did not open the options panel")
	if fails.is_empty():
		print("MENU_OK")
	else:
		print("MENU_FAIL ", " | ".join(fails))
	quit(0 if fails.is_empty() else 1)

func _buttons() -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	for n in menu.find_children("*", "BaseButton", true, false):
		out.append(n)
	return out

func _button_named(prefix: String) -> BaseButton:
	for b in _buttons():
		if b.text.begins_with(prefix):
			return b
	fails.append("no button '%s'" % prefix)
	return null

func _hover(b: Control) -> void:
	var m := InputEventMouseMotion.new()
	m.position = b.get_global_rect().get_center()
	m.global_position = m.position
	get_root().push_input(m)
	await _frames(2)

func _click(b: Control) -> void:
	if b == null:
		return
	await _hover(b)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = b.get_global_rect().get_center()
		e.global_position = e.position
		get_root().push_input(e)
		await _frames(1)
	await _frames(2)

func _frames(n: int) -> void:
	for i in n:
		await process_frame
