extends Node2D
## Game loop: spawn fallers, track score, game over and restart.
## Run with `-- --selftest` (after the project path) for a headless check of the loop.

const FALLER := preload("res://scenes/faller.tscn")

@onready var player: Area2D = $Player
@onready var score_label: Label = $Hud/ScoreLabel
@onready var message_label: Label = $Hud/MessageLabel

var playing := false
var elapsed := 0.0
var coins := 0
var spawn_timer := 0.0
var selftest := false

func _ready() -> void:
	randomize()
	player.area_entered.connect(_on_player_area_entered)
	selftest = "--selftest" in OS.get_cmdline_user_args()
	_start()

func _start() -> void:
	for f in get_tree().get_nodes_in_group("fallers"):
		f.queue_free()
	var size := get_viewport_rect().size
	player.position = Vector2(size.x / 2.0, size.y - 60.0)
	elapsed = 0.0
	coins = 0
	spawn_timer = 0.0
	playing = true
	message_label.text = ""
	_update_score()

func _process(delta: float) -> void:
	if selftest:
		_selftest_step(delta)
	if not playing:
		if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER):
			_start()
		return
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.25, 0.9 - elapsed * 0.01)
		_spawn(randf() < 0.25)
	_update_score()

func _spawn(is_coin: bool, at: Vector2 = Vector2.INF) -> void:
	var f := FALLER.instantiate()
	f.is_coin = is_coin
	f.speed = 200.0 + elapsed * 4.0
	var size := get_viewport_rect().size
	f.position = Vector2(randf_range(20.0, size.x - 20.0), -20.0) if at == Vector2.INF else at
	f.add_to_group("fallers")
	add_child(f)

func _on_player_area_entered(area: Area2D) -> void:
	if not playing:
		return
	if area.is_coin:
		coins += 1
		area.queue_free()
	else:
		_game_over()

func _game_over() -> void:
	playing = false
	message_label.text = "GAME OVER  score %d\nSpace or Enter to restart" % _score()

func _score() -> int:
	return coins * 10 + int(elapsed)

func _update_score() -> void:
	score_label.text = "Score %d" % _score()

# --- headless self-test: a hazard on the player must end the game, a coin on it must score ---
var _st_t := 0.0
var _st_stage := 0

func _selftest_step(delta: float) -> void:
	_st_t += delta
	if _st_stage == 0 and _st_t > 0.3:
		_spawn(true, player.position)
		_st_stage = 1
	elif _st_stage == 1 and _st_t > 0.6:
		if coins != 1:
			_selftest_end(false, "coin not collected")
			return
		_spawn(false, player.position)
		_st_stage = 2
	elif _st_stage == 2 and _st_t > 0.9:
		_selftest_end(not playing, "hazard did not end the game")

func _selftest_end(ok: bool, why: String) -> void:
	print("SELFTEST_OK coins=%d score=%d" % [coins, _score()] if ok else "SELFTEST_FAIL " + why)
	get_tree().quit(0 if ok else 1)
