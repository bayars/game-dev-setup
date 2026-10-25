class_name Npc
extends Actor
## A resident: follows a daily schedule (at each listed clock time, in minutes since midnight, they walk to
## a spot), may wander between spots, and hears noise. What they notice goes into `noticed`, the Seen log
## the police read back on day 2.
##
## Day 2 adds modes: SEARCH walks a plan of rooms, looking round each one for a while; CHECK goes to
## see what a noise was and then goes back to the plan; TALK stands with someone who is keeping them busy;
## GATHER comes to where Daniel was found; AWAY is out of the house (Robert at work).

enum Mode { ROUTINE, SEARCH, CHECK, TALK, GATHER, AWAY }

signal paused(clip: String)                # a search pause begins ("phone": calling Daniel)

const LOOK_SECONDS := 14.0                  # how long a searcher looks round one room

var schedule: Array = []   # [[minute, Vector3 spot], ...] sorted by minute
var wander: Array = []     # spots to drift between when the schedule leaves them idle
var hearing := 1.0         # multiplier on noise radius (Rose hears less, Linda more)
var noticed: Array[String] = []
var mode := Mode.ROUTINE
var plan: Array = []       # SEARCH: [[spot, room], ...]
var plan_i := 0
var looking := 0.0         # seconds left looking round the current room (sees all of it meanwhile)
var searched: Array[String] = []           # rooms already looked through
var deflected := 0         # how often the brothers have sent them somewhere else
var talk_with: Actor = null
var speed_search := 1.0    # Rose walks slower
var _next := 0
var _wander_wait := 4.0
var _last_heard := {}      # what -> minute, so one long noise is one memory
var _talk_left := 0.0
var _before_talk := Mode.ROUTINE

func tick(minute: float, delta: float) -> void:
	match mode:
		Mode.ROUTINE:
			_routine(minute, delta)
		Mode.SEARCH, Mode.CHECK:
			_search(delta)
		Mode.TALK:
			_talk_left -= delta
			if talk_with:
				face(talk_with.global_position)
			if _talk_left <= 0.0:
				end_talk()
		Mode.GATHER, Mode.AWAY:
			pass

func _routine(minute: float, delta: float) -> void:
	while _next < schedule.size() and minute >= schedule[_next][0]:
		go_to(schedule[_next][1])
		_next += 1
	if not wander.is_empty() and not is_going() and not busy:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_wander_wait = randf_range(6.0, 14.0)
			go_to(wander[randi() % wander.size()])

## Starts (or restarts) searching: `rooms` in order, each looked through for LOOK_SECONDS. An entry
## "pause:<seconds>:<clip>" stops there for a while instead (on the phone to his friends, sitting down).
func search(rooms: Array) -> void:
	plan = []
	for r in rooms:
		if String(r).begins_with("pause:"):
			var parts := String(r).split(":")
			plan.append(["pause", float(parts[1]), parts[2]])
		else:
			plan.append([_room_spot(r), r])
	plan_i = 0
	looking = 0.0
	mode = Mode.SEARCH
	idle_clip = "idle"
	speed_mul = speed_search
	_start_entry()

## Walks to the current plan entry, or begins its pause.
func _start_entry() -> void:
	looking = 0.0
	if plan.is_empty():
		return
	var e: Array = plan[plan_i]
	if e[0] is String:
		stop()
		looking = e[1]
		idle_clip = e[2]
		paused.emit(e[2])
	else:
		go_to(e[0])

## Puts `room` next in the plan (the brothers said he might be there, or a noise came from there).
func search_next(room: String) -> void:
	plan.insert(plan_i, [_room_spot(room), room])
	mode = Mode.SEARCH
	_start_entry()

static func _room_spot(room: String) -> Vector3:
	match room:                           # a spot inside each room from where most of it is in view
		"Outside": return Vector3(9.5, 0, 14.5)
		"Garage": return Vector3(4.5, 0, 9.4)
		"Work room": return Vector3(4.5, 0, 4.6)
		"Stairs": return Vector3(13.6, 0, 9.6)
		"Daniel's room": return Vector3(5.2, House.UP, 3.0)
		"Storage": return Vector3(12.2, House.UP, 6.3)
		"Upstairs bathroom": return Vector3(12.0, House.UP, 2.2)
		"Bathroom": return Vector3(12.0, 0, 2.2)
		"Landing": return Vector3(12.2, House.UP, 9.4)
	return House.room_center(room)

func _search(delta: float) -> void:
	if is_going() or plan.is_empty():
		return
	var pausing: bool = mode == Mode.SEARCH and plan[plan_i][0] is String
	if looking > 0.0:
		looking -= delta
		if not pausing:
			idle_clip = "search"
		if looking <= 0.0:
			idle_clip = "idle"
			if mode == Mode.CHECK:
				mode = Mode.SEARCH
				_start_entry()
				return
			if not pausing:
				searched.append(plan[plan_i][1])
			plan_i = (plan_i + 1) % plan.size()   # looked everywhere: start again
			_start_entry()
		return
	if pausing:
		_start_entry()
	else:
		looking = LOOK_SECONDS * (0.6 if mode == Mode.CHECK else 1.0)

## True while looking round a room: they see the whole room, not only what is in front of them.
func is_looking_round() -> bool:
	if mode == Mode.CHECK:
		return looking > 0.0
	return mode == Mode.SEARCH and looking > 0.0 and not plan[plan_i][0] is String

## The room they are on their way to or looking through ("" while pausing).
func target_room() -> String:
	if mode != Mode.SEARCH or plan.is_empty() or plan[plan_i][0] is String:
		return ""
	return plan[plan_i][1]

## Goes to see what a noise at `at` was, then back to the search.
func check(at: Vector3) -> void:
	if mode != Mode.SEARCH and mode != Mode.CHECK:
		return
	mode = Mode.CHECK
	looking = 0.0
	idle_clip = "idle"
	go_to(at)

## Someone keeps them talking for `seconds` (they stop where they are).
func start_talk(with: Actor, seconds: float) -> void:
	if mode == Mode.TALK:
		_talk_left = maxf(_talk_left, seconds)
		return
	_before_talk = mode
	mode = Mode.TALK
	talk_with = with
	_talk_left = seconds
	stop()
	talking = true

func end_talk() -> void:
	if mode != Mode.TALK:
		return
	talking = false
	talk_with = null
	mode = _before_talk
	if mode == Mode.SEARCH:
		_start_entry()

func set_away(on: bool) -> void:
	mode = Mode.AWAY if on else Mode.ROUTINE
	visible = not on
	set_physics_process(not on)
	_shape.disabled = on

## Comes to `at` (Daniel has been found).
func gather(at: Vector3) -> void:
	mode = Mode.GATHER
	talking = false
	speed_mul = 1.0
	idle_clip = "idle"
	go_to(at)

## A noise of `radius` metres happened at `at`. Returns true if this resident heard it.
func hear(at: Vector3, radius: float, what: String, minute: float, where: String) -> bool:
	if limp or mode == Mode.AWAY or global_position.distance_to(at) > radius * hearing:
		return false
	if _last_heard.has(what) and minute - _last_heard[what] < 10.0:
		return true
	_last_heard[what] = minute
	note("heard %s %s" % [what, Game.place(where)], minute)
	return true

## Adds a line to the Seen log, stamped with the clock.
func note(what: String, minute: float) -> void:
	noticed.append("%02d:%02d %s" % [int(minute) / 60 % 24, int(minute) % 60, what])

## The Seen log folded for reading: one line per kind of thing heard, with every time it happened
## ("heard a loud bang in the work room  (09:03, 09:26)").
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
