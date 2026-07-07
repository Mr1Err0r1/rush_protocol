extends Node3D
## MenuBackground3D — Rush / Null Protocol
## Edler Schwarz/Gold-Hintergrund:
##   • tiefschwarzer BG + Filmic Tonemap + Bloom + Fog
##   • 22 schlanke goldene Kristallsplitter (PrismMesh, metallisch, glowend)
##   • 3 langsam rotierende Torus-Ringe (Tresor/Roulette-Feeling)
##   • subtiles goldenes Bodengitter
##   • 260 driftende Goldpartikel
## Komplett prozedural — keine externen Assets nötig.

@export var gold_warm : Color = Color(0.96, 0.78, 0.36)   # warmes Gold
@export var gold_deep : Color = Color(0.62, 0.42, 0.10)   # dunkles Antikgold
@export var shard_count : int = 22
@export var particle_count : int = 260
@export var drift_speed : float = 0.06

var _time := 0.0
var _camera : Camera3D
var _shards : Array[Dictionary] = []
var _rings  : Array[MeshInstance3D] = []

func _ready() -> void:
	randomize()
	_build_environment()
	_build_lights()
	_build_camera()
	_build_rings()
	_build_shards()
	_build_floor_grid()
	_build_particles()

# ------------------------------------------------------------------- Environment
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.010, 0.008)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.10, 0.08, 0.05)
	env.ambient_light_energy = 0.22

	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.035, 0.015)
	env.fog_density = 0.045
	env.fog_sky_affect = 0.0

	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_bloom = 0.35
	env.glow_strength = 1.2
	env.glow_hdr_threshold = 0.75
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast   = 1.10
	env.adjustment_brightness = 0.98

	we.environment = env
	add_child(we)

# ------------------------------------------------------------------- Lights
func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = gold_warm
	key.light_energy = 0.55
	key.rotation_degrees = Vector3(-58, 32, 0)
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.light_color = gold_warm
	rim.light_energy = 3.2
	rim.omni_range = 16.0
	rim.position = Vector3(-6, 1.5, -3)
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.light_color = gold_deep
	fill.light_energy = 2.0
	fill.omni_range = 14.0
	fill.position = Vector3(6, -1.0, -2)
	add_child(fill)

# ------------------------------------------------------------------- Camera
func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.6, 9.0)
	_camera.fov = 52.0
	add_child(_camera)

# ------------------------------------------------------------------- Materials
func _gold_material(emit_strength: float = 1.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = gold_warm
	m.metallic = 1.0
	m.metallic_specular = 0.95
	m.roughness = 0.18
	m.emission_enabled = true
	m.emission = gold_warm
	m.emission_energy_multiplier = emit_strength
	m.rim_enabled = true
	m.rim = 0.9
	m.rim_tint = 0.6
	return m

# ------------------------------------------------------------------- Crystal shards
func _build_shards() -> void:
	for i in shard_count:
		var mi := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(
			randf_range(0.12, 0.28),
			randf_range(0.9, 2.4),
			randf_range(0.12, 0.28)
		)
		prism.left_to_right = randf_range(0.2, 0.8)
		mi.mesh = prism
		mi.material_override = _gold_material(randf_range(1.1, 2.0))

		var angle := randf() * TAU
		var radius := randf_range(2.5, 7.0)
		var base_pos := Vector3(
			cos(angle) * radius,
			randf_range(-2.2, 2.2),
			-randf_range(1.0, 6.0) + sin(angle) * 1.5
		)
		mi.position = base_pos
		mi.rotation = Vector3(
			randf_range(-PI, PI),
			randf_range(-PI, PI),
			randf_range(-PI, PI)
		)
		add_child(mi)

		_shards.append({
			"node": mi,
			"base_pos": base_pos,
			"freq": randf_range(0.25, 0.7),
			"phase": randf() * TAU,
			"spin": Vector3(
				randf_range(-0.25, 0.25),
				randf_range(-0.35, 0.35),
				randf_range(-0.15, 0.15)
			)
		})

# ------------------------------------------------------------------- Torus rings
func _build_rings() -> void:
	var defs := [
		{ "inner": 2.4, "outer": 2.55, "pos": Vector3(0, 0, -2.0),
			"rot": Vector3(deg_to_rad(75), 0, 0), "spin": 0.10, "emit": 1.6 },
		{ "inner": 3.6, "outer": 3.78, "pos": Vector3(0.5, -0.3, -3.5),
			"rot": Vector3(deg_to_rad(70), deg_to_rad(15), 0), "spin": -0.07, "emit": 1.2 },
		{ "inner": 5.2, "outer": 5.42, "pos": Vector3(-0.4, 0.2, -5.0),
			"rot": Vector3(deg_to_rad(78), deg_to_rad(-10), 0), "spin": 0.045, "emit": 0.9 },
	]
	for d in defs:
		var mi := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = d.inner
		t.outer_radius = d.outer
		t.rings = 96
		t.ring_segments = 12
		mi.mesh = t
		mi.material_override = _gold_material(d.emit)
		mi.position = d.pos
		mi.rotation = d.rot
		mi.set_meta("spin", d.spin)
		add_child(mi)
		_rings.append(mi)

# ------------------------------------------------------------------- Floor grid
func _build_floor_grid() -> void:
	var grid := Node3D.new()
	grid.position = Vector3(0, -2.6, -3.0)
	add_child(grid)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = gold_deep
	mat.emission_enabled = true
	mat.emission = gold_warm
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35

	var span := 14.0
	var lines := 14
	var step := span / float(lines)
	# parallele Linien in Z
	for i in range(lines + 1):
		var x := -span * 0.5 + step * i
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.002, span)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(x, 0, 0)
		grid.add_child(mi)
	# parallele Linien in X
	for i in range(lines + 1):
		var z := -span * 0.5 + step * i
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(span, 0.002, 0.012)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(0, 0, z)
		grid.add_child(mi)

# ------------------------------------------------------------------- Particles
func _build_particles() -> void:
	var p := GPUParticles3D.new()
	p.amount = particle_count
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 14, 20))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 3.5, 6.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.02, 0)
	pm.scale_min = 0.018
	pm.scale_max = 0.045
	pm.color = gold_warm

	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(gold_warm.r, gold_warm.g, gold_warm.b, 0.0))
	ramp.add_point(0.25, Color(gold_warm.r, gold_warm.g, gold_warm.b, 0.9))
	ramp.add_point(1.0, Color(gold_warm.r, gold_warm.g, gold_warm.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = ramp
	pm.color_ramp = grad_tex

	p.process_material = pm

	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 6
	mesh.rings = 4
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = gold_warm
	dot_mat.emission_enabled = true
	dot_mat.emission = gold_warm
	dot_mat.emission_energy_multiplier = 2.4
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = dot_mat
	p.draw_pass_1 = mesh

	p.position = Vector3(0, -2.0, -2.0)
	add_child(p)

# ------------------------------------------------------------------- Loop
func _process(delta: float) -> void:
	_time += delta

	# Kamera-Parallaxe
	if _camera:
		_camera.position.x = sin(_time * 0.18) * 0.35
		_camera.position.y = 0.6 + sin(_time * 0.22) * 0.12
		_camera.position.z = 9.0 + cos(_time * 0.13) * 0.25
		_camera.look_at(Vector3(0, 0, -3), Vector3.UP)

	# Shards driften & rotieren
	for s in _shards:
		var n: MeshInstance3D = s.node
		var base: Vector3 = s.base_pos
		n.position = base + Vector3(
			sin(_time * s.freq + s.phase) * 0.18,
			cos(_time * s.freq * 0.85 + s.phase) * 0.22,
			sin(_time * s.freq * 0.6 + s.phase) * 0.10
		)
		n.rotation += s.spin * delta * drift_speed * 14.0

	# Torus-Ringe drehen
	for r in _rings:
		var spin: float = r.get_meta("spin", 0.1)
		r.rotate_y(spin * delta)
