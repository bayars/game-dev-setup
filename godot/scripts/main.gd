extends Node2D
## Game loop: start screen, spawning, lives, score, game over, saved high score.
## Run with `-- --selftest` (after the project path) for a headless check of the rules.

enum State { MENU, PLAYING, GAME_OVER }

const FALLER := preload("res://scenes/faller.tscn")
const SAVE_PATH := "user://highscore.cfg"
const START_LIVES := 3
const INVULN_TIME := 1.0

@onready var player: Area2D = $Player
@onready var score_label: Label = $Hud/ScoreLabel
@onready var lives_label: Label = $Hud/LivesLabel
@onready var best_label: Label = $Hud/BestLabel
@onready var message_label: Label = $Hud/MessageLabel

var state := State.MENU
var elapsed := 0.0
var coins := 0
var lives := START_LIVES
var invuln := 0.0
var best := 0
var spawn_timer := 0.0
var selftest := false

func _ready() -> void:
	randomize()
	player.area_entered.connect(_on_player_area_entered)
	selftest = "--selftest" in OS.get_cmdline_user_args()
	if not selftest:
		best = _load_best()
	_show_menu()
	if selftest:
		_start()

func _show_menu() -> void:
	state = State.MENU
	player.visible = false
	message_label.text = "DODGER\nCatch coins, dodge red.\nSpace or Enter to start"
	_update_hud()

func _start() -> void:
	for f in get_tree().get_nodes_in_group("fallers"):
		f.queue_free()
	var size := get_viewport_rect().size
	player.position = Vector2(size.x / 2.0, size.y - 60.0)
	player.visible = true
	elapsed = 0.0
	coins = 0
	lives = START_LIVES
	invuln = 0.0
	spawn_timer = 0.0
	state = State.PLAYING
	message_label.text = ""
	_update_hud()

func _process(delta: float) -> void:
	if selftest:
		_selftest_step(delta)
	if state != State.PLAYING:
		if _confirm_pressed() and not selftest:
			_start()
		return
	elapsed += delta
	if invuln > 0.0:
		invuln = maxf(0.0, invuln - delta)
		player.modulate.a = 0.35 if int(invuln * 10.0) % 2 == 0 else 1.0
	else:
		player.modulate.a = 1.0
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.25, 0.9 - elapsed * 0.01)
		_spawn(randf() < 0.25)
	_update_hud()

func _confirm_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER)

func _spawn(is_coin: bool, at: Vector2 = Vector2.INF) -> void:
	var f := FALLER.instantiate()
	f.is_coin = is_coin
	f.speed = 200.0 + elapsed * 4.0
	var size := get_viewport_rect().size
	f.position = Vector2(randf_range(20.0, size.x - 20.0), -20.0) if at == Vector2.INF else at
	f.add_to_group("fallers")
	add_child(f)

func _on_player_area_entered(area: Area2D) -> void:
	if state != State.PLAYING:
		return
	if area.is_coin:
		coins += 1
		area.queue_free()
	elif invuln <= 0.0:
		area.queue_free()
		lives -= 1
		invuln = INVULN_TIME
		if lives <= 0:
			_game_over()
		_update_hud()

func _game_over() -> void:
	state = State.GAME_OVER
	player.modulate.a = 1.0
	var new_best := _score() > best
	if new_best:
		best = _score()
		if not selftest:
			_save_best()
	message_label.text = "GAME OVER  score %d%s\nSpace or Enter to play again" % [_score(), "  (new best!)" if new_best else ""]

func _score() -> int:
	return coins * 10 + int(elapsed)

func _update_hud() -> void:
	score_label.text = "Score %d" % _score()
	lives_label.text = "Lives %d" % lives
	best_label.text = "Best %d" % best

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("score", "best", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save(SAVE_PATH)

# --- headless self-test of the rules ---
var _st_t := 0.0
var _st_stage := 0

func _selftest_step(delta: float) -> void:
	_st_t += delta
	if _st_t < 0.3 or state == State.MENU:
		return
	match _st_stage:
		0:  # coin scores
			_spawn(true, player.position)
			_st_stage = 1
			_st_t = 0.0
		1:
			if _st_t > 0.3:
				_selftest_expect(coins == 1, "coin not collected")
				_spawn(false, player.position)
				_st_stage = 2
				_st_t = 0.0
		2:  # hazard costs a life, then invulnerability blocks the next one
			if _st_t > 0.3:
				_selftest_expect(lives == START_LIVES - 1 and invuln > 0.0, "hazard did not cost a life")
				_spawn(false, player.position)
				_st_stage = 3
				_st_t = 0.0
		3:
			if _st_t > 0.3:
				_selftest_expect(lives == START_LIVES - 1, "invulnerability did not block a hit")
				invuln = 0.0
				_spawn(false, player.position)
				_st_stage = 4
				_st_t = 0.0
		4:
			if _st_t > 0.3:
				_selftest_expect(lives == START_LIVES - 2, "second hit did not count")
				invuln = 0.0
				_spawn(false, player.position)
				_st_stage = 5
				_st_t = 0.0
		5:
			if _st_t > 0.3:
				_selftest_expect(state == State.GAME_OVER and best == _score(), "game did not end / best not updated")
				print("SELFTEST_OK coins=%d score=%d best=%d" % [coins, _score(), best])
				get_tree().quit(0)

func _selftest_expect(cond: bool, why: String) -> void:
	if not cond:
		print("SELFTEST_FAIL " + why)
		get_tree().quit(1)
