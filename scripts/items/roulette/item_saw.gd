extends ItemDefinition
class_name ItemSaw
## Säge — Roulette-Modus: der nächste Schuss richtet doppelten Schaden an.

func _init() -> void:
	item_id             = &"saw"
	display_name        = "Säge"
	description         = "Dein nächster Schuss verursacht doppelten Schaden (auch bei Platzpatrone verbraucht)."
	category            = "weapon"
	item_type           = "roulette"
	can_be_smuggled     = false
	roulette_only       = true
	requires_target     = false


func can_use(user: PlayerState, _target: PlayerState, match_ctrl: Node) -> Dictionary:
	if match_ctrl.roulette == null:
		return {"allowed": false, "reason": "no_roulette_table"}
	if match_ctrl.roulette.is_sawed(user.player_id):
		return {"allowed": false, "reason": "already_sawed"}
	return {"allowed": true, "reason": ""}


func execute_effect(user: PlayerState, _target: PlayerState, match_ctrl: Node) -> Dictionary:
	var ok: bool = match_ctrl.roulette.use_saw(user.player_id)
	return {"success": ok, "reason": "" if ok else "already_sawed", "sound_key": "item_force"}
