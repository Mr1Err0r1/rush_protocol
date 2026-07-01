extends Control
class_name CharacterCustomizationUI

@onready var skin_opt:       OptionButton = $Panel/VBox/SkinRow/OptionButton
@onready var hair_opt:       OptionButton = $Panel/VBox/HairRow/OptionButton
@onready var hair_color_opt: OptionButton = $Panel/VBox/HairColorRow/OptionButton
@onready var confirm_btn:    Button       = $Panel/VBox/ConfirmBtn
@onready var back_btn:       Button       = $Panel/VBox/BackBtn

var current_data := {
	"skin": 0,
	"hair": 0,
	"hair_color": Color.BLACK
}

func _ready() -> void:
	_setup_options()
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(_on_back)
	var lm = get_node_or_null("/root/LocaleManager")
	if lm:
		lm.locale_changed.connect(_update_texts)
	_update_texts()

func _setup_options() -> void:
	skin_opt.clear()
	skin_opt.add_item("Hell", 0)
	skin_opt.add_item("Gebräunt", 1)
	skin_opt.add_item("Dunkel", 2)
	
	hair_opt.clear()
	hair_opt.add_item("Kurz", 0)
	hair_opt.add_item("Lang", 1)
	hair_opt.add_item("Glatze", 2)

func _on_confirm() -> void:
	current_data.skin = skin_opt.selected
	current_data.hair = hair_opt.selected
	# Hier würde man die Daten im SaveManager oder GameManager speichern
	SaveManager.set_setting("player_customization", current_data)
	EventBus.audio_play_sfx.emit("ui_confirm")
	hide()

func _on_back() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	hide()

func _update_texts(_l=null) -> void:
	var lm = get_node_or_null("/root/LocaleManager")
	if not lm: return
	$Panel/Title.text = lm.t("char.title")
	$Panel/VBox/SkinRow/Label.text = lm.t("char.skin")
	$Panel/VBox/HairRow/Label.text = lm.t("char.hair")
	confirm_btn.text = lm.t("char.confirm")
	back_btn.text = lm.t("settings.back")
