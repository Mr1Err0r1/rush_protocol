extends Node
class_name EntryPhaseController
## EntryPhaseController — Null Protocol
## Verwaltet die Einlass-Phase bevor Spieler das Casino betreten.
## Jeder Spieler wählt Loadout → wird am Eingang geprüft → bestimmte Items
## werden konfisziert, Suspicion erhöht, oder Spieler sofort rausgeworfen.

signal entry_phase_complete()

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

		# Suspicion der Klasse beeinflusst Entdeckungswahrscheinlichkeit
		var base_chance: float  = idef.confiscation_chance
		var suspicion_modifier: float = state.suspicion * 0.03   # 3% pro Suspicion-Punkt
		var final_chance: float = clampf(base_chance + suspicion_modifier, 0.0, 1.0)

		# Klassen-Bonus: z.B. Assassine kann Waffen besser verstecken
		if char_class != null and char_class.class_id == &"assassin":
			if idef.category == "weapon":
				final_chance *= 0.4   # Assassinen sind Profis im Verstecken

		if randf() < final_chance:
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


func _get_class(state: PlayerState, match_ctrl: Node) -> CharacterClass:
	return match_ctrl.get_character_class(state.char_class_id)


func _has_bribe(state: PlayerState) -> bool:
	# Coin oder hoher Einfluss kann Security bestechen
	return state.has_item(&"coin") or state.influence >= 4


func get_result(player_id: int) -> Dictionary:
	return _results.get(player_id, {})


func all_checks_done() -> bool:
	return _pending_checks.is_empty()
