extends Node
class_name MatchController
## MatchController — Null Protocol
## Orchestriert eine komplette Partie:
##   ENTRY (Einlass) → CASINO_FLOOR (Runden) → VAULT / BOSS → GAME_OVER
## Alle Entscheidungen laufen hier durch. UI und Netzwerk reagieren NUR
## auf EventBus-Signale die dieser Controller aussendet.

enum Phase {
	CHARACTER_SELECT,
	SMUGGLE_LOADOUT,
	ENTRY_CHECK,
	CASINO_FLOOR,
	VAULT_RUN,
	BOSS_ENCOUNTER,
	GAME_OVER,
}

enum TurnPhase { ITEM, ACTION, RESOLVE }

# ── Konfiguration ─────────────────────────────────────────────────────────────
var match_config: Dictionary = {}

# ── Zustände ──────────────────────────────────────────────────────────────────
var current_phase:      Phase     = Phase.CHARACTER_SELECT
var current_turn_phase: TurnPhase = TurnPhase.ITEM

var _states:      Dictionary = {}   # player_id → PlayerState
var _turn_order:  Array[int]  = []
var _turn_index:  int         = 0
var _round_index: int         = 0
var _actions_this_turn: int   = 0
var _boss_health:        int   = 8

# ── Sub-Controller ────────────────────────────────────────────────────────────
@onready var risk_controller:  RiskController       = $RiskController
@onready var entry_controller: EntryPhaseController = $EntryPhaseController
@onready var rpc_relay:        Node                 = $RpcRelay   # NetworkRpcRelay

# ── Charakter-Klassen-Cache ───────────────────────────────────────────────────
var _char_classes: Dictionary = {}   # StringName → CharacterClass


func _ready() -> void:
	GameManager.register_match(self)
	_load_character_classes()
	entry_controller.entry_phase_complete.connect(_on_entry_phase_complete)


# ── Initialisierung ───────────────────────────────────────────────────────────

func initialize(configs: Array[Dictionary], cfg: Dictionary) -> void:
	match_config = cfg
	_states.clear()
	_turn_order.clear()

	for c in configs:
		var state := PlayerState.new()
		state.player_id    = c["player_id"]
		state.player_name  = c["player_name"]
		state.is_ai        = c.get("is_ai", false)
		state.ai_difficulty = c.get("ai_difficulty", 1)
		state.health       = c.get("vitality", 3)
		state.max_health   = c.get("max_vitality", 3)
		state.influence    = 2
		state.chips        = 50
		_states[state.player_id] = state
		_turn_order.append(state.player_id)
		EventBus.player_registered.emit(state.player_id, state.to_dict())

	risk_controller.setup_from_config(match_config)
	current_phase = Phase.CHARACTER_SELECT
	EventBus.phase_changed.emit("CHARACTER_SELECT")


# ── Charakter-Auswahl ─────────────────────────────────────────────────────────

func select_character(player_id: int, class_id: StringName, gender: String) -> bool:
	var state := get_state(player_id)
	if state == null or current_phase != Phase.CHARACTER_SELECT:
		return false

	var char_class := get_character_class(class_id)
	if char_class == null:
		return false

	state.char_class_id = class_id
	state.gender        = gender

	# Startwerte der Klasse anwenden
	state.health         = char_class.start_health
	state.max_health     = char_class.start_health
	state.suspicion      = char_class.start_suspicion
	state.heat           = char_class.start_heat
	state.influence      = char_class.start_influence
	state.chips          = char_class.start_chips

	EventBus.character_selected.emit(player_id, class_id)
	return true


## Bestätigt das Loadout — Items werden fürs Schmuggeln ausgewählt.
func confirm_loadout(player_id: int, item_ids: Array[StringName]) -> bool:
	var state := get_state(player_id)
	if state == null:
		return false

	var char_class := get_character_class(state.char_class_id)
	var max_slots  := char_class.smuggle_slots if char_class else 2

	# Garantierte Items hinzufügen
	var all_items: Array[StringName] = []
	if char_class:
		for gid in char_class.guaranteed_items:
			all_items.append(gid)

	# Gewählte Items (bis max_slots)
	var count := 0
	for iid in item_ids:
		if count >= max_slots:
			break
		if ItemDatabase.has_item(iid):
			all_items.append(iid)
			count += 1

	state.smuggled_items = all_items
	for iid in all_items:
		state.add_item(iid)

	EventBus.loadout_confirmed.emit(player_id, all_items)
	_check_all_loadouts_confirmed()
	return true


func _check_all_loadouts_confirmed() -> void:
	# Wenn alle Spieler ihr Loadout bestätigt haben → Entry-Phase
	for state in _states.values():
		if state.char_class_id == &"":
			return   # Noch nicht alle ausgewählt
		if state.smuggled_items.is_empty() and not state.is_ai:
			return
	_start_entry_phase()


# ── Einlass-Phase ─────────────────────────────────────────────────────────────

func _start_entry_phase() -> void:
	current_phase = Phase.ENTRY_CHECK
	EventBus.phase_changed.emit("ENTRY_CHECK")

	var ids: Array[int] = []
	for pid in _states.keys():
		ids.append(pid)
	entry_controller.start_entry_checks(ids)

	# KI-Spieler direkt durchführen
	for state in _states.values():
		if state.is_ai:
			_ai_auto_loadout(state)
			entry_controller.run_check(state.player_id, self)

	# Menschliche Spieler: Entry-Check auf Anfrage (UI triggert confirm_entry_check)


func confirm_entry_check(player_id: int) -> Dictionary:
	if current_phase != Phase.ENTRY_CHECK:
		return {}
	return entry_controller.run_check(player_id, self)


func _on_entry_phase_complete() -> void:
	# Rauswürfe verarbeiten
	for state in _states.values():
		if state.is_eliminated:
			EventBus.player_eliminated.emit(state.player_id, -1, state.elimination_cause)

	current_phase = Phase.CASINO_FLOOR
	EventBus.phase_changed.emit("CASINO_FLOOR")
	_start_round()


# ── Runden-Ablauf ─────────────────────────────────────────────────────────────

func _start_round() -> void:
	_round_index   += 1
	_turn_index     = 0
	_actions_this_turn = 0

	# Items verteilen
	_distribute_round_items()

	EventBus.round_started.emit(_round_index, get_active_player_id())
	_start_turn()


func _start_turn() -> void:
	_actions_this_turn = 0
	current_turn_phase = TurnPhase.ITEM
	var active_id := get_active_player_id()

	EventBus.turn_phase_changed.emit("ITEM")
	EventBus.audio_play_sfx.emit("turn_start")

	# KI-Zug sofort ausführen
	var state := get_state(active_id)
	if state != null and state.is_ai:
		_run_ai_turn(active_id)


func advance_turn_phase() -> void:
	match current_turn_phase:
		TurnPhase.ITEM:
			current_turn_phase = TurnPhase.ACTION
			EventBus.turn_phase_changed.emit("ACTION")
		TurnPhase.ACTION:
			current_turn_phase = TurnPhase.RESOLVE
			EventBus.turn_phase_changed.emit("RESOLVE")
			_end_turn()


func _end_turn() -> void:
	var pid := get_active_player_id()
	var state := get_state(pid)
	if state != null:
		# Status-Ticks
		var expired := state.tick_statuses()
		for sid in expired:
			EventBus.player_status_removed.emit(pid, sid)

		# Gift-Schaden
		if state.has_status(&"poisoned"):
			state.modify_resource("health", -1)
			EventBus.player_health_changed.emit(pid, state.health + 1, state.health)
			if state.is_eliminated:
				EventBus.player_eliminated.emit(pid, -1, "poisoned")

		state.stat_rounds_survived += 1

	EventBus.turn_ended.emit(pid, "action")
	_check_win_conditions()

	if current_phase == Phase.CASINO_FLOOR:
		_advance_to_next_player()


func _advance_to_next_player() -> void:
	var attempts := 0
	while attempts < _turn_order.size():
		_turn_index = (_turn_index + 1) % _turn_order.size()
		var candidate_state := get_state(_turn_order[_turn_index])
		if candidate_state != null and not candidate_state.is_eliminated:
			break
		attempts += 1

	if _turn_index == 0:
		_start_round()
	else:
		_start_turn()


# ── Aktionen ──────────────────────────────────────────────────────────────────

func request_use_item(user_id: int, item_id: StringName, target_id: int) -> Dictionary:
	if not _is_authority():
		return {}
	if get_active_player_id() != user_id:
		EventBus.item_use_failed.emit(user_id, item_id, "not_your_turn")
		return {"success": false, "reason": "not_your_turn"}
	if current_turn_phase != TurnPhase.ITEM:
		EventBus.item_use_failed.emit(user_id, item_id, "wrong_phase")
		return {"success": false, "reason": "wrong_phase"}

	var user_state   := get_state(user_id)
	var target_state := get_state(target_id) if target_id != user_id else user_state
	var idef         := ItemDatabase.get_item(item_id) as ItemDefinition

	if idef == null:
		EventBus.item_use_failed.emit(user_id, item_id, "unknown_item")
		return {"success": false, "reason": "unknown_item"}
	if not user_state.has_item(item_id):
		EventBus.item_use_failed.emit(user_id, item_id, "not_in_inventory")
		return {"success": false, "reason": "not_in_inventory"}

	var can := idef.can_use(user_state, target_state, self)
	if not can["allowed"]:
		EventBus.item_use_failed.emit(user_id, item_id, can["reason"])
		return {"success": false, "reason": can["reason"]}

	# Suspicion-Kosten
	if idef.suspicion_on_use > 0:
		user_state.modify_resource("suspicion", idef.suspicion_on_use)

	var health_before := target_state.health
	var result := idef.execute_effect(user_state, target_state, self)
	user_state.record_item_use(item_id)

	if result.get("success", false):
		if not result.get("passive", false):
			user_state.remove_item(item_id)

	# Item-Effekt kann das Ziel verletzt/eliminiert haben (z.B. Revolver) — HUD informieren
	if target_state.health != health_before:
		EventBus.player_health_changed.emit(target_id, health_before, target_state.health)
		if target_state.is_eliminated:
			EventBus.player_eliminated.emit(target_id, user_id, target_state.elimination_cause)

	# Private Infos (ai_lens etc.) NUR an user_id schicken
	if result.get("is_private", false):
		EventBus.item_used.emit(user_id, item_id, target_id, result)
		# rpc_relay sendet nur an user_id
	else:
		EventBus.item_used.emit(user_id, item_id, target_id, result)

	# Lärm-Reaktion für Revolver
	if result.has("noise_zone") and result.has("noise_suspicion"):
		_apply_zone_noise(result["noise_zone"], result["noise_suspicion"], user_id)

	_check_win_conditions()
	return result


func request_risk_action(actor_id: int, target_id: int) -> Dictionary:
	if not _is_authority():
		return {}
	if get_active_player_id() != actor_id:
		return {"success": false, "reason": "not_your_turn"}
	if current_turn_phase != TurnPhase.ACTION:
		return {"success": false, "reason": "wrong_phase"}

	var actor_state  := get_state(actor_id)
	var target_state := get_state(target_id)
	if actor_state == null or target_state == null:
		return {"success": false, "reason": "invalid_state"}

	var outcome := risk_controller.draw()
	if outcome == null:
		return {"success": false, "reason": "pool_empty"}

	# Outcome anwenden
	var actual_delta := target_state.modify_resource(outcome.resource, outcome.delta)
	EventBus.risk_triggered.emit(actor_id, target_id, outcome.outcome_id, actual_delta)
	EventBus.audio_play_sfx.emit("risk_win" if outcome.delta > 0 else "risk_lose")

	# Weste zerstören wenn Treffer
	if outcome.delta < -1 and target_state.has_status(&"protected"):
		target_state.remove_status(&"protected")
		EventBus.item_destroyed.emit(target_id, &"bulletproof_band")

	if target_state.is_eliminated:
		EventBus.player_eliminated.emit(target_id, actor_id, target_state.elimination_cause)
		actor_state.stat_targets_hit += 1

	_actions_this_turn += 1
	_check_win_conditions()

	var max_actions: int = match_config.get("actions_per_turn", 1)
	if _actions_this_turn >= max_actions:
		_end_turn()

	return {"success": true, "outcome_id": outcome.outcome_id, "delta": actual_delta}


func request_move_zone(player_id: int, target_zone: String) -> bool:
	var state := get_state(player_id)
	if state == null or state.is_eliminated:
		return false
	if state.has_status(&"stuck"):
		EventBus.ui_toast.emit("Du kannst dich nicht bewegen!", "warn", 2.0)
		return false

	# Vault nur mit Key oder nach Boss
	if target_zone == "vault" and not state.has_vault_key:
		EventBus.ui_toast.emit("Du brauchst den Vault-Schlüssel!", "warn", 2.0)
		return false

	var _old_zone := state.current_zone
	state.current_zone = target_zone
	if not state.visited_zones.has(target_zone):
		state.visited_zones.append(target_zone)

	EventBus.player_location_changed.emit(player_id, target_zone)

	if target_zone == "vault":
		_trigger_vault_event(player_id)
	elif target_zone == "boss_office":
		_trigger_boss_encounter(player_id)

	return true


# ── Vault & Boss ──────────────────────────────────────────────────────────────

func _trigger_vault_event(player_id: int) -> void:
	current_phase = Phase.VAULT_RUN
	EventBus.phase_changed.emit("VAULT_RUN")
	EventBus.vault_door_state_changed.emit(true, player_id)
	# Vault enthüllt: Win-Condition "reach_vault" erfüllt
	var state := get_state(player_id)
	if state != null:
		state.objective_progress["reach_vault"] = true
	_check_win_conditions()


func _trigger_boss_encounter(player_id: int) -> void:
	current_phase = Phase.BOSS_ENCOUNTER
	EventBus.phase_changed.emit("BOSS_ENCOUNTER")
	EventBus.boss_encounter_started.emit(player_id)


func request_attack_boss(player_id: int, item_id: StringName = &"") -> Dictionary:
	if current_phase != Phase.BOSS_ENCOUNTER:
		return {"success": false, "reason": "not_in_boss_encounter"}

	var state := get_state(player_id)
	var damage := 1

	if item_id != &"" and state.has_item(item_id):
		var idef := ItemDatabase.get_item(item_id) as ItemDefinition
		if idef != null and idef.category == "weapon":
			damage = 2
			state.remove_item(item_id)

	_boss_health -= damage
	if _boss_health <= 0:
		_boss_health = 0
		EventBus.boss_eliminated.emit(player_id)
		EventBus.casino_won.emit(player_id)
		_end_match(player_id, "casino_takeover")
		return {"success": true, "boss_killed": true}

	return {"success": true, "boss_health_remaining": _boss_health, "damage": damage}


# ── Hilfsfunktionen ───────────────────────────────────────────────────────────

func _apply_zone_noise(zone: String, suspicion_amount: int, shooter_id: int) -> void:
	for state in _states.values():
		if state.current_zone == zone and not state.is_eliminated:
			if state.player_id != shooter_id:
				state.modify_resource("suspicion", suspicion_amount)
				EventBus.player_suspicion_changed.emit(state.player_id,
						state.suspicion - suspicion_amount, state.suspicion)
				if state.is_eliminated:
					EventBus.player_ejected.emit(state.player_id, "caught_in_shooting")
					EventBus.player_eliminated.emit(state.player_id, shooter_id, "ejected")


func _distribute_round_items() -> void:
	var items_per_round: int = match_config.get("items_per_round", 2)
	var available_ids   := ItemDatabase.get_all_ids()
	if available_ids.is_empty():
		return

	for state in _states.values():
		if state.is_eliminated:
			continue
		for i in items_per_round:
			var random_id: StringName = available_ids[randi() % available_ids.size()]
			state.add_item(random_id)
			EventBus.item_given.emit(state.player_id, random_id, "round_distribution")


func _check_win_conditions() -> void:
	var alive: Array[PlayerState] = []
	for state in _states.values():
		if not state.is_eliminated:
			alive.append(state)

	# Letzter Überlebender
	if alive.size() <= 1:
		var winner_id := alive[0].player_id if alive.size() == 1 else -1
		_end_match(winner_id, "last_standing")
		return

	# Vault-Ziel erreicht
	for state in alive:
		if state.objective_progress.get("reach_vault", false):
			_end_match(state.player_id, "vault_reached")
			return


func _end_match(winner_id: int, condition: String) -> void:
	if current_phase == Phase.GAME_OVER:
		return
	current_phase = Phase.GAME_OVER

	var stats: Dictionary = {}
	for state in _states.values():
		stats[state.player_id] = {
			"name":           state.player_name,
			"rounds":         state.stat_rounds_survived,
			"items_used":     state.stat_items_used,
			"hits":           state.stat_targets_hit,
			"chips_won":      state.stat_chips_won,
			"final_chips":    state.chips,
			"eliminated":     state.is_eliminated,
		}

	EventBus.match_over.emit(winner_id, condition, stats)
	EventBus.audio_play_sfx.emit("match_over")
	GameManager.record_match_over(winner_id, stats)


func _load_character_classes() -> void:
	var path := "res://resources/characters/"
	var dir  := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(path + fname)
			if res is CharacterClass:
				_char_classes[res.class_id] = res
		fname = dir.get_next()
	dir.list_dir_end()


func _ai_auto_loadout(state: PlayerState) -> void:
	var char_class := get_character_class(state.char_class_id)
	if char_class == null:
		return
	# KI wählt zufällige Schmuggelitems basierend auf Klasse
	var smuggleable := ItemDatabase.get_smuggleable_items()
	smuggleable.shuffle()
	var slots := char_class.smuggle_slots
	state.smuggled_items.clear()
	for gid in char_class.guaranteed_items:
		state.smuggled_items.append(gid)
		state.add_item(gid)
	var count := 0
	for idef in smuggleable:
		if count >= slots:
			break
		if not state.smuggled_items.has(idef.item_id):
			state.smuggled_items.append(idef.item_id)
			state.add_item(idef.item_id)
			count += 1


# ── Öffentliche Getter ────────────────────────────────────────────────────────

func get_state(player_id: int) -> PlayerState:
	return _states.get(player_id)


func get_all_states() -> Array:
	return _states.values()


func get_active_player_id() -> int:
	if _turn_order.is_empty():
		return -1
	return _turn_order[_turn_index]


func get_character_class(class_id: StringName) -> CharacterClass:
	return _char_classes.get(class_id)


func get_boss_health() -> int:
	return _boss_health


func _is_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


# ── KI-Zug ───────────────────────────────────────────────────────────────────

func _run_ai_turn(ai_id: int) -> void:
	await get_tree().create_timer(1.2).timeout   # "Denkpause" für Atmosphäre
	EventBus.ai_decision_made.emit(ai_id, {})
	# Wird von AiOpponentController detaillierter ausgeführt (siehe ai/)
	# Hier nur Fallback: Risiko-Aktion gegen zufälligen Gegner
	var targets: Array[int] = []
	for pid in _turn_order:
		if pid != ai_id:
			var s := get_state(pid)
			if s != null and not s.is_eliminated:
				targets.append(pid)
	if targets.is_empty():
		_end_turn()
		return
	var target_id: int = targets[randi() % targets.size()]
	advance_turn_phase()   # ITEM → ACTION
	request_risk_action(ai_id, target_id)
