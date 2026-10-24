class_name Npc
extends Actor
## A resident who follows a daily schedule: at each listed clock time (minutes since midnight) they walk
## to a spot. Searching, hearing and sight come later (milestone 5).

var schedule: Array = []   # [[minute, Vector3 spot], ...] sorted by minute
var _next := 0

func tick(minute: float) -> void:
	while _next < schedule.size() and minute >= schedule[_next][0]:
		go_to(schedule[_next][1])
		_next += 1
