extends Node
## NetworkManager — Null Protocol
## Host/Join via ENetMultiplayerPeer (Godot 4.6).
## Trennt sich KOMPLETT von Spielregeln — nur Verbindung und Lobby.

const PORT:        int = 7433
const MAX_CLIENTS: int = 4

# peer_id → {name, ready, ping_ms}
var lobby_players: Dictionary = {}
var local_name:    String     = "Spieler"
var _ping_timers:  Dictionary = {}   # peer_id → float (Zeit seit letztem Ping)



func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if not is_active():
		return
	# Ping alle 2 Sekunden
	for pid in _ping_timers.keys():
		_ping_timers[pid] += delta
		if _ping_timers[pid] >= 2.0:
			_ping_timers[pid] = 0.0
			_rpc_ping.rpc_id(pid, Time.get_ticks_msec())


# ── Host ──────────────────────────────────────────────────────────────────────

func host_session(player_name: String, port: int = PORT) -> Error:
	local_name = player_name
	var peer   := ENetMultiplayerPeer.new()
	var err    := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		EventBus.net_connection_failed.emit("server_create_failed:%d" % err)
		return err
	multiplayer.multiplayer_peer = peer
	lobby_players[1] = {name = player_name, ready = false, ping_ms = 0}
	EventBus.net_host_started.emit(port)
	EventBus.net_lobby_updated.emit(lobby_players)
	return OK


# ── Join ──────────────────────────────────────────────────────────────────────

func join_session(player_name: String, address: String, port: int = PORT) -> Error:
	local_name = player_name
	var peer   := ENetMultiplayerPeer.new()
	var err    := peer.create_client(address, port)
	if err != OK:
		EventBus.net_connection_failed.emit("client_create_failed:%d" % err)
		return err
	multiplayer.multiplayer_peer = peer
	return OK


# ── Disconnect ────────────────────────────────────────────────────────────────

func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	lobby_players.clear()
	_ping_timers.clear()


# ── Lobby-Bereitschaft ────────────────────────────────────────────────────────

func set_ready(is_ready: bool) -> void:
	var local_id := get_local_id()
	if lobby_players.has(local_id):
		lobby_players[local_id]["ready"] = is_ready
	if is_server():
		_broadcast_lobby.rpc(lobby_players)
	else:
		_rpc_server_set_ready.rpc_id(1, local_id, is_ready)


func all_players_ready() -> bool:
	if lobby_players.size() < 2:
		return false
	for data in lobby_players.values():
		if not data["ready"]:
			return false
	return true


# ── Match starten (nur Host) ──────────────────────────────────────────────────

func host_start_match() -> void:
	if not is_server():
		return
	var configs: Array[Dictionary] = []
	for pid in lobby_players.keys():
		configs.append({
			"player_id":   pid,
			"player_name": lobby_players[pid]["name"],
			"is_ai":       false,
			"ai_difficulty": 1,
			"vitality": 5, "max_vitality": 5,
			"stability": 0, "max_stability": 3,
		})
	EventBus.net_match_starting.emit()
	_rpc_begin_match.rpc(configs, GameManager.pending_match_config)


# ── Helfer ────────────────────────────────────────────────────────────────────

func is_active() -> bool:
	return multiplayer.multiplayer_peer != null

func is_server() -> bool:
	if not is_active():
		return true   # Solo = immer "Server"
	return multiplayer.is_server()

func get_local_id() -> int:
	if not is_active():
		return 1
	return multiplayer.get_unique_id()

func get_ping(peer_id: int) -> int:
	if lobby_players.has(peer_id):
		return lobby_players[peer_id].get("ping_ms", 0)
	return 0


# ── RPCs ──────────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func _rpc_register_name(player_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0: sender = 1
	if is_server():
		lobby_players[sender] = {name = player_name, ready = false, ping_ms = 0}
		_ping_timers[sender]  = 0.0
		_broadcast_lobby.rpc(lobby_players)


@rpc("any_peer", "call_local", "reliable")
func _rpc_server_set_ready(peer_id: int, ready_state: bool) -> void:
	if not is_server(): return
	if lobby_players.has(peer_id):
		lobby_players[peer_id]["ready"] = ready_state
	_broadcast_lobby.rpc(lobby_players)


@rpc("authority", "call_local", "reliable")
func _broadcast_lobby(players: Dictionary) -> void:
	lobby_players = players
	EventBus.net_lobby_updated.emit(lobby_players)


@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(configs: Array[Dictionary], match_cfg: Dictionary) -> void:
	GameManager.start_online_match(configs, match_cfg)


@rpc("any_peer", "call_local", "unreliable")
func _rpc_ping(sent_at_ms: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0: return
	_rpc_pong.rpc_id(sender, sent_at_ms)


@rpc("any_peer", "call_local", "unreliable")
func _rpc_pong(sent_at_ms: int) -> void:
	var sender  := multiplayer.get_remote_sender_id()
	if sender == 0: return
	var ping_ms := int(Time.get_ticks_msec()) - sent_at_ms
	if lobby_players.has(sender):
		lobby_players[sender]["ping_ms"] = ping_ms
	EventBus.net_lobby_updated.emit(lobby_players)


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	print("[NET] Peer verbunden: %d" % peer_id)
	if is_server():
		_ping_timers[peer_id] = 0.0

func _on_peer_disconnected(peer_id: int) -> void:
	print("[NET] Peer getrennt: %d" % peer_id)
	lobby_players.erase(peer_id)
	_ping_timers.erase(peer_id)
	EventBus.net_lobby_updated.emit(lobby_players)
	EventBus.player_left_lobby.emit(peer_id)

func _on_connected_to_server() -> void:
	print("[NET] Verbunden mit Server, eigene ID: %d" % get_local_id())
	_rpc_register_name.rpc_id(1, local_name)
	EventBus.net_client_connected.emit(get_local_id())

func _on_connection_failed() -> void:
	EventBus.net_connection_failed.emit("timeout_or_refused")

func _on_server_disconnected() -> void:
	lobby_players.clear()
	EventBus.net_server_disconnected.emit()
