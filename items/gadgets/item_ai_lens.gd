extends ItemDefinition
class_name ItemAiLens
## KI-Linse (als Stift getarnt) — Null Protocol

func _init() -> void:
	item_id             = &"ai_lens"
	display_name        = "KI-Linse (Stift-Kamera)"
	description         = "Ein Kugelschreiber mit Mikrokamera und eingebetteter KI."
	category            = "intel"
	item_type           = "surveillance"
	can_be_smuggled     = true
	detection_weight    = 1
	confiscation_chance = 0.02
	requires_target     = true
	can_target_self     = false
	can_target_enemies  = true
	can_target_allies   = true
	max_uses_per_match  = 4
	suspicion_on_use    = 0


func execute_effect(_user_state: PlayerState, target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:
	var revealed: Dictionary = {}

	revealed["health"]     = target_state.health
	revealed["suspicion"]  = target_state.suspicion
	revealed["zone"]       = target_state.current_zone
	revealed["char_class"] = str(target_state.char_class_id)

	if target_state.has_status(&"disguised"):
		revealed["real_identity"]    = str(target_state.char_class_id)
		revealed["disguise_exposed"] = true

	var risk_ctrl = match_ctrl.risk_controller
	if risk_ctrl != null and risk_ctrl.is_cheat_active():
		revealed["cheat_detected"] = true
		revealed["cheater_id"]     = risk_ctrl.get_cheat_owner_id()

	var inventory_categories: Array[String] = []
	for iid in target_state.inventory.keys():
		var idef = ItemDatabase.get_item(iid)
		if idef != null and not inventory_categories.has(idef.category):
			inventory_categories.append(idef.category)
	revealed["inventory_categories"] = inventory_categories

	return {
		"success":    true,
		"is_private": true,
		"revealed":   revealed,
		"sound_key":  "lens_scan",
	}
