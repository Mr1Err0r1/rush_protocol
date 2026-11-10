extends Node
## Tests für ItemDraft (Logik), den Draft-Ablauf im MatchController und das ItemDraftUI.
## Start: bash tests/run_tests.sh

var _checks := 0
var _fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _cls(allowed: Array[String]) -> CharacterClass:
	var cc := CharacterClass.new()
	cc.class_id = &"t"
	var cats: Array[String] = []
	cats.assign(allowed)
	cc.allowed_item_categories = cats
	return cc


## n Spieler; die letzten `ai` sind KI. Draft-Modus mit festem Seed.
func _new_match(humans: int, ai: int = 0, cfg: Dictionary = {}) -> MatchController:
	var mc := MatchController.new()
	var rc := RiskController.new(); rc.name = "RiskController"
	var ec := EntryPhaseController.new(); ec.name = "EntryPhaseController"
	mc.add_child(rc); mc.add_child(ec)
	add_child(mc)
	mc.match_config = {"item_mode": "draft", "actions_per_turn": 1, "draft_seed": 11, "draft_picks": 2, "draft_offers": 4}
	mc.match_config.merge(cfg, true)
	for i in humans + ai:
		var s := PlayerState.new()
		s.player_id = i + 1
		s.player_name = "P%d" % (i + 1)
		s.is_ai = i >= humans
		s.health = 3
		s.max_health = 3
		s.current_zone = "lobby"
		mc._states[s.player_id] = s
		mc._turn_order.append(s.player_id)
	mc.current_phase = MatchController.Phase.CASINO_FLOOR
	return mc


func _ready() -> void:
	test_offers()
	test_capacity_and_validation()
	test_auto_pick()
	test_match_flow()
	test_full_inventory_and_modes()
	await test_ui()
	_finish()


func test_offers() -> void:
	var r := _rng(1)
	var o := ItemDraft.build_offers(_cls([]), 4, r)
	check(o.size() == 4, "4 Angebote")
	check(o.size() == o.duplicate().filter(func(x): return o.count(x) == 1).size(), "keine Doppelten")
	for id in o:
		check(ItemDatabase.get_item(id) != null, "Angebot existiert in der ItemDatabase: " + str(id))
		check((ItemDatabase.get_item(id) as ItemDefinition).get("roulette_only") != true, "Roulette-Items nicht im normalen Angebot")
	check(ItemDraft.build_offers(_cls([]), 999, _rng(2)).size() == ItemDatabase.get_all_ids().filter(func(i): return (ItemDatabase.get_item(i) as ItemDefinition).get("roulette_only") != true).size(),
		"Angebot größer als der Pool → ganzer Pool")
	check(ItemDraft.build_offers(_cls([]), 0, r).is_empty(), "0 Angebote")
	check(ItemDraft.build_offers(_cls([]), 4, _rng(7)) == ItemDraft.build_offers(_cls([]), 4, _rng(7)), "gleicher Seed → gleiches Angebot")

	# Rollenpassende Kategorien sind häufiger
	var weapon_role := _cls(["weapon"])
	var neutral := _cls([])
	var w := 0
	var n := 0
	var rr := _rng(99)
	for i in 1500:
		for id in ItemDraft.build_offers(weapon_role, 4, rr):
			if (ItemDatabase.get_item(id) as ItemDefinition).category == "weapon":
				w += 1
		for id in ItemDraft.build_offers(neutral, 4, rr):
			if (ItemDatabase.get_item(id) as ItemDefinition).category == "weapon":
				n += 1
	check(w > n * 1.4, "Waffen-Rolle bekommt deutlich mehr Waffen angeboten (%d vs %d)" % [w, n])
	check(n > 0, "auch rollenfremde Kategorien kommen vor")


func test_capacity_and_validation() -> void:
	var s := PlayerState.new()
	check(ItemDraft.inventory_size(s) == 0 and ItemDraft.free_slots(s) == 8, "leeres Inventar: 8 freie Plätze")
	s.add_item(&"revolver", 3)
	s.add_item(&"ai_lens")
	check(ItemDraft.inventory_size(s) == 4 and ItemDraft.free_slots(s) == 4, "Stapel zählen einzeln: 4 belegt")
	check(ItemDraft.picks_for(s, 2) == 2 and ItemDraft.picks_for(s, 9) == 4, "Auswahl durch freie Plätze begrenzt")
	check(ItemDraft.free_slots(s, 3) == 0 and ItemDraft.picks_for(s, 2, 3) == 0, "kleinere Kapazität: voll")
	var offers: Array = [&"coin", &"glue"]
	check(ItemDraft.validate_pick(s, offers, &"coin", 1)["ok"], "gültige Wahl")
	check(ItemDraft.validate_pick(s, offers, &"coin", 0)["reason"] == "no_picks_left", "keine Wahl übrig")
	check(ItemDraft.validate_pick(s, offers, &"revolver", 1)["reason"] == "not_offered", "nicht angeboten")
	s.add_item(&"coin", 4)
	check(ItemDraft.validate_pick(s, offers, &"coin", 1)["reason"] == "inventory_full", "Inventar voll")


func test_auto_pick() -> void:
	var offers: Array = [&"revolver", &"coin", &"ai_lens", &"glue"]
	var picks := ItemDraft.auto_pick(_cls(["weapon"]), offers, 2, _rng(3))
	check(picks.size() == 2 and picks[0] != picks[1], "KI wählt 2 verschiedene")
	check(picks.all(func(p): return offers.has(p)), "KI wählt nur aus dem Angebot")
	check(picks.has(&"revolver"), "KI bevorzugt Waffen der eigenen Rolle")
	check(ItemDraft.auto_pick(null, [], 2, _rng(3)).is_empty(), "leeres Angebot → nichts")
	check(ItemDraft.auto_pick(null, offers, 10, _rng(3)).size() == 4, "nie mehr als angeboten")


func test_match_flow() -> void:
	var mc := _new_match(2, 1)
	var log: Array = []
	var cb_off := func(p, o, k): log.append(["offered", p, o.size(), k])
	var cb_pick := func(p, i): log.append(["picked", p, i])
	var cb_fin := func(r): log.append(["finished", r])
	var cb_round := func(r, a): log.append(["round", r, a])
	EventBus.item_draft_offered.connect(cb_off)
	EventBus.item_draft_picked.connect(cb_pick)
	EventBus.item_draft_finished.connect(cb_fin)
	EventBus.round_started.connect(cb_round)

	mc._start_round()
	check(mc.is_draft_active(), "Draft läuft")
	check(log.filter(func(e): return e[0] == "round").is_empty(), "Runde startet erst nach der Wahl")
	check(log.filter(func(e): return e[0] == "offered").map(func(e): return e[1]) == [1, 2], "Angebote nur für Menschen (P1, P2)")
	check(log[0][2] == 4 and log[0][3] == 2, "4 Angebote, 2 Wahlen")
	check(ItemDraft.inventory_size(mc.get_state(3)) == 2, "KI hat sofort 2 Items gewählt")

	# Aktionen sind gesperrt
	check(mc.request_risk_action(1, 2).get("reason", "") == "draft_active", "Risiko-Aktion gesperrt")
	check(mc.request_use_item(1, &"revolver", 2).get("reason", "") == "draft_active", "Item-Einsatz gesperrt")
	check(not mc.request_move_zone(1, "vip_lounge"), "Bewegung gesperrt")
	var phase_before := mc.current_turn_phase
	mc.advance_turn_phase()
	check(mc.current_turn_phase == phase_before, "advance_turn_phase gesperrt")

	# Ungültige Wahl
	var o1 := mc.get_draft_offers(1).duplicate()
	check(mc.request_draft_pick(1, &"nonexistent")["reason"] == "not_offered", "nicht angebotenes Item abgelehnt")
	check(mc.request_draft_pick(3, o1[0])["reason"] == "no_draft", "KI/Unbeteiligte können nicht wählen")

	# P1 wählt 2 Items
	var res := mc.request_draft_pick(1, o1[0])
	check(res["success"] and res["picks_left"] == 1, "1. Wahl ok, 1 übrig")
	check(mc.get_state(1).has_item(o1[0]) and not mc.get_draft_offers(1).has(o1[0]), "Item im Inventar, aus Angebot entfernt")
	check(mc.request_draft_pick(1, o1[0])["reason"] == "not_offered", "dasselbe Item nicht zweimal")
	res = mc.request_draft_pick(1, o1[1])
	check(res["success"] and res["picks_left"] == 0, "2. Wahl ok")
	check(mc.get_draft_offers(1).is_empty() and ItemDraft.inventory_size(mc.get_state(1)) == 2, "P1 fertig")
	check(mc.request_draft_pick(1, o1[2])["reason"] == "no_draft", "keine 3. Wahl")
	check(mc.is_draft_active(), "Draft wartet noch auf P2")

	# P2 verzichtet auf den Rest
	mc.request_draft_done(2)
	check(not mc.is_draft_active(), "Draft beendet")
	check(ItemDraft.inventory_size(mc.get_state(2)) == 0, "P2 hat nichts gewählt")
	var kinds := log.map(func(e): return e[0])
	check(kinds.back() == "round" and kinds[kinds.size() - 2] == "finished", "Reihenfolge: … finished → round_started: " + str(kinds))
	check(mc.get_active_player_id() == 1 and mc.current_turn_phase == MatchController.TurnPhase.ITEM, "Zug von P1 beginnt in der ITEM-Phase")
	check(mc.request_use_item(1, o1[0], 2).get("reason", "") != "draft_active", "nach dem Draft wieder freigegeben")
	EventBus.item_draft_offered.disconnect(cb_off)
	EventBus.item_draft_picked.disconnect(cb_pick)
	EventBus.item_draft_finished.disconnect(cb_fin)
	EventBus.round_started.disconnect(cb_round)
	mc.free()

	# Nur KI → kein Warten, Runde startet sofort
	var ai_only := _new_match(0, 2)
	ai_only._start_round()
	check(not ai_only.is_draft_active() and ai_only.current_turn_phase == MatchController.TurnPhase.ITEM, "nur KI: Runde startet sofort")
	check(ItemDraft.inventory_size(ai_only.get_state(1)) == 2, "KI-Inventar gefüllt")
	ai_only.free()


func test_full_inventory_and_modes() -> void:
	# Volles Inventar: keine Wahl, Draft endet sofort; Eliminierte werden übersprungen
	var mc := _new_match(2, 0, {"inventory_capacity": 3})
	mc.get_state(1).add_item(&"coin", 3)
	mc.get_state(2).is_eliminated = true
	mc._start_round()
	check(not mc.is_draft_active(), "alle voll/eliminiert → Draft endet sofort")
	check(mc.current_turn_phase == MatchController.TurnPhase.ITEM, "Runde läuft")
	mc.free()

	# Kapazität begrenzt die Anzahl der Wahlen (1 Platz frei, 2 Wahlen vorgesehen)
	mc = _new_match(1, 0, {"inventory_capacity": 3})
	mc.get_state(1).add_item(&"coin", 2)
	mc._start_round()
	check(mc.get_draft_picks_left(1) == 1, "nur 1 freier Platz → 1 Wahl")
	var o := mc.get_draft_offers(1)
	mc.request_draft_pick(1, o[0])
	check(not mc.is_draft_active(), "Platz voll → Draft endet automatisch")
	mc.free()

	# Klassischer Modus unverändert
	mc = _new_match(2, 0, {"item_mode": "random", "items_per_round": 2})
	mc._start_round()
	check(not mc.is_draft_active(), "item_mode random: kein Draft")
	check(ItemDraft.inventory_size(mc.get_state(1)) == 2 and ItemDraft.inventory_size(mc.get_state(2)) == 2, "zufällige Ausgabe wie bisher (2 Items)")
	mc.free()
	check(GameManager._default_match_config()["item_mode"] == "random", "Standardmodus bleibt 'random'")


func test_ui() -> void:
	var mc := _new_match(2)
	var ui := ItemDraftUI.new()
	add_child(ui)
	ui.setup(mc)
	await get_tree().process_frame
	check(not ui._root.visible, "UI zunächst unsichtbar")
	mc._start_round()
	await get_tree().process_frame
	check(ui._root.visible, "UI zeigt das Angebot")
	check(ui._title.text.contains("P1"), "zuerst wählt P1: " + ui._title.text)
	check(ui._list.get_child_count() == 4, "4 Buttons (ist %d)" % ui._list.get_child_count())
	var btn: Button = ui._list.get_child(0)
	var id: StringName = btn.get_meta("item_id")
	btn.pressed.emit()
	await get_tree().process_frame
	check(mc.get_state(1).has_item(id), "Klick legt das Item ins Inventar")
	check(ui._list.get_child_count() == 3, "Angebot schrumpft auf 3 (ist %d)" % ui._list.get_child_count())
	check(ui._info.text.contains("Noch 1 Wahl"), "Info zeigt 1 übrige Wahl: " + ui._info.text)
	var btn2: Button = ui._list.get_child(0)
	btn2.pressed.emit()
	await get_tree().process_frame
	check(ui._title.text.contains("P2"), "danach wählt P2: " + ui._title.text)
	ui._done_btn.pressed.emit()
	await get_tree().process_frame
	check(not ui._root.visible and not mc.is_draft_active(), "Fertig → UI weg, Runde läuft")
	check(mc.current_turn_phase == MatchController.TurnPhase.ITEM, "Zug beginnt")
	ui.free()
	mc.free()


func _finish() -> void:
	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		print("FAIL %d von %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
