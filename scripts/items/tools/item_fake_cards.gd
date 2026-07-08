extends ItemDefinition
class_name ItemFakeCards
## Fake-Karten — Null Protocol
## Manipuliert den Risiko-Pool (das zentrale Spielelement).
## Erzeugt beim Benutzen einen "forced positive" Outcome.
## ABER: Wenn ein anderer Spieler "Linse mit KI" hat, kann er den Betrug entdecken.

func _init() -> void:
	item_id          = &"fake_cards"
	display_name     = "Präparierte Karten"
	description      = "Ein Set Spielkarten mit hauchdünnen Markierungen und einem gezinkten Ass-Stapel. Glück ist, wenn Vorbereitung auf Gelegenheit trifft."
	category         = "tool"
	item_type        = "deception"
	can_be_smuggled  = true
	detection_weight = 4
	confiscation_chance = 0.3
	requires_target  = false
	can_target_self  = true
	max_uses_per_match = 3
	suspicion_on_use   = 0   # erstmal unsichtbar


func execute_effect(_user_state: PlayerState, target_state: PlayerState, match_ctrl: Node) -> Dictionary:
	# Erzwingt dass der nächste Risiko-Outcome "positiv" ist
	var risk_ctrl = match_ctrl.risk_controller
	if risk_ctrl == null:
		return {"success": false, "reason": "no_risk_controller"}

	risk_ctrl.force_next_positive()

	# Andere Spieler mit "ai_lens" können den Betrug jetzt sehen
	# (MatchController prüft das nach execute_effect)
	return {
		"success":        true,
		"cheat_active":   true,
		"detectable_by":  ["ai_lens"],
		"sound_key":      "cards_shuffle",
	}
