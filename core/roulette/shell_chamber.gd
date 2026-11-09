extends RefCounted
class_name ShellChamber
## ShellChamber — das Magazin des Roulette-Modus (inspiriert von Buckshot Roulette).
## Enthält scharfe (LIVE) und Platzpatronen (BLANK) in verdeckter Reihenfolge.
## Bekannt sind nur die Anzahlen (announce()) – die Reihenfolge nicht.

enum Shell { BLANK = 0, LIVE = 1 }
const NONE := -1

var _shells: Array[int] = []
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


## Lädt ein neues Magazin (ersetzt den Inhalt) und mischt es.
func load_shells(live: int, blank: int) -> void:
	_shells.clear()
	for i in maxi(live, 0):
		_shells.append(Shell.LIVE)
	for i in maxi(blank, 0):
		_shells.append(Shell.BLANK)
	# Fisher-Yates mit dem eigenen RNG (reproduzierbar bei festem Seed)
	for i in range(_shells.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _shells[i]
		_shells[i] = _shells[j]
		_shells[j] = tmp


func remaining() -> int:
	return _shells.size()


func live_count() -> int:
	return _shells.count(Shell.LIVE)


func blank_count() -> int:
	return _shells.count(Shell.BLANK)


func is_empty() -> bool:
	return _shells.is_empty()


## Die öffentlich bekannte Zusammensetzung – ohne Reihenfolge.
func announce() -> Dictionary:
	return {"live": live_count(), "blank": blank_count(), "total": remaining()}


## Die aktuelle Patrone ansehen, ohne sie zu verbrauchen (Lupe). NONE wenn leer.
func peek() -> int:
	return _shells[0] if not _shells.is_empty() else NONE


## Die aktuelle Patrone abfeuern (verbraucht sie). NONE wenn leer.
func draw() -> int:
	return _shells.pop_front() if not _shells.is_empty() else NONE


## Die aktuelle Patrone auswerfen, ohne zu schießen. Gibt ihren Typ zurück. NONE wenn leer.
func eject() -> int:
	return draw()
