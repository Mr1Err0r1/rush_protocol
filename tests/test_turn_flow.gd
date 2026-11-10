extends Node
## Regression: Zugfluss, wenn sich ein Spieler durch einen Item-Einsatz selbst aus dem Spiel nimmt.
## Start: bash tests/run_tests.sh

var _checks := 0
var _fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _new_match(n: int) -> MatchController:
	var mc := MatchController.new()
	var rc := RiskController.new(); rc.name = "RiskController"
	var ec := EntryPhaseController.new(); ec.name = "EntryPhaseController"
	mc.add_child(rc); mc.add_child(ec)
	add_child(mc)
	mc.match_config = {"actions_per_turn": 1, "items_per_round": 0}
	for i in n:
		var s := PlayerState.new()
		s.player_id = i + 1
		s.player_name = "P%d" % (i + 1)
		s.health = 3
		s.max_health = 3
		s.current_zone = "lobby"
		mc._states[s.player_id] = s
		mc._turn_order.append(s.player_id)
	mc.current_phase = MatchController.Phase.CASINO_FLOOR
	mc._start_round()
	return mc


func _ready() -> void:
	var mc := _new_match(3)
	var elim: Array = []
	var cb := func(p, k, c): elim.append([p, k, c])
	EventBus.player_eliminated.connect(cb)

	# Spieler 1 steht kurz vor dem Rauswurf; der Revolver kostet 3 Misstrauen
	var s1 := mc.get_state(1)
	s1.suspicion = s1.max_suspicion - 1
	s1.add_item(&"revolver")
	check(mc.get_active_player_id() == 1 and mc.current_turn_phase == MatchController.TurnPhase.ITEM, "Spieler 1 ist in der ITEM-Phase dran")
	var r := mc.request_use_item(1, &"revolver", 2)
	check(r.get("success", false), "Revolver benutzbar: " + str(r))
	check(s1.is_eliminated and s1.elimination_cause == "ejected", "Spieler 1 wird wegen Misstrauens rausgeworfen")
	check(mc.get_active_player_id() == 2, "Der Zug bleibt nicht beim Ausgeschiedenen hängen (aktiv: %d)" % mc.get_active_player_id())
	check(mc.current_turn_phase == MatchController.TurnPhase.ITEM, "Spieler 2 beginnt in der ITEM-Phase")
	check(elim.any(func(e): return e[0] == 1 and e[2] == "ejected"), "player_eliminated(1, …, 'ejected') wurde gemeldet: " + str(elim))
	check(elim.filter(func(e): return e[0] == 1).size() == 1, "Ausscheiden nur einmal gemeldet")

	# Ausgeschiedene kommen in den folgenden Runden nicht mehr dran
	for i in 6:
		var a := mc.get_active_player_id()
		check(not mc.get_state(a).is_eliminated, "kein Zug für Ausgeschiedene (Zug %d: Spieler %d)" % [i, a])
		mc.advance_turn_phase()   # ITEM → ACTION
		mc.advance_turn_phase()   # ACTION → RESOLVE → nächster Spieler
	EventBus.player_eliminated.disconnect(cb)
	mc.queue_free()

	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		print("FAIL %d von %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
