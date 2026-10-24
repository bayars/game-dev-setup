class_name Carryable
extends Node3D
## A heavy object the brothers move (boxed couch, dishwasher; on day 2 the body uses the same rules).
## One carrier: slow and loud (noise rings residents hear). Two carriers: fast and quiet.

var label := ""
var carriers: Array[Actor] = []

func setup(what: String, size: Vector3, color: Color) -> void:
	label = what
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	mi.position.y = size.y / 2.0
	add_child(mi)
	var tag := Label3D.new()
	tag.text = what
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 28
	tag.outline_size = 8
	tag.pixel_size = 0.006
	tag.position.y = size.y + 0.35
	tag.modulate = Color(1, 0.9, 0.6)
	add_child(tag)

func is_carried() -> bool:
	return not carriers.is_empty()

func lead() -> Actor:
	return carriers[0] if carriers.size() > 0 else null
