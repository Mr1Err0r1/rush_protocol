extends Node3D
class_name CasinoTower

## Baut den mehrstöckigen Schauplatz des Blackglass Casinos zur Laufzeit auf.
## Die Aufzüge transportieren Spieler zwischen Lobby, VIP, Schwarzmarkt, Tresor
## und Boss-Penthouse. Sämtliche Waffen- und Schmuggelinhalte bleiben fiktive
## Spielmechaniken und sind nicht als reale Anleitung gedacht.

signal floor_changed(body: Node3D, zone_id: String, floor_name: String)

const FLOOR_HEIGHT := 6.5
const FLOOR_NAMES := [
	"01 · DIE SPIELHALLE",
	"02 · DER GOLDENE SALON",
	"03 · HINTERZIMMER",
	"04 · TRESOR-KORRIDOR",
	"05 · PENTHOUSE DES HAUSHERRN",
]
const FLOOR_ZONES := ["lobby", "vip_lounge", "backroom", "vault_corridor", "boss_office"]
const FLOOR_COLORS := [
	Color("#c89a42"), Color("#f0c76c"), Color("#a53848"),
	Color("#49a8a0"), Color("#d7b4ff"),
]

var _materials: Array[StandardMaterial3D] = []
var _elevator_lock := false
## Optional: Callable(body: Node3D, zone_id: String) -> bool.
## Wird vor dem Teleport gefragt; false = Aufzug verweigert die Fahrt.
var travel_validator: Callable = Callable()

func _ready() -> void:
	_build_materials()
	_build_tower()

func _build_materials() -> void:
	for color in FLOOR_COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.62
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = color.darkened(0.42)
		mat.emission_energy_multiplier = 0.28
		_materials.append(mat)

func _build_tower() -> void:
	for floor_index in FLOOR_NAMES.size():
		var level := Node3D.new()
		level.name = "Floor_%02d" % (floor_index + 1)
		level.position.y = floor_index * FLOOR_HEIGHT
		add_child(level)
		if floor_index > 0:
			_add_platform(level, floor_index)
		_add_sign(level, floor_index)
		_add_railings(level, floor_index)
		_add_casino_tables(level, floor_index)
		_add_elevator(level, floor_index, 1)
		if floor_index > 0:
			_add_elevator(level, floor_index, -1)
	_add_atrium_spine()

func _add_platform(parent: Node3D, floor_index: int) -> void:
	var slab := StaticBody3D.new()
	slab.name = "WalkableFloor"
	parent.add_child(slab)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(28.0, 0.35, 28.0)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _materials[floor_index]
	visual.position.y = -0.22
	slab.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position.y = -0.22
	slab.add_child(collision)

func _add_sign(parent: Node3D, floor_index: int) -> void:
	var sign := Label3D.new()
	sign.name = "FloorSign"
	sign.text = FLOOR_NAMES[floor_index]
	sign.font_size = 64
	sign.outline_size = 10
	sign.modulate = Color("#fff0c8")
	sign.position = Vector3(0, 3.0, -10.5)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(sign)
	var accent := OmniLight3D.new()
	accent.name = "FloorAccentLight"
	accent.position = Vector3(0, 4.2, -9.0)
	accent.light_color = FLOOR_COLORS[floor_index]
	accent.light_energy = 1.4
	accent.omni_range = 13.0
	parent.add_child(accent)

func _add_railings(parent: Node3D, floor_index: int) -> void:
	var rail_mat := _materials[floor_index]
	for side in 4:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(23.0, 0.12, 0.12) if side < 2 else Vector3(0.12, 0.12, 23.0)
		rail.mesh = mesh
		rail.material_override = rail_mat
		match side:
			0: rail.position = Vector3(0, 1.05, -13.4)
			1: rail.position = Vector3(0, 1.05, 13.4)
			2: rail.position = Vector3(-13.4, 1.05, 0)
			3: rail.position = Vector3(13.4, 1.05, 0)
		parent.add_child(rail)
	for x in [-13.4, 13.4]:
		for z in [-13.4, 13.4]:
			_add_box(parent, Vector3(x, 2.3, z), Vector3(0.34, 4.6, 0.34), rail_mat, "GoldColumn")

func _add_casino_tables(parent: Node3D, floor_index: int) -> void:
	var positions: Array[Vector2] = [Vector2(-5.0, -1.0), Vector2(5.0, -1.0), Vector2(-5.0, 5.5), Vector2(5.0, 5.5)]
	for i in positions.size():
		var p := positions[i]
		var table_color := _materials[(floor_index + i + 1) % _materials.size()]
		_add_box(parent, Vector3(p.x, 1.0, p.y), Vector3(3.5, 0.22, 2.2), table_color, "GameTable_%d" % i)
		_add_box(parent, Vector3(p.x, 0.5, p.y), Vector3(0.18, 1.0, 0.18), _materials[0], "TablePedestal_%d" % i)
		if floor_index == 0:
			var label := Label3D.new()
			label.text = ["POKER", "BLACKJACK", "ROULETTE", "HIGH STAKES"][i]
			label.font_size = 24
			label.position = Vector3(p.x, 1.55, p.y)
			parent.add_child(label)

func _add_elevator(parent: Node3D, floor_index: int, direction: int) -> void:
	var target_floor := clampi(floor_index + direction, 0, FLOOR_NAMES.size() - 1)
	if target_floor == floor_index:
		return
	var area := Area3D.new()
	area.name = "ElevatorUp" if direction > 0 else "ElevatorDown"
	area.position = Vector3(9.0 if direction > 0 else -9.0, 0.8, 8.0)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.35
	shape.height = 2.2
	shape_node.shape = shape
	area.add_child(shape_node)
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.2
	pad_mesh.bottom_radius = 1.2
	pad_mesh.height = 0.12
	pad.mesh = pad_mesh
	pad.material_override = _materials[4 if direction > 0 else 1]
	pad.position.y = -0.28
	area.add_child(pad)
	var prompt := Label3D.new()
	prompt.text = "LIFT ↑" if direction > 0 else "LIFT ↓"
	prompt.font_size = 28
	prompt.position.y = 1.5
	area.add_child(prompt)
	area.body_entered.connect(_on_elevator_entered.bind(target_floor))
	parent.add_child(area)

func _on_elevator_entered(body: Node3D, target_floor: int) -> void:
	if _elevator_lock or not (body is CharacterBody3D):
		return
	_elevator_lock = true
	if travel_validator.is_valid() and not travel_validator.call(body, FLOOR_ZONES[target_floor]):
		await get_tree().create_timer(0.8).timeout
		_elevator_lock = false
		return
	var safe_destination := Vector3(0.0, target_floor * FLOOR_HEIGHT + 1.1, 0.0)
	body.global_position = to_global(safe_destination)
	floor_changed.emit(body, FLOOR_ZONES[target_floor], FLOOR_NAMES[target_floor])
	EventBus.ui_toast.emit("Aufzug: " + FLOOR_NAMES[target_floor], "info", 2.5)
	await get_tree().create_timer(0.8).timeout
	_elevator_lock = false

func _add_atrium_spine() -> void:
	for x in [-14.0, 14.0]:
		for z in [-14.0, 14.0]:
			var spine := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.65, FLOOR_HEIGHT * (FLOOR_NAMES.size() - 1), 0.65)
			spine.mesh = mesh
			spine.material_override = _materials[0]
			spine.position = Vector3(x, mesh.size.y / 2.0, z)
			add_child(spine)

func _add_box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material, node_name: String) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
