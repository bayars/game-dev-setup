extends Area2D
## Something that falls from the top: a hazard (red square) or a coin (yellow circle).

var is_coin := false
var speed := 200.0

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > get_viewport_rect().size.y + 40.0:
		queue_free()

func _draw() -> void:
	if is_coin:
		draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.85, 0.2))
	else:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.9, 0.25, 0.25))
