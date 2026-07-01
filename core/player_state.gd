extends Resource
class_name PlayerState
## PlayerState — Null Protocol
## Hält ALLE Laufzeit-Daten eines Spielers. Keine Logik, nur Daten.
## Alle Wert-Änderungen laufen über MatchController, der dann EventBus-Signale sendet.

signal any_value_changed()   # für Auto-Sync im Multiplayer

# ── Identität ─────────────────────────────────────────────────────────────────
var player_id:    int         = -1
var player_name:  String      = "???"
var is_ai:        bool        = false
var ai_difficulty: int        = 1
var char_class_id: StringName = &""
var gender:        String     = "m"    # "m","f","nb"
var disguise_id:   StringName = &""    # leer = echte Identität sichtbar

# ── Kernwerte ─────────────────────────────────────────────────────────────────
var health:     int = 3
var max_health: int = 3

## Misstrauen der Casino-Security (0-10). Bei 10: Rauswurf.
var suspicion:  int = 0
var max_suspicion: int = 10

## Soziale "Wärme" — wie sehr andere Spieler/NPCs einen als Bedrohung einschätzen.
var heat:       int = 0
var max_heat:   int = 10

## Einfluss: für Bestechung, Info-Kauf, NPC-Überzeugung.
var influence:  int = 2
var max_influence: int = 5

## Casino-Chips (Ingame-Währung für Käufe, Wetten, Bestechungen).
var chips:      int = 50

# ── Status-Effekte ────────────────────────────────────────────────────────────
## status_id → {rounds_remaining, stacks}
var active_statuses: Dictionary = {}
## Bekannte Status-IDs: "poisoned","stunned","disguised","protected",
##                      "marked","exposed","bribed","tipped_off"

# ── Inventar ──────────────────────────────────────────────────────────────────
## item_id → Anzahl
var inventory: Dictionary = {}

## Welche Items wurden bereits für dieses Match X-mal benutzt
var item_use_counts: Dictionary = {}

## Welche Items wurden erfolgreich reingeschmuggelt (vs. wurden konfisziert)
var smuggled_items: Array[StringName] = []

# ── Position & Zonen ──────────────────────────────────────────────────────────
var current_zone: String = "entrance"
## Bekannte Zonen: "entrance","lobby","floor","bar","vault_corridor",
##                 "vault","boss_office","backroom","rooftop","exit"
var visited_zones: Array[String] = []
var has_vault_key: bool = false

# ── Ziele & Siegbedingungen ───────────────────────────────────────────────────
var objective_progress: Dictionary = {}
## z.B. {"reach_vault": false, "eliminate_rivals": 0, "collect_chips": 200}
var is_eliminated: bool = false
var elimination_cause: String = ""  # "ejected","killed","exposed","timeout"

# ── Statistiken (für Endscreen) ───────────────────────────────────────────────
var stat_items_used:       int = 0
var stat_targets_hit:      int = 0
var stat_times_suspected:  int = 0
var stat_chips_won:        int = 0
var stat_rounds_survived:  int = 0


# ── Ressourcen-Helfer ─────────────────────────────────────────────────────────

func get_resource(res_name: String) -> int:
	match res_name:
		"health":    return health
		"suspicion": return suspicion
		"heat":      return heat
		"influence": return influence
		"chips":     return chips
	push_warning("PlayerState: unbekannte Ressource '%s'" % res_name)
	return 0


func get_resource_max(res_name: String) -> int:
	match res_name:
		"health":    return max_health
		"suspicion": return max_suspicion
		"heat":      return max_heat
		"influence": return max_influence
		"chips":     return 9999
	return 0


func modify_resource(res_name: String, delta: int) -> int:
	## Gibt den tatsächlichen Delta zurück (nach Clamping).
	var old_val := get_resource(res_name)
	var max_val := get_resource_max(res_name)
	var raw_new := old_val + delta
	var new_val := 0

	match res_name:
		"health":
			new_val = clampi(raw_new, 0, max_val)
			health  = new_val
			if health <= 0:
				is_eliminated    = true
				elimination_cause = "killed"
		"suspicion":
			new_val    = clampi(raw_new, 0, max_val)
			suspicion  = new_val
			if suspicion >= max_suspicion:
				is_eliminated    = true
				elimination_cause = "ejected"
		"heat":
			new_val = clampi(raw_new, 0, max_val)
			heat    = new_val
		"influence":
			new_val   = clampi(raw_new, 0, max_val)
			influence = new_val
		"chips":
			new_val = maxi(0, raw_new)
			chips   = new_val

	any_value_changed.emit()
	return new_val - old_val   # tatsächlicher Delta (kann kleiner als input sein)


# ── Inventar-Helfer ───────────────────────────────────────────────────────────

func add_item(item_id: StringName, amount: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + amount
	any_value_changed.emit()


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if not has_item(item_id):
		return false
	inventory[item_id] = inventory[item_id] - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	any_value_changed.emit()
	return true


func has_item(item_id: StringName) -> bool:
	return inventory.get(item_id, 0) > 0


func get_item_count(item_id: StringName) -> int:
	return inventory.get(item_id, 0)


func get_use_count(item_id: StringName) -> int:
	return item_use_counts.get(item_id, 0)


func record_item_use(item_id: StringName) -> void:
	item_use_counts[item_id] = get_use_count(item_id) + 1
	stat_items_used += 1


# ── Status-Helfer ─────────────────────────────────────────────────────────────

func apply_status(status_id: StringName, rounds: int, stacks: int = 1) -> void:
	if active_statuses.has(status_id):
		active_statuses[status_id]["rounds"] = maxi(active_statuses[status_id]["rounds"], rounds)
		active_statuses[status_id]["stacks"] = active_statuses[status_id]["stacks"] + stacks
	else:
		active_statuses[status_id] = {"rounds": rounds, "stacks": stacks}
	any_value_changed.emit()


func has_status(status_id: StringName) -> bool:
	return active_statuses.has(status_id)


func remove_status(status_id: StringName) -> void:
	active_statuses.erase(status_id)
	any_value_changed.emit()


func tick_statuses() -> Array[StringName]:
	## Muss am Ende jedes Zugs aufgerufen werden. Gibt Liste abgelaufener Status zurück.
	var expired: Array[StringName] = []
	for sid in active_statuses.keys():
		active_statuses[sid]["rounds"] -= 1
		if active_statuses[sid]["rounds"] <= 0:
			expired.append(sid)
	for sid in expired:
		active_statuses.erase(sid)
	return expired


# ── Netzwerk-Serialisierung ───────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"player_id": player_id, "player_name": player_name,
		"is_ai": is_ai, "ai_difficulty": ai_difficulty,
		"char_class_id": str(char_class_id), "gender": gender,
		"disguise_id": str(disguise_id),
		"health": health, "max_health": max_health,
		"suspicion": suspicion, "heat": heat,
		"influence": influence, "chips": chips,
		"active_statuses": active_statuses.duplicate(true),
		"inventory": inventory.duplicate(),
		"smuggled_items": Array(smuggled_items),
		"current_zone": current_zone,
		"has_vault_key": has_vault_key,
		"is_eliminated": is_eliminated,
		"elimination_cause": elimination_cause,
		"objective_progress": objective_progress.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PlayerState:
	var s := PlayerState.new()
	s.player_id      = d.get("player_id", -1)
	s.player_name    = d.get("player_name", "???")
	s.is_ai          = d.get("is_ai", false)
	s.ai_difficulty  = d.get("ai_difficulty", 1)
	s.char_class_id  = StringName(d.get("char_class_id", ""))
	s.gender         = d.get("gender", "m")
	s.disguise_id    = StringName(d.get("disguise_id", ""))
	s.health         = d.get("health", 3)
	s.max_health     = d.get("max_health", 3)
	s.suspicion      = d.get("suspicion", 0)
	s.heat           = d.get("heat", 0)
	s.influence      = d.get("influence", 2)
	s.chips          = d.get("chips", 50)
	s.active_statuses = d.get("active_statuses", {}).duplicate(true)
	s.inventory      = d.get("inventory", {}).duplicate()
	for item_id in d.get("smuggled_items", []):
		s.smuggled_items.append(StringName(item_id))
	s.current_zone   = d.get("current_zone", "entrance")
	s.has_vault_key  = d.get("has_vault_key", false)
	s.is_eliminated  = d.get("is_eliminated", false)
	s.elimination_cause = d.get("elimination_cause", "")
	s.objective_progress = d.get("objective_progress", {}).duplicate(true)
	return s
