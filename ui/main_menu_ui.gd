extends Control
class_name MainMenuUI
## MainMenuUI — Null Protocol
## Referenziert exakt die Node-Pfade aus main_menu.tscn.

@onready var name_input:     LineEdit     = $CenterBox/PlayerNameInput
@onready var difficulty_opt: OptionButton = $CenterBox/DifficultyRow/DifficultyOption
@onready var start_solo_btn: Button       = $CenterBox/StartSoloBtn
@onready var multiplayer_btn:Button       = $CenterBox/MultiplayerBtn
@onready var characters_btn: Button       = $CenterBox/CharactersBtn
@onready var settings_btn:   Button       = $CenterBox/SettingsBtn
@onready var quit_btn:       Button       = $CenterBox/QuitBtn
@onready var settings_ui:    Control      = $SettingsUI
@onready var character_gallery: Control   = $CharacterGallery

# Eigene "Seite" des Hauptmenüs — wird ausgeblendet, sobald eine Unterseite
# (Einstellungen / Charaktere) geöffnet ist, damit es wie ein sauberer
# Folienwechsel wirkt statt wie ein durchscheinendes Overlay.
@onready var _own_page_nodes: Array[CanvasItem] = [$Title, $Subtitle, $CenterBox, $VersionLabel]
@onready var _overlay_pages:  Array[Control]     = [settings_ui, character_gallery]


func _ready() -> void:
	var lm := _lm()
	if lm:
		lm.locale_changed.connect(func(_l): _update_texts())
	_update_texts()

	# Namen laden
	var saved_name: String = SaveManager.get_setting("last_player_name", "")
	if saved_name != "":
		name_input.text = saved_name

	start_solo_btn.pressed.connect(_on_start_solo)
	multiplayer_btn.pressed.connect(_on_multiplayer)
	characters_btn.pressed.connect(_on_characters)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	# Sauberer Seitenwechsel: sobald eine Unterseite sich zeigt/versteckt,
	# blenden wir unsere eigene Seite entsprechend gegenteilig.
	for page in _overlay_pages:
		page.visibility_changed.connect(_on_overlay_visibility_changed)

	# Hover-Animationen
	var vfx := _vfx()
	if vfx:
		for btn: Button in [start_solo_btn, multiplayer_btn, characters_btn, settings_btn, quit_btn]:
			btn.mouse_entered.connect(func(): vfx.ui_wobble(btn))

	EventBus.audio_play_music.emit("menu")


func _on_overlay_visibility_changed() -> void:
	var any_open := false
	for page in _overlay_pages:
		if page.visible:
			any_open = true
			break
	for n in _own_page_nodes:
		n.visible = not any_open


## Öffnet eine Unterseite und schließt dabei alle anderen — es ist immer
## nur eine "Folie" gleichzeitig sichtbar.
func _open_page(page: Control) -> void:
	for p in _overlay_pages:
		if p != page:
			p.hide()
	page.show()


func _update_texts() -> void:
	var lm := _lm()
	if not lm:
		return
	$Title.text                                      = lm.t("menu.title")
	$Subtitle.text                                   = lm.t("menu.subtitle")
	$VersionLabel.text                               = lm.t("menu.version")
	name_input.placeholder_text                      = lm.t("menu.name_hint")
	$CenterBox/DifficultyRow/Label.text              = lm.t("menu.difficulty")
	start_solo_btn.text                              = lm.t("menu.start_solo")
	multiplayer_btn.text                             = lm.t("menu.multiplayer")
	characters_btn.text                              = lm.t("menu.characters")
	settings_btn.text                                = lm.t("menu.settings")
	quit_btn.text                                    = lm.t("menu.quit")

	difficulty_opt.clear()
	difficulty_opt.add_item(lm.t("menu.diff_easy"),   0)
	difficulty_opt.add_item(lm.t("menu.diff_normal"), 1)
	difficulty_opt.add_item(lm.t("menu.diff_hard"),   2)
	difficulty_opt.select(SaveManager.get_setting("last_difficulty", 1))


func _on_start_solo() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Spieler"
	SaveManager.set_setting("last_player_name", player_name)
	SaveManager.set_setting("last_difficulty", difficulty_opt.get_selected_id())
	EventBus.audio_play_sfx.emit("ui_click")
	GameManager.start_solo(player_name, difficulty_opt.get_selected_id())


func _on_multiplayer() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	GameManager.go_to_lobby()


func _on_characters() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	_open_page(character_gallery)


func _on_settings() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	_open_page(settings_ui)


func _on_quit() -> void:
	get_tree().quit()


func _lm() -> Node:
	return get_node_or_null("/root/LocaleManager")

func _vfx() -> Node:
	return get_node_or_null("/root/VisualFX")
