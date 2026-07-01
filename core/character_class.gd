extends Resource
class_name CharacterClass
## CharacterClass — Null Protocol
## Definiert eine spielbare Charakterklasse (siehe resources/characters/*.tres).
## Reine Daten-Ressource — Spiellogik liegt im MatchController.

@export var class_id:     StringName = &""
@export var display_name: String     = "Unbekannt"
@export_multiline var lore_text: String = ""
## Welche Geschlechts-Optionen für diese Klasse wählbar sind ("m","f","nb")
@export var gender_options: Array[String] = ["m", "f"]

@export_group("Startwerte")
@export var start_health:    int = 3
@export var start_suspicion: int = 0
@export var start_heat:      int = 0
@export var start_influence: int = 2
@export var start_chips:     int = 50

@export_group("Schmuggel & Loadout")
@export var smuggle_slots: int = 2
## Items, die diese Klasse immer dabei hat (zählen NICHT gegen smuggle_slots).
@export var guaranteed_items: Array[StringName] = []
## Leer = alle Kategorien erlaubt. Sonst Filter für die Loadout-Auswahl.
@export var allowed_item_categories: Array[String] = []
## Bonus gegen Metalldetektoren bei der Einlass-Kontrolle (0.0 - 1.0).
@export var detection_resistance: float = 0.0

@export_group("Fähigkeiten")
@export var entry_bonus_id:    StringName = &""
@export var passive_ability_id: StringName = &""
@export var active_ability_id:  StringName = &""

@export_group("Sieg")
## z.B. "control_casino","eliminate_rivals","survive_undetected","reach_vault"
@export var primary_objective: String = ""

@export_group("Freischaltung")
@export var unlocked_by_default: bool = false
