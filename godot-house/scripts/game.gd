class_name Game
extends RefCounted
## What carries over between scenes: which day to play, the accident case, the options, and the save
## (user://save.cfg: progress and options). A first-time player gets day 1, then day 2; once day 2 has
## been played to an ending, either day can be picked from the menu.

const SAVE := "user://save.cfg"

static var day := 1
static var case_id := ""                  # "" = the next case in turn
static var soften := false                # the accident close-ups cut to black instead
static var volume := 0.8
static var seen_warning := false
static var day2_unlocked := false         # day 1 done: the menu continues with day 2
static var day2_done := false             # day 2 played to an ending: the menu offers both days
static var runs := 0                      # day 2 runs so far: the cases rotate
static var _loaded := false

static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) != OK:
		return
	day2_unlocked = cfg.get_value("progress", "day2", false)
	day2_done = cfg.get_value("progress", "day2_done", false)
	runs = cfg.get_value("progress", "runs", 0)
	soften = cfg.get_value("options", "soften", false)
	volume = cfg.get_value("options", "volume", 0.8)
	seen_warning = cfg.get_value("options", "warning", false)

static func save() -> void:
	if DisplayServer.get_name() == "headless":
		return                              # self-tests never touch the save
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "day2", day2_unlocked)
	cfg.set_value("progress", "day2_done", day2_done)
	cfg.set_value("progress", "runs", runs)
	cfg.set_value("options", "soften", soften)
	cfg.set_value("options", "volume", volume)
	cfg.set_value("options", "warning", seen_warning)
	cfg.save(SAVE)

## The sentence for "where": "in the work room", "in Daniel's room", "on the stairs", "outside".
static func place(room: String) -> String:
	match room:
		"Outside": return "outside"
		"Stairs": return "on the stairs"
		"Landing": return "on the landing"
	if "'" in room:
		return "in " + room
	return "in the " + room.to_lower()
