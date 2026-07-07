extends ItemDefinition
## class_name ItemCoin
## Falschmünze / Fake-Chip — Null Protocol
## Vielseitigstes Item. Kann:
## - Als Ablenkung geworfen werden (Geräusch lockt Security weg)
## - Als gefälschter Casino-Chip gespielt werden (+Chips, Suspicion-Risiko)
## - Einen Dealer oder Security-Mitarbeiter bestechen (Suspicion senken)
## - Einem anderen Spieler gegeben werden (Chips-Transfer + Einfluss)

func _init() -> void:
	item_id          = &"coin"
	display_name     = "Falschmünze / Fake-Chip"
	description      = "Perfekt gefälschter Casino-Chip. Für Spielen, Bestechen oder einfach als Ablenkung quer durch den Raum werfen. Einige Probleme löst man mit Geld."
	category         = "chip"
	item_type        = "multi_use"
	can_be_smuggled  = true
	detection_weight = 3
	confiscation_chance = 0.15
	requires_target  = true   # Ziel bestimmt Verwendung
	can_target_self  = true
	can_target_enemies = true
	max_uses_per_match = -1   # solange im Inventar vorhanden
	suspicion_on_use   = 0


## Verwendungsmodus — wird durch use_mode im Aufruf übergeben
## Modi: "distract", "play", "bribe", "transfer"
func execute_effect(user_state: PlayerState, target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:

	var mode: String = "play"

	if target_state.player_id != user_state.player_id:
		mode = "transfer"

	match mode:
		"distract":
			return _mode_distract(user_state, match_ctrl)

		"play":
			return _mode_play(user_state, match_ctrl)

		"bribe":
			return _mode_bribe(user_state)

		"transfer":
			return _mode_transfer(user_state, target_state)

	return {
		"success": false,
		"reason": "unknown_mode"
	}


func _mode_distract(user_state: PlayerState, _match_ctrl: Node) -> Dictionary:
	# Wirft Münze — Security in Zone wird 1 Runde abgelenkt
	user_state.modify_resource("suspicion", -1)
	return {"success": true, "mode": "distract", "suspicion_delta": -1, "sound_key": "coin_throw"}


func _mode_play(user_state: PlayerState, _match_ctrl: Node) -> Dictionary:
	# Riskantes Spielen: 50/50 Chance auf Chip-Gewinn oder Suspicion
	if randf() > 0.5:
		var won := randi_range(20, 80)
		user_state.modify_resource("chips", won)
		return {"success": true, "mode": "play", "chips_won": won, "sound_key": "chips_win"}
	else:
		user_state.modify_resource("suspicion", 1)
		return {"success": true, "mode": "play", "chips_won": 0, "suspicion_delta": 1, "sound_key": "chips_lose"}


func _mode_bribe(user_state: PlayerState) -> Dictionary:
	# Reduziert Suspicion des Benutzers massiv
	if user_state.chips < 30:
		return {"success": false, "reason": "not_enough_chips"}
	user_state.modify_resource("chips", -30)
	user_state.modify_resource("suspicion", -3)
	return {"success": true, "mode": "bribe", "chips_spent": 30, "suspicion_delta": -3, "sound_key": "bribe_handshake"}


func _mode_transfer(user_state: PlayerState, target_state: PlayerState) -> Dictionary:
	# Chip-Transfer: gibt Einfluss beim Empfänger, kleine Allianz-Geste
	var amount := 25
	if user_state.chips < amount:
		return {"success": false, "reason": "not_enough_chips"}
	user_state.modify_resource("chips", -amount)
	target_state.modify_resource("chips", amount)
	user_state.modify_resource("influence", 1)
	return {"success": true, "mode": "transfer", "amount": amount, "sound_key": "chips_transfer"}
