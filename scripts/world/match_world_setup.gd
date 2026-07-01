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
	# Sofortiger Default: Charakterauswahl sichtbar, HUD aus, Maus frei.
	# Verhindert, dass vor dem ersten phase_changed-Signal versehentlich
	# schon HUD/Maussteuerung greifen.
	$CharacterSelectLayer.visible = true
	match_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_collect_seats()

	# Vor initialize() verbinden, falls MatchController die erste Phase
	# synchron innerhalb von initialize() feuert.
	EventBus.phase_changed.connect(_on_phase_changed)

	match_ctrl.initialize(
		GameManager.pending_player_configs,
		GameManager.pending_match_config
	)

	if GameManager.is_online():
		char_select_ui.set_rpc_relay(rpc_relay)

	EventBus.audio_play_music.emit("match")


func _collect_seats() -> void:
	_seat_transforms.clear()
	for child in seat_markers.get_children():
		if child is Node3D:
			_seat_transforms.append(child.global_transform)


func _spawn_player(player_id: int) -> void:
	if _spawned.has(player_id):
		return
	var instance: PlayerController = PLAYER_SCENE.instantiate()
	instance.name = "Player_%d" % player_id
	instance.set_multiplayer_authority(player_id)
	spawned_root.add_child(instance, true)
	var seat_index := _get_seat_index(player_id)
	if seat_index < _seat_transforms.size():
		instance.seat_at(_seat_transforms[seat_index])
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
			_enter_casino_floor()
		"CHARACTER_SELECT":
			$CharacterSelectLayer.visible = true
			match_hud.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Erst NACH bestätigter Charakterauswahl aufgerufen.
# UI weg → kurze Ladeblende → Spieler spawnen (inkl. Maus-Capture durch
# PlayerController._ready()) → HUD zeigen.
func _enter_casino_floor() -> void:
	$CharacterSelectLayer.visible = false

	await _play_loading_transition()

	for cfg in GameManager.pending_player_configs:
		if not cfg.get("is_ai", false):
			_spawn_player(cfg["player_id"])

	match_hud.visible = true


func _play_loading_transition() -> void:
	# TODO: Falls VisualFx (autoload) bereits fade_out()/fade_in() anbietet,
	# diese Funktion durch die entsprechenden Aufrufe ersetzen.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.add_child(fade)
	add_child(layer)

	var tw_in := create_tween()
	tw_in.tween_property(fade, "color:a", 1.0, 0.25)
	await tw_in.finished

	await get_tree().create_timer(0.35).timeout

	var tw_out := create_tween()
	tw_out.tween_property(fade, "color:a", 0.0, 0.35)
	await tw_out.finished

	layer.queue_free()
