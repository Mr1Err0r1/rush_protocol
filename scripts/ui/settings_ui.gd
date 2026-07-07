extends Control
class_name SettingsUI

const KeyBindingsPanel = preload("res://scripts/ui/key_bindings_panel.gd")
var _bindings_overlay: Control = null
var _kbp: KeyBindingsPanel = null
## SettingsUI — Null Protocol
## Einstellungs-Panel: Sprache, Monitor, Vollbild, Auflösung,
## V-Sync, Soundlautstärke, Musik, Maus-Sensitivität.
## Wird als Kind von MainMenu direkt ein-/ausgeblendet (show/hide).

@onready var language_opt:    OptionButton = $Panel/VBox/LanguageRow/OptionButton
@onready var monitor_opt:     OptionButton = $Panel/VBox/MonitorRow/OptionButton
@onready var resolution_opt:  OptionButton = $Panel/VBox/ResolutionRow/OptionButton
@onready var fullscreen_chk:  CheckBox     = $Panel/VBox/FullscreenRow/CheckBox
@onready var vsync_chk:       CheckBox     = $Panel/VBox/VsyncRow/CheckBox
@onready var sfx_slider:      HSlider      = $Panel/VBox/SfxRow/HSlider
@onready var music_slider:    HSlider      = $Panel/VBox/MusicRow/HSlider
@onready var sens_slider:     HSlider      = $Panel/VBox/SensRow/HSlider
@onready var apply_btn:       Button       = $Panel/VBox/Buttons/ApplyBtn
@onready var back_btn:        Button       = $Panel/VBox/Buttons/BackBtn

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]


func _ready() -> void:
	_setup_dropdowns()
	_load_settings()
	apply_btn.pressed.connect(_on_apply)
	back_btn.pressed.connect(_on_back)

	var lm := _lm()
	if lm:
		lm.locale_changed.connect(_update_texts)
	_update_texts()

	# Live-Vorschau für Lautstärke
	sfx_slider.value_changed.connect(func(v): AudioManager.set_sfx_volume(linear_to_db(v)))
	music_slider.value_changed.connect(func(v): AudioManager.set_music_volume(linear_to_db(v)))

	_inject_bindings_ui()


func _setup_dropdowns() -> void:
	# Sprachen
	var lm := _lm()
	language_opt.clear()
	if lm:
		for loc: String in lm.SUPPORTED_LOCALES:
			language_opt.add_item(lm.LOCALE_NAMES[loc])
	else:
		language_opt.add_item("Deutsch")
		language_opt.add_item("English")
		language_opt.add_item("Русский")

	# Monitore
	monitor_opt.clear()
	var screen_count: int = DisplayServer.get_screen_count()
	for i in screen_count:
		var screen_sz: Vector2i = DisplayServer.screen_get_size(i)
		monitor_opt.add_item("Monitor %d  (%dx%d)" % [i + 1, screen_sz.x, screen_sz.y], i)

	# Auflösungen
	resolution_opt.clear()
	for res in RESOLUTIONS:
		resolution_opt.add_item("%d × %d" % [res.x, res.y])


func _load_settings() -> void:
	# Sprache
	var lm := _lm()
	if lm:
		var idx: int = lm.SUPPORTED_LOCALES.find(lm.current_locale)
		language_opt.select(idx if idx != -1 else 0)

	# Monitor
	monitor_opt.select(DisplayServer.window_get_current_screen())

	# Auflösung — aktuelle Fenster-Größe suchen
	var cur_size: Vector2i = DisplayServer.window_get_size()
	var res_idx := 2   # Default 1920×1080
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == cur_size:
			res_idx = i
			break
	resolution_opt.select(res_idx)

	# Vollbild
	var mode: int = DisplayServer.window_get_mode()
	fullscreen_chk.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or
									mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# V-Sync
	vsync_chk.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)

	# Lautstärken (0.0–1.0 auf Slider)
	sfx_slider.value   = db_to_linear(SaveManager.get_setting("sfx_volume",   0.0))
	music_slider.value = db_to_linear(SaveManager.get_setting("music_volume", -6.0))

	# Sensitivität
	sens_slider.value = SaveManager.get_setting("mouse_sensitivity", 1.0)


func _on_apply() -> void:
	var lm := _lm()

	# Sprache
	if lm:
		var loc: String = lm.SUPPORTED_LOCALES[language_opt.selected]
		lm.set_locale(loc)

	# Monitor
	var screen: int = monitor_opt.get_selected_id()
	DisplayServer.window_set_current_screen(screen)

	# Auflösung (nur im Fenster-Modus)
	if not fullscreen_chk.button_pressed:
		var res: Vector2i = RESOLUTIONS[resolution_opt.selected]
		DisplayServer.window_set_size(res)
		# Fenster zentrieren auf dem gewählten Monitor
		var screen_pos:  Vector2i = DisplayServer.screen_get_position(screen)
		var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
		var diff  := screen_size - res
		var half := Vector2i(diff.x >> 1, diff.y >> 1)
		var center := screen_pos + half
		DisplayServer.window_set_position(center)

	# Vollbild
	if fullscreen_chk.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# V-Sync
	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync_chk.button_pressed else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	# Lautstärken speichern
	var sfx_db:   float = linear_to_db(sfx_slider.value)
	var music_db: float = linear_to_db(music_slider.value)
	AudioManager.set_sfx_volume(sfx_db)
	AudioManager.set_music_volume(music_db)
	SaveManager.set_setting("sfx_volume",   sfx_db)
	SaveManager.set_setting("music_volume", music_db)

	# Sensitivität
	SaveManager.set_setting("mouse_sensitivity", sens_slider.value)

	# Vollbild / VSync persisitieren
	SaveManager.set_setting("fullscreen", fullscreen_chk.button_pressed)
	SaveManager.set_setting("vsync",      vsync_chk.button_pressed)

	EventBus.audio_play_sfx.emit("ui_click")
	var toast_text: String = lm.t("settings.apply") if lm else "Gespeichert"
	EventBus.ui_toast.emit(toast_text, "win", 1.5)


func _on_back() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	hide()


func _update_texts(_l = null) -> void:
	var lm := _lm()
	if not lm:
		return

	var title := get_node_or_null("Panel/Title")
	if title and title is Label:
		title.text = lm.t("settings.title")

	var lang_label := get_node_or_null("Panel/VBox/LanguageRow/Label")
	if lang_label:
		lang_label.text = lm.t("settings.language")

	var monitor_label := get_node_or_null("Panel/VBox/MonitorRow/Label")
	if monitor_label:
		monitor_label.text = lm.t("settings.monitor")

	var resolution_label := get_node_or_null("Panel/VBox/ResolutionRow/Label")
	if resolution_label:
		resolution_label.text = lm.t("settings.resolution")

	var fullscreen_label := get_node_or_null("Panel/VBox/FullscreenRow/Label")
	if fullscreen_label:
		fullscreen_label.text = lm.t("settings.fullscreen")

	var vsync_label := get_node_or_null("Panel/VBox/VsyncRow/Label")
	if vsync_label:
		vsync_label.text = lm.t("settings.vsync")

	var sfx_label := get_node_or_null("Panel/VBox/SfxRow/Label")
	if sfx_label:
		sfx_label.text = lm.t("settings.sfx_vol")

	var music_label := get_node_or_null("Panel/VBox/MusicRow/Label")
	if music_label:
		music_label.text = lm.t("settings.music_vol")

	var sens_label := get_node_or_null("Panel/VBox/SensRow/Label")
	if sens_label:
		sens_label.text = lm.t("settings.sens")

	apply_btn.text = lm.t("settings.apply")
	back_btn.text = lm.t("settings.back")


func _lm() -> Node:
	return get_node_or_null("/root/LocaleManager")

# ── Tastenbelegung ────────────────────────────────────────────────────────────

func _inject_bindings_ui() -> void:
	var btn := Button.new()
	btn.text = "⌨  Steuerung  /  Tastenbelegung"
	btn.pressed.connect(_show_bindings_overlay)
	var buttons_box := get_node_or_null("Panel/VBox/Buttons")
	if buttons_box:
		buttons_box.add_child(btn)
		buttons_box.move_child(btn, 0)
	else:
		var vbox := get_node_or_null("Panel/VBox")
		if vbox:
			vbox.add_child(btn)
			vbox.move_child(btn, maxi(0, vbox.get_child_count() - 1))
	_build_bindings_overlay()


func _build_bindings_overlay() -> void:
	const C_PANEL      := Color(0.10, 0.08, 0.13, 0.98)
	const C_PANEL_BORD := Color(0.62, 0.46, 0.10, 1.0)
	const C_TITLE      := Color(0.96, 0.82, 0.22, 1.0)
	const C_TEXT       := Color(0.92, 0.88, 0.84, 1.0)
	const C_TEXT_DIM   := Color(0.56, 0.50, 0.44, 1.0)

	_bindings_overlay = Control.new()
	_bindings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bindings_overlay.visible = false
	_bindings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bindings_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	_bindings_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_bindings_overlay.add_child(center)

	var sty := StyleBoxFlat.new()
	sty.bg_color = C_PANEL
	sty.border_color = C_PANEL_BORD
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(8)
	sty.content_margin_left = 32; sty.content_margin_right = 32
	sty.content_margin_top  = 24; sty.content_margin_bottom = 24

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(560, 0)
	outer.add_theme_stylebox_override("panel", sty)
	center.add_child(outer)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	outer.add_child(v)

	var hdr := Label.new()
	hdr.text = "STEUERUNG  /  TASTENBELEGUNG"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", C_TITLE)
	v.add_child(hdr)

	var hint := Label.new()
	hint.text = "Klicke eine Taste zum Ändern  •  ESC = Schließen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", C_TEXT_DIM)
	v.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_kbp = KeyBindingsPanel.new()
	_kbp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_kbp)

	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.20, 0.16, 0.28, 1.0)
	cs.border_color = C_PANEL_BORD
	cs.set_border_width_all(1); cs.set_corner_radius_all(5)
	cs.content_margin_left = 14; cs.content_margin_right = 14
	cs.content_margin_top = 8;   cs.content_margin_bottom = 8

	var close_btn := Button.new()
	close_btn.text = "✕  Schließen"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_color_override("font_color", C_TEXT)
	close_btn.pressed.connect(_hide_bindings_overlay)
	v.add_child(close_btn)


func _show_bindings_overlay() -> void:
	if _kbp:
		_kbp.refresh()
	_bindings_overlay.visible = true


func _hide_bindings_overlay() -> void:
	_bindings_overlay.visible = false


func _input(event: InputEvent) -> void:
	if _bindings_overlay == null or not _bindings_overlay.visible:
		return
	if event is InputEventKey and event.pressed:
		var kc: Key = (
			event.keycode
			if event.physical_keycode == 0
			else event.physical_keycode
		)
		if kc == KEY_ESCAPE and (_kbp == null or not _kbp.is_rebinding()):
			_hide_bindings_overlay()
			get_viewport().set_input_as_handled()
