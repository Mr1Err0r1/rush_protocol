extends ItemDefinition
class_name ItemBug
## Abhörwanze — Null Protocol
## Platziert eine unsichtbare Wanze beim Ziel.
## Für X Runden bekommt der Benutzer nach JEDEM Zug des Ziels
## einen privaten Bericht: Was hat das Ziel getan? Welche Items benutzt?
## Sehr mächtig für Information — schwer zu verteidigen.

func _init() -> void:
	item_id             = &"listening_bug"
	display_name        = "Abhörwanze"
	description         = "Kleiner als ein Fingernagel, klebt unter jedem Tisch. Drei Runden lang weißt du jeden Zug deines Ziels — bevor Security es merkt."
	category            = "intel"
	item_type           = "surveillance"
	can_be_smuggled     = true
	detection_weight    = 1
	confiscation_chance = 0.03
	requires_target     = true
	can_target_self     = false
	can_target_enemies  = true
	max_uses_per_match  = 2
	suspicion_on_use    = 0


@export var bug_duration_rounds: int = 3


func execute_effect(user_state: PlayerState, target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:

	target_state.apply_status(&"bugged", bug_duration_rounds)

	if match_ctrl.has_method("register_bug_listener"):
		match_ctrl.register_bug_listener(
			user_state.player_id,
			target_state.player_id,
			bug_duration_rounds
		)

	return {
		"success": true,
		"is_private": true,
		"target_bugged": true,
		"duration": bug_duration_rounds,
		"sound_key": "item_generic",
	}
