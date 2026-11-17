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

	# One found item can reach the suspicion cap; eliminate before moving or starting a boss encounter.
	var ejected_events: Array = []
	var eliminated_events: Array = []
	EventBus.player_ejected.connect(func(pid, reason): ejected_events.append([pid, reason]))
	EventBus.player_eliminated.connect(func(pid, killer_id, cause): eliminated_events.append([pid, killer_id, cause]))
	mc.current_phase = MatchController.Phase.CASINO_FLOOR
	mc.entry_controller.roll_fn = func() -> float: return 0.0
	var s7 := _add_player(mc, 7, &"citizen", [&"revolver"] as Array[StringName], 9)
	check(not mc.request_move_zone(7, "boss_office"), "suspicion-cap ejection blocks movement")
	check(s7.is_eliminated and s7.elimination_cause == "ejected", "suspicion cap eliminates with ejected cause")
	check(s7.current_zone == "lobby" and not s7.visited_zones.has("boss_office"), "ejected player stays in lobby and boss office is not visited")
	check(mc.current_phase == MatchController.Phase.CASINO_FLOOR, "ejected player cannot trigger boss encounter")
	check(ejected_events.size() == 1 and ejected_events[0][0] == 7 and ejected_events[0][1] == "caught_smuggling", "ejection event is emitted")
	check(eliminated_events.size() == 1 and eliminated_events[0][0] == 7 and eliminated_events[0][2] == "ejected", "elimination event is broadcast")
	check(seen.size() == 2 and seen[1][2] == "ejected", "checkpoint result reports ejected")

	# A two-item bounce that also reaches the cap must still emit ejection/elimination.
	mc.current_phase = MatchController.Phase.CASINO_FLOOR
	var s8 := _add_player(mc, 8, &"citizen", [&"revolver", &"ai_lens"] as Array[StringName], 9)
	check(not mc.request_move_zone(8, "backroom"), "two-item suspicion-cap bounce also blocks movement")
	check(s8.is_eliminated and s8.heat == 1, "two-item bounce applies heat and eliminates at suspicion cap")
	check(ejected_events.size() == 2 and eliminated_events.size() == 2, "two-item suspicion-cap bounce emits both events")
	check(seen.size() == 3 and seen[2][2] == "ejected", "two-item cap outcome is ejected")
	var previous_locale := LocaleManager.current_locale
	var expected_ejection_text := {"en": "Security check: you have been ejected from the casino.", "de": "Sicherheitskontrolle: Du bist aus dem Casino ausgeschieden.", "ru": "Проверка безопасности: вы выбыли из казино."}
	for locale in expected_ejection_text:
		LocaleManager.current_locale = locale
		check(LocaleManager.translate("checkpoint.ejected") == expected_ejection_text[locale], "ejection message localized for " + locale)
	LocaleManager.current_locale = previous_locale

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
