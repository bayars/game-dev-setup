class_name Token
extends Node3D
## A sign of what really happened (a game rule, not forensics): the fallen stud, dust, loose nails, drag
## marks... It lies somewhere in the house until a brother tidies it away (E, a few seconds) or takes it
## (an `item`, such as the nail gun). Residents who see one remember it; the police find the ones left.
## A faint ring marks it while the cover-up runs, so the player can find them.

var id := ""
var label := ""
var seconds := 3.0
var item := ""                             # taking it puts this in the brother's hands instead
var main := false                          # the accident's own piece (worse to leave behind)
var room := ""
var noticed_by: Array[String] = []
var linked: Node3D = null                  # a scene piece that goes with it (the fallen stud, the sheet)
var _ring: MeshInstance3D

static func make(spec: Dictionary, at: Vector3, parent: Node) -> Token:
	var t := Token.new()
	t.id = spec.id
	t.label = spec.label
	t.seconds = spec.get("seconds", 3.0)
	t.item = spec.get("item", "")
	t.main = spec.get("main", false)
	parent.add_child(t)
	t.global_position = at
	t.room = House.room_at(at + Vector3(0, 0.3, 0))
	t._build()
	return t

func _build() -> void:
	var dark := _mat(Color(0.16, 0.13, 0.11, 0.85))
	var white := _mat(Color(0.93, 0.92, 0.88, 0.9))
	var steel := _mat(Color(0.7, 0.72, 0.75, 1.0))
	steel.metallic = 0.8
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + str(global_position.snapped(Vector3.ONE * 0.1)))
	match id:
		"scuffs":
			for k in 4:
				_flat(Vector3(rng.randf_range(0.25, 0.5), 0.004, 0.025), Vector3(rng.randf_range(-0.3, 0.3), 0.006, rng.randf_range(-0.3, 0.3)), rng.randf() * PI, dark)
		"drag":
			for side in [-0.12, 0.12]:
				_flat(Vector3(0.03, 0.004, 0.9), Vector3(side, 0.006, 0), 0.0, dark)
		"dust":
			for k in 7:
				var r := rng.randf_range(0.08, 0.2)
				_flat(Vector3(r, 0.003, r * rng.randf_range(0.6, 1.2)), Vector3(rng.randf_range(-0.4, 0.4), 0.005, rng.randf_range(-0.4, 0.4)), rng.randf() * PI, white)
		"nails":
			for k in 9:
				var n := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.004
				c.bottom_radius = 0.004
				c.height = 0.08
				c.radial_segments = 6
				n.mesh = c
				n.material_override = steel
				n.position = Vector3(rng.randf_range(-0.3, 0.3), 0.006, rng.randf_range(-0.3, 0.3))
				n.rotation = Vector3(PI / 2, rng.randf() * PI, 0)
				add_child(n)
		"nailgun":
			var tools := Actor.TOOLS.instantiate()
			var src := tools.get_node_or_null("T_nailgun") as Node3D
			if src:
				var g := src.duplicate() as Node3D
				g.rotation = Vector3(PI / 2, 0.7, 0)
				g.position.y = 0.05
				add_child(g)
			tools.free()
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.54
	torus.rings = 40
	_ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale.y = 0.1
	_ring.position.y = 0.02
	add_child(_ring)

func _flat(size: Vector3, at: Vector3, yaw: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## The prompt verb: "Stand the fallen stud back up", "Take the nail gun", "Tidy the gypsum dust..."
func verb() -> String:
	match id:
		"stud": return "Stand the fallen stud back up"
		"sheet": return "Carry the broken sheet out to the van"
		"nailgun": return "Take the nail gun"
	return "Tidy up: " + label.to_lower()

## Where it is, for sight lines (a little above the floor).
func point() -> Vector3:
	return global_position + Vector3(0, 0.15, 0)
