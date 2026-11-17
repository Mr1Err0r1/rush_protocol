extends Node
## Tests für ShellChamber und RouletteTable (Buckshot-inspirierter Kern).
## Start: bash tests/run_tests.sh

var _checks := 0
var _fails: Array[String] = []

const LIVE := ShellChamber.Shell.LIVE
const BLANK := ShellChamber.Shell.BLANK


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Tisch mit festem Magazin (alles scharf oder alles Platz) für deterministische Regeltests.
func _table(hp: Dictionary, live: int, blank: int, lvl: int = 1, seed_value: int = 1) -> RouletteTable:
	var t := RouletteTable.new(_rng(seed_value))
	t.setup(hp, lvl)
	t.chamber.load_shells(live, blank)
	return t


func _ready() -> void:
	test_chamber()
	test_load_for_level()
	test_empty_setup()
	test_shooting_rules()
	test_turn_order_and_elimination()
	test_items()
	test_signals()
	test_fuzz()
	test_level_difficulty()
	_finish()


func test_chamber() -> void:
	var c := ShellChamber.new(_rng(7))
	check(c.is_empty() and c.peek() == ShellChamber.NONE and c.draw() == ShellChamber.NONE, "leeres Magazin: peek/draw = NONE")
	c.load_shells(3, 2)
	check(c.remaining() == 5 and c.live_count() == 3 and c.blank_count() == 2, "3 scharf + 2 Platz")
	check(c.announce() == {"live": 3, "blank": 2, "total": 5}, "announce zeigt nur Anzahlen")
	var p := c.peek()
	check(c.remaining() == 5, "peek verbraucht nichts")
	check(c.draw() == p, "draw liefert, was peek gezeigt hat")
	check(c.remaining() == 4, "draw verbraucht eine Patrone")
	var e := c.eject()
	check(e != ShellChamber.NONE and c.remaining() == 3, "eject verbraucht ebenfalls")
	while not c.is_empty():
		c.draw()
	check(c.draw() == ShellChamber.NONE, "leer → NONE")
	c.load_shells(-2, 0)
	check(c.is_empty(), "negative Anzahlen werden ignoriert")

	# Gleicher Seed → gleiche Reihenfolge
	var a := ShellChamber.new(_rng(99)); a.load_shells(4, 4)
	var b := ShellChamber.new(_rng(99)); b.load_shells(4, 4)
	var same := true
	for i in 8:
		if a.draw() != b.draw():
			same = false
	check(same, "gleicher Seed → gleiche Reihenfolge")

	# Fairness: Wahrscheinlichkeit, dass die erste Patrone scharf ist = live/total
	var r := _rng(2024)
	var hits := 0
	var n := 6000
	for i in n:
		var ch := ShellChamber.new(r)
		ch.load_shells(3, 2)
		if ch.draw() == LIVE:
			hits += 1
	check(absf(float(hits) / n - 0.6) < 0.025, "erste Patrone scharf ≈ 60 %% (ist %.3f)" % (float(hits) / n))


func test_load_for_level() -> void:
	var r := _rng(5)
	for lvl in range(RouletteTable.MIN_LEVEL, RouletteTable.MAX_LEVEL + 1):
		var live_sum := 0.0
		var ok := true
		for i in 500:
			var cfg := RouletteTable.load_for_level(lvl, r)
			if cfg["total"] != RouletteTable.SHELLS_BY_LEVEL[lvl - 1] or cfg["live"] < 1 or cfg["blank"] < 1 or cfg["live"] + cfg["blank"] != cfg["total"]:
				ok = false
			live_sum += float(cfg["live"]) / cfg["total"]
		check(ok, "Level %d: Gesamtzahl stimmt, immer >= 1 scharf und >= 1 Platz" % lvl)
		var avg := live_sum / 500.0
		check(absf(avg - RouletteTable.LIVE_RATIO_BY_LEVEL[lvl - 1]) < 0.06, "Level %d: scharfer Anteil ≈ %.2f (ist %.3f)" % [lvl, RouletteTable.LIVE_RATIO_BY_LEVEL[lvl - 1], avg])
	check(RouletteTable.load_for_level(0, r)["total"] == 4, "Level 0 wird auf 1 begrenzt")
	check(RouletteTable.load_for_level(99, r)["total"] == 8, "Level 99 wird auf 5 begrenzt")


func test_empty_setup() -> void:
	var t := RouletteTable.new(_rng(17))
	t.setup({})
	check(t.is_over() and t.current_player() == -1 and t.winner_id == -1,
		"leerer Tisch ist beendet und hat keinen Sieger")


func test_shooting_rules() -> void:
	# Platzpatrone auf sich selbst → Extrazug
	var t := _table({1: 3, 2: 3}, 0, 3)
	check(t.current_player() == 1, "Spieler 1 beginnt")
	var r := t.shoot(1, 1)
	check(r["ok"] and not r["live"] and r["damage"] == 0 and r["keeps_turn"], "Platz auf sich selbst: kein Schaden, Extrazug")
	check(t.current_player() == 1, "Spieler 1 bleibt am Zug")
	# Platzpatrone auf Gegner → Zug wechselt
	r = t.shoot(1, 2)
	check(not r["live"] and not r["keeps_turn"] and t.current_player() == 2, "Platz auf Gegner: Zug wechselt")
	check(t.hp[2] == 3, "Gegner unverletzt")

	# Scharf auf sich selbst → Schaden, Zug wechselt
	t = _table({1: 3, 2: 3}, 3, 0)
	r = t.shoot(1, 1)
	check(r["live"] and r["damage"] == 1 and t.hp[1] == 2 and not r["keeps_turn"] and t.current_player() == 2, "scharf auf sich selbst: -1 Leben, Zug wechselt")
	# Scharf auf Gegner
	r = t.shoot(2, 1)
	check(t.hp[1] == 1 and t.current_player() == 1, "scharf auf Gegner: -1 Leben")

	# Ungültige Aktionen
	t = _table({1: 3, 2: 3}, 3, 3)
	check(t.shoot(2, 1)["reason"] == "not_your_turn", "falscher Spieler wird abgelehnt")
	check(t.shoot(1, 9)["reason"] == "target_not_alive", "unbekanntes Ziel wird abgelehnt")
	check(t.shoot(9, 1)["reason"] == "actor_not_alive", "unbekannter Schütze wird abgelehnt")

	# Nachladen, wenn das Magazin leer wird
	t = _table({1: 3, 2: 3}, 0, 1)
	r = t.shoot(1, 1)
	check(r["reloaded"] and t.chamber.remaining() >= 4, "leeres Magazin → automatisch neu geladen")
	check(r["keeps_turn"], "Extrazug bleibt auch beim Nachladen")

	# Tod beendet den Tisch
	t = _table({1: 1, 2: 1}, 2, 0)
	r = t.shoot(1, 2)
	check(r["killed"] and r["over"] and r["winner_id"] == 1 and t.is_over(), "Treffer auf letztes Leben → Sieger")
	check(t.shoot(1, 2)["reason"] == "table_over", "nach Tischende kein Schießen mehr")

	# Selbstmord: der andere gewinnt
	t = _table({1: 1, 2: 3}, 2, 0)
	r = t.shoot(1, 1)
	check(r["killed"] and t.winner_id == 2, "Selbsttreffer auf letztes Leben → Gegner gewinnt")


func test_turn_order_and_elimination() -> void:
	# Drei Spieler: Reihenfolge, Tod in der Mitte
	var t := _table({1: 1, 2: 1, 3: 1}, 5, 0)
	t.shoot(1, 2)                      # 2 stirbt
	check(not t.is_alive(2) and t.alive_ids() == [1, 3], "Spieler 2 ist raus")
	check(t.current_player() == 3, "nach Tod von 2 ist 3 dran")
	t.shoot(3, 1)                      # 1 stirbt → 3 gewinnt
	check(t.is_over() and t.winner_id == 3, "Spieler 3 gewinnt")

	# Letzter Spieler in der Reihenfolge erschießt den ersten
	t = _table({1: 1, 2: 3, 3: 3}, 5, 0)
	t.shoot(1, 2)                      # 2 verliert 1 → 2 hat 2; Zug → 2
	t.shoot(2, 3)                      # Zug → 3
	check(t.current_player() == 3, "3 ist dran")
	t.shoot(3, 1)                      # 1 stirbt, Zug → 2 (nächster nach 3 in [2,3])
	check(t.alive_ids() == [2, 3] and t.current_player() == 2, "Reihenfolge nach Tod des ersten: 2 ist dran (ist %d)" % t.current_player())

	# Schütze erschießt sich selbst in der Mitte
	t = _table({1: 3, 2: 1, 3: 3}, 5, 0)
	t.shoot(1, 1)                      # 1 → 2 Leben, Zug 2
	t.shoot(2, 2)                      # 2 stirbt, Zug 3
	check(t.alive_ids() == [1, 3] and t.current_player() == 3, "Selbsttod: nächster lebender Spieler ist dran")

	# strict_turns = false: Aufrufer steuert die Reihenfolge, der Tisch lehnt niemanden ab
	t = _table({1: 3, 2: 3}, 3, 0)
	t.strict_turns = false
	check(t.shoot(2, 1)["ok"], "strict_turns=false: beliebiger Schütze")
	check(t.current_player() == 1, "strict_turns=false: Tisch schaltet den Zug nicht weiter")


func test_items() -> void:
	# Lupe: zeigt die aktuelle Patrone, verbraucht nichts
	var t := _table({1: 3, 2: 3}, 1, 1)
	var seen := t.use_peek(1)
	check(t.chamber.remaining() == 2, "Lupe verbraucht nichts")
	check(t.shoot(1, 2)["shell"] == seen, "Lupe sagt die Wahrheit")

	# Säge: doppelter Schaden, nur einmal, verfällt auch bei Platzpatrone
	t = _table({1: 5, 2: 5}, 3, 0)
	check(t.use_saw(1) and t.is_sawed(1), "Säge angelegt")
	check(not t.use_saw(1), "Säge nicht doppelt")
	var r := t.shoot(1, 2)
	check(r["damage"] == 2 and t.hp[2] == 3 and not t.is_sawed(1), "Säge: 2 Schaden, danach verbraucht")
	t = _table({1: 5, 2: 5}, 0, 3)
	t.use_saw(1)
	t.shoot(1, 1)                      # Platz auf sich selbst, Extrazug
	check(not t.is_sawed(1), "Säge verfällt auch bei Platzpatrone")

	# Handschellen: Gegner setzt Zug aus, nicht auf sich selbst, nicht doppelt
	t = _table({1: 3, 2: 3}, 0, 4)
	check(not t.use_cuff(1, 1), "Handschellen nicht auf sich selbst")
	check(t.use_cuff(1, 2) and t.is_cuffed(2), "Gegner gefesselt")
	check(not t.use_cuff(1, 2), "nicht doppelt fesseln")
	t.shoot(1, 2)                      # Platz auf Gegner → 2 ist gefesselt → wieder 1
	check(t.current_player() == 1 and not t.is_cuffed(2), "gefesselter Gegner setzt aus (Fessel verbraucht)")

	# Verbandskasten: Heilung bis Maximum
	t = _table({1: 3, 2: 3}, 3, 0)
	check(t.use_heal(1, 1) == 0, "volle Leben: keine Heilung")
	t.shoot(1, 1)                      # 1 → 2 Leben
	check(t.use_heal(1, 5) == 1 and t.hp[1] == 3, "Heilung nur bis Maximum")
	t = _table({1: 1, 2: 3}, 0, 3)
	check(t.use_heal(1, -1) == 0 and t.hp[1] == 1 and t.is_alive(1),
		"negative Heilung wird abgelehnt und lässt den Spieler am Leben")
	check(t.use_heal(1, 0) == 0 and t.hp[1] == 1,
		"Heilung um null verändert keine Leben")

	# Auswerfen
	t = _table({1: 3, 2: 3}, 1, 1)
	var top := t.chamber.peek()
	check(t.use_eject(1) == top and t.chamber.remaining() == 1, "Auswerfen entfernt die oberste Patrone")
	t = _table({1: 3, 2: 3}, 0, 1)
	t.use_eject(1)
	check(t.chamber.remaining() >= 4, "Auswerfen der letzten Patrone lädt nach")

	# Nach Tischende wirkungslos
	t = _table({1: 1, 2: 1}, 1, 0)
	t.shoot(1, 2)
	check(t.use_peek(1) == ShellChamber.NONE and not t.use_saw(1) and t.use_heal(1) == 0, "Items nach Tischende wirkungslos")


func test_signals() -> void:
	var log: Array = []
	var t := RouletteTable.new(_rng(3))
	t.reloaded.connect(func(l, b, tot): log.append(["reload", l, b, tot]))
	t.shot_fired.connect(func(a, tg, sh, d): log.append(["shot", a, tg, sh, d]))
	t.player_down.connect(func(p): log.append(["down", p]))
	t.table_over.connect(func(w): log.append(["over", w]))
	t.setup({1: 1, 2: 1}, 2)
	check(log.size() == 1 and log[0][0] == "reload" and log[0][3] == 5, "setup lädt und meldet das Magazin (Level 2 = 5 Patronen)")
	t.chamber.load_shells(1, 0)
	t.shoot(1, 2)
	var kinds := log.map(func(e): return e[0])
	check(kinds == ["reload", "shot", "down", "over"], "Signalfolge shot → down → over: %s" % str(kinds))


func test_fuzz() -> void:
	var master := _rng(31337)
	var games := 2000
	var worst := 0
	var ok := true
	var problem := ""
	for g in games:
		var n := master.randi_range(2, 4)
		var hp := {}
		for i in n:
			hp[i + 1] = master.randi_range(1, 6)
		var t := RouletteTable.new(_rng(g + 1))
		t.setup(hp, master.randi_range(1, 5))
		var steps := 0
		while not t.is_over() and steps < 1000:
			steps += 1
			var actor := t.current_player()
			if not t.is_alive(actor):
				ok = false; problem = "Zug bei totem Spieler (Spiel %d)" % g; break
			var roll := master.randf()
			if roll < 0.15:
				t.use_peek(actor)
			elif roll < 0.25:
				t.use_saw(actor)
			elif roll < 0.35:
				var others := t.alive_ids().filter(func(p): return p != actor)
				t.use_cuff(actor, others[master.randi() % others.size()])
			elif roll < 0.42:
				t.use_heal(actor, 1)
			elif roll < 0.47:
				t.use_eject(actor)
			var alive := t.alive_ids()
			var res := t.shoot(actor, alive[master.randi() % alive.size()])
			if not res["ok"]:
				ok = false; problem = "ungültiger Schuss: %s (Spiel %d)" % [res["reason"], g]; break
			for pid in t.alive_ids():
				if t.hp[pid] <= 0 or t.hp[pid] > t.max_hp[pid]:
					ok = false; problem = "Leben außerhalb 1..max (Spiel %d)" % g
		if not ok:
			break
		worst = maxi(worst, steps)
		if not (t.is_over() and t.alive_ids().size() == 1 and t.winner_id == t.alive_ids()[0]):
			ok = false; problem = "Spiel %d endete ohne genau einen Sieger" % g; break
	check(ok, "Fuzz: " + problem)
	check(worst < 1000, "Fuzz: alle Spiele enden (längstes: %d Schüsse)" % worst)
	print("Fuzz: %d Spiele ok, längstes %d Schüsse" % [games, worst])


func test_level_difficulty() -> void:
	# Höhere Etagen sind gefährlicher: mehr scharfe Patronen pro Magazin und im Mittel mehr Schaden pro Schuss
	var r := _rng(77)
	var avg_live := []
	for lvl in [1, 3, 5]:
		var s := 0.0
		for i in 1000:
			s += RouletteTable.load_for_level(lvl, r)["live"]
		avg_live.append(s / 1000.0)
	check(avg_live[0] < avg_live[1] and avg_live[1] < avg_live[2], "mehr scharfe Patronen pro Magazin je höher die Etage: %s" % str(avg_live))


func _finish() -> void:
	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		print("FAIL %d von %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
