extends Node
class_name NetworkRpcRelay
## NetworkRpcRelay — Null Protocol
## Brücke zwischen Netzwerk (RPC) und MatchController (lokale Logik).
## MatchController selbst hat KEINEN Netzwerk-Code.

@export var match_ctrl_path: NodePath
var _ctrl: MatchController


func _ready() -> void:
	_ctrl = get_node(match_ctrl_path) as MatchController

	# Lokale Signale → Broadcast an alle Clients
	EventBus.risk_triggered.connect(_on_risk_triggered)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.round_started.connect(_on_round_started)
	EventBus.match_over.connect(_on_match_over)
	EventBus.player_eliminated.connect(_on_player_eliminated)
	EventBus.item_used.connect(_on_item_used)
	EventBus.phase_changed.connect(_on_phase_changed)


# ── Client → Server ────────────────────────────────────────────────────────────

func request_item_use(player_id: int, item_id: StringName, target_id: int) -> void:
	_rpc_item_use.rpc_id(1, player_id, item_id, target_id)

func request_risk_action(player_id: int, target_id: int) -> void:
	_rpc_risk_action.rpc_id(1, player_id, target_id)

func request_move_zone(player_id: int, zone: String) -> void:
	_rpc_move_zone.rpc_id(1, player_id, zone)

func request_end_turn(player_id: int) -> void:
	_rpc_end_turn.rpc_id(1, player_id)

func request_select_character(player_id: int, class_id: StringName, gender: String) -> void:
	_rpc_select_character.rpc_id(1, player_id, class_id, gender)

func request_confirm_loadout(player_id: int, items: Array[StringName]) -> void:
	_rpc_confirm_loadout.rpc_id(1, player_id, items)

func request_entry_check(player_id: int) -> void:
	_rpc_entry_check.rpc_id(1, player_id)


# ── Server-seitige RPC-Empfänger ──────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func _rpc_item_use(player_id: int, item_id: StringName, target_id: int) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.request_use_item(player_id, item_id, target_id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_risk_action(player_id: int, target_id: int) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.request_risk_action(player_id, target_id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_move_zone(player_id: int, zone: String) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.request_move_zone(player_id, zone)

@rpc("any_peer", "call_local", "reliable")
func _rpc_end_turn(player_id: int) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.advance_turn_phase()

@rpc("any_peer", "call_local", "reliable")
func _rpc_select_character(player_id: int, class_id: StringName, gender: String) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.select_character(player_id, class_id, gender)

@rpc("any_peer", "call_local", "reliable")
func _rpc_confirm_loadout(player_id: int, items: Array[StringName]) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.confirm_loadout(player_id, items)

@rpc("any_peer", "call_local", "reliable")
func _rpc_entry_check(player_id: int) -> void:
	if not _is_server() or not _validate(player_id): return
	_ctrl.confirm_entry_check(player_id)


# ── Server → alle Clients (Broadcast) ────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _bcast_risk(actor_id: int, target_id: int, oid: StringName, val: int) -> void:
	if _is_server(): return
	EventBus.risk_triggered.emit(actor_id, target_id, oid, val)

@rpc("authority", "call_local", "reliable")
func _bcast_turn_ended(pid: int, reason: String) -> void:
	if _is_server(): return
	EventBus.turn_ended.emit(pid, reason)

@rpc("authority", "call_local", "reliable")
func _bcast_round_started(idx: int, active: int) -> void:
	if _is_server(): return
	EventBus.round_started.emit(idx, active)

@rpc("authority", "call_local", "reliable")
func _bcast_match_over(winner: int, condition: String, stats: Dictionary) -> void:
	if _is_server(): return
	EventBus.match_over.emit(winner, condition, stats)

@rpc("authority", "call_local", "reliable")
func _bcast_eliminated(pid: int, killer: int, cause: String) -> void:
	if _is_server(): return
	EventBus.player_eliminated.emit(pid, killer, cause)

@rpc("authority", "call_local", "reliable")
func _bcast_item_used(pid: int, iid: StringName, tid: int, result: Dictionary) -> void:
	if _is_server(): return
	EventBus.item_used.emit(pid, iid, tid, result)

@rpc("authority", "reliable")   # KEIN call_local — nur Empfänger bekommt private Info
func _private_item_result(pid: int, iid: StringName, result: Dictionary) -> void:
	EventBus.item_used.emit(pid, iid, -1, result)

@rpc("authority", "call_local", "reliable")
func _bcast_phase(phase: String) -> void:
	if _is_server(): return
	EventBus.phase_changed.emit(phase)


# ── Lokale Signal-Handler (Server sendet Broadcasts aus) ──────────────────────

func _on_risk_triggered(a: int, t: int, oid: StringName, val: int) -> void:
	if _is_server() and _has_remote_clients():
		_bcast_risk.rpc(a, t, oid, val)

func _on_turn_ended(pid: int, reason: String) -> void:
	if _is_server() and _has_remote_clients():
		_bcast_turn_ended.rpc(pid, reason)

func _on_round_started(idx: int, active: int) -> void:
	if _is_server() and _has_remote_clients():
		_bcast_round_started.rpc(idx, active)

func _on_match_over(winner: int, condition: String, stats: Dictionary) -> void:
	if _is_server() and _has_remote_clients():
		_bcast_match_over.rpc(winner, condition, stats)

func _on_player_eliminated(pid: int, killer: int, cause: String) -> void:
	if _is_server() and _has_remote_clients():
		_bcast_eliminated.rpc(pid, killer, cause)

func _on_item_used(pid: int, iid: StringName, tid: int, result: Dictionary) -> void:
	if not _is_server() or not _has_remote_clients():
		return
	if result.get("is_private", false):
		_private_item_result.rpc_id(pid, pid, iid, result)
	else:
		_bcast_item_used.rpc(pid, iid, tid, result)

func _on_phase_changed(phase: String) -> void:
	if _is_server() and _has_remote_clients():
		_bcast_phase.rpc(phase)


# ── Helfer ────────────────────────────────────────────────────────────────────

func _is_server() -> bool:
	if not multiplayer.has_multiplayer_peer(): return true
	return multiplayer.is_server()

func _has_remote_clients() -> bool:
	return NetworkManager.lobby_players.size() > 1

func _validate(claimed_id: int) -> bool:
	if not multiplayer.has_multiplayer_peer(): return true
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0: sender = 1
	return sender == claimed_id
