extends Area2D
## Something that falls from the top: a spiked mine (hazard) or a spinning gold coin.
## Sprites are 8-frame sheets rendered in Blender (art-src/sprites/).

const COIN_SHEET := preload("res://assets/sprites/coin_sheet.png")
const MINE_SHEET := preload("res://assets/sprites/hazard_sheet.png")
const FRAMES := 8
const FPS := 12.0

var is_coin := false
var speed := 200.0
var _sprite: Sprite2D
var _phase := randf() * FRAMES

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = COIN_SHEET if is_coin else MINE_SHEET
	_sprite.hframes = FRAMES
	_sprite.scale = Vector2(0.5, 0.5)
	add_child(_sprite)

func _process(delta: float) -> void:
	position.y += speed * delta
	_phase += delta * FPS
	_sprite.frame = int(_phase) % FRAMES
	if position.y > get_viewport_rect().size.y + 40.0:
		queue_free()
