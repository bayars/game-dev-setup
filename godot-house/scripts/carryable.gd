class_name Carryable
extends Node3D
## A heavy object the brothers move (boxed couch, dishwasher; on day 2 the body uses the same rules).
## One carrier: slow and loud (noise rings residents hear). Two carriers: fast and quiet.
## The look is a prop from house_props.glb; its long side runs along the carriers' walking direction.

var label := ""
var size := Vector3.ONE                # footprint and height, metres (x across, z along the carry)
var carriers: Array[Actor] = []
var carry_height := 0.45               # lifted this high between two carriers

func setup(what: String, house: House, prop_name: String, footprint: Vector3, yaw_deg: float) -> void:
	label = what
	size = footprint
	house.prop(prop_name, Vector3.ZERO, yaw_deg, false, self)

func is_carried() -> bool:
	return not carriers.is_empty()

func lead() -> Actor:
	return carriers[0] if carriers.size() > 0 else null

## Picked up / set down (the body overrides these).
func lift() -> void:
	pass

func drop() -> void:
	pass
