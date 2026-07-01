extends ItemDefinition
## class_name ItemGlue
## Kleber — Null Protocol
## Sabotage-Tool. Kann:
## - Einen Spieler "festkleben" (darf eine Runde Zone nicht verlassen)
## - Ein Item im Inventar eines Gegners unbrauchbar machen
## - Eine Tür/Schloss blockieren (Zone für X Runden gesperrt)

func _init() -> void:
	item_id          = &"glue"
	display_name     = "Supercleberpatrone"
	description      = "Industriekleber in einer unauffälligen Stiftmine. Ein Tropfen auf den richtigen Mechanismus, und nichts bewegt sich mehr. Außer dem Problem."
	category         = "tool"
	item_type        = "sabotage"
	can_be_smuggled  = true
	detection_weight = 2
	confiscation_chance = 0.08
	requires_target  = true
	can_target_self  = false
	can_target_enemies = true
	max_uses_per_match = 2
	suspicion_on_use   = 1


func execute_effect(_user_state: PlayerState, target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	# Klebt Ziel-Spieler fest: kann Zone 1 Runde nicht wechseln
	target_state.apply_status(&"stuck", 1)

	# Zusatz: eines der Items des Ziels wird unbrauchbar (zufällig)
	var disabled_item: StringName = &""
	var items := target_state.inventory.keys()
	if items.size() > 0:
		disabled_item = items[randi() % items.size()]
		target_state.apply_status(&"item_disabled_%s" % disabled_item, 2)

	return {
		"success":          true,
		"target_stuck":     true,
		"stuck_rounds":     1,
		"disabled_item":    str(disabled_item),
		"sound_key":        "glue_splat",
	}
