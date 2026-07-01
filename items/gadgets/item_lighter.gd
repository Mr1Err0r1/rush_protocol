extends ItemDefinition
## class_name ItemLighter
## Feuerzeug — Null Protocol
## Zündet etwas an (Vorhang, Papierkorb, etc.).
## Alle Spieler in der Zone bekommen Ablenkungsbonus — ihre Suspicion sinkt
## weil Security abgelenkt ist. ABER: Rauchmelder → Kasino-Alarm möglich.

func _init() -> void:
	item_id          = &"lighter"
	display_name     = "Feuerzeug"
	description      = "Ein goldenes Zippo. Für Zigaretten, Ablenkungsmanöver und alles dazwischen. Feuer vergisst keine Fingerabdrücke."
	category         = "gadget"
	item_type        = "distraction"
	can_be_smuggled  = true
	detection_weight = 1   # Metallisch aber unauffällig
	confiscation_chance = 0.05
	requires_target  = false
	usable_in_zones  = ["lobby","floor","bar","vault_corridor","backroom"]
	max_uses_per_match = 1
	suspicion_on_use   = 0


@export var suspicion_reduction_all_zone: int = 2
@export var alarm_chance: float = 0.25


func execute_effect(user_state: PlayerState, _target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:
	var alarm_triggered: bool = randf() < alarm_chance
	var affected_player_ids: Array[int] = []

	# Alle Spieler in gleicher Zone bekommen Suspicion-Reduktion
	for state in match_ctrl.get_all_states():
		if state.current_zone == user_state.current_zone and not state.is_eliminated:
			state.modify_resource("suspicion", -suspicion_reduction_all_zone)
			affected_player_ids.append(state.player_id)

	return {
		"success":           true,
		"alarm_triggered":   alarm_triggered,
		"affected_players":  affected_player_ids,
		"suspicion_delta":   -suspicion_reduction_all_zone,
		"zone":              user_state.current_zone,
		"sound_key":         "fire_whoosh",
	}
