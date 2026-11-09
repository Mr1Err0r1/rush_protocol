extends Node
## Tests für CheckpointRules und EntryPhaseController (Einlass + Etagenkontrollen).
## Start: bash tests/run_tests.sh  (oder: godot --headless --path . res://tests/host.tscn -- tests/test_checkpoints.gd)

var _checks := 0
var _fails: Array[String] = []


class FakeCtrl extends Node:
	var states: Dictionary = {}
	var classes: Dictionary = {}
	func get_state(pid: int):
		return states.get(pid)
	func get_character_class(cid: StringName):
		return classes.get(cid)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func approx(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func make_class(id: StringName, faction: StringName, guaranteed: Array[StringName] = []) -> CharacterClass:
	var cc := CharacterClass.new()
	cc.class_id = id
	cc.faction_id = faction
	cc.guaranteed_items = guaranteed
	return cc


func make_state(pid: int, cc: CharacterClass, items: Array[StringName]) -> PlayerState:
	var s := PlayerState.new()
	s.player_id = pid
	s.char_class_id = cc.class_id
	for it in items:
		s.add_item(it)
		s.smuggled_items.append(it)
	return s


func _ready() -> void:
	test_formulas()
	test_describe()
	test_controller()
	test_statistics()
	_finish()


func test_formulas() -> void:
	var civ := make_class(&"civ", &"civilian")
	var gov := make_class(&"gov", &"government")
	var asn := make_class(&"asn", &"assassins")

	# Zonen
	check(CheckpointRules.is_checkpoint("backroom"), "backroom ist Kontrollpunkt")
	check(not CheckpointRules.is_checkpoint("lobby"), "lobby ist kein Kontrollpunkt")
	check(CheckpointRules.trigger_chance("lobby", 0, 0, civ) == 0.0, "keine Kontrolle in der Lobby")

	# Penthouse immer – auch für Geheimdienst (mandatory)
	check(CheckpointRules.trigger_chance("boss_office", 0, 0, gov) == 1.0, "Penthouse: Geheimdienst wird kontrolliert")
	check(CheckpointRules.trigger_chance("boss_office", 0, 0, civ) == 1.0, "Penthouse: Zivilist wird kontrolliert")

	# Rollenunterschied: Geheimdienst wird öfter durchgewinkt
	var c_civ := CheckpointRules.trigger_chance("backroom", 0, 0, civ)
	var c_gov := CheckpointRules.trigger_chance("backroom", 0, 0, gov)
	check(approx(c_civ, 0.30 * 0.95), "Zivilist backroom = 28,5 %% (ist %f)" % c_civ)
	check(approx(c_gov, 0.30 * 0.70), "Geheimdienst backroom = 21 %% (ist %f)" % c_gov)
	check(c_gov < c_civ, "Geheimdienst wird seltener kontrolliert als Zivilist")

	# Misstrauen/Heat erhöhen, Clamp
	check(CheckpointRules.trigger_chance("backroom", 5, 0, civ) > c_civ, "Misstrauen erhöht die Kontrollchance")
	check(CheckpointRules.trigger_chance("backroom", 0, 5, civ) > c_civ, "Heat erhöht die Kontrollchance")
	check(CheckpointRules.trigger_chance("backroom", 99, 99, civ) == 1.0, "Chance wird auf 1.0 begrenzt")

	# Rollen-Override überschreibt Fraktionsstandard
	var lucky := make_class(&"lucky", &"civilian")
	lucky.checkpoint_skip_chance = 0.9
	check(CheckpointRules.trigger_chance("backroom", 0, 0, lucky) < c_gov, "Override: skip 0.9 senkt die Chance")
	check(approx(CheckpointRules.profile_for(lucky)["skip"], 0.9), "profile_for nutzt checkpoint_skip_chance")

	# Fundchance: Assassine versteckt Waffen (wie vorher: ×0.4), nur Waffen
	var rev: ItemDefinition = load("res://resources/items/revolver.tres")
	var lens: ItemDefinition = load("res://resources/items/ai_lens.tres")
	check(rev != null and lens != null, "Items laden")
	var base_w := CheckpointRules.item_find_chance(rev, 0, civ, 1.0)
	var asn_w := CheckpointRules.item_find_chance(rev, 0, asn, 1.0)
	check(approx(base_w, clampf(rev.confiscation_chance, 0.0, 1.0)), "Zivilist: Fundchance = confiscation_chance")
	check(approx(asn_w, base_w * 0.4), "Assassine: Waffen ×0,4 wie bisher (%f vs %f)" % [asn_w, base_w * 0.4])
	check(approx(CheckpointRules.item_find_chance(lens, 0, asn, 1.0), CheckpointRules.item_find_chance(lens, 0, civ, 1.0)),
		"Assassine: Nicht-Waffen unverändert")
	# Misstrauen +3 %/Punkt, Strenge skaliert, detection_resistance wirkt, Clamp
	check(approx(CheckpointRules.item_find_chance(lens, 4, civ, 1.0) - CheckpointRules.item_find_chance(lens, 0, civ, 1.0), 0.12),
		"Misstrauen: +3 %% pro Punkt")
	check(CheckpointRules.item_find_chance(rev, 0, civ, 1.5) > CheckpointRules.item_find_chance(rev, 0, civ, 0.6),
		"strengere Kontrolle findet mehr")
	var sneaky := make_class(&"sneaky", &"civilian")
	sneaky.detection_resistance = 0.5
	check(CheckpointRules.item_find_chance(rev, 0, sneaky, 1.0) < base_w, "detection_resistance senkt die Fundchance")
	check(CheckpointRules.item_find_chance(rev, 0, sneaky, 1.0) >= 0.0, "Fundchance nie negativ")
	check(CheckpointRules.item_find_chance(rev, 99, civ, 1.5) == 1.0, "Fundchance max. 1.0")
	check(CheckpointRules.item_find_chance(null, 0, civ) == 0.0, "null-Item: 0")


func test_describe() -> void:
	var text := CheckpointRules.describe(make_class(&"civ", &"civilian"))
	check(text.contains("Penthouse 100%"), "describe nennt Penthouse 100 %%: " + text)
	check(text.contains("Hinterzimmer"), "describe nennt Hinterzimmer")
	check(CheckpointRules.describe(null) == "", "describe(null) leer")


func test_controller() -> void:
	var ctrl := FakeCtrl.new()
	var ec := EntryPhaseController.new()
	var civ := make_class(&"civ", &"civilian")
	var mil := make_class(&"mil", &"military", [&"revolver"] as Array[StringName])
	ctrl.classes[&"civ"] = civ
	ctrl.classes[&"mil"] = mil

	# Würfel = 0.0: immer kontrolliert, alles mit Fundchance > 0 wird gefunden
	ec.roll_fn = func() -> float: return 0.0
	var s1 := make_state(1, civ, [&"revolver", &"ai_lens"] as Array[StringName])
	s1.suspicion = 5   # sichert Fundchance > 0 für beide Items
	ctrl.states[1] = s1
	var r1 := ec.run_checkpoint(1, "backroom", ctrl)
	check(r1["triggered"], "roll 0.0 → kontrolliert")
	check(r1["outcome"] == "bounced", "2 Funde ohne Bestechung → bounced (ist %s)" % r1["outcome"])
	check(r1["confiscated"].size() == 2, "beide Items beschlagnahmt")
	check(not s1.has_item(&"revolver") and not s1.has_item(&"ai_lens"), "Items aus dem Inventar entfernt")
	check(s1.smuggled_items.is_empty(), "smuggled_items geleert")
	check(s1.heat == 1, "Heat +1 bei bounced")
	check(s1.suspicion > 5, "Misstrauen durch Funde gestiegen")

	# Bestechung (hoher Einfluss) → kein bounce, nur beschlagnahmt
	var s2 := make_state(2, civ, [&"revolver", &"ai_lens"] as Array[StringName])
	s2.suspicion = 5
	s2.influence = 4
	ctrl.states[2] = s2
	check(ec.run_checkpoint(2, "backroom", ctrl)["outcome"] == "confiscated", "Einfluss 4 → bestochen, nur beschlagnahmt")

	# Garantierte Rollen-Items werden nie konfisziert
	var s3 := make_state(3, mil, [&"revolver"] as Array[StringName])
	s3.suspicion = 5
	ctrl.states[3] = s3
	var r3 := ec.run_checkpoint(3, "backroom", ctrl)
	check(s3.has_item(&"revolver") and r3["confiscated"].is_empty(), "Dienstwaffe bleibt")
	check(r3["outcome"] == "searched", "nichts gefunden → searched")

	# Würfel = 0.999: normale Etage wird nicht kontrolliert, Penthouse schon (aber nichts gefunden)
	ec.roll_fn = func() -> float: return 0.999
	var s4 := make_state(4, civ, [&"ai_lens"] as Array[StringName])   # unauffällig (Fundchance ~2 %)
	ctrl.states[4] = s4
	check(ec.run_checkpoint(4, "backroom", ctrl)["outcome"] == "clear", "roll 0.999 → keine Kontrolle")
	var r4 := ec.run_checkpoint(4, "boss_office", ctrl)
	check(r4["triggered"] and r4["outcome"] == "searched", "Penthouse: immer kontrolliert, Item unentdeckt")
	check(s4.has_item(&"ai_lens"), "unentdecktes Item bleibt")

	# Nicht-Kontrollpunkt / Unbekannter Spieler
	check(ec.run_checkpoint(4, "lobby", ctrl)["outcome"] == "none", "lobby: keine Kontrolle")
	check(ec.run_checkpoint(99, "backroom", ctrl)["outcome"] == "none", "unbekannter Spieler: none")

	# Einlasskontrolle am Eingang nutzt dieselbe Formel
	var s5 := make_state(5, civ, [&"revolver", &"ai_lens"] as Array[StringName])
	s5.suspicion = 5
	ctrl.states[5] = s5
	ec.roll_fn = func() -> float: return 0.0
	ec.start_entry_checks([5] as Array[int])
	var e5 := ec.run_check(5, ctrl)
	check(e5["ejected"] and not e5["passed"], "Einlass: 2 Funde ohne Bestechung → Rauswurf")
	var s6 := make_state(6, civ, [&"revolver"] as Array[StringName])
	ctrl.states[6] = s6
	ec.roll_fn = func() -> float: return 0.999
	ec.start_entry_checks([6] as Array[int])
	var e6 := ec.run_check(6, ctrl)
	check(e6["passed"] and s6.current_zone == "lobby", "Einlass: nichts gefunden → Lobby")

	ctrl.free()
	ec.free()


func test_statistics() -> void:
	# Stichprobe: beobachtete Kontrollrate ≈ berechnete Chance (fester Seed)
	var ctrl := FakeCtrl.new()
	var ec := EntryPhaseController.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	ec.roll_fn = func() -> float: return rng.randf()
	for faction in [&"civilian", &"government", &"elite"]:
		var cc := make_class(StringName("c_" + str(faction)), faction)
		ctrl.classes[cc.class_id] = cc
		var s := make_state(1, cc, [] as Array[StringName])
		ctrl.states[1] = s
		var hits := 0
		var n := 6000
		for i in n:
			if ec.run_checkpoint(1, "backroom", ctrl)["triggered"]:
				hits += 1
		var expected := CheckpointRules.trigger_chance("backroom", 0, 0, cc)
		var observed := float(hits) / n
		check(absf(observed - expected) < 0.02, "%s: beobachtet %.3f vs erwartet %.3f" % [faction, observed, expected])
	ctrl.free()
	ec.free()


func _finish() -> void:
	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		print("FAIL %d von %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
