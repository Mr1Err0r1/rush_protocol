extends ItemDefinition
## class_name ItemRevolver

func _init() -> void:
	item_id             = &"revolver"
	display_name        = "Revolver"
	description         = "Ein alter .38er. Laut, tödlich, unbestreitbar."
	category            = "weapon"
	item_type           = "lethal"
	can_be_smuggled     = true
	detection_weight    = 9
	confiscation_chance = 0.85
	requires_target     = true
	can_target_self     = false
	can_target_enemies  = true
	can_target_allies   = false
	max_uses_per_match  = 6
	suspicion_on_use    = 3
	requires_chips_cost = 0


func execute_effect(user_state: PlayerState, target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	var damage := 2
	var target_has_vest: bool = target_state.has_status(&"protected")
	if target_has_vest:
		damage = 1
	var actual_delta := target_state.modify_resource("health", -damage)
	var zone_noise_suspicion := 3
	if user_state.current_zone == "vault" or user_state.current_zone == "boss_office":
		zone_noise_suspicion = 5
	user_state.modify_resource("suspicion", suspicion_on_use)
	return {
		"success":          true,
		"damage":           -actual_delta,
		"target_killed":    target_state.is_eliminated,
		"noise_zone":       user_state.current_zone,
		"noise_suspicion":  zone_noise_suspicion,
		"blocked_by_vest":  target_has_vest,
		"sound_key":        "revolver_shot",
	}


func can_use(user_state: PlayerState, target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:
	var base := super.can_use(user_state, target_state, match_ctrl)
	if not base["allowed"]:
		return base
	if target_state.is_eliminated:
		return {"allowed": false, "reason": "target_already_eliminated"}
	return {"allowed": true, "reason": ""}
