extends Area2D
## Player: a Blender-made hover drone (8-frame idle loop), moved with WASD or the arrow keys.

const SPEED := 420.0
const HALF := 16.0
const FPS := 10.0

@onready var sprite: Sprite2D = $Sprite

func _process(delta: float) -> void:
	var dir := Vector2(
		float(_pressed(KEY_RIGHT, KEY_D)) - float(_pressed(KEY_LEFT, KEY_A)),
		float(_pressed(KEY_DOWN, KEY_S)) - float(_pressed(KEY_UP, KEY_W)))
	position += dir.normalized() * SPEED * delta
	var size := get_viewport_rect().size
	position = position.clamp(Vector2(HALF, HALF), size - Vector2(HALF, HALF))
	sprite.frame = int(Time.get_ticks_msec() / 1000.0 * FPS) % sprite.hframes

func _pressed(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)
