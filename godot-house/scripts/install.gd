class_name Install
extends Node3D
## The install view: the camera moves in on the job, the tool bag opens as a tray at the bottom of the
## screen, and the work happens on glowing hotspots in the scene. Pick the right tool (click it or press
## its number), then click each hotspot; on held steps keep the mouse button (or E) down on the hotspot.
## Every action plays the brother's work clip with the tool in his hand, and the piece appears in the
## house (Worksite). The wrong tool or the wrong order is a mistake; a hammer where none is needed, or a
## wrong wire, is also loud (`mistake` carries the noise for the residents to hear).
##
## Step dictionaries (Day1): {tool, text, kind = "spots" | "hold" | "order", seconds (hold)}.

signal finished(job: Job)
signal cancelled(job: Job)
signal mistake(at: Vector3, loud: bool, what: String)
signal changed                             # step, progress, selection or message changed (redraw the HUD)

const PICK_PX := 34.0                      # how close the mouse must be to a hotspot, in pixels
const ACTION_SECONDS := 0.75               # one hotspot: the clip plays, then the piece appears
const VIEW := Vector2(45, -45)             # default view angles (yaw, pitch in degrees) for a step
const CLOSEST := 6.5                       # the camera never comes nearer than this to the work

## Everything in the tool bag, in tray order: id -> display name.
const EQUIPMENT := {
	"tape": "Tape measure", "knife": "Utility knife", "drill": "Drill", "hammer": "Hammer",
	"screwdriver": "Screwdriver", "stripper": "Wire stripper", "taping": "Tape + knife", "mud": "Joint mud",
	"mallet": "Mallet", "wrench": "Wrench", "allen": "Allen key", "level": "Spirit level",
	"sheet": "Drywall sheet", "planks": "Laminate", "underlay": "Underlay", "plate": "Socket cover",
}

var job: Job
var step := 0
var tray: Array[String] = []
var selected := ""
var message := ""
var message_bad := false
var show_tool := false                     # after a wrong pick, the tray points at the right tool
var hover := -1
var worker: Actor
var helper: Actor                          # holds the sheet on two-person jobs
var worksite: Worksite
var cam: IsoCamera
var safe_rect: Callable                    # -> Rect2: the screen the HUD leaves free for the hotspots
var people: Array = []                     # everyone in the house: faded out while in front of the work

var _spots: Array = []
var _done: Array[bool] = []
var _order_next := 0
var _hold := 0.0
var _acting := 0.0
var _pending := -1
var _markers: Array[MeshInstance3D] = []
var _tags: Array[Label3D] = []
var _active := false
var _mat_idle: StandardMaterial3D
var _mat_hover: StandardMaterial3D
var _mat_done: StandardMaterial3D

func _ready() -> void:
	_mat_idle = _marker_mat(Color(1.0, 0.76, 0.36), 2.2)
	_mat_hover = _marker_mat(Color(1.0, 0.95, 0.75), 4.0)
	_mat_done = _marker_mat(Color(0.47, 0.82, 0.52), 1.2)

func is_active() -> bool:
	return _active

func start(j: Job, w: Actor, h: Actor, ws: Worksite, c: IsoCamera) -> void:
	job = j
	worker = w
	helper = h
	worksite = ws
	cam = c
	tray = _tray_for(j)
	selected = ""
	show_tool = false
	step = 0
	_active = true
	_begin_step()

func current() -> Dictionary:
	return job.steps[step] if _active else {}

func progress() -> Vector2i:
	var n := 0
	for d in _done:
		if d:
			n += 1
	return Vector2i(n, _done.size())

func hold_ratio() -> float:
	var s := current()
	return clampf(_hold / float(s.get("seconds", 1.0)), 0.0, 1.0) if s.get("kind") == "hold" else 0.0

func select(tool: String) -> void:
	if not _active or not tool in tray:
		return
	selected = tool
	message = ""
	worker.hold_tool(tool)
	changed.emit()

## Work on hotspot i with the selected tool (a click, or the self-test).
func use_spot(i: int) -> void:
	if not _active or _acting > 0.0 or i < 0 or i >= _spots.size() or _done[i]:
		return
	var s := current()
	if s.kind == "hold":
		return
	if not _right_tool(s):
		return
	if s.kind == "order" and i != _order_next:
		_say("Wrong order. %s." % s.text, true)
		mistake.emit(_spots[i], true, "a loud pop from the wiring")
		return
	_pending = i
	_acting = ACTION_SECONDS
	worker.face(_spots[i])
	worker.work(Worksite.anim_for(selected, _spots[i].y - worker.global_position.y), selected)
	if helper:
		helper.work("lift", "")

## The self-test and the other brother finish a job without the view.
func auto_solve() -> void:
	worksite.finish(job.id, job.steps)
	_end(true)

func cancel() -> void:
	if _active:
		_end(false)

func _right_tool(s: Dictionary) -> bool:
	if selected == "":
		_say("Pick a tool first: click it in the bag or press its number.", true)
		return false
	if selected != s.tool:
		var loud := selected == "hammer"
		_say("Not the %s for this.%s" % [EQUIPMENT[selected].to_lower(), " And everyone heard that." if loud else ""], true)
		show_tool = true
		mistake.emit(worker.global_position, loud, "a loud bang")
		return false
	return true

func _begin_step() -> void:
	_spots = worksite.spots(job.id, step)
	_done.clear()
	_done.resize(_spots.size())
	_done.fill(false)
	_order_next = 0
	_hold = 0.0
	show_tool = false
	_build_markers()
	message = ""
	changed.emit()
	var s := current()
	if s.has("at"):                        # this step is done somewhere else (the sheet stack)
		var at: Vector3 = s.at
		worker.take_post(Vector3(at.x, at.y + Worksite.FLOOR, at.z), _spots[0])
	elif step > 0 and job.steps[step - 1].has("at"):
		worker.take_post(job.station + Vector3(0, Worksite.FLOOR, 0), _centre(_spots))
	_frame_step()

## Turns the camera to this step's view and backs off just enough to show every hotspot between the
## step card and the tool bag.
func _frame_step() -> void:
	var at_step := step
	await get_tree().process_frame             # the HUD lays out the step card first
	if not _active or step != at_step:
		return
	var v: Vector2 = current().get("view", VIEW)
	var safe: Rect2 = safe_rect.call() if safe_rect.is_valid() else get_viewport().get_visible_rect().grow(-120)
	var fit := cam.fit(_spots, deg_to_rad(v.x), deg_to_rad(v.y), safe, CLOSEST)
	cam.focus_on(fit[0], fit[1], deg_to_rad(v.x), deg_to_rad(v.y))

static func _centre(points: Array) -> Vector3:
	var c := Vector3.ZERO
	for p in points:
		c += p
	return c / maxf(1.0, points.size())

func _say(text: String, bad := false) -> void:
	message = text
	message_bad = bad
	changed.emit()

func _process(delta: float) -> void:
	if not _active:
		return
	var s := current()
	_update_hover()
	if _acting > 0.0:
		_acting -= delta
		if _acting <= 0.0:
			var i := _pending
			_pending = -1
			_done[i] = true
			if s.kind == "order":
				_order_next += 1
			worksite.apply(job.id, step, i)
			worker.work("", selected)
			if helper:
				helper.work("", "")
			_markers[i].material_override = _mat_done
			_after_spot()
	elif s.kind == "hold":
		var holding := (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and hover == 0) or Input.is_physical_key_pressed(KEY_E)
		if holding and _right_tool_quiet(s):
			_hold += delta
			worker.face(_spots[0])
			worker.work(Worksite.anim_for(selected, _spots[0].y - worker.global_position.y), selected)
			worksite.apply(job.id, step, 0, hold_ratio())
			changed.emit()
			if _hold >= float(s.seconds):
				_done[0] = true
				worker.work("", selected)
				_after_spot()
		else:
			worker.work("", selected)
	for k in _markers.size():
		var m := _markers[k]
		if not _done[k]:
			m.material_override = _mat_hover if k == hover else _mat_idle
			var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 180.0 + k)
			m.scale = Vector3.ONE * pulse * (1.35 if k == hover else 1.0)
	for a in people:
		(a as Actor).set_faded(blocks_view(a))

## True if `a` stands between the camera and a hotspot still to do (the play-test checks the same).
func blocks_view(a: Actor) -> bool:
	if not a.visible:
		return false
	var c := cam.camera
	var top := a.global_position + Vector3(0, 1.85 * a.size, 0)
	if c.is_position_behind(a.global_position) or c.is_position_behind(top):
		return false
	var feet := c.unproject_position(a.global_position)
	var head := c.unproject_position(top)
	var half := c.unproject_position(a.global_position + c.global_basis.x * 0.32).distance_to(feet)
	var body := Rect2(feet, Vector2.ZERO).expand(head).grow_individual(half, half * 0.5, half, half * 0.5)
	var depth := c.global_position.distance_to(a.global_position + Vector3(0, 0.9 * a.size, 0))
	for k in _spots.size():
		if not _done[k] and body.has_point(c.unproject_position(_spots[k])) and depth < c.global_position.distance_to(_spots[k]) - 0.15:
			return true
	return false

func _right_tool_quiet(s: Dictionary) -> bool:
	if selected == s.tool:
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_E):
		if message == "":
			_right_tool(s)
	return false

func _after_spot() -> void:
	if _done.all(func(d): return d):
		step += 1
		if step >= job.steps.size():
			_end(true)
		else:
			_begin_step()
	else:
		changed.emit()

func _end(ok: bool) -> void:
	_active = false
	_clear_markers()
	for a in people:
		(a as Actor).set_faded(false)
	worker.work("", "")
	worker.hold_tool("")
	if helper:
		helper.work("", "")
	cam.release()
	changed.emit()
	if ok:
		finished.emit(job)
	else:
		cancelled.emit(job)

func _update_hover() -> void:
	hover = -1
	var mouse := get_viewport().get_mouse_position()
	var best := PICK_PX
	for k in _spots.size():
		if _done[k] or cam.camera.is_position_behind(_spots[k]):
			continue
		var d := cam.camera.unproject_position(_spots[k]).distance_to(mouse)
		if d < best:
			best = d
			hover = k

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key == KEY_ESCAPE:
			cancel()
		elif key >= KEY_1 and key <= KEY_9 and key - KEY_1 < tray.size():
			select(tray[key - KEY_1])
		elif key == KEY_E and current().kind != "hold" and hover >= 0:
			use_spot(hover)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if hover >= 0:
					use_spot(hover)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom(0.88)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom(1.12)
				get_viewport().set_input_as_handled()

## The bag shows what this job needs plus the usual tools, so choosing is part of the work.
func _tray_for(j: Job) -> Array[String]:
	var need: Array[String] = []
	for s in j.steps:
		if not s.tool in need:
			need.append(s.tool)
	var out: Array[String] = []
	for id in EQUIPMENT:
		if id in need or id in ["tape", "drill", "hammer", "screwdriver", "knife"]:
			out.append(id)
	return out.slice(0, 9)

# ---------------------------------------------------------------- hotspot markers

func _marker_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 2
	return m

func _build_markers() -> void:
	_clear_markers()
	var s := current()
	var names := worksite.labels(job.id, step)
	for k in _spots.size():
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := 0.075 if s.kind == "hold" else 0.055
		sphere.radius = r
		sphere.height = r * 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		mi.mesh = sphere
		mi.material_override = _mat_idle
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = _spots[k]
		add_child(mi)
		_markers.append(mi)
		if k < names.size():
			var tag := Label3D.new()
			tag.text = names[k][0]
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.no_depth_test = true
			tag.font_size = 30
			tag.outline_size = 8
			tag.fixed_size = true
			tag.pixel_size = 0.0005
			tag.modulate = names[k][1].lightened(0.3)
			tag.position = _spots[k] + Vector3(0, 0.1, 0)
			add_child(tag)
			_tags.append(tag)

func _clear_markers() -> void:
	for m in _markers:
		m.queue_free()
	for t in _tags:
		t.queue_free()
	_markers.clear()
	_tags.clear()
