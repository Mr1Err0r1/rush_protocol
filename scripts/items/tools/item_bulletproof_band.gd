extends ItemDefinition
class_name ItemBulletproofBand
## Kugelsicheres Band — Null Protocol
## Passives Schutz-Item. Beim Anlegen: gibt Status "protected".
## Absorbiert den ersten letalen Treffer (verhindert Tod).
## Danach zerstört (einmalig pro Match verwendbar).

func _init() -> void:
	item_id          = &"bulletproof_band"
	display_name     = "Kugelsicheres Schutzband"
	description      = "Kevlar-Streifen, um den Torso gewickelt. Nicht elegant, aber ein Einschuss der töten sollte, hinterlässt nur einen blauen Fleck. Einmal."
	category         = "tool"
	item_type        = "defense"
	can_be_smuggled  = true
	detection_weight = 7
	confiscation_chance = 0.65
	requires_target  = false
	can_target_self  = true
	max_uses_per_match = 1
	suspicion_on_use   = 0


func execute_effect(user_state: PlayerState, _target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	if user_state.has_status(&"protected"):
		return {"success": false, "reason": "already_protected"}

	user_state.apply_status(&"protected", 999)   # hält bis zum Treffer
	# MatchController entfernt "protected" beim ersten Treffer der >1 Schaden macht
	return {
		"success":    true,
		"passive":    true,
		"sound_key":  "vest_equip",
	}
