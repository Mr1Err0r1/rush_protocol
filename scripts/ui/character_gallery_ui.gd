extends Control
class_name CharacterGalleryUI
## CharacterGalleryUI — Null Protocol
## Eigene "Seite" im Hauptmenü zum Durchstöbern aller freigeschalteten
## Charakterklassen. Wählt der Spieler einen aus, wird er als
## "Lieblingscharakter" gespeichert (SaveManager.set_last_character) und
## in der echten Charakterauswahl beim Match-Start automatisch vorausgewählt.

@onready var class_list:     ItemList      = $Panel/VBox/HBox/ClassList
@onready var name_lbl:       Label         = $Panel/VBox/HBox/Details/NameLbl
@onready var lore_lbl:       RichTextLabel = $Panel/VBox/HBox/Details/LoreLbl
@onready var stats_panel:    GridContainer = $Panel/VBox/HBox/Details/Stats
@onready var pick_btn:       Button        = $Panel/VBox/Buttons/PickBtn
@onready var back_btn:       Button        = $Panel/VBox/Buttons/BackBtn
@onready var title_lbl:      Label         = $Panel/VBox/TitleLbl

var _classes: Array = []
var _selected_id: StringName = &""


func _ready() -> void:
	class_list.item_selected.connect(_on_class_selected)
	pick_btn.pressed.connect(_on_pick_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	var lm := _lm()
	if lm:
		lm.locale_changed.connect(func(_l): _update_texts())
	_update_texts()
	_populate()


func _lm() -> Node:
	return get_node_or_null("/root/LocaleManager")


func _update_texts() -> void:
	var lm := _lm()
	if not lm:
		return
	title_lbl.text = lm.t("gallery.title")
	pick_btn.text  = lm.t("gallery.pick")
	back_btn.text  = lm.t("gallery.back")


func _populate() -> void:
	_classes = _load_classes()
	class_list.clear()
	var preferred := SaveManager.get_last_character()
	var preferred_index := 0
	for i in _classes.size():
		var cc = _classes[i]
		class_list.add_item(cc.display_name)
		class_list.set_item_metadata(class_list.item_count - 1, cc.class_id)
		if cc.class_id == preferred:
			preferred_index = i

	if class_list.item_count > 0:
		class_list.select(preferred_index)
		_on_class_selected(preferred_index)


func _load_classes() -> Array:
	var result: Array = []
	var path := "res://resources/characters/"
	var dir  := DirAccess.open(path)
	if dir == null:
		return result
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
	return result


func _on_class_selected(index: int) -> void:
	if index < 0 or index >= _classes.size():
		return
	var cc = _classes[index]
	_selected_id = cc.class_id
	_show_info(cc)


func _show_info(cc: CharacterClass) -> void:
	name_lbl.text = cc.display_name
	lore_lbl.text = cc.lore_text

	for child in stats_panel.get_children():
		child.queue_free()
	_add_stat_row("❤ Leben",      cc.start_health,    5)
	_add_stat_row("👁 Misstrauen", cc.start_suspicion, 10)
	_add_stat_row("🎩 Einfluss",  cc.start_influence,  5)
	_add_stat_row("💰 Chips",     cc.start_chips,     150)
	_add_stat_row("🎒 Schmuggel-Slots", cc.smuggle_slots, 4)


func _add_stat_row(label_text: String, value: int, max_val: int) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	stats_panel.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_val
	bar.value     = value
	bar.custom_minimum_size = Vector2(140, 16)
	stats_panel.add_child(bar)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	stats_panel.add_child(val_lbl)


func _on_pick_pressed() -> void:
	if _selected_id == &"":
		return
	SaveManager.set_last_character(_selected_id)
	EventBus.audio_play_sfx.emit("ui_click")
	var lm := _lm()
	var msg: String = lm.t("gallery.picked", [name_lbl.text]) if lm else "Favorit: %s" % name_lbl.text
	EventBus.ui_toast.emit(msg, "win", 2.0)


func _on_back_pressed() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	hide()
