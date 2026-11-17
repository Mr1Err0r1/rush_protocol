extends ItemDefinition
class_name ItemHandcuffs
## Handschellen — Roulette-Modus: das Ziel setzt seinen nächsten Zug aus.

func _init() -> void:
	item_id             = &"handcuffs"
	display_name        = "Handschellen"
	description         = "Der gewählte Gegner setzt seinen nächsten Zug aus."
	category            = "tool"
	item_type           = "roulette"
	can_be_smuggled     = false
	roulette_only       = true
	requires_target     = true
	can_target_self     = false
	can_target_enemies  = true


func can_use(user: PlayerState, target: PlayerState, match_ctrl: Node) -> Dictionary:
	if match_ctrl.roulette == null:
		return {"allowed": false, "reason": "no_roulette_table"}
	if target == null or target.player_id == user.player_id:
		return {"allowed": false, "reason": "invalid_target"}
	if match_ctrl.roulette.is_cuffed(target.player_id):
		return {"allowed": false, "reason": "already_cuffed"}
	return {"allowed": true, "reason": ""}


func execute_effect(user: PlayerState, target: PlayerState, match_ctrl: Node) -> Dictionary:
	var ok: bool = match_ctrl.roulette.use_cuff(user.player_id, target.player_id)
	return {"success": ok, "reason": "" if ok else "cannot_cuff", "sound_key": "item_steal"}
