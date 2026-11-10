extends RefCounted
class_name ItemDraft
## ItemDraft — Item-Wahl zu Beginn jeder Runde (statt zufälliger Ausgabe).
##
## Jeder Spieler bekommt ein Angebot aus mehreren Items und wählt eine begrenzte Anzahl davon
## (Picks), die er in sein Inventar packt. Kategorien, die zur Rolle passen
## (CharacterClass.allowed_item_categories), sind im Angebot wahrscheinlicher – aber nicht
## ausschließlich, damit jede Rolle auch Überraschendes bekommt.
## Reine Logik ohne Szenenabhängigkeit (nutzt nur ItemDatabase und PlayerState).

const INVENTORY_CAPACITY := 8     # Items insgesamt (alle Stapel zusammen)
const DEFAULT_PICKS      := 2     # Auswahl pro Runde
const DEFAULT_OFFERS     := 4     # Angebotsgröße
const ROLE_WEIGHT        := 3.0   # Gewicht für rollenpassende Kategorien
const OTHER_WEIGHT       := 1.0


static func inventory_size(state: PlayerState) -> int:
	var total := 0
	for id in state.inventory:
		total += int(state.inventory[id])
	return total


static func free_slots(state: PlayerState, capacity: int = INVENTORY_CAPACITY) -> int:
	return maxi(capacity - inventory_size(state), 0)


## Wie viele Items der Spieler in dieser Runde noch wählen darf.
static func picks_for(state: PlayerState, picks: int = DEFAULT_PICKS, capacity: int = INVENTORY_CAPACITY) -> int:
	return mini(picks, free_slots(state, capacity))


## Zufälliges Angebot ohne Doppelte. Roulette-Items nur, wenn include_roulette = true.
static func build_offers(cc: CharacterClass, count: int, rng: RandomNumberGenerator,
		include_roulette: bool = false) -> Array[StringName]:
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	for id in ItemDatabase.get_all_ids():
		var idef := ItemDatabase.get_item(id) as ItemDefinition
		if idef == null:
			continue
		if idef.get("roulette_only") == true and not include_roulette:
			continue
		var fits := cc != null and cc.allowed_item_categories.has(idef.category)
		pool.append(id)
		weights.append(ROLE_WEIGHT if fits else OTHER_WEIGHT)

	var offers: Array[StringName] = []
	while offers.size() < count and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var roll := rng.randf() * total
		var idx := 0
		for i in weights.size():
			roll -= weights[i]
			if roll <= 0.0:
				idx = i
				break
			idx = i
		offers.append(pool[idx])
		pool.remove_at(idx)
		weights.remove_at(idx)
	return offers


## Prüft eine Wahl. Ergebnis: {"ok": bool, "reason": String}
static func validate_pick(state: PlayerState, offers: Array, item_id: StringName, picks_left: int,
		capacity: int = INVENTORY_CAPACITY) -> Dictionary:
	if picks_left <= 0:
		return {"ok": false, "reason": "no_picks_left"}
	if not offers.has(item_id):
		return {"ok": false, "reason": "not_offered"}
	if free_slots(state, capacity) <= 0:
		return {"ok": false, "reason": "inventory_full"}
	return {"ok": true, "reason": ""}


## Einfache KI-Wahl: rollenpassende Kategorien und Waffen bevorzugt, mit etwas Zufall.
static func auto_pick(cc: CharacterClass, offers: Array, picks: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var scored: Array = []
	for id in offers:
		var idef := ItemDatabase.get_item(id) as ItemDefinition
		var score := rng.randf()
		if idef != null:
			if cc != null and cc.allowed_item_categories.has(idef.category):
				score += 2.0
			if idef.category == "weapon":
				score += 1.0
		scored.append([score, id])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var result: Array[StringName] = []
	for i in mini(picks, scored.size()):
		result.append(scored[i][1])
	return result
