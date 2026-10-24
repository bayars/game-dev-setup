class_name Npc
extends Actor
## A resident: follows a daily schedule (at each listed clock time, in minutes since midnight, they walk to
## a spot), may wander between spots, and hears noise. What they notice goes into `noticed`, the Seen log
## that later days read back (the police interview on day 2).

var schedule: Array = []   # [[minute, Vector3 spot], ...] sorted by minute
var wander: Array = []     # spots to drift between when the schedule leaves them idle
var hearing := 1.0         # multiplier on noise radius (Rose hears less, Linda more)
var noticed: Array[String] = []
var _next := 0
var _wander_wait := 4.0
var _last_heard := {}      # what -> minute, so one long noise is one memory

func tick(minute: float, delta: float) -> void:
	while _next < schedule.size() and minute >= schedule[_next][0]:
		go_to(schedule[_next][1])
		_next += 1
	if not wander.is_empty() and not is_going() and not busy:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_wander_wait = randf_range(6.0, 14.0)
			go_to(wander[randi() % wander.size()])

## A noise of `radius` metres happened at `at`. Returns true if this resident heard it.
func hear(at: Vector3, radius: float, what: String, minute: float, where: String) -> bool:
	if global_position.distance_to(at) > radius * hearing:
		return false
	if _last_heard.has(what) and minute - _last_heard[what] < 10.0:
		return true
	_last_heard[what] = minute
	var place := "outside" if where == "Outside" else "in the " + where
	noticed.append("%02d:%02d heard %s %s" % [int(minute) / 60, int(minute) % 60, what, place])
	return true

## The Seen log folded for reading: one line per kind of thing heard, with every time it happened
## ("heard a loud bang in the Work room  (09:03, 09:26)").
static func summarize(log: Array[String]) -> Array[String]:
	var order: Array[String] = []
	var times := {}
	for entry in log:
		var when := entry.substr(0, 5)
		var what := entry.substr(6)
		if not times.has(what):
			times[what] = []
			order.append(what)
		times[what].append(when)
	var out: Array[String] = []
	for what in order:
		out.append("%s  (%s)" % [what, ", ".join(times[what])])
	return out
