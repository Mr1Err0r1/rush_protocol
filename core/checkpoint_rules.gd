extends RefCounted
class_name CheckpointRules
## CheckpointRules — Wahrscheinlichkeiten für Einlass- und Etagenkontrollen.
## Reine Rechenlogik (keine Seiteneffekte, gut testbar). Die Kontrollen selbst
## führt der EntryPhaseController aus.
##
## Ablauf im Spiel: Einlasskontrolle am Eingang (immer) → Etage 1 → beim ersten
## Betreten höherer Etagen kann eine Kontrolle auslösen (Chance je Etage, Rolle,
## Misstrauen und Heat). Das Penthouse wird immer kontrolliert.

## Zielzone → Kontrollpunkt.
##   chance:    Grundwahrscheinlichkeit, dass kontrolliert wird
##   strictness: Multiplikator auf die Fundchance jedes Schmuggel-Items
##   mandatory: true = Fraktions-Durchwinken gilt hier nicht
const CHECKPOINTS := {
	"vip_lounge":     {"chance": 0.20, "strictness": 0.6, "mandatory": false},
	"backroom":       {"chance": 0.30, "strictness": 0.9, "mandatory": false},
	"vault_corridor": {"chance": 0.40, "strictness": 1.2, "mandatory": false},
	"boss_office":    {"chance": 1.00, "strictness": 1.5, "mandatory": true},
}

## Fraktionsprofil.
##   skip:        Chance, einfach durchgewinkt zu werden (Ausweis, Rang, Trinkgeld)
##   concealment: Kategorie → Multiplikator auf die Fundchance (< 1 = besser versteckt)
const FACTION_PROFILES := {
	&"military":        {"skip": 0.10, "concealment": {"weapon": 0.7}},
	&"government":      {"skip": 0.30, "concealment": {"intel": 0.5, "gadget": 0.6}},
	&"mafia":           {"skip": 0.10, "concealment": {"chip": 0.7}},
	&"civilian":        {"skip": 0.05, "concealment": {}},
	&"elite":           {"skip": 0.40, "concealment": {}},
	&"law_enforcement": {"skip": 0.20, "concealment": {"weapon": 0.6}},
	&"assassins":       {"skip": 0.00, "concealment": {"weapon": 0.4}},
}
const DEFAULT_PROFILE := {"skip": 0.0, "concealment": {}}

## Zusätzliche Chance pro Misstrauens-/Heat-Punkt.
const SUSPICION_STEP := 0.03
const HEAT_STEP      := 0.02

const ZONE_LABELS := {
	"vip_lounge": "Goldener Salon", "backroom": "Hinterzimmer",
	"vault_corridor": "Tresor-Korridor", "boss_office": "Penthouse",
}


## Wirksames Profil einer Rolle: Fraktionsprofil, überschrieben durch Rollen-Felder.
static func profile_for(cc: CharacterClass) -> Dictionary:
	if cc == null:
		return DEFAULT_PROFILE.duplicate(true)
	var prof: Dictionary = FACTION_PROFILES.get(cc.faction_id, DEFAULT_PROFILE).duplicate(true)
	if cc.checkpoint_skip_chance >= 0.0:
		prof["skip"] = cc.checkpoint_skip_chance
	for cat in cc.concealment:
		prof["concealment"][cat] = cc.concealment[cat]
	return prof


static func is_checkpoint(zone: String) -> bool:
	return CHECKPOINTS.has(zone)


## Wahrscheinlichkeit (0..1), dass beim Betreten von `zone` kontrolliert wird.
static func trigger_chance(zone: String, suspicion: int, heat: int, cc: CharacterClass) -> float:
	var cp: Dictionary = CHECKPOINTS.get(zone, {})
	if cp.is_empty():
		return 0.0
	var chance: float = cp["chance"] + suspicion * SUSPICION_STEP + heat * HEAT_STEP
	if not cp["mandatory"]:
		chance *= 1.0 - float(profile_for(cc)["skip"])
	return clampf(chance, 0.0, 1.0)


## Wahrscheinlichkeit (0..1), dass ein Schmuggel-Item gefunden wird.
## strictness = 1.0 entspricht der Einlasskontrolle am Eingang.
static func item_find_chance(idef: ItemDefinition, suspicion: int, cc: CharacterClass,
		strictness: float = 1.0) -> float:
	if idef == null:
		return 0.0
	var chance: float = idef.confiscation_chance * strictness + suspicion * SUSPICION_STEP
	if cc != null:
		chance -= cc.detection_resistance
	var mult: float = float(profile_for(cc)["concealment"].get(idef.category, 1.0))
	return clampf(chance * mult, 0.0, 1.0)


## Kurztext für die Charakterauswahl: Kontrollrisiko dieser Rolle (Misstrauen 0, Heat = Startwert).
static func describe(cc: CharacterClass) -> String:
	if cc == null:
		return ""
	var parts: Array[String] = []
	for zone in CHECKPOINTS:
		var p := trigger_chance(zone, cc.start_suspicion, cc.start_heat, cc)
		parts.append("%s %d%%" % [ZONE_LABELS.get(zone, zone), roundi(p * 100.0)])
	return "Kontrollrisiko je Etage: " + " · ".join(parts)
