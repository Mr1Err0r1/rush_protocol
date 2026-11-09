extends Node
## Integration: MatchController.request_move_zone() mit Etagenkontrollen.
## Start: bash tests/run_tests.sh

var _checks := 0
var _fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _make_match() -> MatchController:
	var mc := MatchController.new()
	var rc := RiskController.new(); rc.name = "RiskController"
	var ec := EntryPhaseController.new(); ec.name = "EntryPhaseController"
	mc.add_child(rc)
	mc.add_child(ec)
	add_child(mc)   # _ready: lädt Rollen aus resources/characters/
	return mc


func _add_player(mc: MatchController, pid: int, class_id: StringName, items: Array[StringName], suspicion: int) -> PlayerState:
	var s := PlayerState.new()
	s.player_id = pid
	s.char_class_id = class_id
	s.suspicion = suspicion
	s.current_zone = "lobby"
	for it in items:
		s.add_item(it)
		s.smuggled_items.append(it)
	mc._states[pid] = s
	return s


func _ready() -> void:
	var mc := _make_match()
	check(mc.get_character_class(&"citizen") != null, "Rollen wurden geladen")

	# Immer kontrollieren und alles finden → bounced, Spieler bleibt unten
	mc.entry_controller.roll_fn = func() -> float: return 0.0
	var s := _add_player(mc, 1, &"citizen", [&"revolver", &"ai_lens"] as Array[StringName], 5)
	var moved := mc.request_move_zone(1, "backroom")
	check(not moved, "bounced → request_move_zone liefert false")
	check(s.current_zone == "lobby", "Zone bleibt lobby")
	check(not s.visited_zones.has("backroom"), "backroom nicht als besucht markiert")
	check(s.smuggled_items.is_empty(), "Schmuggelware beschlagnahmt")

	# Ohne Schmuggelware: Kontrolle findet nichts → Zugang erlaubt, danach nicht erneut kontrolliert
	var s2 := _add_player(mc, 2, &"citizen", [] as Array[StringName], 0)
	check(mc.request_move_zone(2, "backroom"), "sauberer Spieler kommt durch")
	check(s2.current_zone == "backroom" and s2.visited_zones.has("backroom"), "Zone gewechselt und besucht")
	var calls := [0]
	mc.entry_controller.roll_fn = func() -> float:
		calls[0] += 1
		return 0.0
	s2.add_item(&"revolver"); s2.smuggled_items.append(&"revolver"); s2.suspicion = 5
	check(mc.request_move_zone(2, "backroom"), "erneutes Betreten derselben Zone ohne Kontrolle")
	check(calls[0] == 0, "keine Kontrolle beim zweiten Betreten (Würfe: %d)" % calls[0])

	# Schalter match_config.checkpoints = false
	mc.match_config["checkpoints"] = false
	var s3 := _add_player(mc, 3, &"citizen", [&"revolver", &"ai_lens"] as Array[StringName], 5)
	check(mc.request_move_zone(3, "vault_corridor"), "checkpoints=false: keine Kontrolle")
	check(s3.has_item(&"revolver"), "checkpoints=false: Items bleiben")
	mc.match_config["checkpoints"] = true

	# Nicht-Kontrollzone / stuck / Tresor ohne Schlüssel bleiben unverändert
	var s4 := _add_player(mc, 4, &"citizen", [] as Array[StringName], 0)
	check(mc.request_move_zone(4, "lobby"), "Lobby ohne Kontrolle")
	s4.apply_status(&"stuck", 2)
	check(not mc.request_move_zone(4, "vip_lounge"), "stuck blockiert weiterhin")
	var s5 := _add_player(mc, 5, &"citizen", [] as Array[StringName], 0)
	check(not mc.request_move_zone(5, "vault"), "Tresor ohne Schlüssel blockiert weiterhin")

	# Signale
	var seen: Array = []
	EventBus.checkpoint_result.connect(func(pid, zone, outcome, _c): seen.append([pid, zone, outcome]))
	mc.entry_controller.roll_fn = func() -> float: return 0.999
	var s6 := _add_player(mc, 6, &"citizen", [] as Array[StringName], 0)
	mc.request_move_zone(6, "boss_office")
	check(seen.size() == 1 and seen[0][2] == "searched", "checkpoint_result 'searched' im Penthouse: %s" % str(seen))

	mc.queue_free()
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		print("FAIL %d von %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
