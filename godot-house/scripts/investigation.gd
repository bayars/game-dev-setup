class_name Investigation
extends RefCounted
## The police check the scene (game rules only: tokens, timelines, what the residents remember, the staged
## scenario's own rules, never real forensics). `judge(report)` turns what happened in the cover-up into
## five checks, each passed or failed with the reasons a detective would say, and picks the ending.
##
## report keys (Story2 fills them):
##   case: AccidentCase                 truth: bool (told the truth at once)
##   caught: [who, minute, room] or []  a resident saw the brothers moving him
##   moved: bool                        he no longer lies in the room where it happened
##   scenario: StageScenario or null    the place he lies in, if it is a stage scenario
##   setup_done: Array[String]          setup ids finished there
##   room: String                       the room he was found in
##   heard_accident: [[who, minute, room]]   residents who heard the accident itself
##   heard_drag: [[who, minute, room]]       ... something heavy being dragged afterwards
##   phone_off: float (-1 = not)        when his phone was switched off
##   statements: [[who, place, minute]] what the brothers told the residents ("Outside", "Garage", ...)
##   suspicious: [[who, ...]]           residents who were sent around once too often
##   tokens_left: [[label, room, main]] signs still lying about
##   tokens_seen: [[who, label, room, minute]] signs a resident noticed (even if tidied later)
##   item_held: String                  a piece of the accident still in a brother's hands ("nailgun")
##   work_ratio: float                  share of the cover-up minutes that sounded like work
##   stress: float                      Tomas, 0..100
##
## Each check: {name, ok, major, lines: [String]}. Endings: see ENDINGS.

const STRESS_BREAK := 90.0
const STRESS_SHAKY := 60.0

const ENDINGS := {
	"clean": ["Ruled an accident",
		["The coroner calls it a tragic accident at home. Nobody asks about the two men who were working upstairs.",
		"Linda pays you the rest of the money in an envelope, at the door, and cannot look at you.",
		"You send money home that week. Tomas does not sleep. Neither do you."]],
	"shadow": ["A shadow of doubt",
		["The case stays open. A detective calls the number you gave twice, then a third time.",
		"You leave the van with a cousin and take the night bus out of town.",
		"Nobody charged you with anything. Nobody needed to."]],
	"timeline": ["Caught in the timeline",
		["The family's memories do not fit the story. The times are wrong, the places are wrong.",
		"Two detectives come back the next morning, and this time they bring a van of their own.",
		"You are charged before lunch."]],
	"trail": ["The trail",
		["The signs lead from where he was found back up to the room you were working in.",
		"Moving him turns an accident into something else in the report: a cover-up.",
		"You are both arrested in the driveway, next to the van."]],
	"doesnt_add_up": ["It doesn't add up",
		["Nothing where he was found could have done this to him. The detective says so out loud.",
		"The questions turn from the family to the workers.",
		"By evening you are in separate rooms, telling separate stories."]],
	"found_early": ["Found too early",
		["He is found in his own room, among your tools, where it happened.",
		"There is nothing to explain and nobody to explain it to.",
		"The police take you both from the house in the clothes you worked in."]],
	"caught": ["Caught in the act",
		["Someone sees you carrying him. The scream brings the whole house.",
		"There is no story after that. There is only what they saw.",
		"You are held on the floor of the hallway until the police come."]],
	"tomas_breaks": ["Tomas breaks",
		["In the interview, Tomas holds out for eleven minutes.",
		"Then he tells them everything: the room, the stairs, the carrying, the lies.",
		"He cries the whole time. You cannot hate him for it."]],
	"fall_nico": ["One brother takes the fall",
		["You tell them it was you alone. Tomas was downstairs, he saw nothing, he knew nothing.",
		"They believe you, because it is easier to believe one man.",
		"Tomas takes the money home. You write him letters you never send."]],
	"fall_tomas": ["One brother takes the fall",
		["Tomas tells them it was him. He was holding it, he moved the boy, his brother was downstairs.",
		"You let him. You tell yourself it is for the family at home.",
		"You visit once. He asks you not to come again."]],
	"truth": ["The truth", []],
}

static func judge(r: Dictionary) -> Dictionary:
	if r.get("truth", false):
		return {"checks": [], "ending": "truth"}
	var checks: Array = [_scene(r), _timeline(r), _trail(r), _alibi(r), _tomas(r)]
	var ending := "clean"
	var caught: Array = r.get("caught", [])
	if not caught.is_empty():
		ending = "caught"
	elif not r.get("moved", false):
		ending = "found_early"
	elif float(r.get("stress", 0.0)) >= STRESS_BREAK:
		ending = "tomas_breaks"
	elif _major(checks, "Timeline"):
		ending = "timeline"
	elif _major(checks, "Trail"):
		ending = "trail"
	elif _major(checks, "Scene"):
		ending = "doesnt_add_up"
	elif checks.any(func(c): return not c.ok):
		ending = "shadow"
	return {"checks": checks, "ending": ending}

## Endings where the brothers are about to be blamed: one of them may still take it all on himself.
static func can_take_fall(ending: String) -> bool:
	return ending in ["timeline", "trail", "doesnt_add_up", "found_early", "tomas_breaks"]

static func _major(checks: Array, name: String) -> bool:
	for c in checks:
		if c.name == name and not c.ok and c.major:
			return true
	return false

static func _check(name: String) -> Dictionary:
	return {"name": name, "ok": true, "major": false, "lines": []}

static func _fail(c: Dictionary, line: String, major: bool) -> void:
	c.ok = false
	c.major = c.major or major
	c.lines.append(line)

## Does the place he lies in explain what happened to him?
static func _scene(r: Dictionary) -> Dictionary:
	var c := _check("Scene")
	var case: AccidentCase = r.case
	var sc: StageScenario = r.get("scenario")
	if not r.get("moved", false):
		_fail(c, "He was found %s, where the brothers were working, next to their tools." % Game.place(r.get("room", "")), true)
		return c
	if sc == null:
		_fail(c, "He was found %s. Nothing there could have done this to him." % Game.place(r.get("room", "")), true)
		return c
	if not case.injury in sc.explains:
		_fail(c, "\"%s\" does not explain his injuries. %s" % [sc.title, _injury_line(case.injury)], true)
	var done: Array = r.get("setup_done", [])
	var missing: Array = sc.setup.filter(func(s): return not s.id in done)
	if missing.size() == sc.setup.size() and not sc.setup.is_empty():
		_fail(c, "Nothing around him shows how it happened: \"%s\" is only a story." % sc.title, true)
	else:
		for s in missing:
			_fail(c, "Something was missing from the scene (%s)." % String(s.text).to_lower(), false)
	if c.ok:
		c.lines.append("\"%s\" fits his injuries and the room." % sc.title)
	return c

static func _injury_line(injury: String) -> String:
	match injury:
		"puncture": return "A fall does not leave wounds like a nail gun does."
		"crush": return "He was crushed under something heavy and flat."
		_: return "The blow to his head came from something heavy and straight, not from the floor."

## Do the family's memories and the brothers' words fit the place and the time?
static func _timeline(r: Dictionary) -> Dictionary:
	var c := _check("Timeline")
	var sc: StageScenario = r.get("scenario")
	var where: String = r.get("room", "")
	for h in r.get("heard_accident", []):
		var fits: bool = sc != null and h[2] in sc.fits_heard
		if not fits:
			_fail(c, "%s heard %s %s at %s, but he was found %s." % [h[0], r.case.noise_what, Game.place(h[2]),
				_clock(h[1]), Game.place(where)], true)
	var drags: Array = r.get("heard_drag", [])
	for h in drags:
		_fail(c, "%s heard something heavy being dragged %s at %s, after the accident." % [h[0], Game.place(h[2]), _clock(h[1])],
			drags.size() >= 2)
	var off: float = r.get("phone_off", -1.0)
	if off >= 0.0:
		_fail(c, "His phone was switched off at %s, after he was already hurt." % _clock(off), false)
	for st in r.get("suspicious", []):
		_fail(c, "%s felt the workers kept sending her around the house." % st[0], false)
	for st in r.get("statements", []):
		if not _same_place(st[1], where, sc):
			_fail(c, "%s was told he %s. He was found %s." % [st[0], _said(st[1]), Game.place(where)], true)
	if c.ok:
		c.lines.append("What the family heard and was told fits the time and the place.")
	return c

static func _said(place: String) -> String:
	match place:
		"Outside": return "had gone out to the shop"
		"Garage": return "had gone down to the garage"
		"Upstairs": return "was somewhere upstairs"
	return "was " + Game.place(place)

## A statement fits if it points at the room he was found in (or its floor, for "upstairs").
static func _same_place(said: String, room: String, sc: StageScenario) -> bool:
	if said == room:
		return true
	if said == "Upstairs":
		return sc != null and sc.level == 1 or room in ["Upstairs hall", "Upstairs bathroom", "Storage", "Landing", "Sofia's room", "Parents' room", "Daniel's room"]
	return false

## Signs between where it happened and where he was found.
static func _trail(r: Dictionary) -> Dictionary:
	var c := _check("Trail")
	var left: Array = r.get("tokens_left", [])
	var minor := 0
	for t in left:
		if t[2]:
			_fail(c, "%s was still %s." % [t[0], Game.place(t[1])], true)
		else:
			minor += 1
	for t in left:
		if not t[2]:
			_fail(c, "%s %s." % [t[0], Game.place(t[1])], minor >= 2)
	for t in r.get("tokens_seen", []):
		_fail(c, "%s noticed %s %s at %s." % [t[0], String(t[1]).to_lower(), Game.place(t[2]), _clock(t[3])], false)
	var held: String = r.get("item_held", "")
	if held != "":
		_fail(c, "The %s was found in the brothers' tool bag." % held.replace("nailgun", "nail gun"), true)
	if c.ok:
		c.lines.append("Nothing leads from the scene to anywhere else in the house.")
	return c

## Did the house sound like an ordinary working day after the accident?
static func _alibi(r: Dictionary) -> Dictionary:
	var c := _check("Work")
	var ratio: float = r.get("work_ratio", 0.0)
	if ratio < 0.5:
		_fail(c, "The family remembers the work going quiet upstairs for most of the morning.", false)
	else:
		c.lines.append("The family heard the brothers working all morning.")
	return c

## Tomas in the interview room.
static func _tomas(r: Dictionary) -> Dictionary:
	var c := _check("Tomas")
	var s: float = r.get("stress", 0.0)
	if s >= STRESS_BREAK:
		_fail(c, "Tomas could not hold it together in the interview.", true)
	elif s >= STRESS_SHAKY:
		_fail(c, "Tomas stumbled over his answers. They wrote that down.", false)
	else:
		c.lines.append("Tomas kept his answers short and steady.")
	return c

static func _clock(minute: float) -> String:
	return "%02d:%02d" % [int(minute) / 60 % 24, int(minute) % 60]
