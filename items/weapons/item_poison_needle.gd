extends ItemDefinition
## class_name ItemPoisonNeedle
## Giftnadel — Null Protocol
## Lautlose Waffe. Kein Lärm, kein sofortiger Tod.
## Ziel bekommt Status "poisoned" (verliert 1 HP pro Runde für X Runden).
## Sehr schwer zu entdecken beim Einlass.

func _init() -> void:
	item_id          = &"poison_needle"
	display_name     = "Giftnadel"
	description      = "Mikrofeine Nadel, gefüllt mit einem langsam wirkenden Neurotoxin. Kein Knall, kein Alarm — nur ein kurzes Kribbeln und Zeit."
	category         = "weapon"
	item_type        = "non_lethal"   # nicht sofort letal
	can_be_smuggled  = true
	detection_weight = 2   # sehr schwer zu finden
	confiscation_chance = 0.1
	requires_target  = true
	can_target_self  = false
	can_target_enemies = true
	max_uses_per_match = 2
	suspicion_on_use   = 0   # kein direktes Misstrauen


@export var poison_duration_rounds: int = 3
@export var poison_damage_per_round: int = 1


func execute_effect(_user_state: PlayerState, target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	# Bereits vergiftet? Dauer verlängern statt stacken
	if target_state.has_status(&"poisoned"):
		target_state.apply_status(&"poisoned", poison_duration_rounds, 0)
		return {
			"success":   true,
			"refreshed": true,
			"duration":  poison_duration_rounds,
			"sound_key": "needle_inject",
		}

	target_state.apply_status(&"poisoned", poison_duration_rounds)
	# Poison-Schaden wird in MatchController.process_status_effects() angewendet
	return {
		"success":          true,
		"duration_rounds":  poison_duration_rounds,
		"damage_per_round": poison_damage_per_round,
		"sound_key":        "needle_inject",
	}
