class_name People
extends RefCounted
## The cast: one model per person (art-src/models/people.py profiles, built with
## `scripts/delegate.sh models person_<id>`). Every model is built 1.78 m tall with the same rig and clips;
## the game scales it to the person's height (keep `height` in step with people.py).

const BUILT_HEIGHT := 1.78

const CAST := {
	"Nico": {"id": "nico", "height": 1.80},
	"Tomas": {"id": "tomas", "height": 1.76},
	"Daniel": {"id": "daniel", "height": 1.70},
	"Linda": {"id": "linda", "height": 1.67},
	"Robert": {"id": "robert", "height": 1.84},
	"Sofia": {"id": "sofia", "height": 1.62},
	"Rose": {"id": "rose", "height": 1.56},
}

## Every clip each model has (Godot strips `_loop` from the looping ones).
const CLIPS := ["idle", "walk", "run", "open_door", "carry", "drag", "hammer", "drill", "lift", "kneel", "wire",
	"talk", "search", "crouch", "phone", "sit", "react_fall", "limp"]

static func model(who: String) -> PackedScene:
	return load("res://assets/models/person_%s.glb" % CAST[who].id)

## Uniform scale that takes the built model to this person's height.
static func scale_of(who: String) -> float:
	return CAST[who].height / BUILT_HEIGHT
