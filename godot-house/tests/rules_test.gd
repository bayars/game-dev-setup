extends SceneTree
## Unit tests for the investigation rules (Investigation.judge): plausibility, timeline contradictions,
## the token trail, the work alibi, Tomas, and the ending each combination leads to.
##   godot --headless --path godot-house -s res://tests/rules_test.gd      -> RULES_OK / RULES_FAIL

var fails: Array[String] = []

func _initialize() -> void:
	var cases := {}
	for c in Day2.cases():
		cases[c.id] = c
	var scen := {}
	for s in Day2.scenarios():
		scen[s.id] = s
	if cases.size() < 3 or scen.size() < 4:
		fails.append("data: %d cases, %d scenarios loaded" % [cases.size(), scen.size()])
		_done()
		return

	# a clean run for every case, at a scenario that explains it
	for id in cases:
		var sc: StageScenario = scen["storage_nailgun"] if cases[id].injury == "puncture" else scen["stairs"]
		var r := _clean(cases[id], sc)
		_expect("clean %s" % id, r, "clean")

	var stud: AccidentCase = cases["stud"]
	var stairs: StageScenario = scen["stairs"]
	_expect("truth", {"truth": true, "case": stud}, "truth")
	_expect("never moved", _with(_clean(stud, stairs), {"moved": false, "scenario": null, "room": "Daniel's room"}), "found_early")
	_expect("seen carrying", _with(_clean(stud, stairs), {"caught": ["Rose", 600.0, "Stairs"]}), "caught")
	_expect("Tomas breaks", _with(_clean(stud, stairs), {"stress": 95.0}), "tomas_breaks")
	_expect("shaky Tomas", _with(_clean(stud, stairs), {"stress": 70.0}), "shadow")
	_expect("not a scenario", _with(_clean(stud, stairs), {"scenario": null, "room": "Hallway"}), "doesnt_add_up")
	_expect("wrong injury", _with(_clean(cases["nailgun"], stairs), {}), "doesnt_add_up")
	_expect("nothing set up", _with(_clean(stud, stairs), {"setup_done": []}), "doesnt_add_up")
	_expect("crash heard elsewhere", _with(_clean(stud, scen["ladder"]),
		{"heard_accident": [["Linda", 580.0, "Daniel's room"]]}), "timeline")
	_expect("crash heard and it fits", _with(_clean(stud, stairs),
		{"heard_accident": [["Linda", 580.0, "Daniel's room"]]}), "clean")
	_expect("one drag heard", _with(_clean(stud, stairs), {"heard_drag": [["Rose", 590.0, "Hallway"]]}), "shadow")
	_expect("drags heard", _with(_clean(stud, stairs),
		{"heard_drag": [["Rose", 590.0, "Hallway"], ["Linda", 592.0, "Stairs"]]}), "timeline")
	_expect("phone off", _with(_clean(stud, stairs), {"phone_off": 590.0}), "shadow")
	_expect("lied about the place", _with(_clean(stud, stairs), {"statements": [["Linda", "Outside", 585.0]]}), "timeline")
	_expect("said upstairs, found upstairs", _with(_clean(stud, scen["bathroom"]),
		{"statements": [["Linda", "Upstairs", 585.0]], "room": "Upstairs bathroom"}), "clean")
	_expect("sent around too often", _with(_clean(stud, stairs), {"suspicious": [["Linda", "?", 590.0]]}), "shadow")
	_expect("main sign left", _with(_clean(stud, stairs), {"tokens_left": [["The fallen stud", "Daniel's room", true]]}), "trail")
	_expect("one small sign", _with(_clean(stud, stairs), {"tokens_left": [["Drag marks", "Hallway", false]]}), "shadow")
	_expect("small signs", _with(_clean(stud, stairs),
		{"tokens_left": [["Drag marks", "Hallway", false], ["Drag marks", "Stairs", false]]}), "trail")
	_expect("sign noticed", _with(_clean(stud, stairs), {"tokens_seen": [["Rose", "Drag marks", "Hallway", 590.0]]}), "shadow")
	_expect("nail gun in the bag", _with(_clean(cases["nailgun"], scen["storage_nailgun"]), {"item_held": "nailgun"}), "trail")
	_expect("quiet house", _with(_clean(stud, stairs), {"work_ratio": 0.2}), "shadow")
	for e in ["timeline", "trail", "doesnt_add_up", "found_early"]:
		if not Investigation.can_take_fall(e):
			fails.append("taking the fall is not offered for %s" % e)
	if Investigation.can_take_fall("clean"):
		fails.append("taking the fall is offered for a clean result")
	for e in Investigation.ENDINGS:
		if e != "truth" and (Investigation.ENDINGS[e][1] as Array).is_empty():
			fails.append("ending %s has no text" % e)
	_done()

func _clean(case: AccidentCase, sc: StageScenario) -> Dictionary:
	return {"case": case, "truth": false, "caught": [], "moved": true, "scenario": sc,
		"setup_done": sc.setup.map(func(s): return s.id), "room": sc.room, "heard_accident": [], "heard_drag": [],
		"phone_off": -1.0, "statements": [], "tokens_left": [], "tokens_seen": [], "item_held": "",
		"work_ratio": 0.8, "stress": 30.0}

func _with(r: Dictionary, over: Dictionary) -> Dictionary:
	var out := r.duplicate()
	out.merge(over, true)
	return out

func _expect(name: String, r: Dictionary, ending: String) -> void:
	var got := Investigation.judge(r)
	if got.ending != ending:
		var why := []
		for c in got.checks:
			if not c.ok:
				why.append("%s: %s" % [c.name, "; ".join(c.lines)])
		fails.append("%s: ending %s, expected %s (%s)" % [name, got.ending, ending, " | ".join(why)])

func _done() -> void:
	if fails.is_empty():
		print("RULES_OK")
	else:
		for f in fails:
			print("  - " + f)
		print("RULES_FAIL %d" % fails.size())
	quit(0 if fails.is_empty() else 1)
