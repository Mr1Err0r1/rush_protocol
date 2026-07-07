extends ItemDefinition
## class_name ItemFakeId
## Gefälschter Ausweis — Null Protocol
## Legt eine Verkleidung an: Security sieht eine andere Klasse,
## Suspicion sinkt sofort um 3. Wird durch KI-Linse durchleuchtet.

func _init() -> void:
	item_id             = &"fake_id"
	display_name        = "Gefälschter Ausweis"
	description         = "Ein perfekt gefälschter VIP-Gästeausweis. Biometrische Daten, Hologramm, alles echt — außer dem Namen."
	category            = "disguise"
	item_type           = "deception"
	can_be_smuggled     = true
	detection_weight    = 3
	confiscation_chance = 0.2
	requires_target     = false
	can_target_self     = true
	max_uses_per_match  = 1
	suspicion_on_use    = 0


@export var disguise_id: StringName  = &"disguise_vip"
@export var suspicion_reduction: int = 3


func execute_effect(user_state: PlayerState, _target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	if user_state.has_status(&"disguised"):
		return {"success": false, "reason": "already_disguised"}

	user_state.apply_status(&"disguised", 4)   # hält 4 Runden
	user_state.disguise_id = disguise_id
	user_state.modify_resource("suspicion", -suspicion_reduction)

	EventBus.player_disguise_changed.emit(user_state.player_id, disguise_id)
	return {
		"success":           true,
		"disguise_id":       str(disguise_id),
		"suspicion_delta":   -suspicion_reduction,
		"duration_rounds":   4,
		"sound_key":         "item_generic",
	}
