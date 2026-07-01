extends Node
class_name AiOpponentController
## AiOpponentController — Null Protocol
## KI-Entscheidungslogik für einen einzelnen KI-Spieler.
## Drei Schwierigkeitsgrade: Easy=zufällig, Normal=taktisch, Hard=strategisch+bluffend.

@export var player_id: int   = -1
@export var difficulty: int  = 1   # 0=easy, 1=normal, 2=hard

var _match_ctrl: MatchController

const THINK_TIME := {0: 0.6, 1: 1.1, 2: 1.8}   # Sekunden "Denkzeit" je Schwierigkeit


func initialize(match_controller: MatchController, pid: int, diff: int) -> void:
	_match_ctrl = match_controller
	player_id   = pid
	difficulty  = diff


## Wird von MatchController aufgerufen wenn dieser KI-Spieler dran ist.
func take_turn() -> void:
	EventBus.ai_thinking_started.emit(player_id)
	var think_sec: float = THINK_TIME.get(difficulty, 1.1)
	await _match_ctrl.get_tree().create_timer(think_sec).timeout

	var state := _match_ctrl.get_state(player_id)
	if state == null or state.is_eliminated:
		return

	# Phase 1: Item benutzen?
	var item_action := _decide_item_use(state)
	if item_action["use_item"]:
		_match_ctrl.request_use_item(player_id, item_action["item_id"], item_action["target_id"])
		await _match_ctrl.get_tree().create_timer(0.5).timeout

	# Phase 2: Zur nächsten Phase
	_match_ctrl.advance_turn_phase()

	# Phase 3: Risiko-Aktion oder Zonenwechsel
	var action := _decide_main_action(state)
	EventBus.ai_decision_made.emit(player_id, action)

	match action["type"]:
		"risk":
			_match_ctrl.request_risk_action(player_id, action["target_id"])
		"move":
			_match_ctrl.request_move_zone(player_id, action["zone"])
			_match_ctrl.advance_turn_phase()
		"boss_attack":
			_match_ctrl.request_attack_boss(player_id, action.get("item_id", &""))


# ── Entscheidungs-Logik ────────────────────────────────────────────────────────

func _decide_item_use(state: PlayerState) -> Dictionary:
	match difficulty:
		0:  return _easy_item(state)
		1:  return _normal_item(state)
		2:  return _hard_item(state)
	return {"use_item": false}


func _easy_item(state: PlayerState) -> Dictionary:
	# Easy: 30% Chance ein zufälliges Item zu benutzen
	if state.inventory.is_empty() or randf() > 0.3:
		return {"use_item": false}
	var item_id: StringName = state.inventory.keys()[randi() % state.inventory.size()]
	var target := _random_enemy_id(state)
	return {"use_item": true, "item_id": item_id, "target_id": target}


func _normal_item(state: PlayerState) -> Dictionary:
	# Normal: priorisiert Heilung wenn schwach, Angriff wenn stark
	if state.health == 1 and state.has_item(&"bulletproof_band"):
		return {"use_item": true, "item_id": &"bulletproof_band", "target_id": player_id}

	if state.suspicion >= 7 and state.has_item(&"coin"):
		return {"use_item": true, "item_id": &"coin", "target_id": player_id}

	if state.has_item(&"poison_needle"):
		var weakest := _weakest_enemy(state)
		if weakest != -1:
			return {"use_item": true, "item_id": &"poison_needle", "target_id": weakest}

	return {"use_item": false}


func _hard_item(state: PlayerState) -> Dictionary:
	# Hard: vollständige Strategie

	# Wenn kurz vor Elimination → sofort Schutz anlegen
	if state.health <= 1:
		if state.has_item(&"bulletproof_band"):
			return {"use_item": true, "item_id": &"bulletproof_band", "target_id": player_id}

	# Wenn Suspicion kritisch → Bestechung via Coin
	if state.suspicion >= 8 and state.has_item(&"coin"):
		return {"use_item": true, "item_id": &"coin", "target_id": player_id}

	# Wenn gefährlichster Gegner >3 HP → Giftnadel
	var strongest := _strongest_enemy(state)
	if strongest != -1:
		var enemy := _match_ctrl.get_state(strongest)
		if enemy != null and enemy.health >= 3 and state.has_item(&"poison_needle"):
			return {"use_item": true, "item_id": &"poison_needle", "target_id": strongest}

	# Fake-Cards wenn Pool-Outcome nächste schlecht
	var next_outcome := _match_ctrl.risk_controller.peek()
	if next_outcome == &"house_wins" and state.has_item(&"fake_cards"):
		return {"use_item": true, "item_id": &"fake_cards", "target_id": player_id}

	# KI-Linse um Info zu sammeln
	if state.has_item(&"ai_lens") and state.get_use_count(&"ai_lens") == 0:
		var scan_target := _most_dangerous_enemy(state)
		if scan_target != -1:
			return {"use_item": true, "item_id": &"ai_lens", "target_id": scan_target}

	return {"use_item": false}


func _decide_main_action(state: PlayerState) -> Dictionary:
	# Vault-Ziel: wenn Schlüssel vorhanden → Vault-Run
	if state.has_vault_key and state.current_zone != "vault":
		return {"type": "move", "zone": "vault"}

	# Boss-Begegnung wenn in boss_office
	if state.current_zone == "boss_office":
		var best_weapon := _best_weapon_in_inventory(state)
		return {"type": "boss_attack", "item_id": best_weapon}

	# Strategie-basiertes Ziel
	match difficulty:
		0: return _easy_action(state)
		1: return _normal_action(state)
		2: return _hard_action(state)
	return _normal_action(state)


func _easy_action(state: PlayerState) -> Dictionary:
	var target := _random_enemy_id(state)
	return {"type": "risk", "target_id": target if target != -1 else player_id}


func _normal_action(state: PlayerState) -> Dictionary:
	# Auf sich selbst wenn Chips gebraucht, auf Gegner wenn Angriff sinnvoll
	if state.chips < 20:
		return {"type": "risk", "target_id": player_id}   # Selbst spielen für Chips
	var target := _weakest_enemy(state)
	return {"type": "risk", "target_id": target if target != -1 else player_id}


func _hard_action(state: PlayerState) -> Dictionary:
	# Analysiert ob Vault-Move sinnvoller ist als Angriff
	if not state.has_vault_key:
		# Versuche Vault-Key zu erreichen (Backroom)
		if state.current_zone == "floor" and randf() > 0.6:
			return {"type": "move", "zone": "backroom"}

	var strongest := _strongest_enemy(state)
	if strongest == -1:
		return {"type": "risk", "target_id": player_id}

	var enemy := _match_ctrl.get_state(strongest)
	# Angreifen wenn Gegner schwach ist, sonst selbst spielen
	if enemy != null and enemy.health <= 2:
		return {"type": "risk", "target_id": strongest}
	elif state.chips < 30:
		return {"type": "risk", "target_id": player_id}
	else:
		return {"type": "risk", "target_id": strongest}


# ── Analyse-Hilfsfunktionen ───────────────────────────────────────────────────

func _random_enemy_id(own_state: PlayerState) -> int:
	var enemies: Array[int] = []
	for state in _match_ctrl.get_all_states():
		if state.player_id != player_id and not state.is_eliminated:
			enemies.append(state.player_id)
	if enemies.is_empty():
		return -1
	return enemies[randi() % enemies.size()]


func _weakest_enemy(own_state: PlayerState) -> int:
	var best_id := -1
	var min_hp  := 999
	for state in _match_ctrl.get_all_states():
		if state.player_id != player_id and not state.is_eliminated:
			if state.health < min_hp:
				min_hp  = state.health
				best_id = state.player_id
	return best_id


func _strongest_enemy(own_state: PlayerState) -> int:
	var best_id  := -1
	var max_score := -1
	for state in _match_ctrl.get_all_states():
			if state.player_id != player_id and not state.is_eliminated:
				var score: float = state.health * 2.0 + state.influence + state.chips / 20.0
				if score > max_score:
					max_score = score
					best_id   = state.player_id
	return best_id


func _most_dangerous_enemy(own_state: PlayerState) -> int:
	return _strongest_enemy(own_state)


func _best_weapon_in_inventory(state: PlayerState) -> StringName:
	for item_id in state.inventory.keys():
		var idef := ItemDatabase.get_item(item_id) as ItemDefinition
		if idef != null and idef.category == "weapon":
			return item_id
	return &""
