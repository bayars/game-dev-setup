class_name Graphics
extends Node
## Rendering for "Walk Home" (Forward+): physical sunset sky, sun with soft shadows, SDFGI bounce light,
## volumetric fog with light shafts, SSAO/SSIL, bloom, depth of field for the title portrait, the PBR
## material library (textures baked in Blender/Cycles, see art-src/textures) and quality presets.
##
## G cycles the quality level; --quality=low|medium|high|ultra forces one. The default follows the GPU:
## discrete NVIDIA/AMD -> ULTRA, software renderers -> LOW, anything else (integrated) -> MEDIUM.

enum Level { LOW, MEDIUM, HIGH, ULTRA }
const NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
const TEX := "res://assets/textures/"
const GRASS_CLUMPS := 26000
const GRASS_AT_LEVEL := [0, 6000, 15000, 26000]
const CONFIG := "user://graphics.cfg"

signal changed(level_name: String)

var level := Level.HIGH
var env: Environment
var sun: DirectionalLight3D
var attrs: CameraAttributesPractical
var _grass: MultiMeshInstance3D
var _lamps: Array[OmniLight3D] = []
var _post: ColorRect
var _cache := {}
var _portrait := false

# ---------------------------------------------------------------- materials

func tex(name: String, kind: String) -> Texture2D:
	return load(TEX + "%s_%s.png" % [name, kind])

## A tiling PBR material. `meters` is the size of one texture tile in the world; the texture is projected
## triplanar so the models need no UVs. `world` false projects in object space (door, trees).
func pbr(name: String, meters: float, tint := Color.WHITE, world := true, normal_scale := 1.0, rough := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s|%s" % [name, meters, tint, world, normal_scale, rough]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name, "albedo")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = tex(name, "normal")
	m.normal_scale = normal_scale
	m.roughness_texture = tex(name, "rough")
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3.ONE / meters
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m

## Replaces imported flat materials by name. `table` maps a Blender material name to a Dictionary:
## tex (texture set), m (metres per tile), and either tint (Color) or orig (multiplier on the model's colour);
## optional world (bool), ns (normal strength), rough.
func retexture(root: Node, table: Dictionary) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			if "Glow" in src.resource_name:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # lights sit inside the lantern
			var spec: Dictionary = table.get(src.resource_name, {})
			if spec.is_empty():
				continue
			var tint: Color = spec.get("tint", Color.WHITE)
			if spec.has("orig"):
				tint = src.albedo_color * float(spec["orig"])
				tint.a = 1.0
			mi.set_surface_override_material(s, pbr(spec["tex"], spec["m"], tint, spec.get("world", true),
				spec.get("ns", 1.0), spec.get("rough", 1.0)))

## Skin scatters light; cloth and hair get a soft rim so they do not look like plastic.
func style_person(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var n := src.resource_name
			var m := src.duplicate() as BaseMaterial3D
			if n == "Skin" or n == "FaceSkin":
				m.subsurf_scatter_enabled = true
				m.subsurf_scatter_strength = 0.15
				m.subsurf_scatter_skin_mode = true
				m.rim_enabled = true
				m.rim = 0.25
				m.rim_tint = 0.6
			elif n in ["Jacket", "JacketDark", "Scarf", "ScarfStripe", "Pants", "Pack"]:
				m.rim_enabled = true
				m.rim = 0.15
				m.rim_tint = 0.5
			elif n == "Hair":
				m.rim_enabled = true
				m.rim = 0.5
				m.rim_tint = 0.4
				m.anisotropy_enabled = true
				m.anisotropy = 0.6
			else:
				continue
			mi.set_surface_override_material(s, m)

# ---------------------------------------------------------------- world

func build_environment(parent: Node3D) -> void:
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.rayleigh_coefficient = 2.6
	sky_mat.rayleigh_color = Color(0.22, 0.36, 0.62)
	sky_mat.mie_coefficient = 0.022
	sky_mat.mie_eccentricity = 0.66
	sky_mat.mie_color = Color(0.95, 0.62, 0.42)
	sky_mat.turbidity = 11.0
	sky_mat.sun_disk_scale = 1.0
	sky_mat.ground_color = Color(0.14, 0.12, 0.10)
	sky_mat.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_512

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.tonemap_white = 6.0

	env.fog_enabled = true
	env.fog_light_color = Color(0.88, 0.58, 0.46)
	env.fog_density = 0.0025
	env.fog_sun_scatter = 0.5
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.3

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0045
	env.volumetric_fog_albedo = Color(0.92, 0.78, 0.68)
	env.volumetric_fog_gi_inject = 1.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.5
	env.volumetric_fog_temporal_reprojection_enabled = true

	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_read_sky_light = true
	env.sdfgi_energy = 1.0

	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.25
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 0.9

	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12

	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_near_enabled = false
	attrs.dof_blur_amount = 0.12

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.camera_attributes = attrs
	parent.add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.52)
	sun.light_energy = 2.4
	sun.rotation_degrees = Vector3(-14, 18, 0)   # low evening sun, behind the player
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.6              # soft contact-hardening shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.light_volumetric_fog_energy = 1.6
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.4
	parent.add_child(sun)

	_post = ColorRect.new()                       # film finish, under the UI layer
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/post.gdshader")
	_post.material = sm
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.add_child(_post)
	parent.add_child(layer)

func ground_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/ground.gdshader")
	for k in ["grass", "path"]:
		sm.set_shader_parameter(k + "_a", tex(k, "albedo"))
		sm.set_shader_parameter(k + "_n", tex(k, "normal"))
		sm.set_shader_parameter(k + "_r", tex(k, "rough"))
	return sm

func add_lamp_light(l: OmniLight3D) -> void:
	l.light_size = 0.12
	l.omni_attenuation = 1.3
	l.light_volumetric_fog_energy = 1.4
	_lamps.append(l)

func build_grass(parent: Node3D, keep_out: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _clump_mesh(rng)
	mm.instance_count = GRASS_CLUMPS
	var i := 0
	var guard := 0
	while i < GRASS_CLUMPS and guard < GRASS_CLUMPS * 6:
		guard += 1
		var near := rng.randf() < 0.72
		var x := rng.randf_range(1.2, 15.0) if near else rng.randf_range(15.0, 38.0)
		x *= -1.0 if rng.randf() < 0.5 else 1.0
		var z := rng.randf_range(-34.0, 26.0)
		if keep_out.call(Vector2(x, z)):
			continue
		var s := rng.randf_range(0.7, 1.45)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, 0.0, z)))
		i += 1
	mm.instance_count = i
	mm.visible_instance_count = GRASS_AT_LEVEL[level] if GRASS_AT_LEVEL[level] < i else i
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	_grass = MultiMeshInstance3D.new()
	_grass.multimesh = mm
	_grass.material_override = mat
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_grass.custom_aabb = AABB(Vector3(-45, -1, -45), Vector3(90, 3, 90))
	parent.add_child(_grass)

## One clump = 8 bent, tapered blades (4 segments each) pointing in random directions.
func _clump_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 4
	for b in 8:
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var off := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var height := rng.randf_range(0.2, 0.46)
		var width := rng.randf_range(0.022, 0.04)
		var lean := rng.randf_range(0.05, 0.28)
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var p0 := off + dir * (lean * t0 * t0) + Vector3(0, height * t0, 0)
			var p1 := off + dir * (lean * t1 * t1) + Vector3(0, height * t1, 0)
			var w0 := width * (1.0 - t0 * 0.92)
			var w1 := width * (1.0 - t1 * 0.92)
			var a := p0 - side * w0
			var c := p0 + side * w0
			var d := p1 - side * w1
			var e := p1 + side * w1
			for v in [[a, t0], [c, t0], [d, t1], [c, t0], [e, t1], [d, t1]]:
				st.set_uv(Vector2(0.5, v[1]))
				st.add_vertex(v[0])
	return st.commit()

# ---------------------------------------------------------------- quality

func detect_level() -> int:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	if "llvmpipe" in name or "lavapipe" in name or "swiftshader" in name or "software" in name:
		return Level.LOW
	if "nvidia" in name or "geforce" in name or "tesla" in name or "quadro" in name or "radeon rx" in name or "rtx" in name:
		return Level.ULTRA
	return Level.MEDIUM

func load_level(forced: String, remember: bool) -> void:
	var l := detect_level()
	if remember:
		var cfg := ConfigFile.new()
		if cfg.load(CONFIG) == OK:
			l = clampi(int(cfg.get_value("graphics", "level", l)), 0, 3)
	if forced != "" and forced.to_upper() in NAMES:
		l = NAMES.find(forced.to_upper())
	apply(l, false)

func cycle() -> void:
	apply((level + 1) % 4, true)

func apply(l: int, save: bool) -> void:
	level = l as Level
	var vp := get_viewport()
	var hi := level >= Level.HIGH
	var ultra := level == Level.ULTRA
	vp.msaa_3d = Viewport.MSAA_4X if hi else (Viewport.MSAA_2X if level == Level.MEDIUM else Viewport.MSAA_DISABLED)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level == Level.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = ultra
	vp.use_debanding = true
	if env:
		env.sdfgi_enabled = hi
		env.sdfgi_cascades = 4 if ultra else 3
		env.volumetric_fog_enabled = hi
		env.ssao_enabled = level >= Level.MEDIUM
		env.ssil_enabled = ultra
		env.glow_enabled = level >= Level.MEDIUM
		env.fog_density = 0.0025 if hi else 0.006
	if sun:
		sun.shadow_blur = 1.2 if hi else 0.8
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if hi else (
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
		sun.light_angular_distance = 0.6 if hi else 0.0
	for l2 in _lamps:
		l2.shadow_enabled = hi
	if _grass:
		_grass.multimesh.visible_instance_count = mini(GRASS_AT_LEVEL[level], _grass.multimesh.instance_count)
		_grass.visible = level != Level.LOW
	if _post:
		_post.visible = level >= Level.MEDIUM
	_apply_dof()
	if save and DisplayServer.get_name() != "headless":
		var cfg := ConfigFile.new()
		cfg.set_value("graphics", "level", int(level))
		cfg.save(CONFIG)
	changed.emit(NAMES[level])

## Shallow depth of field for the title portrait (the background falls out of focus).
func set_portrait(on: bool) -> void:
	_portrait = on
	_apply_dof()

func _apply_dof() -> void:
	if attrs == null:
		return
	var dof := _portrait and level >= Level.MEDIUM
	attrs.dof_blur_far_enabled = dof
	attrs.dof_blur_far_distance = 2.6
	attrs.dof_blur_far_transition = 3.0
	attrs.dof_blur_amount = 0.14
	RenderingServer.camera_attributes_set_dof_blur_quality(
		RenderingServer.DOF_BLUR_QUALITY_HIGH if level >= Level.HIGH else RenderingServer.DOF_BLUR_QUALITY_LOW, true)
