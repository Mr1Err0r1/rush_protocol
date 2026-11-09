extends Node
## Validiert alle Rollen in resources/characters/ gegen die Item-Ressourcen.
## Start: bash tests/run_tests.sh

const FACTIONS := ["military", "mafia", "law_enforcement", "government", "elite", "civilian", "assassins"]
const CATEGORIES := ["weapon", "gadget", "intel", "tool", "disguise", "chip"]
const MIN_ROLES_PER_FACTION := {"military": 3, "mafia": 3, "government": 2, "civilian": 3}

var _checks := 0
var _fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _ready() -> void:
	var item_ids: Dictionary = {}
	for f in DirAccess.get_files_at("res://resources/items/"):
		if f.ends_with(".tres"):
			var it = load("res://resources/items/" + f)
			check(it != null and it.get("item_id") != null, "Item lädt nicht: " + f)
			if it != null:
				item_ids[it.item_id] = it
	check(item_ids.size() >= 12, "weniger als 12 Items gefunden")

	var seen: Dictionary = {}
	var per_faction: Dictionary = {}
	for f in DirAccess.get_files_at("res://resources/characters/"):
		if not f.ends_with(".tres"):
			continue
		var cc = load("res://resources/characters/" + f)
		check(cc is CharacterClass, "keine CharacterClass: " + f)
		if not (cc is CharacterClass):
			continue
		var id := str(cc.class_id)
		check(id != "", "leere class_id in " + f)
		check(not seen.has(id), "doppelte class_id: " + id)
		seen[id] = true
		check(FACTIONS.has(str(cc.faction_id)), "%s: unbekannte Fraktion %s" % [id, cc.faction_id])
		check(cc.display_name != "" and cc.display_name != "Unbekannt", id + ": display_name fehlt")
		check(cc.lore_text.length() > 20, id + ": lore_text zu kurz")
		check(cc.start_health >= 1 and cc.start_health <= 10, id + ": start_health außerhalb 1..10")
		check(cc.smuggle_slots >= 0 and cc.smuggle_slots <= 4, id + ": smuggle_slots außerhalb 0..4")
		check(cc.start_chips >= 0, id + ": negative Chips")
		check(cc.detection_resistance >= 0.0 and cc.detection_resistance <= 1.0, id + ": detection_resistance außerhalb 0..1")
		for g in cc.guaranteed_items:
			check(item_ids.has(g), "%s: garantiertes Item existiert nicht: %s" % [id, g])
		for cat in cc.allowed_item_categories:
			check(CATEGORIES.has(cat), "%s: unbekannte Item-Kategorie %s" % [id, cat])
		per_faction[str(cc.faction_id)] = per_faction.get(str(cc.faction_id), 0) + 1

	for fac in MIN_ROLES_PER_FACTION:
		check(per_faction.get(fac, 0) >= MIN_ROLES_PER_FACTION[fac],
			"Fraktion %s hat %d Rollen, erwartet >= %d" % [fac, per_faction.get(fac, 0), MIN_ROLES_PER_FACTION[fac]])
	print("Rollen pro Fraktion: ", per_faction)
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
