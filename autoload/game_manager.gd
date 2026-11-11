extends Node
## GameManager — Null Protocol
## Kennt den aktuellen Spielmodus und steuert Szenenübergänge.
## Enthält KEINE Spielregeln — das macht MatchController.

enum AppState { MENU, LOBBY, MATCH, PAUSED, GAME_OVER }
enum GameMode  { SOLO, LOCAL_HOTSEAT, ONLINE_MULTIPLAYER }

const SCENE_MAIN_MENU   := "res://scenes/world/main_menu.tscn"
const SCENE_LOBBY       := "res://scenes/ui/lobby_screen.tscn"
const SCENE_MATCH_WORLD := "res://scenes/world/match_world.tscn"

var app_state:  AppState = AppState.MENU
var game_mode:  GameMode = GameMode.SOLO
var prev_state: AppState = AppState.MENU

# Wird vor Szenenwechsel gesetzt, MatchWorld liest es in _ready().
var pending_player_configs: Array[Dictionary] = []
var pending_match_config:   Dictionary = {}

# Aktiver MatchController — wird von MatchWorld registriert.
var active_match: Node = null   # MatchController

# Statistiken der laufenden Partie (für End-Screen).
var match_stats: Dictionary = {}
var paused_from_state: AppState = AppState.MATCH
var mouse_mode_before_pause: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var pause_rebind_capture: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if pause_rebind_capture:
		return
	if not event.is_action_pressed("pause"):
		return
	if event is InputEventKey and event.echo:
		return

	match app_state:
		AppState.MATCH, AppState.GAME_OVER:
			toggle_pause()
			get_viewport().set_input_as_handled()
		AppState.LOBBY:
			return_to_menu()
			get_viewport().set_input_as_handled()

# ── Öffentliche API ───────────────────────────────────────────────────────────

func start_solo(local_name: String, difficulty: int = 1) -> void:
	game_mode = GameMode.SOLO
	pending_player_configs = [
		_make_player_cfg(1, local_name, false),
		_make_player_cfg(2, _ai_name(difficulty), true, difficulty),
	]
	pending_match_config = _default_match_config()
	_change_to(SCENE_MATCH_WORLD, AppState.MATCH)


func start_local_hotseat(names: Array[String]) -> void:
	game_mode = GameMode.LOCAL_HOTSEAT
	pending_player_configs.clear()
	for i in names.size():
		pending_player_configs.append(_make_player_cfg(i + 1, names[i], false))
	pending_match_config = _default_match_config()
	_change_to(SCENE_MATCH_WORLD, AppState.MATCH)


func start_online_match(configs: Array[Dictionary], match_cfg: Dictionary) -> void:
	game_mode = GameMode.ONLINE_MULTIPLAYER
	pending_player_configs = configs
	pending_match_config   = match_cfg
	_change_to(SCENE_MATCH_WORLD, AppState.MATCH)


func go_to_lobby() -> void:
	_change_to(SCENE_LOBBY, AppState.LOBBY)


func return_to_menu() -> void:
	active_match = null
	get_tree().paused = false  # BUGFIX: vor Szenenwechsel entpausieren
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.disconnect_session()
	_change_to(SCENE_MAIN_MENU, AppState.MENU)


func toggle_pause() -> void:
	if app_state == AppState.MATCH or app_state == AppState.GAME_OVER:
		paused_from_state = app_state
		mouse_mode_before_pause = Input.mouse_mode
		app_state = AppState.PAUSED
		get_tree().paused = true
		EventBus.ui_open_pause.emit()
	elif app_state == AppState.PAUSED:
		app_state = paused_from_state
		get_tree().paused = false
		Input.mouse_mode = mouse_mode_before_pause
		EventBus.ui_close_pause.emit()


func register_match(match_node: Node) -> void:
	active_match = match_node


func record_match_over(_winner_id: int, stats: Dictionary) -> void:
	match_stats = stats
	app_state   = AppState.GAME_OVER


# ── Hilfsfunktionen ───────────────────────────────────────────────────────────

func _change_to(
	scene_path:String,
	new_state:AppState
):

	if not ResourceLoader.exists(scene_path):

		push_error(
			"Scene missing: " + scene_path
		)
		return


	prev_state = app_state
	app_state = new_state


	print(
		"Changing scene:",
		scene_path
	)


	get_tree().change_scene_to_file(
		scene_path
	)


func _make_player_cfg(pid: int, pname: String, is_ai: bool,
		ai_level: int = 1) -> Dictionary:
	return {
		"player_id": pid,
		"player_name": pname,
		"is_ai": is_ai,
		"ai_difficulty": ai_level,   # 0=easy 1=normal 2=hard
		"vitality": 5,
		"max_vitality": 5,
		"stability": 0,   # Bonuswert, den Items verändern können
		"max_stability": 3,
	}


func _default_match_config() -> Dictionary:
	return {
		"win_condition": "last_standing",
		"max_rounds": 0,              # 0 = unbegrenzt
		"actions_per_turn": 1,
		"items_per_round": 2,         # Wie viele Items zu Rundenstart ausgeteilt werden
		"risk_pool_positive": 4,      # Wie viele "positive" Outcomes im Pool
		"risk_pool_negative": 6,
		"allow_self_target": true,
	}


func _ai_name(difficulty: int) -> String:
	match difficulty:
		0: return "GHOST [EASY]"
		2: return "CIPHER [HARD]"
		_: return "PHANTOM [NORMAL]"


func is_online() -> bool:
	return game_mode == GameMode.ONLINE_MULTIPLAYER


func is_my_turn(player_id: int) -> bool:
	if active_match == null:
		return false
	return active_match.get_active_player_id() == player_id
