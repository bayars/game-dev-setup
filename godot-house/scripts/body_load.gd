class_name BodyLoad
extends Carryable
## Daniel, after the accident, as a load the brothers can move. Alone he is dragged along the floor (slow,
## loud, and it leaves marks); together he is lifted between them (fast and quiet, but both are busy and
## anyone who sees them knows). While carried the ragdoll rests in the "limp" pose and follows this node;
## set down, he falls back under physics where he is.

const HIPS := 0.12                         # the limp pose has its hips this high above the actor's origin

var body: Actor

func setup_body(a: Actor) -> void:
	body = a
	label = "Daniel"
	size = Vector3(0.55, 0.4, 1.8)
	carry_height = 0.55
	var p := a.body_position()
	global_position = Vector3(p.x, a.global_position.y, p.z)

func lift() -> void:
	body.hold_limp()

## Lets him fall where he is now (the ragdoll takes over again).
func drop() -> void:
	body.global_transform = Transform3D(Basis(Vector3.UP, rotation.y), global_position - Vector3(0, 0.02, 0))
	body.go_limp()

## Where he lies (the hips), carried or not.
func where() -> Vector3:
	return body.body_position()

func _process(_delta: float) -> void:
	if body == null or not body.is_held():
		return
	# lifted: the hips at the carrying height; dragged: lying on the floor
	var down := HIPS if carriers.size() > 1 else 0.02
	body.global_transform = Transform3D(Basis(Vector3.UP, rotation.y), global_position - Vector3(0, down, 0))
