extends Control
class_name CharacterSelectUI
## CharacterSelectUI — Null Protocol
## Zeigt alle verfügbaren Charakterklassen, Geschlecht-Wahl und Loadout-Auswahl.
## Reagiert auf EventBus-Signale, sendet Auswahl über RpcRelay oder direkt.

@onready var class_list:      ItemList    = $HBox/Left/ClassList
@onready var class_name_lbl:  Label       = $HBox/Right/ClassName
@onready var class_lore_lbl: RichTextLabel = $HBox/Right/LoreTxt
@onready var gender_m_btn:    Button      = $HBox/Right/GenderRow/MaleBtn
@onready var gender_f_btn:    Button      = $HBox/Right/GenderRow/FemaleBtn
@onready var gender_lbl:      Label       = $HBox/Right/GenderRow/GenderLbl
@onready var gender_row:      HBoxContainer = $HBox/Right/GenderRow
@onready var stats_panel:     GridContainer = $HBox/Right/Stats
@onready var smuggle_label:   Label       = $HBox/Right/SmuggleInfo
@onready var loadout_container: HBoxContainer = $Bottom/LoadoutRow
@onready var confirm_btn:     Button      = $Bottom/ConfirmBtn
@onready var status_lbl:      Label       = $Bottom/StatusLbl

var _selected_class_id: StringName = &""
var _selected_gender:   String     = "m"
var _selected_items:    Array[StringName] = []
var _local_player_id:   int = -1
var _rpc_relay:         Node = null   # NetworkRpcRelay oder null für Solo
var _available_classes: Array = []
var _selected_faction_id: StringName = &""
var _selection_step: int = 0 # 0 = Fraktion, 1 = Charakter
var _step_label: Label
var _back_faction_btn: Button
var _gender_nb_btn: Button
var _gender_buttons: Dictionary = {}


func _ready() -> void:
	_local_player_id = NetworkManager.get_local_id()
	gender_lbl.text = _ui_text("character.gender_label", "Geschlecht:")
	_available_classes = _get_available_classes()
	_available_classes.sort_custom(func(a: CharacterClass, b: CharacterClass) -> bool: return a.display_name.to_lower() < b.display_name.to_lower())
	confirm_btn.pressed.connect(_on_confirm_pressed)
	_gender_buttons = {"m": gender_m_btn, "f": gender_f_btn}
	for gender_id in _gender_buttons:
		_gender_buttons[gender_id].pressed.connect(_select_gender.bind(gender_id))
	_gender_nb_btn = Button.new()
	_gender_nb_btn.toggle_mode = true
	_gender_nb_btn.visible = false
	gender_row.add_child(_gender_nb_btn)
	_gender_buttons["nb"] = _gender_nb_btn
	_gender_nb_btn.pressed.connect(_select_gender.bind("nb"))
	class_list.item_selected.connect(_on_class_selected)
	_add_wizard_navigation()
	_populate_class_list()


func set_rpc_relay(relay: Node) -> void:
	_rpc_relay = relay


func _add_wizard_navigation() -> void:
	var right := get_node("HBox/Right") as VBoxContainer
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 12)
	_step_label.add_theme_color_override("font_color", Color(0.82, 0.68, 0.32))
	right.add_child(_step_label)
	right.move_child(_step_label, 0)
	_back_faction_btn = Button.new()
	_back_faction_btn.text = _ui_text("character.back_to_factions", "← Fraktionen")
	_back_faction_btn.pressed.connect(_populate_class_list)
	var bottom := get_node("Bottom") as HBoxContainer
	bottom.add_child(_back_faction_btn)
	bottom.move_child(_back_faction_btn, 0)


func _ui_text(key: String, fallback: String) -> String:
	var translated := LocaleManager.translate(key)
	return fallback if translated == key else translated


func _show_faction_info() -> void:
	_selected_class_id = &""
	var role_count := 0
	for cc in _available_classes:
		if cc.faction_id == _selected_faction_id:
			role_count += 1
	class_name_lbl.text = _faction_label(_selected_faction_id)
	class_lore_lbl.text = "%s\n\n%s %d" % [
		_ui_text("character.faction_hint", "Wähle zuerst deine Seite. Danach siehst du nur die Rollen dieser Fraktion."),
		_ui_text("character.roles_available", "Verfügbare Rollen:"), role_count
	]
	gender_row.visible = false
	stats_panel.visible = false
	smuggle_label.visible = false
	loadout_container.visible = false
	confirm_btn.text = _ui_text("character.continue", "Rollen ansehen")


func _advance_to_characters() -> void:
	if _selected_faction_id == &"":
		status_lbl.text = _ui_text("character.select_faction_first", "Bitte zuerst eine Fraktion auswählen.")
		return
	_selection_step = 1
	_step_label.text = _ui_text("character.step_role", "SCHRITT 2/2 · CHARAKTER WÄHLEN")
	_back_faction_btn.visible = true
	confirm_btn.text = _ui_text("character.confirm_start", "Bestätigen & Starten")
	class_list.clear()
	var preferred_index := 0
	var preferred_class := SaveManager.get_last_character()
	for cc in _available_classes:
		if cc.faction_id != _selected_faction_id:
			continue
		class_list.add_item(cc.display_name)
		class_list.set_item_metadata(class_list.item_count - 1, cc.class_id)
		if cc.class_id == preferred_class:
			preferred_index = class_list.item_count - 1
	if class_list.item_count == 0:
		status_lbl.text = _ui_text("character.no_roles", "Für diese Fraktion sind keine Charaktere freigeschaltet.")
		return
	class_list.select(preferred_index)
	_on_class_selected(preferred_index)


func _populate_class_list() -> void:
	class_list.clear()
	_selected_class_id = &""
	_selected_items.clear()
	_selection_step = 0
	_back_faction_btn.visible = false
	loadout_container.visible = false
	gender_row.visible = false
	stats_panel.visible = false
	smuggle_label.visible = false
	_step_label.text = _ui_text("character.step_faction", "SCHRITT 1/2 · FRAKTION WÄHLEN")
	class_name_lbl.text = _ui_text("character.choose_faction", "Wähle eine Fraktion")
	class_lore_lbl.text = _ui_text("character.faction_hint", "Wähle zuerst deine Seite. Danach siehst du nur die Rollen dieser Fraktion.")
	confirm_btn.text = _ui_text("character.continue", "Rollen ansehen")
	var faction_ids: Array[StringName] = []
	for cc in _available_classes:
		var faction_id := StringName(cc.faction_id)
		if not faction_ids.has(faction_id):
			faction_ids.append(faction_id)
	faction_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	var preferred_class := SaveManager.get_last_character()
	var preferred_faction: StringName = faction_ids[0] if not faction_ids.is_empty() else &"independent"
	for cc in _available_classes:
		if cc.class_id == preferred_class:
			preferred_faction = cc.faction_id
			break
	var preferred_index := 0
	for i in faction_ids.size():
		var faction_id: StringName = faction_ids[i]
		class_list.add_item(_faction_label(faction_id))
		class_list.set_item_metadata(class_list.item_count - 1, faction_id)
		if faction_id == preferred_faction:
			preferred_index = i

	if class_list.item_count > 0:
		class_list.select(preferred_index)
		_on_class_selected(preferred_index)


func _get_available_classes() -> Array:
	## Lädt CharacterClass-Resources aus resources/characters/
	var result: Array = []
	var path := "res://resources/characters/"
	var dir  := DirAccess.open(path)
	if dir == null:
		# Fallback: hartcodierte Liste wenn noch keine Resources existieren
		return _get_fallback_classes()
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(path + fname)
			if res is CharacterClass:
				var unlocked := SaveManager.get_unlocked_characters()
				if res.unlocked_by_default or unlocked.has(str(res.class_id)):
					result.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	return result if not result.is_empty() else _get_fallback_classes()


func _get_fallback_classes() -> Array:
	## Gibt Dummy-Daten zurück solange keine .tres-Dateien vorhanden sind
	var dummies: Array = []
	var entries := [
		{"id": &"mafia_boss","name": "Mafia-Boss","lore": "Beherrsche das Spiel.","health": 4,"sus": 1,"inf": 4,"chips": 80,"slots": 2},
		{"id": &"assassin","name": "Assassine","lore": "Lautlos. Toedlich. Unsichtbar.","health": 3,"sus": 0,"inf": 2,"chips": 50,"slots": 3},
		{"id": &"undercover_cop","name": "Verdeckter Ermittler","lore": "Observiere, verhindere den Raub.","health": 3,"sus": 0,"inf": 3,"chips": 40,"slots": 1},
		{"id": &"millionaire","name": "Millionaer","lore": "Geld loest alle Probleme.","health": 3,"sus": 2,"inf": 5,"chips": 150,"slots": 2},
		{"id": &"government_agent","name": "Regierungsagent","lore": "Offizielle Befugnisse.","health": 3,"sus": 0,"inf": 4,"chips": 60,"slots": 2},
		{"id": &"citizen","name": "Normalbuerger","lore": "Unterschaetzt - der gefaehrlichste Fehler.","health": 5,"sus": 0,"inf": 1,"chips": 30,"slots": 1},
	]
	for data in entries:
		var cc := CharacterClass.new()
		cc.class_id      = data["id"]
		cc.display_name  = data["name"]
		cc.lore_text     = data["lore"]
		cc.start_health  = data["health"]
		cc.start_suspicion = data["sus"]
		cc.start_influence = data["inf"]
		cc.start_chips   = data["chips"]
		cc.smuggle_slots = data["slots"]
		cc.unlocked_by_default = true
		dummies.append(cc)
	return dummies


func _on_class_selected(index: int) -> void:
	if _selection_step == 0:
		_selected_faction_id = StringName(class_list.get_item_metadata(index))
		_show_faction_info()
		return
	_selected_class_id = class_list.get_item_metadata(index)
	for cc in _available_classes:
		if cc.class_id == _selected_class_id:
			_show_class_info(cc)
			break


func _show_class_info(cc: CharacterClass) -> void:
	class_name_lbl.text = cc.display_name
	class_lore_lbl.text = "Fraktion: %s\n\n%s" % [_faction_label(cc.faction_id), cc.lore_text]
	smuggle_label.text  = _ui_text("character.smuggle_slots", "Schmuggel-Slots: %d") % cc.smuggle_slots
	gender_row.visible = true
	stats_panel.visible = true
	smuggle_label.visible = true
	loadout_container.visible = true
	var gender_fallbacks := {"m": "Männlich", "f": "Weiblich", "nb": "Nichtbinär"}
	for gender_id in _gender_buttons:
		var button: Button = _gender_buttons[gender_id]
		button.text = _ui_text("character.gender_" + str(gender_id), gender_fallbacks.get(str(gender_id), str(gender_id)))
		button.visible = cc.gender_options.has(str(gender_id))
	if not cc.gender_options.has(_selected_gender):
		_select_gender(cc.gender_options[0] if not cc.gender_options.is_empty() else "m")
	else:
		_select_gender(_selected_gender)

	# Stats in GridContainer darstellen
	for child in stats_panel.get_children():
		child.queue_free()
	_add_stat_row(_ui_text("character.stats_health", "❤ Leben"), cc.start_health, 5)
	_add_stat_row(_ui_text("character.stats_suspicion", "👁 Misstrauen"), cc.start_suspicion, 10, true)
	_add_stat_row(_ui_text("character.stats_influence", "🎩 Einfluss"), cc.start_influence, 5)
	_add_stat_row(_ui_text("character.stats_chips", "💰 Chips"), cc.start_chips, 150)

	_populate_loadout_slots(cc)


func _add_stat_row(label_text: String, value: int, max_val: int,
		_lower_is_better: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	stats_panel.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_val
	bar.value     = value
	bar.custom_minimum_size = Vector2(120, 16)
	stats_panel.add_child(bar)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	stats_panel.add_child(val_lbl)


func _populate_loadout_slots(cc: CharacterClass) -> void:
	for child in loadout_container.get_children():
		child.queue_free()
	_selected_items.clear()

	for i in cc.smuggle_slots:
		var btn := Button.new()
		btn.text = _ui_text("character.item_slot", "+ Item %d wählen") % (i + 1)
		btn.custom_minimum_size = Vector2(160, 60)
		var slot_index := i
		btn.pressed.connect(func(): _open_item_picker(slot_index, btn, cc))
		loadout_container.add_child(btn)
		_selected_items.append(&"")


func _open_item_picker(slot_index: int, slot_btn: Button, cc: CharacterClass) -> void:
	## In einem vollständigen Projekt würde hier ein modales Popup-Menü öffnen.
	## Für dieses Gerüst: zyklisch durch verfügbare Items rotieren.
	var smuggleable: Array = []
	for item in ItemDatabase.get_smuggleable_items():
		if cc.allowed_item_categories.is_empty() or cc.allowed_item_categories.has(item.category):
			smuggleable.append(item)
	if smuggleable.is_empty():
		return
	var current_id: StringName = _selected_items[slot_index]
	var current_idx: int = -1
	for i in smuggleable.size():
		if smuggleable[i].item_id == current_id:
			current_idx = i
			break
	var next_idx   := (current_idx + 1) % smuggleable.size()
	var next_item: ItemDefinition = smuggleable[next_idx]
	_selected_items[slot_index] = next_item.item_id
	slot_btn.text = next_item.display_name
	EventBus.audio_play_sfx.emit("ui_click")


func _select_gender(g: String) -> void:
	_selected_gender = g
	for gender_id in _gender_buttons:
		var button: Button = _gender_buttons[gender_id]
		button.button_pressed = str(gender_id) == g


func _on_confirm_pressed() -> void:
	if _selection_step == 0:
		_advance_to_characters()
		return
	if _selected_class_id == &"":
		status_lbl.text = _ui_text("character.select_role_first", "Bitte zuerst einen Charakter wählen.")
		return

	confirm_btn.disabled = true
	status_lbl.text      = _ui_text("character.confirmed_wait", "Bestätigt — warte auf andere Spieler...")
	EventBus.audio_play_sfx.emit("ui_click")
	SaveManager.set_last_character(_selected_class_id)

	var items: Array[StringName] = []
	for iid in _selected_items:
		if iid != &"":
			items.append(iid)

	if _rpc_relay != null:
		_rpc_relay.request_select_character(_local_player_id, _selected_class_id, _selected_gender)
		_rpc_relay.request_confirm_loadout(_local_player_id, items)
	elif GameManager.active_match != null:
		GameManager.active_match.select_character(_local_player_id, _selected_class_id, _selected_gender)
		GameManager.active_match.confirm_loadout(_local_player_id, items)

func _faction_label(faction_id: StringName) -> String:
	match faction_id:
		&"mafia": return _ui_text("character.faction_mafia", "Mafia")
		&"military": return _ui_text("character.faction_military", "Militär")
		&"civilian": return _ui_text("character.faction_civilian", "Zivilisten")
		&"assassins": return _ui_text("character.faction_assassins", "Assassinen-Gilde")
		&"government": return _ui_text("character.faction_government", "Regierung")
		&"law_enforcement": return _ui_text("character.faction_law_enforcement", "Ermittler")
		&"elite": return _ui_text("character.faction_elite", "Casino-Elite")
		_: return _ui_text("character.faction_independent", "Unabhängig")
