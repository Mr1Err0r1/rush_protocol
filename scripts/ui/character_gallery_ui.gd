extends Control
class_name CharacterGalleryUI

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
	_populate()

func _populate() -> void:
	_classes = _load_classes()
	class_list.clear()
	for i in _classes.size():
		var cc = _classes[i]
		class_list.add_item(cc.display_name)
		class_list.set_item_metadata(i, cc.class_id)
	
	if class_list.item_count > 0:
		class_list.select(0)
		_on_class_selected(0)

func _load_classes() -> Array:
	var result: Array = []
	var path := "res://resources/characters/"
	var dir := DirAccess.open(path)
	if dir == null: return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = load(path + fname)
			if res != null: # Wir prüfen nicht auf 'is CharacterClass', falls das Skript-Laden noch hakt
				result.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	return result

func _on_class_selected(index: int) -> void:
	var cc = _classes[index]
	_selected_id = cc.class_id
	name_lbl.text = cc.display_name
	lore_lbl.text = cc.lore_text

func _on_pick_pressed() -> void:
	if _selected_id != &"":
		SaveManager.set_last_character(_selected_id)
		hide()

func _on_back_pressed() -> void:
	hide()