class_name StageScenario
extends Resource
## A place in the house where Daniel's death could pass for an accident that has nothing to do with the
## work (resources/scenarios/*.tres). These are the game's own rules: the injuries a scenario explains, the
## rooms a heard crash fits, and the few things to set up there. The police check them (Investigation).

@export var id := ""
@export var title := ""                   # "Fell down the stairs"
@export var story := ""                   # what the police are meant to believe
@export var room := ""                    # the room it counts as (statements, the Seen log)
@export var level := 0
@export var area := Rect2()               # where he must lie (x, z)
@export var mark := Vector3.ZERO          # centre of the place (the floor ring, the camera)
@export var explains: Array = []         # injuries it fits (plain arrays: they survive the export)
@export var fits_heard: Array = []       # rooms a heard crash could have come from
@export var setup: Array = []             # [{id, text, at: Vector3, seconds, needs: item id or ""}]
