extends SceneTree
## The title screen with the mouse, for each point in the story: a new player sees only Play (day 1),
## after day 1 Continue (day 2), and once day 2 has been played both days. In each, every button is the
## control under the pointer at its centre (nothing invisible on top), a click on the content warning's
## button closes it, Options opens the options panel, and the first button starts the right day.
## Prints MENU_OK, or MENU_FAIL with the reasons. The real save is not read or written.
##   godot --headless --path godot-house -s res://tests/menu_test.gd

const STATES := [
	# [name, day 1 done, day 2 played, the story buttons, the day the first one starts]
	["new player", false, false, ["Play"], 1],
	["after day 1", true, false, ["Continue: day 2"], 2],
	["after day 2", true, true, ["Day 1: The first job", "Day 2: Daniel's room"], 1],
]
const ALWAYS := ["Options", "Quit"]

var menu: Node
var fails: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	get_root().size = Vector2i(1280, 720)      # the headless window is 64x64: clicks would land outside it
	Game.load_save()                           # read once now, so the menu won't overwrite the flags below
	for s in STATES:
		Game.day2_unlocked = s[1]
		Game.day2_done = s[2]
		await _check(s[0], s[3], s[4])
	if fails.is_empty():
		print("MENU_OK")
	else:
		print("MENU_FAIL ", " | ".join(fails))
	quit(0 if fails.is_empty() else 1)

func _check(state: String, story: Array, day: int) -> void:
	menu = load("res://scenes/menu.tscn").instantiate()
	get_root().add_child(menu)
	await _frames(3)
	var warning: Control = menu._warning
	if not warning.visible:                    # seen before on this machine: show it again for the test
		menu._show_warning()
		await _frames(2)
	await _click(_button_named(state, "I understand"))
	if warning.visible:
		fails.append("%s: a click on 'I understand' did not close the content warning" % state)
		menu._accept_warning()
		await _frames(2)
	var first: BaseButton = menu._first
	if first.text != story[0] or not first.has_focus():
		fails.append("%s: the first button '%s' should be '%s' and focused after the warning" % [state, first.text, story[0]])
	var shown: Array = []
	for b in _buttons():
		if b.is_visible_in_tree() and not b is CheckButton:
			shown.append(b.text)
			await _hover(b)
			var under := get_root().gui_get_hovered_control()
			if under != b:
				fails.append("%s: '%s' is covered by %s" % [state, b.text, under.get_path() if under else "nothing"])
	if shown.filter(func(t): return not t.begins_with("Graphics")) != story + ALWAYS:
		fails.append("%s: buttons %s, expected %s" % [state, shown, story + ALWAYS])
	var options: Control = menu._options
	await _click(_button_named(state, "Options"))
	if not options.visible:
		fails.append("%s: a click on Options did not open the options panel" % state)
	var starts: Array = menu.story_buttons().map(func(x): return x[1])
	if starts[0] != day:
		fails.append("%s: the first button starts day %d, expected day %d" % [state, starts[0], day])
	menu.queue_free()
	await _frames(2)

func _buttons() -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	for n in menu.find_children("*", "BaseButton", true, false):
		out.append(n)
	return out

func _button_named(state: String, prefix: String) -> BaseButton:
	for b in _buttons():
		if b.text.begins_with(prefix):
			return b
	fails.append("%s: no button '%s'" % [state, prefix])
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
