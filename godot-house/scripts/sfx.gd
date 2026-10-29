class_name Sfx
extends Node
## Sound for the house: one-shot effects (placed in the world, or flat for the interface and the score),
## looping beds (room tone, a drag scrape), and the muffle that takes the world away at the accident.
## The sounds are WAV / Ogg files in assets/audio/, made by art-src/audio/make_sounds.py; a name without a file
## plays nothing, so the game runs before (or without) them.

const DIR := "res://assets/audio/%s"

var _cache := {}
var _loops := {}
var _world_bus := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("World") < 0:
		AudioServer.add_bus()
		_world_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_world_bus, "World")
		AudioServer.set_bus_send(_world_bus, "Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 500.0
		AudioServer.add_bus_effect(_world_bus, lp)
		AudioServer.set_bus_effect_enabled(_world_bus, 0, false)
	_world_bus = AudioServer.get_bus_index("World")
	set_volume(Game.volume)

func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))
	AudioServer.set_bus_mute(0, v <= 0.001)

func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		_cache[name] = null
		for ext in [".ogg", ".wav"]:
			if ResourceLoader.exists(DIR % name + ext):
				_cache[name] = load(DIR % name + ext)
				break
		if _cache[name] is AudioStreamOggVorbis:
			(_cache[name] as AudioStreamOggVorbis).loop = name.ends_with("_loop")
	return _cache[name]

## Plays `name` once: at a point in the house (heard from the camera), or flat when `at` is null.
func play(name: String, at: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.unit_size = 6.0
		p3.max_distance = 60.0
		p3.bus = "World"
		add_child(p3)
		p3.global_position = at
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = s
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		add_child(p2)
		p2.play()
		p = p2
	p.finished.connect(p.queue_free)

## Starts or stops a looping sound (room tone, the drag scrape). `at` follows nothing: flat if null.
func loop(name: String, on: bool, volume_db := 0.0, world := true) -> void:
	if on == _loops.has(name):
		return
	if not on:
		(_loops[name] as Node).queue_free()
		_loops.erase(name)
		return
	var s := _stream(name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.bus = "World" if world else "Master"
	add_child(p)
	p.play()
	_loops[name] = p

## The accident: the house goes dull and far away (the heartbeat and the score stay clear).
func mute_world(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(_world_bus, 0, on)
	var t := create_tween()
	t.tween_method(func(db: float): AudioServer.set_bus_volume_db(_world_bus, db),
		AudioServer.get_bus_volume_db(_world_bus), -14.0 if on else 0.0, 0.6)
