class_name Coverup
extends Node
## Day 2 after the accident, until someone finds Daniel. Everything the player can do and everything the
## house notices, as game rules:
##   the body      lift him together (fast, quiet) or drag him alone (slow, loud, drag marks every few m)
##   signs         the accident's own pieces and marks (Token): tidy them away, take the nail gun
##   staging       set him down in a stage scenario's area, then do its few setup steps
##   the house     residents search room by room (Npc SEARCH), check noises, notice signs, call his phone
##   Tomas         keep a searcher busy, tidy a sign, keep working (the work alibi); his nerves (stress)
##   talking       tell a searcher where Daniel went: it sends them elsewhere, and the police will compare
## `report()` hands it all to the Investigation once he is found.

signal found(by: Npc, caught: bool)

const ACCIDENT_ROOM := "Daniel's room"
const DRAG_MARK_EVERY := 1.6               # metres of dragging between two marks
const SEE_BODY := 7.5                      # how far a resident sees him (line of sight, same floor)
const SEE_SIGN := 4.5
const CONE := 65.0                         # half angle of a walking resident's view, degrees
const TALK_SECONDS := 40.0                 # a searcher kept busy stays this long
const NEAR := 1.6
const POLICE_AFTER := 180.0                # game minutes after the accident: Linda calls the police

## When each resident starts searching (game minutes after the accident) and where they look, in order.
const SEARCH := {
	"Linda": [10.0, ["Work room", "Garage", "Outside", "pause:60:phone", "Daniel's room", "Sofia's room",
		"Upstairs bathroom", "pause:45:phone", "Storage", "Parents' room", "Landing", "Stairs", "Hallway",
		"Bathroom", "Rose's room", "pause:60:phone"]],
	"Sofia": [30.0, ["Sofia's room", "pause:45:phone", "Daniel's room", "Upstairs bathroom", "Storage",
		"Landing", "pause:60:phone", "Parents' room", "Garage", "Outside", "Work room"]],
	"Rose": [25.0, ["Rose's room", "pause:60:sit", "Bathroom", "Hallway", "pause:60:sit", "Stairs", "Work room",
		"Garage", "pause:60:sit"]],
	"Robert": [60.0, ["Garage", "Outside", "pause:40:phone", "Work room", "Stairs", "Daniel's room", "Storage",
		"Upstairs bathroom", "Bathroom", "Landing"]],
}

const BUSY_LINES := [
	"Have you tried his friends? The boy from the bike shop, maybe?",
	"He said something about the park this morning. I think.",
	"Sit down a moment. He'll turn up, boys do.",
	"Do you want me to check the garage for you?",
]

var main: Node3D
var story: Node
var case: AccidentCase
var body: BodyLoad
var tokens: Array[Token] = []
var scenarios: Array[StageScenario] = []
var staged: StageScenario = null           # the scenario whose area he lies in (set down)
var setup_done := {}                       # scenario id -> [setup ids]
var statements: Array = []                 # [who, place, minute]
var heard_accident: Array = []
var heard_drag: Array = []
var tokens_seen: Array = []
var phone_off := -1.0
var items := {}                            # Actor -> item id in their hands ("nailgun")
var stress := 35.0                         # Tomas
var t0 := 0.0                              # the accident's clock minute
var active := false
var caught_by: Array = []                  # [who, minute, room]
var found_by := ""
var _work_minutes := 0
var _minutes := 0
var _last_minute := -1
var _last_work := 100.0                    # seconds since the last work sound
var _rings: Array[Node3D] = []
var _setup_marks: Array = []               # [{spec, node}]
var _actions := {}                         # Actor -> {left, total, text, done: Callable}
var _drag_last := Vector3.INF
var _sight := 0.0
var _hud := 0.0
var _task := {}                            # the other brother's order: {kind, who, target, phase}
var _started := {}                         # resident name -> started searching
var _robert_back := false
var _police := false
var _props := {}                           # staging props by setup id (basket, ladder, ...)

func setup(m: Node3D, s: Node, c: AccidentCase) -> void:
	main = m
	story = s
	case = c
	scenarios = Day2.scenarios()
	main.noise_made.connect(_on_noise)
	for r in main.residents:
		(r as Npc).paused.connect(_on_pause.bind(r))
	_place_props()

## The props the scenarios use, in their everyday places from the morning on.
func _place_props() -> void:
	var h: House = main.house
	_props["basket"] = h.prop("LaundryBasket", Vector3(9.4, House.UP, 11.6), 0, false)
	var ladder := h.prop("Ladder", Vector3.ZERO, 0, false, main)
	var lean := 0.22
	ladder.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(-sin(lean), cos(lean), 0), Vector3(-cos(lean), -sin(lean), 0)),
		Vector3(0.12 + 2.6 * sin(lean), 0.04, 11.2))
	_props["ladder"] = ladder
	h.prop("Compressor", Vector3(15.2, House.UP, 7.3), -90, false)

## The accident has happened: Daniel lies at `at`; the signs appear around him and the house starts to
## notice. `minute` is the clock at the accident.
func begin(minute: float, daniel: Actor) -> void:
	t0 = minute
	_last_minute = int(minute)
	body = BodyLoad.new()
	main.add_child(body)
	body.setup_body(daniel)
	var at := body.where()
	var floor_y := House.UP if House.level_of(at) == 1 else 0.0
	for spec in case.tokens:
		var p: Vector3 = at + spec.get("offset", Vector3.ZERO)
		var t := Token.make(spec, Vector3(p.x, floor_y + 0.01, p.z), main)
		if spec.get("main", false):
			t.linked = main.site.piece(case.what) if main.site.has_method("piece") else null
			if t.linked:
				var lp := t.linked.global_position
				var toward := Vector3(at.x - lp.x, 0, at.z - lp.z).normalized()   # by the piece, not on him
				t.global_position = Vector3(lp.x, floor_y + 0.01, lp.z) + toward * 0.35
		tokens.append(t)
	for sc in scenarios:
		_rings.append(_ring(sc.mark, Color(0.45, 0.7, 1.0, 0.5), 0.9, sc.title))
	_set_rings(true)
	active = true

func _set_rings(on: bool) -> void:
	for r in _rings:
		r.visible = on

func _ring(at: Vector3, col: Color, radius: float, text: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.06
	torus.outer_radius = radius
	torus.rings = 48
	mi.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale.y = 0.1
	root.add_child(mi)
	if text != "":
		var l := Label3D.new()
		l.text = text
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 26
		l.outline_size = 8
		l.fixed_size = true
		l.pixel_size = 0.0004
		l.modulate = col.lightened(0.4)
		l.modulate.a = 0.9
		l.position.y = 0.35
		root.add_child(l)
	main.add_child(root)
	root.global_position = at + Vector3(0, 0.03, 0)
	return root

# ---------------------------------------------------------------- every frame

func tick(delta: float) -> void:
	if not active:
		return
	var minute: float = main.minute
	_schedule(minute)
	_last_work = 0.0 if _working() else _last_work + delta
	while _last_minute < int(minute):          # the work alibi, minute by minute
		_last_minute += 1
		_minutes += 1
		if _last_work < 15.0:                  # a work sound in the last 15 s (three game minutes)
			_work_minutes += 1
	_update_actions(delta)
	_update_task(delta)
	_update_drag()
	_update_stress(delta)
	_sight -= delta
	if _sight <= 0.0:
		_sight = 0.15
		_look()
	_hud -= delta
	if _hud <= 0.0:
		_hud = 0.25
		_show()

## Searches begin, Robert comes home, Linda finally calls the police.
func _schedule(minute: float) -> void:
	for r in main.residents:
		var n: Npc = r
		if not SEARCH.has(n.display_name) or _started.has(n.display_name):
			continue
		if n.display_name == "Robert" and not _robert_back:
			if minute >= t0 + SEARCH.Robert[0]:
				_robert_back = true
				n.set_away(false)
				n.global_position = Vector3(10.0, 0.05, 15.5)
				main._dialogue.bark("Robert", "I'm back! ...Linda? What's going on?", 3.0)
			continue
		if minute >= t0 + SEARCH[n.display_name][0]:
			_started[n.display_name] = true
			n.search(SEARCH[n.display_name][1])
			if n.display_name == "Linda":
				main._dialogue.bark("Linda", "Daniel? Daniel! Lunch is ready! ...Has anyone seen Daniel?", 3.5)
	if not _police and minute >= t0 + POLICE_AFTER:
		_police = true
		main._dialogue.bark("Linda", "That's it. I'm calling the police. Something has happened to him.", 4.0)
	if _police and minute >= t0 + POLICE_AFTER + 10.0 and found_by == "":
		found_by = "the police"
		found.emit(null, false)

func _working() -> bool:
	var ins: Install = main.install
	if ins.is_active() and (ins._acting > 0.0 or ins.hold_ratio() > 0.0):
		return true
	var job: Job = main._auto_job
	if job != null:
		var w: Actor = main._auto_worker()
		return not w.is_going() and w.global_position.distance_to(job.station) < 1.5
	return false

# ---------------------------------------------------------------- what the player can do here

## The prompt for `a` here: [key, text, key2, text2], or [] when the cover-up has nothing to offer.
func prompt(a: Actor) -> Array:
	if not active:
		return []
	if _actions.has(a):
		var act: Dictionary = _actions[a]
		return ["…", "%s  %d%%" % [act.text, int(100.0 * (1.0 - act.left / act.total))]]
	if main._carry == body:
		var sc := _scenario_at(body.global_position + Vector3(0, 0.3, 0))
		return ["E", "Put him down here" + ("  (%s)" % sc.title if sc else "")]
	if main._carry != null:
		return []
	var t := _target(a)
	var out: Array = []
	match t.get("kind", ""):
		"body":
			out = ["E", _lift_text()]
			if phone_off < 0.0:
				out += ["P", "Switch off his phone"]
			return out
		"token":
			out = ["E", (t.token as Token).verb()]
		"setup":
			var spec: Dictionary = t.mark.spec
			if spec.needs != "" and items.get(a, "") != spec.needs:
				out = ["E", "%s  (bring the %s)" % [spec.text, String(spec.needs).replace("nailgun", "nail gun")]]
			else:
				out = ["E", spec.text]
		"resident":
			out = ["E", "Talk to %s" % (t.npc as Npc).display_name]
	if _near_body(a):                          # something else is nearer: L still lifts him
		out += ["L", "Lift him" if main._pair_ready() else "Drag him"]
	return out

func _lift_text() -> String:
	if main._pair_ready():
		return "Lift him together"
	return "Drag him alone  (slow, loud, leaves marks;  H calls %s)" % main.other().display_name

## L near him: lift (or drag) him whatever else is close by.
func lift(a: Actor) -> bool:
	if not active or _actions.has(a) or main._carry != null or not _near_body(a):
		return false
	main.pick_up(body)
	_drag_last = body.global_position
	return true

## The nearest thing `a` can use: {kind: body | token | setup | resident, ...} or {}.
func _target(a: Actor) -> Dictionary:
	var best := {}
	var bd := INF
	if _near_body(a):
		var p := body.where()
		# he is big and near everything at the scene: smaller things win unless he is clearly closer
		bd = Vector2(p.x - a.global_position.x, p.z - a.global_position.z).length()
		if bd > 0.9:                           # right next to him, he wins
			bd += 0.6
		best = {"kind": "body"}
	var t := _near_token(a)
	if t and t.global_position.distance_to(a.global_position) < bd:
		bd = t.global_position.distance_to(a.global_position)
		best = {"kind": "token", "token": t}
	var mark := _near_setup(a)
	if not mark.is_empty() and (mark.spec.at as Vector3).distance_to(a.global_position) < bd:
		bd = (mark.spec.at as Vector3).distance_to(a.global_position)
		best = {"kind": "setup", "mark": mark}
	var r := _near_resident(a)
	if r and r.global_position.distance_to(a.global_position) < bd:
		best = {"kind": "resident", "npc": r}
	return best

## E pressed by `a`. True if the cover-up used it.
func interact(a: Actor) -> bool:
	if not active or _actions.has(a) or main._carry != null:
		return false
	var target := _target(a)
	match target.get("kind", ""):
		"body":
			main.pick_up(body)
			_drag_last = body.global_position
			return true
		"token":
			var t: Token = target.token
			_act(a, t.seconds, t.verb(), _take.bind(t, a), t.global_position)
			return true
		"setup":
			var mark: Dictionary = target.mark
			var spec: Dictionary = mark.spec
			if spec.needs != "" and items.get(a, "") != spec.needs:
				main._dialogue.bark(a.display_name, "I need the %s for that." % String(spec.needs).replace("nailgun", "nail gun"), 2.0)
				return true
			_act(a, float(spec.seconds), spec.text, _set_up.bind(mark, a), spec.at)
			return true
		"resident":
			_talk(a, target.npc)
			return true
	return false

## P near him: switch his phone off (it stops ringing; the police will see when).
func phone(a: Actor) -> bool:
	if not active or phone_off >= 0.0 or main._carry != null or not _near_body(a):
		return false
	phone_off = main.minute
	main._dialogue.bark(a.display_name, "(switches his phone off)", 1.5)
	return true

func _near_body(a: Actor) -> bool:
	if body == null or body.is_carried():
		return false
	var p := body.where()
	return absf(p.y - a.global_position.y) < 1.2 and Vector2(p.x - a.global_position.x, p.z - a.global_position.z).length() < NEAR

func _near_token(a: Actor) -> Token:
	var best: Token = null
	var bd := 1.5
	for t in tokens:
		var d := t.global_position.distance_to(a.global_position)
		if d < bd and absf(t.global_position.y - a.global_position.y) < 1.0:
			bd = d
			best = t
	return best

func _near_setup(a: Actor) -> Dictionary:
	var best := {}
	var bd := 1.3
	for m in _setup_marks:
		var d := (m.spec.at as Vector3).distance_to(a.global_position)
		if d < bd:
			bd = d
			best = m
	return best

func _near_resident(a: Actor) -> Npc:
	for r in main.residents:
		var n: Npc = r
		if n.limp or not n.visible or n.mode in [Npc.Mode.AWAY, Npc.Mode.GATHER]:
			continue
		if n.global_position.distance_to(a.global_position) < 1.8:
			return n
	return null

## A timed action (tidying, setting up): the brother kneels for `seconds`, then `done` runs.
func _act(a: Actor, seconds: float, text: String, done: Callable, at: Vector3) -> void:
	a.busy = true
	a.stop()
	a.face(at)
	a.work("kneel", items.get(a, ""))
	_actions[a] = {"left": seconds, "total": seconds, "text": text, "done": done}

func _update_actions(delta: float) -> void:
	for a in _actions.keys():
		var act: Dictionary = _actions[a]
		act.left -= delta
		if act.left <= 0.0:
			_actions.erase(a)
			a.busy = false
			a.work("", items.get(a, ""))
			act.done.call()

func _take(t: Token, a: Actor) -> void:
	if not t in tokens:
		return
	tokens.erase(t)
	if t.item != "":
		items[a] = t.item
		a.hold_tool(t.item)
	elif t.linked:
		if t.id == "stud":                     # back where it stood
			var i := 0
			var site: Worksite2 = main.site
			t.linked.global_transform = Transform3D(Basis.from_euler(Vector3(0, PI / 2, 0)), Vector3(Worksite2.X2, House.UP + 0.045, Worksite2.Z2 + i * Worksite2.GAP2))
			site.house.rebake()
		else:
			t.linked.visible = false
	t.queue_free()

func _set_up(mark: Dictionary, a: Actor) -> void:
	var spec: Dictionary = mark.spec
	var sc: StageScenario = mark.scenario
	if spec.needs != "":
		items.erase(a)
		a.hold_tool("")
	if not setup_done.has(sc.id):
		setup_done[sc.id] = []
	setup_done[sc.id].append(spec.id)
	_stage_prop(spec.id, spec.at, sc)
	(mark.node as Node3D).queue_free()
	_setup_marks.erase(mark)

## What setting up a scenario changes in the scene.
func _stage_prop(id: String, at: Vector3, sc: StageScenario) -> void:
	var h: House = main.house
	match id:
		"basket":
			(_props["basket"] as Node3D).visible = false
			h.prop("LaundrySpill", Vector3(11.35, House.UP - 0.08, 11.35), 90, false, main)
		"ladder":
			var l: Node3D = _props["ladder"]
			l.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3(0.6, 0.08, 10.3))
		"box":
			var b := h.prop("StorageBox", Vector3(1.1, 0.04, 8.3), 37, false, main)
			b.rotation.z = 0.4
		"nailgun":
			var tools := Actor.TOOLS.instantiate()
			var src := tools.get_node_or_null("T_nailgun") as Node3D
			if src:
				var g := src.duplicate() as Node3D
				main.add_child(g)
				g.global_position = at + Vector3(0.25, 0.06 if sc.id != "garage_nailgun" else 0.95, -0.2)
				g.rotation = Vector3(PI / 2, 0.4, 0)
			tools.free()
		"plank", "offcuts":
			var o := h.prop("Offcuts", at + Vector3(0, 0.0 if id == "plank" else 0.91, -0.45 if id == "offcuts" else -0.2), 20, false, main)
			o.name = "Offcuts"
		"water":
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.55
			cyl.height = 0.004
			w.mesh = cyl
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.55, 0.65, 0.75, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.02
			m.metallic = 0.3
			w.material_override = m
			main.add_child(w)
			w.global_position = Vector3(13.5, House.UP + 0.004, 1.7)
			w.scale = Vector3(1.4, 1, 1)
		"towel":
			h.prop("Towel", Vector3(12.4, House.UP, 1.3), 30, false, main)

# ---------------------------------------------------------------- carrying him

## Main hands over carry events: lifting, putting down.
func carry_started(c: Carryable) -> void:
	if c != body:
		return
	for m in _setup_marks:
		(m.node as Node3D).queue_free()
	_setup_marks.clear()
	staged = null

func carry_ended(c: Carryable) -> void:
	if c != body:
		return
	_drag_last = Vector3.INF
	await get_tree().create_timer(0.6).timeout   # let him settle first
	var sc := _scenario_at(body.where())
	staged = sc
	if sc:
		var done: Array = setup_done.get(sc.id, [])
		for spec in sc.setup:
			if not spec.id in done:
				_setup_marks.append({"spec": spec, "scenario": sc, "node": _ring(spec.at, Color(1.0, 0.76, 0.36, 0.6), 0.45, "")})
		main.hud.toast("Here it could pass for this: %s. %s" % [sc.title, "Set up the marked spots." if not sc.setup.is_empty() else ""], 5.0)

func _scenario_at(p: Vector3) -> StageScenario:
	for sc in scenarios:
		if House.level_of(p + Vector3(0, 0.3, 0)) == sc.level and sc.area.has_point(Vector2(p.x, p.z)):
			return sc
	return null

## Dragging alone leaves marks on the floor every DRAG_MARK_EVERY metres.
func _update_drag() -> void:
	if main._carry != body or body.carriers.size() != 1:
		return
	var p := body.global_position
	if _drag_last == Vector3.INF:
		_drag_last = p
		return
	if Vector2(p.x - _drag_last.x, p.z - _drag_last.z).length() >= DRAG_MARK_EVERY:
		var floor_y: float = body.carriers[0].global_position.y
		var t := Token.make({"id": "drag", "label": "Drag marks", "seconds": 2.0}, Vector3(p.x, floor_y + 0.01, p.z), main)
		t.rotation.y = atan2(p.x - _drag_last.x, p.z - _drag_last.z)
		tokens.append(t)
		_drag_last = p

# ---------------------------------------------------------------- the other brother's orders

## K: keep the nearest searcher busy. C: tidy the nearest sign. (Orders go to the brother you are not.)
func order(kind: String) -> void:
	if not active:
		return
	var o: Actor = main.other()
	if o.busy or o.lead != null or _actions.has(o):
		main._dialogue.bark(o.display_name, "My hands are full.", 1.5)
		return
	main.follow = false
	main._stop_auto()
	if kind == "keep_busy":
		var best: Npc = null
		var bd := INF
		for r in main.residents:
			var n: Npc = r
			if n.mode in [Npc.Mode.SEARCH, Npc.Mode.CHECK] and n.visible:
				var d := n.global_position.distance_to(o.global_position)
				if d < bd:
					bd = d
					best = n
		if best == null:
			main._dialogue.bark(o.display_name, "Nobody's looking yet.", 1.5)
			return
		_task = {"kind": "busy", "who": o, "target": best, "phase": "walk", "timer": 0.0}
		main._dialogue.bark(o.display_name, "I'll keep %s talking." % best.display_name, 1.8)
	else:
		var best: Token = null
		var bd := INF
		for t in tokens:
			if t.item == "":
				var d := t.global_position.distance_to(o.global_position)
				if d < bd:
					bd = d
					best = t
		if best == null:
			main._dialogue.bark(o.display_name, "I can't see anything left to tidy.", 1.8)
			return
		_task = {"kind": "tidy", "who": o, "target": best, "phase": "walk", "timer": 0.0}
		o.go_to(best.global_position)
		main._dialogue.bark(o.display_name, "I'll see to the %s." % best.label.to_lower(), 1.8)
	main._board_dirty = true

func task_text() -> String:
	if _task.is_empty():
		return ""
	if _task.kind == "busy":
		return "Keeping %s busy" % (_task.target as Npc).display_name
	return "Tidying"

func _update_task(delta: float) -> void:
	if _task.is_empty():
		return
	var o: Actor = _task.who
	if o == main.current or o.lead != null:     # taken over by the player, or carrying: drop the order
		_end_task()
		return
	_task.timer -= delta
	if _task.kind == "busy":
		var n: Npc = _task.target
		if _task.phase == "walk":
			if n.mode == Npc.Mode.GATHER or n.mode == Npc.Mode.AWAY:
				_end_task()
				return
			if o.global_position.distance_to(n.global_position) < 1.5:
				n.start_talk(o, TALK_SECONDS)
				o.stop()
				o.face(n.global_position)
				o.talking = true
				_task.phase = "talk"
				main._dialogue.bark(o.display_name, BUSY_LINES[randi() % BUSY_LINES.size()], 3.0)
			elif _task.timer <= 0.0:
				_task.timer = 0.5
				o.go_to(n.global_position)
		elif n.mode != Npc.Mode.TALK:
			_end_task()
	elif _task.kind == "tidy":
		var t: Token = _task.target
		if not is_instance_valid(t) or not t in tokens:
			_end_task()
			return
		if _task.phase == "walk" and o.global_position.distance_to(t.global_position) < 1.1:
			_task.phase = "act"
			_act(o, t.seconds * 1.3, t.verb(), func():
				_take(t, o)
				_end_task(), t.global_position)
		elif _task.phase == "walk" and not o.is_going():
			o.go_to(t.global_position)

func _end_task() -> void:
	if not _task.is_empty():
		var o: Actor = _task.who
		o.talking = false
	_task = {}
	main._board_dirty = true

# ---------------------------------------------------------------- talking to a searcher

func _talk(a: Actor, n: Npc) -> void:
	n.start_talk(a, 30.0)
	a.face(n.global_position)
	main.cutscene = true
	var opts := ["\"He went out. To the shop, I think.\"", "\"I saw him go down to the garage.\"",
		"\"He was upstairs a little while ago.\"", "\"Haven't seen him since this morning.\"", "(Say nothing.)"]
	var pick: int = await main.hud.choose("%s: \"Have you seen Daniel? He's not answering his phone.\"" % n.display_name, opts)
	main.cutscene = false
	var place: String = ["Outside", "Garage", "Upstairs", "", ""][pick]
	if place == "":
		n.end_talk()
		return
	if n.deflected >= 2:
		main._dialogue.bark(n.display_name, "You keep sending me places. Why do you keep doing that?", 3.0)
		n.note("the workers kept sending me around the house", main.minute)
		statements.append([n.display_name, "?", main.minute])
		stress += 6.0
		n.end_talk()
		return
	n.deflected += 1
	statements.append([n.display_name, place, main.minute])
	n.end_talk()
	n.search_next({"Outside": "Outside", "Garage": "Garage", "Upstairs": "Upstairs hall"}[place])
	main._dialogue.bark(n.display_name, "Thank you. I'll look there.", 2.0)

# ---------------------------------------------------------------- what the house notices

func _on_noise(at: Vector3, radius: float, what: String, heard: Array) -> void:
	if not active:
		return
	for r in heard:
		var n: Npc = r
		var room := House.room_at(at + Vector3(0, 0.3, 0))
		if "dragged" in what:
			if not heard_drag.any(func(h): return h[0] == n.display_name and h[2] == room):
				heard_drag.append([n.display_name, main.minute, room])
			stress += 3.0
		elif "phone" in what:
			stress += 2.0
		n.check(at)

## A searcher pauses to call him: his phone buzzes three times where he lies (unless it is off).
func _on_pause(clip: String, n: Npc) -> void:
	if clip != "phone" or phone_off >= 0.0 or not active or body == null:
		return
	for k in 3:
		if phone_off >= 0.0 or not active:
			return
		main.make_noise(body.where(), 6.0, "a phone buzzing")
		await get_tree().create_timer(1.8, false).timeout

func _update_stress(delta: float) -> void:
	var tomas: Actor = main.tomas
	var rate := -0.15
	if body.is_carried() and tomas in body.carriers:
		rate = 0.6
	elif not _task.is_empty() and _task.who == tomas and _task.kind == "busy" and _task.phase == "talk":
		rate = 1.0
	elif main._auto_job != null and main._auto_worker() == tomas:
		rate = -0.4
	stress = clampf(stress + rate * delta, 20.0 if rate < 0.0 and stress <= 20.0 else 0.0, 100.0)

## Sight lines: a resident who sees him lying there finds him; seeing him carried catches the brothers;
## a sign in view goes into their memory.
func _look() -> void:
	if found_by != "":
		return
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for r in main.residents:
		var n: Npc = r
		if n == main.daniel or n.mode in [Npc.Mode.AWAY, Npc.Mode.GATHER] or not n.visible:
			continue
		if _sees(n, body.where() + Vector3(0, 0.25, 0), SEE_BODY, space):
			found_by = n.display_name
			if body.is_carried():
				caught_by = [n.display_name, main.minute, House.room_at(body.where() + Vector3(0, 0.3, 0))]
			found.emit(n, body.is_carried())
			return
		for t in tokens:
			if not n.display_name in t.noticed_by and _sees(n, t.point(), SEE_SIGN, space):
				t.noticed_by.append(n.display_name)
				tokens_seen.append([n.display_name, t.label, t.room, main.minute])
				n.note("noticed %s %s" % [t.label.to_lower(), Game.place(t.room)], main.minute)
				stress += 8.0

func _sees(n: Npc, p: Vector3, reach: float, space: PhysicsDirectSpaceState3D) -> bool:
	if n.mode == Npc.Mode.TALK:
		return false
	var eye := n.global_position + Vector3(0, 1.5 * n.size, 0)
	if House.level_of(n.global_position + Vector3(0, 0.6, 0)) != House.level_of(p + Vector3(0, 0.2, 0)):
		return false
	var d := eye.distance_to(p)
	if d > reach:
		return false
	var flat := Vector3(p.x - eye.x, 0, p.z - eye.z)
	if not n.is_looking_round() and d > 1.8 and flat.length() > 0.01:
		if rad_to_deg(n.forward().angle_to(flat.normalized())) > CONE:
			return false
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, p, 1))
	return hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.35

# ---------------------------------------------------------------- the HUD

func _show() -> void:
	var lines: Array = []
	var room := House.room_at(body.where() + Vector3(0, 0.3, 0))
	var moved := room != ACCIDENT_ROOM
	lines.append([UiTheme.OK if moved else UiTheme.DANGER, "Daniel is %s%s" % [Game.place(room), "" if moved else " (move him)"]])
	if staged:
		var done: Array = setup_done.get(staged.id, [])
		var left := staged.setup.size() - done.size()
		lines.append([UiTheme.OK if left == 0 else UiTheme.ACCENT, "Staged: %s%s" % [staged.title, "" if left == 0 else "  (%d to set up)" % left]])
	else:
		lines.append([UiTheme.ACCENT, "Stage it: set him down at a blue ring"])
	lines.append([UiTheme.OK if tokens.is_empty() else UiTheme.ACCENT, "Signs left to tidy: %d" % tokens.size() if not tokens.is_empty() else "No signs left in sight"])
	for a in items:
		lines.append([UiTheme.ACCENT, "%s has the %s" % [(a as Actor).display_name, String(items[a]).replace("nailgun", "nail gun")]])
	var ratio := work_ratio()
	lines.append([UiTheme.OK if ratio >= 0.5 else UiTheme.DANGER, "Sounds like work: %d%%  (send %s to work)" % [int(ratio * 100.0), main.tomas.display_name]])
	for r in main.residents:
		var n: Npc = r
		if n == main.daniel:
			continue
		var doing := ""
		match n.mode:
			Npc.Mode.SEARCH: doing = "searching" + (" " + Game.place(n.target_room()) if n.target_room() != "" else "")
			Npc.Mode.CHECK: doing = "checking a noise"
			Npc.Mode.TALK: doing = "talking"
			Npc.Mode.AWAY: doing = "at work"
			_: doing = "has not noticed yet"
		lines.append([UiTheme.person_color(n.display_name), "%s: %s" % [n.display_name, doing]])
	var open: Array = main.jobs.values().filter(func(j): return j.available(main.jobs) and not story.job_locked(j))
	main.hud.set_objectives("Before they find him", lines, open, main.other().display_name, main._auto_job)
	main.hud.set_cover(true, stress)

# ---------------------------------------------------------------- for the police

## How much of the working day (the morning's work counts) sounded like work.
func work_ratio() -> float:
	var morning := maxf(0.0, t0 - main.START_MINUTE)
	return (morning + _work_minutes) / maxf(1.0, morning + _minutes)

func report() -> Dictionary:
	var where := body.where()
	var room := House.room_at(where + Vector3(0, 0.3, 0))
	var sc := _scenario_at(where) if not body.is_carried() else null
	var left: Array = []
	for t in tokens:
		left.append([t.label, t.room, t.main])
	var held := ""
	for a in items:
		held = items[a]
	return {
		"case": case, "truth": false, "caught": caught_by, "moved": room != ACCIDENT_ROOM, "scenario": sc,
		"setup_done": setup_done.get(sc.id, []) if sc else [], "room": room, "heard_accident": heard_accident,
		"heard_drag": heard_drag, "phone_off": phone_off, "statements": statements.filter(func(s): return s[1] != "?"),
		"suspicious": statements.filter(func(s): return s[1] == "?"), "tokens_left": left, "tokens_seen": tokens_seen,
		"item_held": held, "work_ratio": work_ratio(), "stress": stress,
	}
