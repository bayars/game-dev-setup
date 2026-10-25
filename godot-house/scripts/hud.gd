class_name Hud
extends CanvasLayer
## Everything on screen over the house, in one consistent style (UiTheme):
##   top left    status pill (clock, room, cash) and today's job list (J folds it)
##   top right   the two brothers: who you play, what the other one is doing, his orders
##   top centre  short tips (toasts)
##   bottom      the one action you can take now, as a key cap and a verb; dialogue above it
##   install     the step card (top centre) and the tool bag (bottom) while working on a job
## Controls are listed on F1 instead of always on screen.

signal send_job(job: Job)
signal switch_brother
signal toggle_follow
signal call_brother
signal tool_picked(id: String)
signal restart
signal quit
signal chosen(index: int)
signal order(what: String)                 # day 2 orders to the other brother: "keep_busy", "tidy"
signal end_action(key: String)             # a key on the ending card

const ICONS := "res://assets/icons/%s.png"

var _clock: Label
var _room: Label
var _cash: Label
var _jobs_panel: PanelContainer
var _jobs_box: VBoxContainer
var _jobs_count: Label
var _jobs_open := true
var _cards := {}                        # brother name -> {panel, role}
var _orders: HBoxContainer
var _follow_btn: Button
var _prompt: PanelContainer
var _prompt_key: PanelContainer
var _prompt_text: Label
var _toast: PanelContainer
var _toast_text: Label
var _toast_tween: Tween
var _help: PanelContainer
var _end: PanelContainer
var _pause: PanelContainer
var _choice: PanelContainer
var _choice_title: Label
var _choice_box: VBoxContainer
var _choice_count := 0
var _prompt2: HBoxContainer
var _stress: ProgressBar
var _cover_orders: Array[Button] = []
var _end_keys: Array = []
var _end_body: VBoxContainer
var _step_card: PanelContainer
var _step_title: Label
var _step_dots: HBoxContainer
var _step_text: Label
var _step_progress: ProgressBar
var _step_msg: Label
var _step_hint: Label
var _installing := false
var _tray: PanelContainer
var _tray_box: HBoxContainer
var _tray_ids: Array = []
var _root: Control
var _brothers: Control
var _extra_panels: Array = []          # added from outside (the dialogue)

func _ready() -> void:
	layer = 5                                  # above the cut-scene bars: dialogue, choices and cards stay readable
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)
	_build_status()
	_build_jobs()
	_build_brothers()
	_build_prompt()
	_build_toast()
	_build_help()
	_build_install()
	_build_end()
	_build_pause()
	_build_choice()
	for pair in [[_jobs_panel, "Jobs"], [_prompt, "Prompt"], [_toast, "Toast"], [_help, "Help"], [_end, "EndCard"],
			[_step_card, "StepCard"], [_tray, "ToolBag"], [_brothers, "Brothers"], [_pause, "Pause"], [_choice, "Choice"]]:
		pair[0].name = pair[1]
	process_mode = Node.PROCESS_MODE_ALWAYS     # the pause menu works while the game is paused

func theme_root() -> Control:
	return _root

# ---------------------------------------------------------------- status and jobs

func _build_status() -> void:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _pill_style())
	pill.position = Vector2(16, 16)
	_root.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	pill.add_child(row)
	_clock = UiTheme.label("08:00", UiTheme.TITLE)
	row.add_child(_clock)
	_room = UiTheme.label("", UiTheme.BODY, UiTheme.MUTED)
	_room.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_room)
	_cash = UiTheme.label("$0", UiTheme.TITLE, UiTheme.OK)
	row.add_child(_cash)

func _pill_style() -> StyleBoxFlat:
	var s := UiTheme.panel(UiTheme.BG, 22, 8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s

func set_status(clock: String, room: String, cash: int) -> void:
	_clock.text = clock
	_room.text = room
	_cash.text = "$%d" % cash

func _build_jobs() -> void:
	_jobs_panel = PanelContainer.new()
	_jobs_panel.position = Vector2(16, 68)
	_jobs_panel.custom_minimum_size = Vector2(360, 0)
	_root.add_child(_jobs_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_jobs_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiTheme.label("Today's jobs", UiTheme.TITLE, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_jobs_count = UiTheme.label("", UiTheme.BODY, UiTheme.MUTED)
	_jobs_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_jobs_count)
	var fold := UiTheme.keycap("J")
	fold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(fold)
	_jobs_box = VBoxContainer.new()
	_jobs_box.add_theme_constant_override("separation", 4)
	v.add_child(_jobs_box)

func toggle_jobs() -> void:
	_jobs_open = not _jobs_open
	_jobs_box.visible = _jobs_open

## Rebuilds the list. `helper` is the brother you can send; `auto` is the job he is doing on his own.
## Open jobs get one line each; jobs that wait on another fold into one "later" line, finished ones into
## one "done" line, so the list stays short.
func set_jobs(jobs: Dictionary, helper: String, auto: Job) -> void:
	for c in _jobs_box.get_children():
		_jobs_box.remove_child(c)
		c.queue_free()
	var done: Array = jobs.values().filter(func(j): return j.done)
	var open: Array = jobs.values().filter(func(j): return not j.done and j.available(jobs))
	var later: Array = jobs.values().filter(func(j): return not j.done and not j.available(jobs))
	_jobs_count.text = "%d / %d" % [done.size(), jobs.size()]
	for job in open:
		_jobs_box.add_child(_job_row(job, helper, auto))
	if not later.is_empty():
		var names := ", ".join(later.map(func(j): return j.title.to_lower()))
		_jobs_box.add_child(_fold_line(UiTheme.MUTED.darkened(0.3), "Later: " + names))
	if not done.is_empty():
		var earned := 0
		for job in done:
			earned += job.pay
		_jobs_box.add_child(_fold_line(UiTheme.OK, "%d done  ·  $%d earned" % [done.size(), earned]))

func _fold_line(dot: Color, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_child(UiTheme.dot(dot, 10))
	row.add_child(pad)
	var l := UiTheme.label(text, UiTheme.CAPTION, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 250
	row.add_child(l)
	return row

func _job_row(job: Job, helper: String, auto: Job) -> Control:
	var row := PanelContainer.new()
	var idle := UiTheme.panel(Color(0, 0, 0, 0), 8, 5)
	var hot := UiTheme.panel(UiTheme.BG_SOFT, 8, 5)
	row.add_theme_stylebox_override("panel", idle)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	h.add_child(UiTheme.dot(UiTheme.ACCENT, 10))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	var title := UiTheme.label(job.title, UiTheme.BODY)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 214
	texts.add_child(title)
	var sub := ""
	if job == auto:
		sub = "%s is on it" % helper
	elif job.needs_two:
		sub = "Needs both of you"
	elif job.carry != null:
		sub = "Heavy: carry it together"
	if sub != "":
		texts.add_child(UiTheme.label(sub, UiTheme.CAPTION, UiTheme.MUTED))
	if job == auto and job.progress > 0.0:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 4)
		bar.value = job.progress * 100.0
		texts.add_child(bar)
	var pay := UiTheme.label("$%d" % job.pay, UiTheme.CAPTION, UiTheme.OK)
	pay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pay)
	if job.carry == null and job != auto:
		var send := Button.new()
		send.text = "Send"
		send.tooltip_text = "%s goes and does it on his own" % helper if job.solo_ok() else "%s goes there to hold it for you" % helper
		send.add_theme_font_size_override("font_size", UiTheme.CAPTION)
		send.add_theme_color_override("font_color", UiTheme.person_color(helper))
		send.focus_mode = Control.FOCUS_NONE
		send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		send.pressed.connect(func(): send_job.emit(job))
		send.modulate.a = 0.55                  # always there, brighter on hover
		h.add_child(send)
		row.mouse_entered.connect(func():
			row.add_theme_stylebox_override("panel", hot)
			send.modulate.a = 1.0)
		row.mouse_exited.connect(func():
			if not row.get_global_rect().has_point(row.get_global_mouse_position()):
				row.add_theme_stylebox_override("panel", idle)
				send.modulate.a = 0.55)
	return row

## Day 2 after the accident the job list becomes the cover-up: `lines` are [colour, text] rows under
## `title`, then the jobs still open (to send `helper` to, so the house keeps sounding like work).
func set_objectives(title: String, lines: Array, open_jobs: Array = [], helper := "", auto: Job = null) -> void:
	for c in _jobs_box.get_children():
		_jobs_box.remove_child(c)
		c.queue_free()
	(_jobs_panel.get_child(0).get_child(0).get_child(0) as Label).text = title
	_jobs_count.text = ""
	for l in lines:
		_jobs_box.add_child(_fold_line(l[0], l[1]))
	for job in open_jobs:
		_jobs_box.add_child(_job_row(job, helper, auto))

# ---------------------------------------------------------------- the brothers

func _build_brothers() -> void:
	var v := VBoxContainer.new()
	v.anchor_left = 1.0
	v.anchor_right = 1.0
	v.offset_left = -300
	v.offset_right = -16
	v.offset_top = 16
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.add_theme_constant_override("separation", 6)
	_root.add_child(v)
	_brothers = v
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(cards)
	for who in ["Nico", "Tomas"]:
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.custom_minimum_size = Vector2(136, 0)
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				switch_brother.emit())
		var h := HBoxContainer.new()
		card.add_child(h)
		h.add_child(UiTheme.dot(UiTheme.person_color(who), 14))
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		h.add_child(t)
		t.add_child(UiTheme.label(who, UiTheme.BODY))
		var role := UiTheme.label("", UiTheme.CAPTION, UiTheme.MUTED)
		role.clip_text = true                  # long orders end in "..." instead of widening the card
		role.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		role.custom_minimum_size.x = 104
		t.add_child(role)
		cards.add_child(card)
		_cards[who] = {"panel": card, "role": role}
	_orders = HBoxContainer.new()
	_orders.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_orders)
	_follow_btn = _order_button("F", "Follow me", func(): toggle_follow.emit())
	_orders.add_child(_follow_btn)
	_orders.add_child(_order_button("H", "Come here", func(): call_brother.emit()))
	var more := HBoxContainer.new()
	more.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(more)
	for o in [["K", "Keep busy", "keep_busy"], ["C", "Tidy", "tidy"]]:
		var b := _order_button(o[0], o[1], func(): order.emit(o[2]))
		b.visible = false
		more.add_child(b)
		_cover_orders.append(b)
	_stress = ProgressBar.new()
	_stress.show_percentage = false
	_stress.custom_minimum_size = Vector2(0, 6)
	_stress.tooltip_text = "Tomas's nerves"
	_stress.visible = false
	v.add_child(_stress)
	var tab := UiTheme.key_hint("Tab", "switch", UiTheme.CAPTION)
	tab.modulate.a = 0.75
	tab.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(tab)

func _order_button(key: String, text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = "%s   %s" % [key, text]
	b.add_theme_font_size_override("font_size", UiTheme.CAPTION)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on)
	return b

func set_brothers(you: String, other: String, other_doing: String, following: bool) -> void:
	for who in _cards:
		var c: Dictionary = _cards[who]
		var mine: bool = who == you
		var s := UiTheme.panel(UiTheme.BG if mine else Color(0.07, 0.08, 0.1, 0.6), UiTheme.RADIUS, 8,
			UiTheme.person_color(who) if mine else Color(0, 0, 0, 0))
		(c.panel as PanelContainer).add_theme_stylebox_override("panel", s)
		(c.role as Label).text = "You" if mine else other_doing
		(c.role as Label).tooltip_text = (c.role as Label).text
	_follow_btn.text = "F   %s" % ("Wait here" if following else "Follow me")
	for b in _orders.get_children() + _cover_orders:
		(b as Button).add_theme_color_override("font_color", UiTheme.person_color(other))

## Day 2 after the accident: the extra orders and Tomas's nerves (`stress` 0..100, < 0 hides the bar).
func set_cover(on: bool, stress := -1.0) -> void:
	for b in _cover_orders:
		b.visible = on
	_stress.visible = stress >= 0.0
	if stress >= 0.0:
		_stress.value = stress
		var fill := UiTheme.panel(UiTheme.OK if stress < 60.0 else (UiTheme.ACCENT if stress < 90.0 else UiTheme.DANGER), 4, 0)
		_stress.add_theme_stylebox_override("fill", fill)

# ---------------------------------------------------------------- prompt, tips, help

func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _pill_style())
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -64
	_prompt.offset_bottom = -24
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_prompt.add_child(h)
	_prompt_key = UiTheme.keycap("E")
	_prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_prompt_key)
	_prompt_text = UiTheme.label("", UiTheme.BODY)
	h.add_child(_prompt_text)
	_prompt2 = UiTheme.key_hint("P", "", UiTheme.BODY)
	_prompt2.add_theme_constant_override("separation", 10)
	h.add_child(_prompt2)
	_prompt2.visible = false
	_prompt.visible = false

## The one thing you can do right now ("" hides it), and optionally a second one (`key2`, `text2`).
func set_prompt(key: String, text: String, key2 := "", text2 := "") -> void:
	_prompt.visible = text != ""
	var second := text2 != ""
	if _prompt2.visible != second or (second and (_prompt2.get_child(1) as Label).text != "   " + text2):
		_prompt2.visible = second
		if second:
			((_prompt2.get_child(0) as PanelContainer).get_child(0) as Label).text = key2
			(_prompt2.get_child(1) as Label).text = "   " + text2
		_center.call_deferred(_prompt)
	if text == "" or (_prompt_text.text == text and (_prompt_key.get_child(0) as Label).text == key):
		return
	(_prompt_key.get_child(0) as Label).text = key
	_prompt_text.text = text
	_center.call_deferred(_prompt)

func _build_toast() -> void:
	_toast = PanelContainer.new()
	var s := UiTheme.panel(UiTheme.BG, UiTheme.RADIUS, 12)
	s.border_width_left = 4
	s.border_color = UiTheme.ACCENT
	_toast.add_theme_stylebox_override("panel", s)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -248                   # clear of the job list on the left
	_toast.offset_right = 248
	_toast.offset_top = 16
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)
	_toast_text = UiTheme.label("", UiTheme.BODY)
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_text.custom_minimum_size.x = 472     # a wrapping label has no width of its own
	_toast.add_child(_toast_text)
	_toast.modulate.a = 0.0

func toast(text: String, seconds := 6.0) -> void:
	if _installing:                          # tips go into the step card instead of over the work
		_step_hint.text = text
		_step_hint.visible = true
		return
	_toast_text.text = text
	_toast.reset_size()
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)

func _build_help() -> void:
	var chip := UiTheme.key_hint("F1", "Controls", UiTheme.CAPTION)
	chip.anchor_top = 1.0
	chip.anchor_bottom = 1.0
	chip.offset_top = -30
	chip.offset_left = 16
	chip.modulate.a = 0.7
	_root.add_child(chip)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_help = PanelContainer.new()
	center.add_child(_help)
	var v := VBoxContainer.new()
	_help.add_child(v)
	v.add_child(UiTheme.label("Controls", UiTheme.TITLE, UiTheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for k in [["Click / WASD", "walk"], ["Shift", "run"], ["E", "use, lift, put down"], ["Tab", "switch brother"],
			["Right click", "send the other one there"], ["F", "he follows / waits"], ["H", "call him over"],
			["J", "fold the job list"], ["Q / R", "turn the view"], ["L / P", "day 2: lift him / his phone"],
				["K / C", "day 2: keep someone busy / tidy"], ["Wheel", "zoom"], ["1-9", "pick a tool"],
			["Esc", "pause / stop working"], ["G", "graphics quality"], ["F1", "this help"]]:
		grid.add_child(UiTheme.key_hint(k[0], k[1]))
	_help.visible = false

func toggle_help() -> void:
	if _end.visible and not _help.visible:     # the end card has its own keys
		return
	_help.visible = not _help.visible
	_jobs_panel.visible = not _help.visible and not _installing and not _end.visible
	if _help.visible:
		_toast.modulate.a = 0.0

func help_visible() -> bool:
	return _help.visible

# ---------------------------------------------------------------- install view

func _build_install() -> void:
	_step_card = PanelContainer.new()
	_step_card.anchor_left = 0.5
	_step_card.anchor_right = 0.5
	_step_card.offset_left = -300
	_step_card.offset_right = 300
	_step_card.offset_top = 16
	_step_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_step_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_step_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_step_card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_step_title = UiTheme.label("", UiTheme.TITLE, UiTheme.ACCENT)
	_step_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_step_title)
	_step_dots = HBoxContainer.new()
	_step_dots.add_theme_constant_override("separation", 5)
	head.add_child(_step_dots)
	_step_text = UiTheme.label("", UiTheme.BODY)
	_step_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_text.custom_minimum_size.x = 560
	v.add_child(_step_text)
	_step_progress = ProgressBar.new()
	_step_progress.show_percentage = false
	_step_progress.custom_minimum_size = Vector2(0, 6)
	v.add_child(_step_progress)
	_step_msg = UiTheme.label("", UiTheme.CAPTION, UiTheme.DANGER)
	_step_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_msg.custom_minimum_size = Vector2(560, 18)   # always there, so the card never jumps
	v.add_child(_step_msg)
	_step_hint = UiTheme.label("", UiTheme.CAPTION, UiTheme.ACCENT)
	_step_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_hint.custom_minimum_size.x = 560
	v.add_child(_step_hint)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 16)
	keys.modulate.a = 0.75
	for k in [["1-9", "tool"], ["Click", "work"], ["Wheel", "zoom"], ["Esc", "stop"]]:
		keys.add_child(UiTheme.key_hint(k[0], k[1], UiTheme.CAPTION))
	v.add_child(keys)

	_tray = PanelContainer.new()
	_tray.anchor_left = 0.5
	_tray.anchor_right = 0.5
	_tray.anchor_top = 1.0
	_tray.anchor_bottom = 1.0
	_tray.offset_top = -136                 # room for key, icon and name; grows upward if taller
	_tray.offset_bottom = -16
	_tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_tray)
	_tray_box = HBoxContainer.new()
	_tray_box.add_theme_constant_override("separation", 8)
	_tray.add_child(_tray_box)
	_step_card.visible = false
	_tray.visible = false

## Redraws the step card and the tool bag from the install state.
func show_install(ins: Install) -> void:
	var on := ins.is_active()
	if on and not _installing:
		_step_hint.visible = false
		_toast.modulate.a = 0.0
	_installing = on
	for c in _extra_panels:                    # the dialogue sits above the tool bag while working
		if c is Dialogue:
			c.offset_top = -176 if on else -84
			c.offset_bottom = c.offset_top
	_step_card.visible = on
	_tray.visible = on
	_jobs_panel.visible = not on
	if not on:
		_tray_ids = []
		return
	var s := ins.current()
	_step_title.text = ins.job.title
	for c in _step_dots.get_children():
		_step_dots.remove_child(c)
		c.queue_free()
	for k in ins.job.steps.size():
		var col := UiTheme.OK if k < ins.step else (UiTheme.ACCENT if k == ins.step else UiTheme.MUTED.darkened(0.4))
		_step_dots.add_child(UiTheme.dot(col, 10))
	_step_text.text = "Step %d of %d:  %s" % [ins.step + 1, ins.job.steps.size(), s.text]
	var p := ins.progress()
	_step_progress.value = (ins.hold_ratio() if s.kind == "hold" else float(p.x) / maxf(1.0, p.y)) * 100.0
	_step_msg.text = ins.message
	_step_msg.add_theme_color_override("font_color", UiTheme.DANGER if ins.message_bad else UiTheme.OK)
	if _tray_ids != ins.tray:
		_tray_ids = ins.tray.duplicate()
		for c in _tray_box.get_children():
			_tray_box.remove_child(c)       # gone now, not at the end of the frame: the loop below counts them
			c.queue_free()
		for k in ins.tray.size():
			_tray_box.add_child(_tool_slot(ins.tray[k], k + 1))
		_center.call_deferred(_tray)
	for k in _tray_box.get_child_count():
		var slot := _tray_box.get_child(k) as PanelContainer
		var id: String = ins.tray[k]
		var border := Color(0, 0, 0, 0)
		if id == ins.selected:
			border = UiTheme.ACCENT
		elif ins.show_tool and id == s.tool:
			border = UiTheme.OK
		slot.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.BG_HOVER if id == ins.selected else UiTheme.BG_SOFT, 8, 6, border))

func _tool_slot(id: String, number: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(84, 0)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = Install.EQUIPMENT[id]
	slot.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			tool_picked.emit(id))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UiTheme.keycap(str(number)))
	var icon := TextureRect.new()
	icon.texture = load(ICONS % id)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(icon)
	var name_l := UiTheme.label(Install.EQUIPMENT[id], UiTheme.CAPTION, UiTheme.MUTED)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	return slot

# ---------------------------------------------------------------- end of the day

func _build_end() -> void:
	var center := CenterContainer.new()       # keeps the card in the middle whatever its size
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_end = PanelContainer.new()
	_end.custom_minimum_size = Vector2(620, 0)
	_end.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.055, 0.07, 0.95), 14, 28))
	center.add_child(_end)
	_end_body = VBoxContainer.new()
	_end_body.add_theme_constant_override("separation", 12)
	_end.add_child(_end_body)
	_end.visible = false

## `seen` is [[who, what], ...]; `actions` is [[key, text], ...].
func show_end(title: String, cash: int, seen: Array, lesson: String, actions: Array) -> void:
	for c in _end_body.get_children():
		c.queue_free()
	_end_body.add_child(UiTheme.label(title, UiTheme.HEADLINE, UiTheme.ACCENT))
	var pay := HBoxContainer.new()
	pay.add_child(UiTheme.label("Cash from Linda", UiTheme.BODY, UiTheme.MUTED))
	pay.add_child(UiTheme.label("$%d" % cash, UiTheme.TITLE, UiTheme.OK))
	_end_body.add_child(pay)
	_end_body.add_child(UiTheme.label("What the family noticed" if not seen.is_empty() else "Nobody noticed anything unusual.", UiTheme.TITLE))
	for e in seen:
		var row := HBoxContainer.new()
		row.add_child(UiTheme.dot(UiTheme.person_color(e[0]), 10))
		var who := UiTheme.label(e[0], UiTheme.BODY, UiTheme.person_color(e[0]))
		who.custom_minimum_size.x = 64
		row.add_child(who)
		var what := UiTheme.label(e[1], UiTheme.BODY)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		_end_body.add_child(row)
	if lesson != "":
		var l := UiTheme.label(lesson, UiTheme.BODY, UiTheme.ACCENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_end_body.add_child(l)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 24)
	for a in actions:
		keys.add_child(UiTheme.key_hint(a[0], a[1]))
	_end_body.add_child(keys)
	_end.visible = true
	_jobs_panel.visible = false

# ---------------------------------------------------------------- choices

func _build_choice() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_choice = PanelContainer.new()
	_choice.custom_minimum_size = Vector2(560, 0)
	_choice.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.055, 0.07, 0.95), 14, 22))
	center.add_child(_choice)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_choice.add_child(v)
	_choice_title = UiTheme.label("", UiTheme.TITLE, UiTheme.ACCENT)
	_choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_title.custom_minimum_size.x = 516
	v.add_child(_choice_title)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	v.add_child(_choice_box)
	_choice.visible = false

## Shows `options` as numbered buttons (keys 1-9) under `title`; returns the index picked.
func choose(title: String, options: Array) -> int:
	_choice_title.text = title
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = "%d    %s" % [i + 1, options[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 516
		b.pressed.connect(func(): chosen.emit(i))
		_choice_box.add_child(b)
	_choice_count = options.size()
	_choice.visible = true
	var picked: int = await chosen
	_choice.visible = false
	return picked

func choosing() -> bool:
	return _choice.visible

# ---------------------------------------------------------------- pause

func _build_pause() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_pause = PanelContainer.new()
	_pause.custom_minimum_size = Vector2(360, 0)
	_pause.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.055, 0.07, 0.96), 14, 24))
	center.add_child(_pause)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_pause.add_child(v)
	v.add_child(UiTheme.label("Paused", UiTheme.HEADLINE, UiTheme.ACCENT))
	for b in [["Esc", "Resume", func(): show_pause(false)],
			["F1", "Controls", func():
				show_pause(false)
				toggle_help()],
			["R", "Restart the day", func():
				show_pause(false)
				restart.emit()],
			["Q", "Main menu", func(): quit.emit()]]:
		var btn := Button.new()
		btn.text = "%s     %s" % [b[0], b[1]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[2])
		v.add_child(btn)
	_pause.visible = false

func show_pause(on: bool) -> void:
	_pause.visible = on
	get_tree().paused = on

func paused() -> bool:
	return _pause.visible

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _choice.visible and not _pause.visible:
		var k: int = event.physical_keycode - KEY_1
		if k >= 0 and k < _choice_count:
			chosen.emit(k)
			get_viewport().set_input_as_handled()
		return
	if _end.visible and not _pause.visible:
		for a in _end_keys:
			if OS.find_keycode_from_string(a) == event.physical_keycode:
				end_action.emit(a)
				get_viewport().set_input_as_handled()
				return
	if not _pause.visible:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			show_pause(false)
		KEY_R:
			show_pause(false)
			restart.emit()
		KEY_Q:
			quit.emit()
		KEY_F1:
			show_pause(false)
			toggle_help()
	get_viewport().set_input_as_handled()

## Centres a centre-anchored control on its content size (growing both ways does not re-centre it).
func _center(c: Control, vertical := false) -> void:
	var m := c.get_combined_minimum_size()
	c.offset_left = -m.x / 2.0
	c.offset_right = m.x / 2.0
	if vertical:
		c.offset_top = -m.y / 2.0
		c.offset_bottom = m.y / 2.0
	c.reset_size()

## The end of day 2: the ending's title and text, the police checks (PASS / DOUBT / FAIL with reasons),
## and the keys to go on. `checks` are Investigation check dictionaries.
func show_ending(title: String, lines: Array, checks: Array, actions: Array) -> void:
	for c in _end_body.get_children():
		c.queue_free()
	_end_body.add_child(UiTheme.label(title, UiTheme.HEADLINE, UiTheme.ACCENT))
	for l in lines:
		var t := UiTheme.label(l, UiTheme.BODY)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 600
		_end_body.add_child(t)
	if not checks.is_empty():
		_end_body.add_child(UiTheme.label("What the police found", UiTheme.TITLE))
		for c in checks:
			var row := HBoxContainer.new()
			var verdict := "PASS" if c.ok else ("FAIL" if c.major else "DOUBT")
			var col := UiTheme.OK if c.ok else (UiTheme.DANGER if c.major else UiTheme.ACCENT)
			var v := UiTheme.label(verdict, UiTheme.CAPTION + 1, col)
			v.custom_minimum_size.x = 56
			row.add_child(v)
			var n := UiTheme.label(c.name, UiTheme.CAPTION + 1)
			n.custom_minimum_size.x = 76
			row.add_child(n)
			var why := UiTheme.label(" ".join(c.lines), UiTheme.CAPTION + 1, UiTheme.MUTED)
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			why.custom_minimum_size.x = 440
			row.add_child(why)
			_end_body.add_child(row)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 24)
	_end_keys = []
	for a in actions:
		keys.add_child(UiTheme.key_hint(a[0], a[1]))
		_end_keys.append(a[0])
	_end_body.add_child(keys)
	_end.visible = true
	_jobs_panel.visible = false
	_prompt.visible = false

func end_visible() -> bool:
	return _end.visible

## Where the install view may put hotspots: under the step card, above the tool bag, clear of the sides.
func install_safe_rect() -> Rect2:
	var vp := _root.get_viewport_rect().size
	var top := _step_card.get_global_rect().end.y + 24
	var bottom := _tray.get_global_rect().position.y - 24 if _tray.size.y > 0 else vp.y - 170
	if top < 120:                              # not laid out yet
		top = 190
	return Rect2(48, top, vp.x - 96, bottom - top)

## The top-level panels showing now (play-test: none may overlap another).
func top_panels() -> Array:
	var out := []
	for c in [_jobs_panel, _prompt, _toast, _help, _end, _step_card, _tray, _brothers, _pause, _choice] + _extra_panels:
		if c != null and c.is_visible_in_tree() and c.modulate.a > 0.05:
			out.append(c)
	var status := _clock.get_parent().get_parent() as Control
	out.append(status)
	return out

## Cut-scenes: only the dialogue, choices and cards stay on screen.
func set_cinematic(on: bool) -> void:
	for c in [_jobs_panel, _brothers, _prompt, _toast, _clock.get_parent().get_parent()]:
		(c as CanvasItem).visible = not on if c != _prompt else false
	for c in _root.get_children():
		if c is HBoxContainer:                 # the F1 chip
			c.visible = not on
	if not on:
		_jobs_panel.visible = not _end.visible

## Screen rectangles of the panels that are showing (the play-test keeps hotspots out from under them).
func blocking_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c in _root.find_children("*", "PanelContainer", true, false):
		var p := c as PanelContainer
		if p.is_visible_in_tree() and p.modulate.a > 0.05:
			out.append(p.get_global_rect())
	return out

## Puts a control (the dialogue) under the HUD theme.
func add_ui(c: Control) -> void:
	_root.add_child(c)
	_extra_panels.append(c)
