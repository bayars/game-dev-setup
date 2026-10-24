extends Node3D
## "Walk Home": a short 3D story. Walk up the path at dusk and open the door of the house.
##
## Everything is built here in code from the Blender glTF models in assets/models/.
## Flags (after the project path, behind `--`):
##   --selftest   headless check: autoplay the whole story fast, print SELFTEST_OK / SELFTEST_FAIL
##   --autoplay   play the story by itself at normal speed (used for screenshots/movies)
##   --start-z=N  spawn the walker at z = N instead of 13 (closer to the house: quick screenshots)

enum Phase { TITLE, WALK, AT_DOOR, OPENING, END }

const PERSON := preload("res://assets/models/person.glb")
const HOUSE := preload("res://assets/models/house.glb")
const PINE := preload("res://assets/models/tree_pine.glb")
const ROUND_TREE := preload("res://assets/models/tree_round.glb")
const LAMP := preload("res://assets/models/lamp.glb")

## Blender material name -> PBR texture set (see Graphics.retexture).
const HOUSE_MATS := {
	"Wall": {"tex": "plaster", "m": 2.2},
	"Trim": {"tex": "wood", "m": 1.4, "tint": Color(0.93, 0.9, 0.84), "ns": 0.5, "rough": 0.8},
	"Roof": {"tex": "roof", "m": 2.4},
	"RoofRidge": {"tex": "roof", "m": 2.4, "tint": Color(0.55, 0.45, 0.42)},
	"Stone": {"tex": "stone", "m": 3.0},
	"Brick": {"tex": "brick", "m": 1.7},
	"Floor": {"tex": "wood", "m": 1.3},
	"WoodDark": {"tex": "wood", "m": 1.0, "tint": Color(0.55, 0.5, 0.48)},
	"DoorRed": {"tex": "wood", "m": 1.0, "tint": Color(1.35, 0.30, 0.25), "world": false, "ns": 0.6, "rough": 0.7},
	"Plant": {"tex": "foliage", "m": 0.5, "orig": 1.7},
}
const TREE_MATS := {
	"Bark": {"tex": "bark", "m": 1.4, "world": false},
	"Bark2": {"tex": "bark", "m": 1.4, "world": false},
	"PineA": {"tex": "foliage", "m": 1.3, "orig": 1.8, "world": false},
	"PineB": {"tex": "foliage", "m": 1.3, "orig": 1.8, "world": false},
	"PineC": {"tex": "foliage", "m": 1.3, "orig": 1.8, "world": false},
	"LeafA": {"tex": "foliage", "m": 1.3, "orig": 1.8, "world": false},
	"LeafB": {"tex": "foliage", "m": 1.3, "orig": 1.8, "world": false},
	"LeafC": {"tex": "foliage", "m": 1.3, "orig": 1.8, "world": false},
}

const HOUSE_POS := Vector3(0, 0, -18)   # the house front (door side) faces +Z, toward the player
const SPAWN := Vector3(0, 0.05, 13)

var phase := Phase.TITLE
var gfx: Graphics
var player: Player
var door_hinge: Node3D
var interior_light: OmniLight3D
var door_open_angle := deg_to_rad(105.0)

var _dim: ColorRect
var _portrait_light: DirectionalLight3D
var _title: Label
var _sub: Label
var _story: Label
var _objective: Label
var _hint: Label
var _toast: Label
var _time := 0.0
var _selftest := false
var _autoplay := false
var _auto_wait := 0.0
var _end_time := 0.0
var _spawn_z := SPAWN.z

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_selftest = "--selftest" in args
	_autoplay = _selftest or "--autoplay" in args
	for a in args:
		if a.begins_with("--start-z="):
			_spawn_z = float(a.substr(10))
	gfx = Graphics.new()
	add_child(gfx)
	gfx.build_environment(self)
	_build_ground()
	_build_house()
	_build_trees()
	_build_lamps()
	_build_garden()
	gfx.build_grass(self, _grass_keep_out)
	var forced := ""
	for a in args:
		if a.begins_with("--quality="):
			forced = a.substr(10)
	gfx.load_level("low" if _selftest else forced, not _selftest)
	_build_player()
	_build_ui()
	gfx.changed.connect(_on_quality_changed)
	if _selftest:
		Engine.time_scale = 4.0
	_show_title()

# ---------------------------------------------------------------- world

func _flat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _build_ground() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)

	var grass := MeshInstance3D.new()      # grass + gravel path in one shader (see shaders/ground.gdshader)
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	grass.mesh = plane
	grass.material_override = gfx.ground_material()
	add_child(grass)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stone_mat := gfx.pbr("stone", 0.8, Color(0.9, 0.88, 0.84), true, 1.2)
	var z := 18.0
	while z > -13.0:
		for side in [-1.0, 1.0]:
			var stone := MeshInstance3D.new()      # edging stones: flattened, slightly lumpy spheres
			var sm := SphereMesh.new()
			sm.radial_segments = 20
			sm.rings = 10
			var w := rng.randf_range(0.3, 0.55)
			var h := rng.randf_range(0.12, 0.25)
			sm.radius = 0.5
			sm.height = 1.0
			stone.mesh = sm
			stone.scale = Vector3(w, h, rng.randf_range(0.3, 0.5))
			stone.material_override = stone_mat
			stone.position = Vector3(side * rng.randf_range(1.3, 1.5), h * 0.3, z + rng.randf_range(-0.3, 0.3))
			stone.rotation.y = rng.randf() * TAU
			add_child(stone)
		z -= rng.randf_range(1.2, 1.9)

## True where grass blades must not grow: on the path, under the house and porch, in the flower beds.
func _grass_keep_out(p: Vector2) -> bool:
	if absf(p.x) < 1.55 and p.y > -14.5:
		return true
	if absf(p.x) < 6.0 and p.y < -12.8 and p.y > -22.5:
		return true
	return false

func _build_house() -> void:
	var house: Node3D = HOUSE.instantiate()
	house.position = HOUSE_POS
	add_child(house)
	gfx.retexture(house, HOUSE_MATS)
	door_hinge = house.find_child("DoorHinge", true, false)
	if door_hinge == null:
		push_error("house.glb has no DoorHinge node")

	interior_light = OmniLight3D.new()
	interior_light.position = HOUSE_POS + Vector3(0, 2.4, 0.2)
	interior_light.light_color = Color(1.0, 0.74, 0.44)
	interior_light.light_energy = 0.5
	interior_light.omni_range = 9.0
	interior_light.light_volumetric_fog_energy = 1.0
	add_child(interior_light)
	_add_glow(HOUSE_POS + Vector3(0, 2.3, 4.6), 0.5, 5.0)         # porch light (kept away from the wall: close lights blow out)

	# the trigger in front of the door
	var zone := Area3D.new()
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(3.4, 2.4, 2.0)
	zone_shape.shape = zone_box
	zone.position = HOUSE_POS + Vector3(0, 1.2, 4.2)   # the last two metres before the door
	zone.add_child(zone_shape)
	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)
	add_child(zone)

func _add_glow(pos: Vector3, energy: float, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = energy
	l.omni_range = range_m
	add_child(l)

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20241022
	var placed: Array[Vector3] = []
	var attempts := 0
	while placed.size() < 52 and attempts < 4000:
		attempts += 1
		var p := Vector3(rng.randf_range(-36.0, 36.0), 0.0, rng.randf_range(-46.0, 26.0))
		if absf(p.x) < 4.8 and p.z > -16.0:
			continue                                   # keep the path clear
		if absf(p.x) < 9.5 and p.z < -9.0 and p.z > -27.0:
			continue                                   # keep the yard around the house clear
		var close := false
		for q in placed:
			if q.distance_to(p) < 3.8:
				close = true
				break
		if close:
			continue
		placed.append(p)
		var tree: Node3D = (PINE if rng.randf() < 0.55 else ROUND_TREE).instantiate()
		tree.position = p
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		add_child(tree)
		gfx.retexture(tree, TREE_MATS)

func _build_lamps() -> void:
	for spot in [Vector2(-2.3, 9.0), Vector2(2.3, 2.0), Vector2(-2.3, -5.0), Vector2(2.3, -10.5)]:
		var lamp: Node3D = LAMP.instantiate()
		lamp.position = Vector3(spot.x, 0.0, spot.y)
		add_child(lamp)
		var l := OmniLight3D.new()
		l.position = Vector3(spot.x, 2.2, spot.y)
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 1.7
		l.omni_range = 9.0
		gfx.add_lamp_light(l)
		add_child(l)

func _build_garden() -> void:
	var bush_mat := gfx.pbr("foliage", 0.7, Color(0.26, 0.5, 0.24), true, 1.3)
	for x in [-3.55, -2.35, 2.35, 3.55]:
		var bush := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 0.95
		sm.radial_segments = 32
		sm.rings = 16
		bush.mesh = sm
		bush.material_override = bush_mat
		bush.position = HOUSE_POS + Vector3(x, 0.4, 3.3)
		bush.scale = Vector3(1.3, 1.0, 1.0)
		add_child(bush)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var palette := [Color(0.95, 0.35, 0.45), Color(0.98, 0.82, 0.3), Color(0.85, 0.85, 0.95), Color(0.7, 0.45, 0.9)]
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.07
	flower_mesh.height = 0.14
	var mats: Array[StandardMaterial3D] = []
	for c in palette:
		mats.append(_flat(c, 0.7))
	for i in 90:
		var f := MeshInstance3D.new()
		f.mesh = flower_mesh
		f.material_override = mats[rng.randi() % mats.size()]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		f.position = Vector3(side * rng.randf_range(1.9, 4.2), 0.08, rng.randf_range(-13.0, 12.0))
		add_child(f)

func _build_player() -> void:
	player = Player.new()
	player.position = Vector3(SPAWN.x, SPAWN.y, _spawn_z)
	add_child(player)
	player.setup(PERSON)
	gfx.style_person(player.model)
	player.frozen = true

# ---------------------------------------------------------------- UI

func _label(size: int, color: Color, halign: HorizontalAlignment, valign: VerticalAlignment) -> Label:
	var l := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = maxi(4, size / 8)
	settings.outline_color = Color(0, 0, 0, 0.8)
	l.label_settings = settings
	l.horizontal_alignment = halign
	l.vertical_alignment = valign
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.07, 0.18)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_dim)

	_title = _label(88, Color(1.0, 0.9, 0.72), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_title.offset_top = 36.0
	_title.text = "THE WALK HOME"
	layer.add_child(_title)
	_sub = _label(28, Color(0.95, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_sub.offset_bottom = -48.0
	_sub.text = "Press Space to begin"
	layer.add_child(_sub)

	_story = _label(36, Color(1.0, 0.96, 0.86), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_story.offset_bottom = -80.0
	_story.modulate.a = 0.0
	layer.add_child(_story)
	_hint = _label(32, Color(1.0, 0.9, 0.55), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_hint.offset_bottom = -80.0
	_hint.modulate.a = 0.0
	layer.add_child(_hint)
	_toast = _label(20, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	_toast.offset_right = -24.0
	_toast.offset_top = 18.0
	_toast.modulate.a = 0.0
	layer.add_child(_toast)
	_objective = _label(22, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_objective.offset_left = 28.0
	_objective.offset_top = 22.0
	_objective.modulate.a = 0.0
	layer.add_child(_objective)

func _on_quality_changed(level_name: String) -> void:
	if _toast == null:
		return
	_toast.text = "Graphics: %s   (G to change)" % level_name
	_toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_property(_toast, "modulate:a", 0.0, 0.8)

func _fade(node: CanvasItem, alpha: float, seconds: float) -> Tween:
	var t := create_tween()
	t.tween_property(node, "modulate:a", alpha, seconds)
	return t

func _say(text: String, hold: float) -> void:
	_story.text = text
	var t := create_tween()
	t.tween_property(_story, "modulate:a", 1.0, 0.6)
	t.tween_interval(hold)
	t.tween_property(_story, "modulate:a", 0.0, 0.6)
	await t.finished

# ---------------------------------------------------------------- story

func _show_title() -> void:
	phase = Phase.TITLE
	player.frozen = true
	player.cam_yaw = PI            # camera in front of the walker for a close portrait
	player.cam_fov = 26.0          # long lens: flattering, keeps the head in proportion
	player.cam_distance = 1.75
	player.cam_pitch = -0.02
	player.cam_focus = 1.60
	gfx.set_portrait(true)
	if _portrait_light == null:      # soft warm light from the camera side, only for the title portrait
		_portrait_light = DirectionalLight3D.new()
		_portrait_light.light_color = Color(1.0, 0.86, 0.72)
		_portrait_light.light_energy = 2.2
		_portrait_light.rotation_degrees = Vector3(-12, 200, 0)
		_portrait_light.shadow_enabled = false
		add_child(_portrait_light)

func _begin() -> void:
	phase = Phase.WALK
	gfx.set_portrait(false)
	_fade(_title, 0.0, 0.8)
	_fade(_sub, 0.0, 0.8)
	# the camera swings from the portrait in front of the walker to the follow position behind
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_dim, "color:a", 0.0, 1.4)
	t.tween_property(player, "cam_yaw", 0.0, 1.8)
	t.tween_property(player, "cam_distance", 4.4, 1.8)
	t.tween_property(player, "cam_pitch", -0.22, 1.8)
	t.tween_property(player, "cam_focus", 1.5, 1.8)
	t.tween_property(player, "cam_fov", 62.0, 1.8)
	if _portrait_light:
		t.tween_property(_portrait_light, "light_energy", 0.0, 1.8)
	if not _autoplay and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_intro()
	await t.finished
	player.frozen = false

func _intro() -> void:
	await get_tree().create_timer(0.8).timeout
	await _say("The day was long.", 3.0)
	if phase != Phase.WALK:
		return
	await _say("Through the trees, a light is waiting.", 3.6)
	if phase == Phase.WALK:
		_objective.text = "Follow the path to the door   (WASD move, mouse look, Shift run)"
		_fade(_objective, 0.85, 0.8)

func _on_zone_entered(body: Node3D) -> void:
	if body == player and phase == Phase.WALK:
		phase = Phase.AT_DOOR
		_hint.text = "Press E to open the door"
		_fade(_hint, 1.0, 0.3)
		_fade(_objective, 0.0, 0.3)
		_fade(_story, 0.0, 0.2)

func _on_zone_exited(body: Node3D) -> void:
	if body == player and phase == Phase.AT_DOOR:
		phase = Phase.WALK
		_fade(_hint, 0.0, 0.3)
		_fade(_objective, 0.85, 0.3)

func _open_door() -> void:
	phase = Phase.OPENING
	player.frozen = true
	player.move_input = Vector2.ZERO
	player.face_toward(HOUSE_POS + Vector3(0, 0, 3.0))
	_fade(_hint, 0.0, 0.2)
	player.play_action("open_door")
	var t := create_tween().set_parallel(true)   # the door starts moving once the hand is on the knob
	t.tween_property(door_hinge, "rotation:y", door_open_angle, 1.8).set_delay(0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(interior_light, "light_energy", 2.2, 1.8).set_delay(0.55)
	await t.finished
	player.end_action()
	await _say("Welcome home.", 2.2)
	_end()

func _end() -> void:
	phase = Phase.END
	_end_time = _time
	_title.text = "HOME"
	_sub.text = "R: walk again      Esc: quit"
	_fade(_title, 1.0, 1.0)
	_fade(_sub, 1.0, 1.0)
	create_tween().tween_property(_dim, "color:a", 0.55, 1.2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------------------------------------------------------------- input and loop

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER:
				if phase == Phase.TITLE:
					_begin()
			KEY_E:
				if phase == Phase.AT_DOOR:
					_open_door()
			KEY_G:
				gfx.cycle()
			KEY_R:
				if phase == Phase.END:
					get_tree().reload_current_scene()
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					get_tree().quit()
	elif event is InputEventMouseButton and event.pressed:
		if phase in [Phase.WALK, Phase.AT_DOOR] and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_time += delta
	if phase == Phase.TITLE:
		player.cam_yaw = PI + sin(_time * 0.35) * 0.22   # slow sway around the portrait
	if _autoplay:
		_autoplay_step(delta)

## Plays the story without input. In --selftest mode it also verifies the result.
func _autoplay_step(delta: float) -> void:
	match phase:
		Phase.TITLE:
			if _time > 0.5:
				_begin()
		Phase.WALK:
			player.move_input = Vector2(0, -1)
			if _selftest and _time > 90.0:
				_fail("never reached the door (player at %s)" % player.global_position)
		Phase.AT_DOOR:
			_auto_wait += delta
			player.move_input = Vector2(0, -1) if _auto_wait < 1.0 else Vector2.ZERO   # walk up to the door
			if _auto_wait > 1.6:
				_open_door()
		Phase.END:
			if _selftest:
				_check_result()
			elif _time - _end_time > 3.0:
				get_tree().quit()

func _check_result() -> void:
	var p := player.global_position
	for clip in ["idle", "walk", "run", "open_door"]:
		if not player.has_animation(clip):
			_fail("missing animation " + clip)
			return
	if door_hinge == null or door_hinge.rotation.y < deg_to_rad(95.0):
		_fail("door did not open")
	elif p.y < -0.2 or p.z > -13.5 or p.z < -15.0 or absf(p.x) > 1.5:
		_fail("player ended up in the wrong place: %s" % p)
	elif interior_light.light_energy < 1.8:
		_fail("interior light did not come on")
	else:
		print("SELFTEST_OK pos=(%.1f, %.1f, %.1f) door=%.0f deg" % [p.x, p.y, p.z, rad_to_deg(door_hinge.rotation.y)])
		get_tree().quit(0)

func _fail(why: String) -> void:
	print("SELFTEST_FAIL " + why)
	get_tree().quit(1)
