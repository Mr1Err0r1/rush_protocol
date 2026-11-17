extends ItemDefinition
class_name ItemMagnifier
## Lupe — Roulette-Modus: verrät dem Benutzer privat, ob die aktuelle Patrone scharf ist.

func _init() -> void:
	item_id             = &"magnifier"
	display_name        = "Lupe"
	description         = "Zeigt dir, ob die aktuelle Patrone scharf oder eine Platzpatrone ist."
	category            = "intel"
	item_type           = "roulette"
	can_be_smuggled     = false
	roulette_only       = true
	requires_target     = false
	max_uses_per_match  = -1


func can_use(_user: PlayerState, _target: PlayerState, match_ctrl: Node) -> Dictionary:
	if match_ctrl.roulette == null:
		return {"allowed": false, "reason": "no_roulette_table"}
	return {"allowed": true, "reason": ""}


func execute_effect(user: PlayerState, _target: PlayerState, match_ctrl: Node) -> Dictionary:
	var shell: int = match_ctrl.roulette_peek(user.player_id)
	if shell == ShellChamber.NONE:
		return {"success": false, "reason": "chamber_empty"}
	return {
		"success":    true,
		"is_private": true,
		"revealed":   {"shell": "live" if shell == ShellChamber.Shell.LIVE else "blank"},
		"sound_key":  "lens_scan",
	}
