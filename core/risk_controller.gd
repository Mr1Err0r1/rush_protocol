extends Node
class_name RiskController
## RiskController — Null Protocol
## Das zentrale Zufalls-System. Verwaltet einen Pool aus positiven und
## negativen Outcomes, der bei jeder "Wette" / jedem "Schuss" gezogen wird.
## Vollständig austauschbar — die Spiellogik kennt nur die Outcome-IDs.

enum OutcomeType { POSITIVE, NEGATIVE, NEUTRAL }

class Outcome:
	var outcome_id:    StringName
	var type:          int          # OutcomeType
	var resource:      String       # welche Ressource beeinflusst wird
	var delta:         int          # Veränderung
	var feedback_text: String

	func _init(oid: StringName, t: int, res: String, d: int, fb: String = "") -> void:
		outcome_id    = oid
		type          = t
		resource      = res
		delta         = d
		feedback_text = fb


var _pool:           Array[Outcome] = []
var _last_outcome:   Outcome        = null
var _force_next:     Outcome        = null   # gesetzt von fake_cards etc.
var _cheat_active:   bool           = false
var _cheat_owner_id: int            = -1

signal pool_changed(remaining: int, total: int)
signal outcome_drawn(outcome_id: StringName, type: int)


func setup(positive_count: int, negative_count: int) -> void:
	_pool.clear()
	_force_next    = null
	_cheat_active  = false
	_cheat_owner_id = -1

	# Casino-Kontext: Outcomes sind thematisch benannt
	for i in positive_count:
		_pool.append(Outcome.new(
			&"jackpot", OutcomeType.POSITIVE, "chips", randi_range(20, 60),
			"JACKPOT — Chips gewonnen!"
		))
	for i in negative_count:
		_pool.append(Outcome.new(
			&"house_wins", OutcomeType.NEGATIVE, "chips", -randi_range(15, 40),
			"Das Haus gewinnt immer."
		))

	_pool.shuffle()
	pool_changed.emit(_pool.size(), _pool.size())


func setup_from_config(cfg: Dictionary) -> void:
	setup(cfg.get("risk_pool_positive", 4), cfg.get("risk_pool_negative", 6))


## Gibt den nächsten Outcome ohne ihn zu entfernen (für Vorschau-Items).
func peek() -> StringName:
	if _force_next != null:
		return _force_next.outcome_id
	if _pool.is_empty():
		return &"none"
	return _pool[0].outcome_id


## Zieht einen Outcome und gibt ihn zurück. Server-only.
func draw() -> Outcome:
	if _pool.is_empty():
		EventBus.risk_pool_empty.emit()
		return null

	var drawn: Outcome
	if _force_next != null:
		drawn       = _force_next
		_force_next = null
		_cheat_active   = false
		_cheat_owner_id = -1
	else:
		drawn = _pool.pop_front()

	_last_outcome = drawn
	pool_changed.emit(_pool.size(), _pool.size() + 1)
	outcome_drawn.emit(drawn.outcome_id, drawn.type)
	return drawn


## Erzwingt nächsten Outcome als POSITIV (fake_cards).
func force_next_positive(owner_id: int = -1) -> void:
	_force_next = Outcome.new(
		&"forced_jackpot", OutcomeType.POSITIVE, "chips", randi_range(30, 70),
		"[BETRUG] Gezinktes Ergebnis."
	)
	_cheat_active   = true
	_cheat_owner_id = owner_id
	EventBus.risk_forced.emit(owner_id, &"forced_jackpot")


## Erzwingt nächsten Outcome als NEGATIV (für Vergeltungs-Items).
func force_next_negative(owner_id: int = -1) -> void:
	_force_next = Outcome.new(
		&"forced_loss", OutcomeType.NEGATIVE, "chips", -randi_range(30, 60),
		"[MANIPULATION] Schlechtes Ergebnis erzwungen."
	)
	EventBus.risk_forced.emit(owner_id, &"forced_loss")


func get_last_outcome() -> Outcome:
	return _last_outcome


func is_empty() -> bool:
	return _pool.is_empty() and _force_next == null


func get_remaining() -> int:
	return _pool.size()


func is_cheat_active() -> bool:
	return _cheat_active


func get_cheat_owner_id() -> int:
	return _cheat_owner_id


func refill(additional_positive: int, additional_negative: int) -> void:
	for i in additional_positive:
		var o := Outcome.new(&"jackpot", OutcomeType.POSITIVE, "chips",
				randi_range(20, 60), "JACKPOT!")
		_pool.append(o)
	for i in additional_negative:
		var o := Outcome.new(&"house_wins", OutcomeType.NEGATIVE, "chips",
				-randi_range(15, 40), "Das Haus gewinnt.")
		_pool.append(o)
	_pool.shuffle()
	pool_changed.emit(_pool.size(), _pool.size())

# --- NEU: Schmuggel & Detektion ---

signal item_confiscated(player_id: int, item_id: StringName)
signal player_detected(player_id: int, suspicion_increase: int)

func perform_entry_check(player_state: PlayerState, character: CharacterClass) -> Dictionary:
	var results := {
		"detected_items": [],
		"suspicion_gain": 0,
		"passed": true
	}
	
	for item_id in player_state.inventory:
		var item_def = ItemDatabase.get_item(item_id)
		if not item_def or not item_def.can_be_smuggled: 
			continue
		
		var detection_chance = item_def.confiscation_chance
		if character:
			detection_chance -= character.detection_resistance
		
		# KORREKTUR: Da 'is_metallic' nicht existiert, nutzen wir 'detection_weight' als Faktor
		if item_def.detection_weight > 7:
			detection_chance += 0.2
			
		if randf() < detection_chance:
			results.detected_items.append(item_id)
			# KORREKTUR: Nutze 'suspicion_on_use' oder fixen Wert, da 'suspicion_on_detection' fehlt
			results.suspicion_gain += 2 
			results.passed = false
			item_confiscated.emit(player_state.player_id, item_id)
	
	player_state.modify_resource("suspicion", results.suspicion_gain)
	if results.suspicion_gain > 0:
		player_detected.emit(player_state.player_id, results.suspicion_gain)
		
	return results
