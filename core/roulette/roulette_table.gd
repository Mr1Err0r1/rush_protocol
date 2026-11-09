extends RefCounted
class_name RouletteTable
## RouletteTable — Regelwerk des Roulette-Modus (inspiriert von Buckshot Roulette).
##
## Regeln:
##  • Das Magazin enthält scharfe und Platzpatronen; die Anzahlen sind bekannt, die Reihenfolge nicht.
##  • Wer am Zug ist, schießt auf einen Gegner ODER auf sich selbst.
##  • Scharf → Ziel verliert 1 Leben (2 mit Säge). Platzpatrone → nichts.
##  • Platzpatrone auf sich selbst → man bleibt am Zug. Alles andere beendet den Zug.
##  • Items: peek (Lupe), saw (Säge), cuff (Handschellen), heal (Verbandskasten), eject (Auswerfen).
##  • Schutzweste (set_shield) fängt den nächsten Treffer ab.
##  • Ist das Magazin leer, wird neu geladen (Anzahlen werden angesagt).
##  • Je höher die Etage (level 1–5), desto größer das Magazin und desto höher der Anteil scharfer Patronen.
##
## Reine Logik ohne Szenenabhängigkeit. strict_turns=false erlaubt, dass der Aufrufer
## (z. B. MatchController) die Zugreihenfolge selbst verwaltet.

signal reloaded(live: int, blank: int, total: int)
signal shot_fired(actor_id: int, target_id: int, shell: int, damage: int)
signal player_down(player_id: int)
signal turn_changed(player_id: int)
signal table_over(winner_id: int)

const MIN_LEVEL := 1
const MAX_LEVEL := 5
const SHELLS_BY_LEVEL := [4, 5, 6, 7, 8]
const LIVE_RATIO_BY_LEVEL := [0.40, 0.45, 0.50, 0.55, 0.60]

var level: int = 1
var chamber: ShellChamber
var hp: Dictionary = {}          # player_id → aktuelle Leben
var max_hp: Dictionary = {}      # player_id → Maximum (für Heilung)
var order: Array[int] = []       # Spieler am Tisch in Zugreihenfolge
var strict_turns: bool = true
var winner_id: int = -1

var _rng: RandomNumberGenerator
var _turn_index: int = 0
var _sawed: Dictionary = {}      # player_id → nächster Schuss doppelt
var _cuffed: Dictionary = {}     # player_id → setzt den nächsten Zug aus
var _shield: Dictionary = {}     # player_id → fängt den nächsten Treffer ab (Schutzweste)


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	chamber = ShellChamber.new(_rng)


## Größe und Mischung eines Magazins für eine Etage. Mindestens 1 scharfe und 1 Platzpatrone.
static func load_for_level(lvl: int, rng: RandomNumberGenerator) -> Dictionary:
	var l := clampi(lvl, MIN_LEVEL, MAX_LEVEL)
	var total: int = SHELLS_BY_LEVEL[l - 1]
	var live := roundi(total * float(LIVE_RATIO_BY_LEVEL[l - 1]) + rng.randf_range(-0.5, 0.5))
	live = clampi(live, 1, total - 1)
	return {"live": live, "blank": total - live, "total": total}


## player_hp: player_id → Leben (Reihenfolge der Schlüssel = Zugreihenfolge).
func setup(player_hp: Dictionary, lvl: int = 1) -> void:
	level = clampi(lvl, MIN_LEVEL, MAX_LEVEL)
	hp = player_hp.duplicate()
	max_hp = player_hp.duplicate()
	order.clear()
	for pid in player_hp.keys():
		if player_hp[pid] > 0:
			order.append(pid)
	_sawed.clear()
	_cuffed.clear()
	_shield.clear()
	_turn_index = 0
	winner_id = -1
	_reload()
	_check_over()


func current_player() -> int:
	return order[_turn_index] if not order.is_empty() else -1


func is_over() -> bool:
	return winner_id != -1 or order.size() <= 1


func alive_ids() -> Array[int]:
	return order.duplicate()


func is_alive(pid: int) -> bool:
	return order.has(pid)


func is_sawed(pid: int) -> bool:
	return _sawed.get(pid, false)


func has_shield(pid: int) -> bool:
	return _shield.get(pid, false)


## Schutzweste an-/ausschalten: fängt den nächsten Treffer vollständig ab.
func set_shield(pid: int, on: bool) -> void:
	if not is_alive(pid):
		return
	if on:
		_shield[pid] = true
	else:
		_shield.erase(pid)


func is_cuffed(pid: int) -> bool:
	return _cuffed.get(pid, false)


## Wird aufgerufen, wenn `pid` an der Reihe wäre: verbraucht die Handschellen.
## true = dieser Zug entfällt.
func consume_cuff(pid: int) -> bool:
	if _cuffed.get(pid, false):
		_cuffed.erase(pid)
		return true
	return false


# ── Schießen ──────────────────────────────────────────────────────────────────

## Schießt auf target_id (= actor_id für sich selbst).
## Ergebnis: {ok, reason, shell, live, damage, target_id, killed, keeps_turn, reloaded, over, winner_id}
func shoot(actor_id: int, target_id: int) -> Dictionary:
	var fail := func(reason: String) -> Dictionary:
		return {"ok": false, "reason": reason}
	if is_over():
		return fail.call("table_over")
	if not is_alive(actor_id):
		return fail.call("actor_not_alive")
	if strict_turns and actor_id != current_player():
		return fail.call("not_your_turn")
	if not is_alive(target_id):
		return fail.call("target_not_alive")
	if chamber.is_empty():
		_reload()

	var shell := chamber.draw()
	var live := shell == ShellChamber.Shell.LIVE
	var damage := 0
	if live:
		damage = 2 if _sawed.get(actor_id, false) else 1
	_sawed.erase(actor_id)   # die Säge gilt nur für den nächsten Schuss, egal ob scharf

	var absorbed := false
	if damage > 0 and _shield.get(target_id, false):
		absorbed = true
		damage = 0
		_shield.erase(target_id)

	var killed := false
	if damage > 0:
		hp[target_id] = maxi(int(hp[target_id]) - damage, 0)
		killed = hp[target_id] <= 0
	shot_fired.emit(actor_id, target_id, shell, damage)
	if killed:
		_remove(target_id)

	var keeps_turn := (target_id == actor_id and not live and not killed)
	var reloaded := false
	if not is_over():
		if chamber.is_empty():
			_reload()
			reloaded = true
		if not keeps_turn:
			_advance_after(actor_id)
	_check_over()

	return {"ok": true, "shell": shell, "live": live, "damage": damage, "target_id": target_id,
			"killed": killed, "absorbed": absorbed, "keeps_turn": keeps_turn, "reloaded": reloaded,
			"over": is_over(), "winner_id": winner_id}


# ── Items ─────────────────────────────────────────────────────────────────────

## Lupe: verrät dem Benutzer die aktuelle Patrone (ShellChamber.Shell oder NONE).
func use_peek(actor_id: int) -> int:
	if is_over() or not is_alive(actor_id):
		return ShellChamber.NONE
	return chamber.peek()


## Säge: der nächste Schuss des Benutzers verursacht doppelten Schaden.
func use_saw(actor_id: int) -> bool:
	if is_over() or not is_alive(actor_id) or _sawed.get(actor_id, false):
		return false
	_sawed[actor_id] = true
	return true


## Handschellen: das Ziel setzt seinen nächsten Zug aus. Nicht auf sich selbst, nicht doppelt.
func use_cuff(actor_id: int, target_id: int) -> bool:
	if is_over() or not is_alive(actor_id) or not is_alive(target_id):
		return false
	if actor_id == target_id or _cuffed.get(target_id, false):
		return false
	_cuffed[target_id] = true
	return true


## Verbandskasten: heilt bis max_hp. Gibt die tatsächliche Heilung zurück.
func use_heal(actor_id: int, amount: int = 1) -> int:
	if is_over() or not is_alive(actor_id) or amount <= 0:
		return 0
	var before: int = hp[actor_id]
	hp[actor_id] = mini(before + amount, int(max_hp[actor_id]))
	return int(hp[actor_id]) - before


## Auswerfen: wirft die aktuelle Patrone aus, ohne zu schießen. Gibt ihren Typ zurück.
func use_eject(actor_id: int) -> int:
	if is_over() or not is_alive(actor_id) or chamber.is_empty():
		return ShellChamber.NONE
	var shell := chamber.eject()
	if chamber.is_empty():
		_reload()
	return shell


## Spieler vom Tisch nehmen (z. B. von außen eliminiert).
func drop(pid: int) -> void:
	_remove(pid)
	_check_over()


## Leben eines Spielers von außen setzen (z. B. aus dem PlayerState). hp <= 0 nimmt ihn vom Tisch.
func sync_player(pid: int, hp_value: int, max_hp_value: int) -> void:
	if not is_alive(pid):
		return
	if hp_value <= 0:
		drop(pid)
		return
	hp[pid] = hp_value
	max_hp[pid] = maxi(max_hp_value, hp_value)


# ── intern ────────────────────────────────────────────────────────────────────

func _reload() -> void:
	var cfg := load_for_level(level, _rng)
	chamber.load_shells(cfg["live"], cfg["blank"])
	reloaded.emit(cfg["live"], cfg["blank"], cfg["total"])


func _remove(pid: int) -> void:
	var idx := order.find(pid)
	if idx == -1:
		return
	order.remove_at(idx)
	_sawed.erase(pid)
	_cuffed.erase(pid)
	_shield.erase(pid)
	if idx < _turn_index:
		_turn_index -= 1
	if not order.is_empty():
		_turn_index = _turn_index % order.size()
	player_down.emit(pid)


## Nächster Spieler am Zug (strikter Modus); Handschellen werden hier NICHT verbraucht –
## das macht der Aufrufer über consume_cuff(), weil er den Zugwechsel steuert.
func _advance_after(actor_id: int) -> void:
	if order.is_empty():
		return
	if strict_turns:
		var idx := order.find(actor_id)
		_turn_index = (idx + 1) % order.size() if idx != -1 else _turn_index % order.size()
		# Gefesselte überspringen (verbraucht die Fessel), max. einmal pro Spieler
		var guard := 0
		while guard < order.size() and consume_cuff(order[_turn_index]):
			_turn_index = (_turn_index + 1) % order.size()
			guard += 1
		turn_changed.emit(order[_turn_index])


func _check_over() -> void:
	if winner_id == -1 and order.size() == 1:
		winner_id = order[0]
		table_over.emit(winner_id)
