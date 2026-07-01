extends Node3D
class_name MatchWorldSetup

# Wires all subsystems on startup: loads configs from GameManager,
# spawns player nodes, connects CharacterSelect → MatchController.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var match_ctrl:     MatchController   = $MatchController
@onready var rpc_relay:      NetworkRpcRelay   = $MatchController/RpcRelay
@onready var seat_markers:   Node3D            = $SeatMarkers
@onready var spawned_root:   Node3D            = $SpawnedPlayers
@onready var match_hud:      MatchHUD          = $UILayer/MatchHUD
@onready var char_select_ui: CharacterSelectUI = $CharacterSelectLayer/CharacterSelectUI

var _seat_transforms: Array[Transform3D] = []
var _spawned: Dictionary = {}   # player_id → PlayerController


func _ready() -> void:
	_collect_seats()

	match_ctrl.initialize(
		GameManager.pending_player_configs,
		GameManager.pending_match_config
	)

	if GameManager.is_online():
		char_select_ui.set_rpc_relay(rpc_relay)

	for cfg in GameManager.pending_player_configs:
		if not cfg.get("is_ai", false):
			_spawn_player(cfg["player_id"])

	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.audio_play_music.emit("match")


func _collect_seats() -> void:
	_seat_transforms.clear()
	for child in seat_markers.get_children():
		if child is Node3D:
			_seat_transforms.append(child.global_transform)


func _spawn_player(player_id: int) -> void:
	var instance: PlayerController = PLAYER_SCENE.instantiate()
	instance.name = "Player_%d" % player_id
	instance.set_multiplayer_authority(player_id)

	# Node must be in the tree before get_node / find_child can resolve children
	spawned_root.add_child(instance, true)

	var seat_index := _get_seat_index(player_id)
	if seat_index < _seat_transforms.size():
		instance.seat_at(_seat_transforms[seat_index])

	# find_child searches the whole subtree; safe even if the node is deeply nested
	var ah := instance.find_child("PlayerActionHandler", true, false) as PlayerActionHandler
	if ah == null:
		push_error("_spawn_player: PlayerActionHandler not found in player scene for id %d" % player_id)
	else:
		ah.bound_player_id = player_id
		ah.match_ctrl      = match_ctrl
		if GameManager.is_online():
			ah.rpc_relay = rpc_relay

	_spawned[player_id] = instance


func _get_seat_index(player_id: int) -> int:
	var i := 0
	for cfg in GameManager.pending_player_configs:
		if cfg["player_id"] == player_id:
			return i
		i += 1
	return 0


func _on_phase_changed(phase: String) -> void:
	match phase:
		"CASINO_FLOOR":
			$CharacterSelectLayer.visible = false
			match_hud.visible = true
		"CHARACTER_SELECT":
			$CharacterSelectLayer.visible = true
			match_hud.visible = false
