extends Control
## class_name LobbyUI
## LobbyUI — Null Protocol
## is_host / is_me explizit als bool typisiert → behebt den Godot-4-Typinferenzfehler.

@onready var name_input:    LineEdit      = $MainVBox/NameRow/NameInput
@onready var host_btn:      Button        = $MainVBox/HostBtn
@onready var address_input: LineEdit      = $MainVBox/JoinRow/AddressInput
@onready var join_btn:      Button        = $MainVBox/JoinRow/JoinBtn
@onready var player_list:   VBoxContainer = $MainVBox/PlayerListContainer
@onready var start_btn:     Button        = $MainVBox/StartBtn
@onready var back_btn:      Button        = $MainVBox/BackBtn
@onready var status_lbl:    Label         = $MainVBox/StatusLabel


func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(_on_back)

	var lm := _lm()
	if lm:
		lm.locale_changed.connect(func(_l): _update_texts())
	_update_texts()

	var saved_name: String = SaveManager.get_setting("last_player_name", "")
	if saved_name != "":
		name_input.text = saved_name

	EventBus.net_host_started.connect(_on_host_started)
	EventBus.net_client_connected.connect(_on_client_connected)
	EventBus.net_connection_failed.connect(_on_connection_failed)
	EventBus.net_server_disconnected.connect(_on_server_disconnected)
	EventBus.net_lobby_updated.connect(_rebuild_player_list)


func _update_texts() -> void:
	var lm := _lm()
	if not lm:
		return
	$MainVBox/TitleLbl.text      = lm.t("lobby.title")
	$MainVBox/NameRow/NameLbl.text = lm.t("lobby.name_hint")
	host_btn.text                = lm.t("lobby.host")
	address_input.placeholder_text = lm.t("lobby.ip_hint")
	join_btn.text                = lm.t("lobby.join")
	$MainVBox/PlayerListLbl.text = lm.t("lobby.players")
	start_btn.text               = lm.t("lobby.start")
	back_btn.text                = lm.t("lobby.back")


func _on_host() -> void:
	status_lbl.text = _t("lobby.connecting")
	var err: Error = NetworkManager.host_session(_get_name())
	if err != OK:
		status_lbl.text = _t("lobby.err_host") % err


func _on_join() -> void:
	var address: String = address_input.text.strip_edges()
	if address.is_empty():
		status_lbl.text = _t("lobby.err_no_ip")
		return
	status_lbl.text = _t("lobby.connecting")
	NetworkManager.join_session(_get_name(), address)


func _on_start() -> void:
	if not NetworkManager.is_server():
		return
	NetworkManager.host_start_match()


func _on_back() -> void:
	NetworkManager.disconnect_session()
	GameManager.return_to_menu()


func _on_host_started(_port: int) -> void:
	status_lbl.text    = _t("lobby.waiting")
	start_btn.disabled = false
	host_btn.disabled  = true
	join_btn.disabled  = true


func _on_client_connected(peer_id: int) -> void:
	status_lbl.text   = _t("lobby.connected") % peer_id
	host_btn.disabled = true
	join_btn.disabled = true


func _on_connection_failed(reason: String) -> void:
	status_lbl.text = _t("lobby.conn_failed") % reason


func _on_server_disconnected() -> void:
	status_lbl.text    = _t("lobby.disconnected")
	start_btn.disabled = true
	host_btn.disabled  = false
	join_btn.disabled  = false
	_rebuild_player_list({})


func _rebuild_player_list(players: Dictionary) -> void:
	for child in player_list.get_children():
		child.queue_free()

	for peer_id: int in players.keys():
		var data: Dictionary  = players[peer_id]
		var row: HBoxContainer = HBoxContainer.new()

		# ── Typfehler-Fix: explizit als bool deklarieren ──────────────────────
		var is_host: bool = (peer_id == 1)
		var is_me:   bool = (peer_id == NetworkManager.get_local_id())
		# ─────────────────────────────────────────────────────────────────────

		var name_lbl := Label.new()
		var host_tag: String = _t("lobby.host_tag") + " " if is_host else ""
		var you_tag:  String = " " + _t("lobby.you_tag") if is_me else ""
		name_lbl.text = host_tag + data.get("name", "?") + you_tag
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var ping_lbl  := Label.new()
		var ping_ms:  int = data.get("ping_ms", 0)
		if is_me:
			ping_lbl.text = _t("lobby.local_ping")
		else:
			ping_lbl.text = "%d ms" % ping_ms
		ping_lbl.modulate = Color(0.4, 1.0, 0.4) if ping_ms < 80 else Color(1.0, 0.6, 0.2)
		row.add_child(ping_lbl)

		player_list.add_child(row)

	start_btn.disabled = not (NetworkManager.is_server() and players.size() >= 2)


func _get_name() -> String:
	var n: String = name_input.text.strip_edges()
	if n.is_empty():
		n = "Spieler"
	SaveManager.set_setting("last_player_name", n)
	return n


func _t(key: String, args: Array = []) -> String:
	var lm := _lm()
	return lm.t(key, args) if lm else key

func _lm() -> Node:
	return get_node_or_null("/root/LocaleManager")
