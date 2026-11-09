extends Node
## Integration: Roulette-Modus im echten MatchController (Zugregeln, Items, Weste, Spielende).
## Start: bash tests/run_tests.sh

var _checks := 0
var _fails: Array[String] = []
var _mc: MatchController


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


## Neues Match mit n menschlichen Spielern (je 3 Leben), Phase CASINO_FLOOR, Roulette-Tisch auf Level 1.
func _new_match(n: int, hp: int = 3) -> MatchController:
	if _mc != null:
		_mc.free()
	var mc := MatchController.new()
	var rc := RiskController.new(); rc.name = "RiskController"
	var ec := EntryPhaseController.new(); ec.name = "EntryPhaseController"
	mc.add_child(rc); mc.add_child(ec)
	add_child(mc)
	mc.match_config = {"risk_mode": "shells", "actions_per_turn": 1, "items_per_round": 0}
	for i in n:
		var s := PlayerState.new()
		s.player_id = i + 1
		s.player_name = "P%d" % (i + 1)
		s.health = hp
		s.max_health = hp
		s.current_zone = "lobby"
		mc._states[s.player_id] = s
		mc._turn_order.append(s.player_id)
	mc.current_phase = MatchController.Phase.CASINO_FLOOR
	mc.start_roulette(1)
	mc._start_round()
	mc.advance_turn_phase()   # ITEM → ACTION
	_mc = mc
	return mc


func _ready() -> void:
	test_turn_rules()
	test_damage_and_signals()
	test_shield()
	test_items()
	test_match_end()
	test_dealing_and_modes()
	test_full_games()
	if _mc != null:
		_mc.free()
	_finish()


func test_turn_rules() -> void:
	var mc := _new_match(3)
	check(mc.roulette != null and mc.roulette.alive_ids() == [1, 2, 3], "Tisch mit 3 Spielern")
	check(mc.get_active_player_id() == 1 and mc.current_turn_phase == MatchController.TurnPhase.ACTION, "Spieler 1 in der Aktionsphase")

	# Platzpatrone auf sich selbst → Extra-Aktion, Zug bleibt
	mc.roulette.chamber.load_shells(0, 4)
	var r := mc.request_risk_action(1, 1)
	check(r["success"] and not r["live"] and r["keeps_turn"], "Platz auf sich selbst: Extra-Aktion")
	check(mc.get_active_player_id() == 1 and mc.current_turn_phase == MatchController.TurnPhase.ACTION, "Spieler 1 bleibt in ACTION")
	check(mc.get_state(1).health == 3, "kein Schaden")

	# Platzpatrone auf Gegner → Zug endet
	r = mc.request_risk_action(1, 2)
	check(r["success"] and not r["keeps_turn"], "Platz auf Gegner beendet den Zug")
	check(mc.get_active_player_id() == 2 and mc.current_turn_phase == MatchController.TurnPhase.ITEM, "Spieler 2 ist dran (ITEM)")

	# Falscher Spieler / falsche Phase
	check(mc.request_risk_action(3, 1).get("reason", "") == "not_your_turn", "falscher Spieler abgelehnt")
	check(mc.request_risk_action(2, 3).get("reason", "") == "wrong_phase", "ITEM-Phase: Schuss abgelehnt")


func test_damage_and_signals() -> void:
	var mc := _new_match(2)
	var log: Array = []
	var cb_shot := func(a, t, l, d): log.append(["shot", a, t, l, d])
	var cb_hp := func(p, o, n): log.append(["hp", p, o, n])
	var cb_rel := func(l, b, t): log.append(["reload", l, b, t])
	EventBus.roulette_shot.connect(cb_shot)
	EventBus.player_health_changed.connect(cb_hp)
	EventBus.roulette_reloaded.connect(cb_rel)

	mc.roulette.chamber.load_shells(5, 0)
	var r := mc.request_risk_action(1, 2)
	check(r["live"] and r["damage"] == 1 and r["delta"] == -1, "scharf: 1 Schaden")
	check(mc.get_state(2).health == 2, "Spieler 2 hat 2 Leben")
	check(log.has(["shot", 1, 2, true, 1]) and log.has(["hp", 2, 3, 2]), "Signale roulette_shot + player_health_changed: " + str(log))
	check(mc.get_state(1).stat_targets_hit == 1, "Treffer-Statistik")

	# Scharf auf sich selbst
	r = mc.request_risk_action(1, 1) if false else {}
	mc.advance_turn_phase()   # Spieler 2: ITEM → ACTION
	r = mc.request_risk_action(2, 2)
	check(r["live"] and mc.get_state(2).health == 1, "scharf auf sich selbst: -1")

	# Nachladen meldet roulette_reloaded
	log.clear()
	mc.roulette.chamber.load_shells(0, 1)
	mc.advance_turn_phase()
	var actor := mc.get_active_player_id()
	mc.request_risk_action(actor, actor)   # letzte Platzpatrone auf sich selbst
	check(log.any(func(e): return e[0] == "reload"), "leeres Magazin → roulette_reloaded")
	EventBus.roulette_shot.disconnect(cb_shot)
	EventBus.player_health_changed.disconnect(cb_hp)
	EventBus.roulette_reloaded.disconnect(cb_rel)


func test_shield() -> void:
	var mc := _new_match(2)
	mc.get_state(2).apply_status(&"protected", 5)
	var destroyed: Array = []
	var cb := func(p, i): destroyed.append([p, i])
	EventBus.item_destroyed.connect(cb)
	mc.roulette.chamber.load_shells(5, 0)
	var r := mc.request_risk_action(1, 2)
	check(r["live"] and r["absorbed"] and r["damage"] == 0, "Weste fängt den Treffer ab")
	check(mc.get_state(2).health == 3 and not mc.get_state(2).has_status(&"protected"), "keine Verletzung, Weste verbraucht")
	check(destroyed == [[2, &"bulletproof_band"]], "item_destroyed gemeldet")
	EventBus.item_destroyed.disconnect(cb)


func _give(mc: MatchController, pid: int, item: StringName) -> void:
	mc.get_state(pid).add_item(item)


func test_items() -> void:
	# Lupe (ITEM-Phase)
	var mc := _new_match(2)
	_give(mc, 1, &"magnifier")
	mc._actions_this_turn = 0
	mc.current_turn_phase = MatchController.TurnPhase.ITEM
	mc.roulette.chamber.load_shells(2, 2)
	var top := mc.roulette.chamber.peek()
	var before := mc.roulette.chamber.remaining()
	var r := mc.request_use_item(1, &"magnifier", 1)
	check(r.get("success", false), "Lupe benutzbar: " + str(r))
	check(r["revealed"]["shell"] == ("live" if top == ShellChamber.Shell.LIVE else "blank"), "Lupe zeigt die richtige Patrone")
	check(mc.roulette.chamber.remaining() == before, "Lupe verbraucht keine Patrone")
	check(not mc.get_state(1).has_item(&"magnifier"), "Lupe verbraucht")

	# Säge: doppelter Schaden
	mc = _new_match(2)
	_give(mc, 1, &"saw")
	mc.current_turn_phase = MatchController.TurnPhase.ITEM
	check(mc.request_use_item(1, &"saw", 1).get("success", false), "Säge benutzbar")
	mc.advance_turn_phase()
	mc.roulette.chamber.load_shells(5, 0)
	r = mc.request_risk_action(1, 2)
	check(r["damage"] == 2 and mc.get_state(2).health == 1, "Säge: 2 Schaden")

	# Handschellen: Gegner setzt aus
	mc = _new_match(3)
	_give(mc, 1, &"handcuffs")
	mc.current_turn_phase = MatchController.TurnPhase.ITEM
	check(not mc.request_use_item(1, &"handcuffs", 1).get("success", false), "Handschellen nicht auf sich selbst")
	check(mc.request_use_item(1, &"handcuffs", 2).get("success", false), "Handschellen auf Spieler 2")
	mc.advance_turn_phase()
	mc.roulette.chamber.load_shells(0, 4)
	mc.request_risk_action(1, 3)     # Platz auf 3 → Zug endet; Spieler 2 gefesselt → übersprungen
	check(mc.get_active_player_id() == 3, "Spieler 2 setzt aus, Spieler 3 ist dran (ist %d)" % mc.get_active_player_id())

	# Verbandskasten
	mc = _new_match(2)
	_give(mc, 1, &"medkit")
	mc.current_turn_phase = MatchController.TurnPhase.ITEM
	check(not mc.request_use_item(1, &"medkit", 1).get("success", false), "Verbandskasten bei vollen Leben: abgelehnt")
	mc.get_state(1).modify_resource("health", -2)
	check(mc.request_use_item(1, &"medkit", 1).get("success", false) and mc.get_state(1).health == 2, "Verbandskasten heilt +1")

	# Ohne Roulette-Tisch (Pool-Modus) sind Roulette-Items wirkungslos
	mc = _new_match(2)
	mc.roulette = null
	_give(mc, 1, &"saw")
	mc.current_turn_phase = MatchController.TurnPhase.ITEM
	check(mc.request_use_item(1, &"saw", 1).get("reason", "") == "no_roulette_table", "Säge ohne Tisch: no_roulette_table")


func test_match_end() -> void:
	var mc := _new_match(2, 1)
	var over: Array = []
	var elim: Array = []
	var cb_over := func(w, c, _s): over.append([w, c])
	var cb_elim := func(p, k, c): elim.append([p, k, c])
	EventBus.match_over.connect(cb_over)
	EventBus.player_eliminated.connect(cb_elim)
	mc.roulette.chamber.load_shells(3, 0)
	mc.request_risk_action(1, 2)
	check(mc.get_state(2).is_eliminated, "Spieler 2 eliminiert")
	check(elim == [[2, 1, "killed"]], "player_eliminated: " + str(elim))
	check(over == [[1, "last_standing"]] and mc.current_phase == MatchController.Phase.GAME_OVER, "Match endet mit Sieger 1: " + str(over))
	check(mc.request_risk_action(1, 1).get("success", true) == false, "nach Matchende kein Schuss mehr")
	EventBus.match_over.disconnect(cb_over)
	EventBus.player_eliminated.disconnect(cb_elim)


func test_dealing_and_modes() -> void:
	var mc := _new_match(2)
	mc.roulette = null
	check(not mc._is_dealable(&"magnifier") and not mc._is_dealable(&"saw"), "Pool-Modus: Roulette-Items werden nicht ausgeteilt")
	check(mc._is_dealable(&"revolver"), "normale Items werden weiter ausgeteilt")
	mc.match_config["items_per_round"] = 40
	mc._distribute_round_items()
	var leaked := false
	for pid in [1, 2]:
		for id in mc.get_state(pid).inventory.keys():
			if (ItemDatabase.get_item(id) as ItemDefinition).roulette_only:
				leaked = true
	check(not leaked, "Pool-Modus: keine Roulette-Items im Inventar (80 Zufallsitems)")
	mc.start_roulette(1)
	check(mc._is_dealable(&"magnifier"), "Roulette-Modus: Roulette-Items sind im Umlauf")

	check(GameManager._default_match_config()["risk_mode"] == "pool", "Standardmodus bleibt 'pool'")

	# Etagenstufe aus den Zonen der Spieler
	mc.get_state(1).current_zone = "backroom"
	check(mc._roulette_level() == 3, "Level folgt der höchsten Etage (backroom = 3)")
	mc.get_state(2).current_zone = "boss_office"
	check(mc._roulette_level() == 5, "Penthouse = Level 5")
	for it in ["magnifier", "saw", "handcuffs", "medkit"]:
		var d := ItemDatabase.get_item(StringName(it)) as ItemDefinition
		check(d != null and d.roulette_only and not d.can_be_smuggled, "%s: roulette_only und nicht schmuggelbar" % it)


func test_full_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	var finished := 0
	var longest := 0
	for g in 60:
		var n := rng.randi_range(2, 4)
		var mc := _new_match(n, rng.randi_range(2, 5))
		mc.match_config["items_per_round"] = 2
		var steps := 0
		while mc.current_phase != MatchController.Phase.GAME_OVER and steps < 800:
			steps += 1
			var actor := mc.get_active_player_id()
			var st := mc.get_state(actor)
			if st == null or st.is_eliminated:
				break
			if mc.current_turn_phase == MatchController.TurnPhase.ITEM:
				# manchmal ein zufälliges Item einsetzen
				if rng.randf() < 0.5 and not st.inventory.is_empty():
					var ids := st.inventory.keys()
					var iid: StringName = ids[rng.randi() % ids.size()]
					var others := mc.roulette.alive_ids().filter(func(p): return p != actor)
					mc.request_use_item(actor, iid, others[rng.randi() % others.size()] if not others.is_empty() else actor)
				mc.advance_turn_phase()
			if mc.current_phase == MatchController.Phase.GAME_OVER:
				break
			var alive := mc.roulette.alive_ids()
			var res := mc.request_risk_action(actor, alive[rng.randi() % alive.size()])
			if res.get("success", false) and res.get("keeps_turn", false) and rng.randf() < 0.3:
				mc.advance_turn_phase()   # Extra-Aktion verzichten → Zug beenden
		if mc.current_phase == MatchController.Phase.GAME_OVER:
			var alive_n := 0
			for s in mc._states.values():
				if not s.is_eliminated:
					alive_n += 1
			if alive_n == 1:
				finished += 1
		longest = maxi(longest, steps)
	check(finished == 60, "Vollständige Spiele: %d/60 enden mit genau einem Sieger (längstes: %d Schritte)" % [finished, longest])
	print("Voll-Spiele: %d/60 ok, längstes %d Schritte" % [finished, longest])


func _finish() -> void:
	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		print("FAIL %d von %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
