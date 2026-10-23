extends Area2D
## Greybox player: a square moved with WASD or the arrow keys, kept on screen.

const SPEED := 420.0
const HALF := 16.0

func _process(delta: float) -> void:
	var dir := Vector2(
		float(_pressed(KEY_RIGHT, KEY_D)) - float(_pressed(KEY_LEFT, KEY_A)),
		float(_pressed(KEY_DOWN, KEY_S)) - float(_pressed(KEY_UP, KEY_W)))
	position += dir.normalized() * SPEED * delta
	var size := get_viewport_rect().size
	position = position.clamp(Vector2(HALF, HALF), size - Vector2(HALF, HALF))

func _pressed(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

func _draw() -> void:
	draw_rect(Rect2(-HALF, -HALF, HALF * 2, HALF * 2), Color(0.3, 0.8, 1.0))
