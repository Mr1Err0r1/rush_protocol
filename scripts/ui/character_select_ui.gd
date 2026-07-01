extends Control
class_name CharacterSelectUI
## CharacterSelectUI — Null Protocol
## Zeigt alle verfügbaren Charakterklassen, Geschlecht-Wahl und Loadout-Auswahl.
## Reagiert auf EventBus-Signale, sendet Auswahl über RpcRelay oder direkt.
##
## Solo-Modus: nur Mafia-Boss ist wählbar, alle anderen Klassen sind gesperrt.

const SOLO_ALLOWED_CLASS := &"mafia_boss"

@onready var class_list:      ItemList    = $HBox/Left/ClassList
@onready var class_name_lbl:  Label       = $HBox/Right/ClassName
@onready var class_lore_lbl:  RichTextLabel = $HBox/Right/LoreTxt
@onready var gender_m_btn:    Button      = $HBox/Right/GenderRow/MaleBtn
@onready var gender_f_btn:    Button      = $HBox/Right/GenderRow/FemaleBtn
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


func _ready() -> void:
	_local_player_id = NetworkManager.get_local_id()
	confirm_btn.pressed.connect(_on_confirm_pressed)
	gender_m_btn.pressed.connect(func(): _select_gender("m"))
	gender_f_btn.pressed.connect(func(): _select_gender("f"))
	class_list.item_selected.connect(_on_class_selected)
	_populate_class_list()


func set_rpc_relay(relay: Node) -> void:
	_rpc_relay = relay


func _is_solo() -> bool:
	return GameManager.game_mode == GameManager.GameMode.SOLO


func _populate_class_list() -> void:
	class_list.clear()
	var classes := _get_available_classes()
	var solo_locked := _is_solo()
	var preferred = SOLO_ALLOWED_CLASS if solo_locked else SaveManager.get_last_character()
	var preferred_index := 0

	for i in classes.size():
		var cc = classes[i]
		class_list.add_item(cc.display_name)
		class_list.set_item_metadata(class_list.item_count - 1, cc.class_id)

		if solo_locked and cc.class_id != SOLO_ALLOWED_CLASS:
			class_list.set_item_disabled(class_list.item_count - 1, true)
			class_list.set_item_tooltip(class_list.item_count - 1, "Im Solo-Modus gesperrt")

		if cc.class_id == preferred:
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
	_selected_class_id = class_list.get_item_metadata(index)
	var classes := _get_available_classes()
	for cc in classes:
		if cc.class_id == _selected_class_id:
			_show_class_info(cc)
			break


func _show_class_info(cc: CharacterClass) -> void:
	class_name_lbl.text = cc.display_name
	class_lore_lbl.text = cc.lore_text
	smuggle_label.text  = "Schmuggel-Slots: %d" % cc.smuggle_slots

	for child in stats_panel.get_children():
		child.queue_free()
	_add_stat_row("❤ Leben",      cc.start_health,    5)
	_add_stat_row("👁 Misstrauen", cc.start_suspicion, 10, true)
	_add_stat_row("🎩 Einfluss",  cc.start_influence,  5)
	_add_stat_row("💰 Chips",     cc.start_chips,     150)

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
		btn.text = "+ Item %d wählen" % (i + 1)
		btn.custom_minimum_size = Vector2(160, 60)
		var slot_index := i
		btn.pressed.connect(func(): _open_item_picker(slot_index, btn, cc))
		loadout_container.add_child(btn)
		_selected_items.append(&"")


func _open_item_picker(slot_index: int, slot_btn: Button, _cc: CharacterClass) -> void:
	var smuggleable := ItemDatabase.get_smuggleable_items()
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
	gender_m_btn.button_pressed = (g == "m")
	gender_f_btn.button_pressed = (g == "f")


func _on_confirm_pressed() -> void:
	if _selected_class_id == &"":
		status_lbl.text = "Bitte zuerst eine Klasse wählen!"
		return

	confirm_btn.disabled = true
	EventBus.audio_play_sfx.emit("ui_click")

	if not _is_solo():
		SaveManager.set_last_character(_selected_class_id)

	var items: Array[StringName] = []
	for iid in _selected_items:
		if iid != &"":
			items.append(iid)

	if _rpc_relay != null:
		status_lbl.text = "Bestätigt — warte auf andere Spieler..."
		_rpc_relay.request_select_character(_local_player_id, _selected_class_id, _selected_gender)
		_rpc_relay.request_confirm_loadout(_local_player_id, items)
	else:
		status_lbl.text = "Bestätigt — betrete den Casino-Boden..."
		if GameManager.active_match != null:
			GameManager.active_match.select_character(_local_player_id, _selected_class_id, _selected_gender)
			GameManager.active_match.confirm_loadout(_local_player_id, items)
