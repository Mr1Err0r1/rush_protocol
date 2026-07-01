extends ItemDefinition
## class_name ItemSmokeGrenade
## Mini-Rauchgranate — Null Protocol
## Füllt die aktuelle Zone mit Rauch: Alle Aktionen in dieser Runde
## haben +50% Misserfolgswahrscheinlichkeit, Security kann niemanden
## identifizieren → alle Suspicion-Gewinne werden für 1 Runde geblockt.

func _init() -> void:
	item_id             = &"smoke_grenade"
	display_name        = "Mini-Rauchgranate"
	description         = "Passt in eine Zigarettenschachtel. Zieht binnen Sekunden jede Sichtlinie zu. Wenn niemand dich sehen kann, gibt es keine Zeugen."
	category            = "gadget"
	item_type           = "distraction"
	can_be_smuggled     = true
	detection_weight    = 6
	confiscation_chance = 0.55
	requires_target     = false
	usable_in_zones     = ["lobby", "floor", "bar", "vault_corridor", "backroom"]
	max_uses_per_match  = 1
	suspicion_on_use    = 2   # Der Knall ist trotzdem hörbar


func execute_effect(user_state: PlayerState, _target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:
	var zone := user_state.current_zone
	var affected: Array[int] = []

	# Alle Spieler in der Zone bekommen "smoked" Status für 1 Runde
	for state in match_ctrl.get_all_states():
		if state.current_zone == zone and not state.is_eliminated:
			state.apply_status(&"smoked", 1)
			affected.append(state.player_id)

	return {
		"success":          true,
		"zone_affected":    zone,
		"affected_players": affected,
		"duration_rounds":  1,
		"sound_key":        "fire_whoosh",
	}
