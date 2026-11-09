extends ItemDefinition
class_name ItemMedkit
## Verbandskasten — Roulette-Modus: stellt 1 Leben wieder her (bis zum Maximum).

const HEAL_AMOUNT := 1

func _init() -> void:
	item_id             = &"medkit"
	display_name        = "Verbandskasten"
	description         = "Stellt 1 Leben wieder her (nicht über das Maximum)."
	category            = "tool"
	item_type           = "roulette"
	can_be_smuggled     = false
	roulette_only       = true
	requires_target     = false


func can_use(user: PlayerState, _target: PlayerState, match_ctrl: Node) -> Dictionary:
	if match_ctrl.roulette == null:
		return {"allowed": false, "reason": "no_roulette_table"}
	if user.health >= user.max_health:
		return {"allowed": false, "reason": "full_health"}
	return {"allowed": true, "reason": ""}


func execute_effect(user: PlayerState, _target: PlayerState, _match_ctrl: Node) -> Dictionary:
	var healed: int = user.modify_resource("health", HEAL_AMOUNT)
	return {"success": healed > 0, "reason": "" if healed > 0 else "full_health", "healed": healed, "sound_key": "item_heal"}
