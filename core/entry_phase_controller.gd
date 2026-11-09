extends Node
class_name EntryPhaseController
## EntryPhaseController — Null Protocol
## Verwaltet die Einlass-Phase bevor Spieler das Casino betreten.
## Jeder Spieler wählt Loadout → wird am Eingang geprüft → bestimmte Items
## werden konfisziert, Suspicion erhöht, oder Spieler sofort rausgeworfen.

signal entry_phase_complete()

## Würfel-Hook: in Tests durch eine feste Funktion (-> float) ersetzbar.
var roll_fn: Callable = Callable()

var _pending_checks: Array[int] = []   # player_ids die noch geprüft werden müssen
var _results: Dictionary = {}          # player_id → {passed, confiscated, suspicion_gained}


func start_entry_checks(player_ids: Array[int]) -> void:
	_pending_checks = player_ids.duplicate()
	_results.clear()
	if _pending_checks.is_empty():
		entry_phase_complete.emit()


## Führt den Einlass-Check für einen Spieler durch.
## match_ctrl wird gebraucht um an PlayerState zu kommen.
func run_check(player_id: int, match_ctrl: Node) -> Dictionary:
	var state: PlayerState = match_ctrl.get_state(player_id)
	if state == null:
		return {"passed": false, "reason": "no_state"}

	EventBus.entry_check_started.emit(player_id)

	var char_class = _get_class(state, match_ctrl)
	var result := {
		"passed":            true,
		"confiscated":       [] as Array[StringName],
		"suspicion_gained":  0,
		"ejected":           false,
	}

	# Garantierte Items der Klasse nie konfiszieren
	var guaranteed: Array[StringName] = []
	if char_class != null:
		guaranteed = char_class.guaranteed_items

	# Jeden Item-Slot prüfen
	var items_to_remove: Array[StringName] = []
	for item_id in state.smuggled_items:
		if guaranteed.has(item_id):
			continue   # Polizei darf Dienstwaffe behalten etc.

		var idef: ItemDefinition = ItemDatabase.get_item(item_id)
		if idef == null:
			continue

		# Fundchance: Item-Grundwert, Misstrauen, detection_resistance und
		# Fraktions-/Rollenprofil (siehe CheckpointRules)
		var final_chance: float = CheckpointRules.item_find_chance(idef, state.suspicion, char_class, 1.0)

		if _roll() < final_chance:
			items_to_remove.append(item_id)
			result["confiscated"].append(item_id)
			result["suspicion_gained"] += idef.detection_weight
			EventBus.item_confiscated.emit(player_id, item_id)

	# Konfiszierte Items entfernen
	for item_id in items_to_remove:
		state.smuggled_items.erase(item_id)
		state.remove_item(item_id)

	# Suspicion anwenden
	var sus_gain: int = result["suspicion_gained"]
	if sus_gain > 0:
		state.modify_resource("suspicion", sus_gain)
		EventBus.player_suspicion_changed.emit(player_id, state.suspicion - sus_gain, state.suspicion)

	# Sofortiger Rauswurf wenn Suspicion zu hoch durch Funde
	if state.suspicion >= state.max_suspicion or (items_to_remove.size() >= 2 and not _has_bribe(state)):
		result["passed"]  = false
		result["ejected"] = true
		state.is_eliminated    = true
		state.elimination_cause = "ejected"
		EventBus.player_ejected.emit(player_id, "caught_smuggling")
	else:
		# Erfolgreich rein: Items als "geschmuggelt" markieren
		for item_id in state.smuggled_items:
			if not items_to_remove.has(item_id):
				EventBus.item_smuggled_in.emit(player_id, item_id)
		state.current_zone = "lobby"
		EventBus.entry_check_passed.emit(player_id, sus_gain)

	_results[player_id] = result
	_pending_checks.erase(player_id)

	if _pending_checks.is_empty():
		entry_phase_complete.emit()

	return result


## Etagenkontrolle beim Betreten von `zone` (Chancen: CheckpointRules).
## Ergebnis: {triggered, outcome ("none"|"clear"|"searched"|"confiscated"|"bounced"),
##            confiscated, suspicion_gained}
func run_checkpoint(player_id: int, zone: String, match_ctrl: Node) -> Dictionary:
	var result := {"triggered": false, "outcome": "none",
			"confiscated": [] as Array[StringName], "suspicion_gained": 0}
	if not CheckpointRules.is_checkpoint(zone):
		return result
	var state: PlayerState = match_ctrl.get_state(player_id)
	if state == null or state.is_eliminated:
		return result

	var char_class: CharacterClass = _get_class(state, match_ctrl)
	var cp: Dictionary = CheckpointRules.CHECKPOINTS[zone]
	var chance := CheckpointRules.trigger_chance(zone, state.suspicion, state.heat, char_class)
	if _roll() >= chance:
		result["outcome"] = "clear"
		EventBus.checkpoint_result.emit(player_id, zone, "clear", [])
		return result

	result["triggered"] = true
	EventBus.checkpoint_started.emit(player_id, zone)

	var guaranteed: Array[StringName] = []
	if char_class != null:
		guaranteed = char_class.guaranteed_items

	var found: Array[StringName] = []
	for item_id in state.smuggled_items.duplicate():
		if guaranteed.has(item_id) or not state.has_item(item_id):
			continue
		var idef: ItemDefinition = ItemDatabase.get_item(item_id)
		if idef == null:
			continue
		var p := CheckpointRules.item_find_chance(idef, state.suspicion, char_class, cp["strictness"])
		if _roll() < p:
			found.append(item_id)
			result["suspicion_gained"] += idef.detection_weight

	for item_id in found:
		state.smuggled_items.erase(item_id)
		state.remove_item(item_id)
		EventBus.item_confiscated.emit(player_id, item_id)
	result["confiscated"] = found

	var sus_gain: int = result["suspicion_gained"]
	if sus_gain > 0:
		state.modify_resource("suspicion", sus_gain)
		EventBus.player_suspicion_changed.emit(player_id, state.suspicion - sus_gain, state.suspicion)

	if found.size() >= 2 and not _has_bribe(state):
		result["outcome"] = "bounced"
		state.modify_resource("heat", 1)
	elif found.size() >= 1:
		result["outcome"] = "confiscated"
	else:
		result["outcome"] = "searched"
	EventBus.checkpoint_result.emit(player_id, zone, result["outcome"], found)
	return result


func _roll() -> float:
	return roll_fn.call() if roll_fn.is_valid() else randf()


func _get_class(state: PlayerState, match_ctrl: Node) -> CharacterClass:
	return match_ctrl.get_character_class(state.char_class_id)


func _has_bribe(state: PlayerState) -> bool:
	# Coin oder hoher Einfluss kann Security bestechen
	return state.has_item(&"coin") or state.influence >= 4


func get_result(player_id: int) -> Dictionary:
	return _results.get(player_id, {})


func all_checks_done() -> bool:
	return _pending_checks.is_empty()
