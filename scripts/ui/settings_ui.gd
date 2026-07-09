extends Control
class_name SettingsUI

## SettingsUI — Null Protocol
## Einstellungs-Panel: Sprache, Monitor, Fenstermodus, Auflösung, V-Sync,
## Master-/SFX-/Musik-Lautstärke, Maus-Sensitivität, Helligkeit, UI-Skalierung,
## Farbfilter (Farbenblindheit), Untertitel, Reduzierte Bewegung, Tastenbelegung.
##
## Wird als Kind von MainMenu direkt ein-/ausgeblendet (show/hide).
##
## HINWEIS: Alle neuen Steuerelemente (Master-Lautstärke, Fenstermodus,
## Helligkeit, UI-Skalierung, Farbfilter, Untertitel, Reduzierte Bewegung,
## Reset-Buttons) werden zur Laufzeit per Code erzeugt und in die bestehende
## VBox eingefügt — es sind KEINE Änderungen an der .tscn nötig. Wer sie
## lieber im Editor layouten möchte, kann den Erzeugungs-Code einfach durch
## @onready-Referenzen auf echte Szenen-Nodes ersetzen.
##
## Neue Übersetzungsschlüssel, die in LocaleManager ergänzt werden sollten:
## settings.saved, settings.master_vol, settings.window_mode, settings.brightness,
## settings.ui_scale, settings.colorblind, settings.subtitles, settings.reduce_motion,
## settings.unsaved_indicator, settings.unsaved_title, settings.unsaved_body,
## settings.reset, settings.reset_title, settings.reset_body,
## settings.reset_bindings_body, settings.controls, settings.controls_title,
## settings.controls_hint, settings.close
## Bis dahin greifen überall deutsche Fallback-Texte (siehe _t()).

signal settings_applied
signal settings_reset

# HINWEIS: Ursprünglich stand hier `preload("res://scenes/ui/key_bindings_panel.tscn")`.
# preload() wird zur PARSE-Zeit aufgelöst — existiert die Datei nicht, bricht
# das gesamte Script schon beim Laden ab (das war der gemeldete Fehler).
# Da es in diesem Projekt keine solche .tscn gibt, wird KeyBindingsPanel direkt
# als Skript instanziert. Falls später doch eine Szene dafür angelegt wird,
# übernimmt _create_kbp() sie automatisch (per Laufzeit-load(), kein preload()).
const KEY_BINDINGS_SCENE_PATH := "res://scenes/ui/key_bindings_panel.tscn"

# ── Default-Werte (einzige Quelle der Wahrheit für "Zurücksetzen") ──────────
const DEFAULT_SFX_DB          := 0.0
const DEFAULT_MUSIC_DB         := -6.0
const DEFAULT_MASTER_DB        := 0.0
const DEFAULT_SENSITIVITY      := 1.0
const DEFAULT_BRIGHTNESS       := 1.0
const DEFAULT_UI_SCALE         := 1.0
const DEFAULT_WINDOW_MODE      := 0   # 0=Fenster 1=randlos 2=Vollbild
const DEFAULT_VSYNC            := true
const DEFAULT_COLORBLIND_MODE  := 0   # 0=Aus 1=Protanopie 2=Deuteranopie 3=Tritanopie

const RESOLUTIONS_BASE: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# Vereinfachter Korrektur-Filter für Farbfehlsichtigkeit.
# HINWEIS: Zugriff auf die Bildschirm-Textur kann sich je nach Godot-Version
# leicht unterscheiden (hint_screen_texture). Dies ist ein Ausgangspunkt,
# kein wissenschaftlich validierter Daltonize-Algorithmus — für ein
# Shipping-Game würde ich einen geprüften Filter empfehlen.
const COLORBLIND_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform int mode : hint_range(0, 3) = 0;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (mode == 1) {
		// Protanopie: Rot-Anteil stärker über Grün/Blau abbilden
		c = vec3(c.r * 0.3 + c.g * 0.7, c.g, c.b + c.r * 0.15);
	} else if (mode == 2) {
		// Deuteranopie: Grün-Anteil von Rot/Blau abheben
		c = vec3(c.r, c.g * 0.4 + c.r * 0.3, c.b + c.g * 0.2);
	} else if (mode == 3) {
		// Tritanopie: Blau/Gelb-Kontrast anheben
		c = vec3(c.r + c.b * 0.15, c.g, c.b * 0.5 + c.g * 0.3);
	}
	COLOR = vec4(c, 1.0);
}
"""

@onready var vbox:            VBoxContainer = $Panel/VBox
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

# ── Dynamisch erzeugte Steuerelemente ───────────────────────────────────────
var master_slider: HSlider
var master_value_lbl: Label
var sfx_value_lbl: Label
var music_value_lbl: Label
var window_mode_opt: OptionButton
var brightness_slider: HSlider
var brightness_value_lbl: Label
var ui_scale_slider: HSlider
var ui_scale_value_lbl: Label
var colorblind_opt: OptionButton
var subtitles_chk: CheckBox
var reduce_motion_chk: CheckBox
var reset_btn: Button
var dirty_lbl: Label
var _extra_rows: Array[HBoxContainer] = []

var _kbp_button: Button
var _overlay_header_lbl: Label
var _overlay_hint_lbl: Label
var _overlay_reset_btn: Button
var _overlay_close_btn: Button

var _resolutions: Array[Vector2i] = []
var _native_resolution: Vector2i
var _dirty := false
var _restoring := false
var _snapshot: Dictionary = {}

var _bindings_overlay: Control = null
var _kbp: KeyBindingsPanel = null

var _confirm_dialog: ConfirmationDialog = null
var _pending_confirm: Callable = Callable()

var _colorblind_layer: CanvasLayer = null
var _colorblind_rect: ColorRect = null


# ─────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_resolution_list()
	_setup_dropdowns()
	_inject_extra_options()
	_load_settings()
	_connect_live_preview()

	apply_btn.pressed.connect(_on_apply)
	back_btn.pressed.connect(_on_back)

	var lm := _lm()
	if lm:
		lm.locale_changed.connect(_update_texts)
	_update_texts()

	_build_confirm_dialog()
	_inject_bindings_ui()

	_snapshot = _snapshot_settings()
	_set_dirty(false)


func _exit_tree() -> void:
	var lm := _lm()
	if lm and lm.locale_changed.is_connected(_update_texts):
		lm.locale_changed.disconnect(_update_texts)
	# Der Farbfilter hängt am Tree-Root (bewusst, damit er auch bei
	# geschlossenem Menü aktiv bleibt) und muss daher manuell aufgeräumt werden.
	if _colorblind_layer and is_instance_valid(_colorblind_layer):
		_colorblind_layer.queue_free()


# ─────────────────────────────────────────────────────────────────────────
# Auflösungen / Dropdowns
# ─────────────────────────────────────────────────────────────────────────

func _build_resolution_list() -> void:
	_resolutions = RESOLUTIONS_BASE.duplicate()
	var screen: int = DisplayServer.window_get_current_screen()
	_native_resolution = DisplayServer.screen_get_size(screen)
	if _native_resolution.x > 0 and _native_resolution.y > 0 and not _resolutions.has(_native_resolution):
		_resolutions.append(_native_resolution)
	_resolutions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)


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

	# Monitore (mit Absicherung gegen 0 erkannte Bildschirme)
	monitor_opt.clear()
	var screen_count: int = maxi(DisplayServer.get_screen_count(), 1)
	for i in screen_count:
		var screen_sz: Vector2i = DisplayServer.screen_get_size(i)
		monitor_opt.add_item("Monitor %d  (%dx%d)" % [i + 1, screen_sz.x, screen_sz.y], i)

	# Auflösungen (inkl. erkannter nativer Auflösung)
	resolution_opt.clear()
	for res in _resolutions:
		var suffix := "  (nativ)" if res == _native_resolution else ""
		resolution_opt.add_item("%d × %d%s" % [res.x, res.y, suffix])


# ─────────────────────────────────────────────────────────────────────────
# Dynamische Erweiterungen (Master-Vol, Fenstermodus, Helligkeit, UI-Skalierung,
# Farbfilter, Untertitel, Reduzierte Bewegung, Reset-Button, "ungespeichert")
# ─────────────────────────────────────────────────────────────────────────

func _make_row(fallback_text: String, i18n_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = fallback_text
	lbl.custom_minimum_size = Vector2(170, 0)
	row.add_child(lbl)
	row.set_meta("i18n_key", i18n_key)
	row.set_meta("fallback", fallback_text)
	return row


func _make_value_label() -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(48, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return lbl


func _inject_extra_options() -> void:
	var buttons_box: Node = vbox.get_node_or_null("Buttons")

	# Alte Fullscreen-Checkbox ausblenden — ersetzt durch Fenstermodus-Dropdown.
	# (Variable/Node bleibt erhalten, damit vorhandene @onready-Referenzen
	# nicht auf null zeigen; sie wird nur nicht mehr angezeigt.)
	var fs_row := fullscreen_chk.get_parent()
	if fs_row and fs_row is Control:
		(fs_row as Control).visible = false

	# Wertelabels für die bereits vorhandenen Sfx-/Musik-Regler
	sfx_value_lbl = _make_value_label()
	sfx_slider.get_parent().add_child(sfx_value_lbl)
	music_value_lbl = _make_value_label()
	music_slider.get_parent().add_child(music_value_lbl)

	# --- Gesamtlautstärke (vor Sfx einfügen) ---
	var master_row := _make_row("Gesamtlautstärke", "settings.master_vol")
	master_slider = HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_row.add_child(master_slider)
	master_value_lbl = _make_value_label()
	master_row.add_child(master_value_lbl)
	vbox.add_child(master_row)
	vbox.move_child(master_row, sfx_slider.get_parent().get_index())

	# --- Fenstermodus (nach Auflösung einfügen) ---
	var wm_row := _make_row("Fenstermodus", "settings.window_mode")
	window_mode_opt = OptionButton.new()
	window_mode_opt.add_item("Fenster")
	window_mode_opt.add_item("Fenster (randlos)")
	window_mode_opt.add_item("Vollbild")
	window_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wm_row.add_child(window_mode_opt)
	vbox.add_child(wm_row)
	vbox.move_child(wm_row, resolution_opt.get_parent().get_index() + 1)

	# --- Helligkeit ---
	var bright_row := _make_row("Helligkeit", "settings.brightness")
	brightness_slider = HSlider.new()
	brightness_slider.min_value = 0.5
	brightness_slider.max_value = 1.5
	brightness_slider.step = 0.01
	brightness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bright_row.add_child(brightness_slider)
	brightness_value_lbl = _make_value_label()
	bright_row.add_child(brightness_value_lbl)
	vbox.add_child(bright_row)
	vbox.move_child(bright_row, wm_row.get_index() + 1)

	# --- UI-Skalierung ---
	var scale_row := _make_row("UI-Skalierung", "settings.ui_scale")
	ui_scale_slider = HSlider.new()
	ui_scale_slider.min_value = 0.75
	ui_scale_slider.max_value = 1.5
	ui_scale_slider.step = 0.05
	ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(ui_scale_slider)
	ui_scale_value_lbl = _make_value_label()
	scale_row.add_child(ui_scale_value_lbl)
	vbox.add_child(scale_row)
	vbox.move_child(scale_row, bright_row.get_index() + 1)

	# --- Farbfilter (Farbenblindheit) ---
	var cb_row := _make_row("Farbfilter", "settings.colorblind")
	colorblind_opt = OptionButton.new()
	for label in ["Aus", "Protanopie", "Deuteranopie", "Tritanopie"]:
		colorblind_opt.add_item(label)
	colorblind_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_child(colorblind_opt)
	vbox.add_child(cb_row)
	vbox.move_child(cb_row, scale_row.get_index() + 1)

	# --- Untertitel ---
	var sub_row := _make_row("Untertitel", "settings.subtitles")
	subtitles_chk = CheckBox.new()
	sub_row.add_child(subtitles_chk)
	vbox.add_child(sub_row)
	vbox.move_child(sub_row, cb_row.get_index() + 1)

	# --- Reduzierte Bewegung ---
	var rm_row := _make_row("Reduzierte Bewegung", "settings.reduce_motion")
	reduce_motion_chk = CheckBox.new()
	rm_row.add_child(reduce_motion_chk)
	vbox.add_child(rm_row)
	vbox.move_child(rm_row, sub_row.get_index() + 1)

	# --- "Ungespeicherte Änderungen"-Hinweis ---
	dirty_lbl = Label.new()
	dirty_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
	dirty_lbl.visible = false
	vbox.add_child(dirty_lbl)
	vbox.move_child(dirty_lbl, rm_row.get_index() + 1)

	_extra_rows = [master_row, wm_row, bright_row, scale_row, cb_row, sub_row, rm_row]

	# --- Reset-Button in die Buttons-Zeile ---
	if buttons_box:
		reset_btn = Button.new()
		reset_btn.pressed.connect(_on_reset_defaults)
		buttons_box.add_child(reset_btn)
		buttons_box.move_child(reset_btn, 0)


func _connect_live_preview() -> void:
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	master_slider.value_changed.connect(_on_master_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	colorblind_opt.item_selected.connect(_on_colorblind_changed)

	# Generisches Dirty-Tracking für alle übrigen (nicht live-vorschaubaren) Controls
	for c in [language_opt, monitor_opt, resolution_opt, window_mode_opt,
			vsync_chk, subtitles_chk, reduce_motion_chk]:
		_connect_dirty_signal(c)
	sens_slider.value_changed.connect(func(_v): _set_dirty(true))


func _connect_dirty_signal(c: Control) -> void:
	if c is OptionButton:
		(c as OptionButton).item_selected.connect(func(_i): _set_dirty(true))
	elif c is CheckBox:
		(c as CheckBox).toggled.connect(func(_b): _set_dirty(true))


# ─────────────────────────────────────────────────────────────────────────
# Laden / Anwenden
# ─────────────────────────────────────────────────────────────────────────

func _load_settings() -> void:
	# Sprache
	var lm := _lm()
	if lm:
		var idx: int = lm.SUPPORTED_LOCALES.find(lm.current_locale)
		language_opt.select(idx if idx != -1 else 0)

	# Monitor
	monitor_opt.select(clampi(DisplayServer.window_get_current_screen(), 0, monitor_opt.item_count - 1))

	# Auflösung — aktuelle Fenstergröße suchen, sonst native Auflösung
	var cur_size: Vector2i = DisplayServer.window_get_size()
	var res_idx := _resolutions.find(cur_size)
	if res_idx == -1:
		res_idx = _resolutions.find(_native_resolution)
	if res_idx == -1:
		res_idx = 0
	resolution_opt.select(res_idx)

	# Fenstermodus (Fenster / randlos / Vollbild)
	var mode: int = DisplayServer.window_get_mode()
	var borderless: bool = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		window_mode_opt.select(2)
	elif borderless:
		window_mode_opt.select(1)
	else:
		window_mode_opt.select(0)
	fullscreen_chk.button_pressed = (window_mode_opt.selected == 2)

	# V-Sync
	vsync_chk.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)

	# Lautstärken (0.0–1.0 auf Slider)
	sfx_slider.value    = db_to_linear(SaveManager.get_setting("sfx_volume",   DEFAULT_SFX_DB))
	music_slider.value  = db_to_linear(SaveManager.get_setting("music_volume", DEFAULT_MUSIC_DB))
	master_slider.value = db_to_linear(SaveManager.get_setting("master_volume", DEFAULT_MASTER_DB))

	# Sensitivität
	sens_slider.value = SaveManager.get_setting("mouse_sensitivity", DEFAULT_SENSITIVITY)

	# Neue Einstellungen
	brightness_slider.value = SaveManager.get_setting("brightness", DEFAULT_BRIGHTNESS)
	ui_scale_slider.value   = SaveManager.get_setting("ui_scale", DEFAULT_UI_SCALE)
	colorblind_opt.select(SaveManager.get_setting("colorblind_mode", DEFAULT_COLORBLIND_MODE))
	subtitles_chk.button_pressed      = SaveManager.get_setting("subtitles_enabled", true)
	reduce_motion_chk.button_pressed  = SaveManager.get_setting("reduce_motion", false)

	_refresh_value_labels()

	# Anfangszustand direkt anwenden, damit Vorschau schon beim Öffnen stimmt
	_apply_master_volume(master_slider.value)
	_apply_brightness(brightness_slider.value)
	_apply_colorblind_filter()
	var w := get_window()
	if w:
		w.content_scale_factor = ui_scale_slider.value


func _refresh_value_labels() -> void:
	sfx_value_lbl.text        = "%d%%" % int(round(sfx_slider.value * 100.0))
	music_value_lbl.text      = "%d%%" % int(round(music_slider.value * 100.0))
	master_value_lbl.text     = "%d%%" % int(round(master_slider.value * 100.0))
	brightness_value_lbl.text = "%d%%" % int(round(brightness_slider.value * 100.0))
	ui_scale_value_lbl.text   = "%d%%" % int(round(ui_scale_slider.value * 100.0))


func _on_apply() -> void:
	var lm := _lm()

	# Sprache
	if lm:
		var loc: String = lm.SUPPORTED_LOCALES[language_opt.selected]
		lm.set_locale(loc)

	# Monitor
	var screen: int = monitor_opt.get_selected_id()
	DisplayServer.window_set_current_screen(screen)

	# Fenstermodus
	var target_mode: int = window_mode_opt.selected
	match target_mode:
		0:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Auflösung (nur außerhalb von exklusivem Vollbild)
	if target_mode != 2:
		var res: Vector2i = _resolutions[resolution_opt.selected]
		DisplayServer.window_set_size(res)
		var screen_pos:  Vector2i = DisplayServer.screen_get_position(screen)
		var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
		# maxi(...,0): verhindert negative Versätze, falls das Fenster größer
		# als der Bildschirm gewählt wurde
		var diff  := Vector2i(maxi(screen_size.x - res.x, 0), maxi(screen_size.y - res.y, 0))
		var half  := Vector2i(diff.x >> 1, diff.y >> 1)
		DisplayServer.window_set_position(screen_pos + half)

	# V-Sync
	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync_chk.button_pressed else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	# Lautstärken speichern
	var sfx_db:    float = linear_to_db(sfx_slider.value)
	var music_db:  float = linear_to_db(music_slider.value)
	var master_db: float = linear_to_db(master_slider.value)
	AudioManager.set_sfx_volume(sfx_db)
	AudioManager.set_music_volume(music_db)
	_apply_master_volume(master_slider.value)
	SaveManager.set_setting("sfx_volume",    sfx_db)
	SaveManager.set_setting("music_volume",  music_db)
	SaveManager.set_setting("master_volume", master_db)

	# Sensitivität
	SaveManager.set_setting("mouse_sensitivity", sens_slider.value)

	# Fenster-/Anzeigeeinstellungen persistieren
	SaveManager.set_setting("fullscreen",   target_mode == 2)
	SaveManager.set_setting("window_mode",  target_mode)
	SaveManager.set_setting("vsync",        vsync_chk.button_pressed)

	# Neue Einstellungen persistieren + anwenden
	SaveManager.set_setting("brightness",        brightness_slider.value)
	SaveManager.set_setting("ui_scale",          ui_scale_slider.value)
	SaveManager.set_setting("colorblind_mode",   colorblind_opt.selected)
	SaveManager.set_setting("subtitles_enabled", subtitles_chk.button_pressed)
	SaveManager.set_setting("reduce_motion",     reduce_motion_chk.button_pressed)
	_apply_brightness(brightness_slider.value)
	_apply_colorblind_filter()
	var w := get_window()
	if w:
		w.content_scale_factor = ui_scale_slider.value

	EventBus.audio_play_sfx.emit("ui_click")
	var toast_text: String = _t("settings.saved", "Gespeichert")
	EventBus.ui_toast.emit(toast_text, "win", 1.5)

	_snapshot = _snapshot_settings()
	_set_dirty(false)
	settings_applied.emit()


func _on_back() -> void:
	EventBus.audio_play_sfx.emit("ui_click")
	if _dirty:
		_confirm(
			_t("settings.unsaved_title", "Ungespeicherte Änderungen"),
			_t("settings.unsaved_body", "Es gibt ungespeicherte Änderungen. Verwerfen und schließen?"),
			func():
				_apply_snapshot(_snapshot)
				hide()
		)
	else:
		hide()


# ─────────────────────────────────────────────────────────────────────────
# Reset auf Standard
# ─────────────────────────────────────────────────────────────────────────

func _on_reset_defaults() -> void:
	_confirm(
		_t("settings.reset_title", "Auf Standard zurücksetzen"),
		_t("settings.reset_body", "Alle Einstellungen auf die Standardwerte zurücksetzen?"),
		func():
			_apply_defaults()
			_on_apply()
			settings_reset.emit()
	)


func _apply_defaults() -> void:
	_restoring = true
	language_opt.select(0)
	monitor_opt.select(0)
	var default_res_idx := _resolutions.find(Vector2i(1920, 1080))
	resolution_opt.select(maxi(default_res_idx, 0))
	window_mode_opt.select(DEFAULT_WINDOW_MODE)
	vsync_chk.button_pressed = DEFAULT_VSYNC
	sfx_slider.value    = db_to_linear(DEFAULT_SFX_DB)
	music_slider.value  = db_to_linear(DEFAULT_MUSIC_DB)
	master_slider.value = db_to_linear(DEFAULT_MASTER_DB)
	sens_slider.value = DEFAULT_SENSITIVITY
	brightness_slider.value = DEFAULT_BRIGHTNESS
	ui_scale_slider.value = DEFAULT_UI_SCALE
	colorblind_opt.select(DEFAULT_COLORBLIND_MODE)
	subtitles_chk.button_pressed = true
	reduce_motion_chk.button_pressed = false
	_refresh_value_labels()
	_restoring = false


# ─────────────────────────────────────────────────────────────────────────
# Dirty-Tracking / Snapshot (für "Zurück" mit Rückfrage)
# ─────────────────────────────────────────────────────────────────────────

func _snapshot_settings() -> Dictionary:
	return {
		"language": language_opt.selected,
		"monitor": monitor_opt.selected,
		"resolution": resolution_opt.selected,
		"window_mode": window_mode_opt.selected,
		"vsync": vsync_chk.button_pressed,
		"sfx": sfx_slider.value,
		"music": music_slider.value,
		"master": master_slider.value,
		"sens": sens_slider.value,
		"brightness": brightness_slider.value,
		"ui_scale": ui_scale_slider.value,
		"colorblind": colorblind_opt.selected,
		"subtitles": subtitles_chk.button_pressed,
		"reduce_motion": reduce_motion_chk.button_pressed,
	}


func _apply_snapshot(snap: Dictionary) -> void:
	_restoring = true
	language_opt.select(snap.get("language", 0))
	monitor_opt.select(snap.get("monitor", 0))
	resolution_opt.select(snap.get("resolution", 2))
	window_mode_opt.select(snap.get("window_mode", 0))
	vsync_chk.button_pressed = snap.get("vsync", true)
	sfx_slider.value    = snap.get("sfx", 1.0)
	music_slider.value  = snap.get("music", 0.5)
	master_slider.value = snap.get("master", 1.0)
	sens_slider.value = snap.get("sens", 1.0)
	brightness_slider.value = snap.get("brightness", 1.0)
	ui_scale_slider.value   = snap.get("ui_scale", 1.0)
	colorblind_opt.select(snap.get("colorblind", 0))
	subtitles_chk.button_pressed     = snap.get("subtitles", true)
	reduce_motion_chk.button_pressed = snap.get("reduce_motion", false)

	# .select()/.value= lösen nicht in jedem Fall ein Signal aus
	# (insbesondere OptionButton.select()) — daher hier explizit erneut anwenden.
	_apply_master_volume(master_slider.value)
	_apply_brightness(brightness_slider.value)
	_apply_colorblind_filter()
	var w := get_window()
	if w:
		w.content_scale_factor = ui_scale_slider.value
	_refresh_value_labels()

	_restoring = false
	_set_dirty(false)


func _set_dirty(v: bool) -> void:
	if _restoring:
		return
	_dirty = v
	if dirty_lbl:
		dirty_lbl.visible = v
		if v:
			dirty_lbl.text = _t("settings.unsaved_indicator", "●  Nicht gespeicherte Änderungen")


# ─────────────────────────────────────────────────────────────────────────
# Live-Vorschau-Handler
# ─────────────────────────────────────────────────────────────────────────

func _on_sfx_changed(v: float) -> void:
	sfx_value_lbl.text = "%d%%" % int(round(v * 100.0))
	AudioManager.set_sfx_volume(linear_to_db(v))
	_set_dirty(true)


func _on_music_changed(v: float) -> void:
	music_value_lbl.text = "%d%%" % int(round(v * 100.0))
	AudioManager.set_music_volume(linear_to_db(v))
	_set_dirty(true)


func _on_master_changed(v: float) -> void:
	master_value_lbl.text = "%d%%" % int(round(v * 100.0))
	_apply_master_volume(v)
	_set_dirty(true)


func _apply_master_volume(v: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))


func _on_brightness_changed(v: float) -> void:
	brightness_value_lbl.text = "%d%%" % int(round(v * 100.0))
	_apply_brightness(v)
	_set_dirty(true)


func _apply_brightness(v: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var we := _find_world_environment(current_scene)
	if we and we.environment:
		we.environment.adjustment_enabled = true
		we.environment.adjustment_brightness = v


func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found:
			return found
	return null


func _on_ui_scale_changed(v: float) -> void:
	ui_scale_value_lbl.text = "%d%%" % int(round(v * 100.0))
	var w := get_window()
	if w:
		w.content_scale_factor = v
	_set_dirty(true)


func _on_colorblind_changed(_idx: int) -> void:
	_apply_colorblind_filter()
	_set_dirty(true)


func _ensure_colorblind_layer() -> void:
	if _colorblind_layer and is_instance_valid(_colorblind_layer):
		return
	_colorblind_layer = CanvasLayer.new()
	_colorblind_layer.layer = 128
	_colorblind_rect = ColorRect.new()
	_colorblind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colorblind_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = COLORBLIND_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("mode", 0)
	_colorblind_rect.material = mat
	_colorblind_layer.add_child(_colorblind_rect)
	get_tree().root.add_child(_colorblind_layer)


func _apply_colorblind_filter() -> void:
	_ensure_colorblind_layer()
	var mode: int = colorblind_opt.selected
	var mat := _colorblind_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("mode", mode)
	_colorblind_layer.visible = mode != 0


# ─────────────────────────────────────────────────────────────────────────
# Texte / Lokalisierung
# ─────────────────────────────────────────────────────────────────────────

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

	apply_btn.text = _t("settings.apply", lm.t("settings.apply"))
	back_btn.text  = _t("settings.back", lm.t("settings.back"))

	# Dynamisch erzeugte Zeilen
	for row in _extra_rows:
		var lbl := row.get_child(0) as Label
		if lbl:
			lbl.text = _t(row.get_meta("i18n_key"), row.get_meta("fallback"))

	if reset_btn:
		reset_btn.text = _t("settings.reset", "↺  Standard")
	if _kbp_button:
		_kbp_button.text = _t("settings.controls", "⌨  Steuerung  /  Tastenbelegung")
	if _overlay_header_lbl:
		_overlay_header_lbl.text = _t("settings.controls_title", "STEUERUNG  /  TASTENBELEGUNG")
	if _overlay_hint_lbl:
		_overlay_hint_lbl.text = _t("settings.controls_hint", "Klicke eine Taste zum Ändern  •  ESC = Schließen")
	if _overlay_reset_btn:
		_overlay_reset_btn.text = _t("settings.reset", "↺  Standard")
	if _overlay_close_btn:
		_overlay_close_btn.text = _t("settings.close", "✕  Schließen")


## Übersetzt `key` über LocaleManager, falls verfügbar; sonst/bei fehlendem
## Key wird `fallback` verwendet. Setzt voraus, dass LocaleManager bei
## fehlender Übersetzung den Key selbst zurückgibt (gängige i18n-Konvention).
func _t(key: String, fallback: String) -> String:
	var lm := _lm()
	if lm and lm.has_method("t"):
		var s: String = lm.t(key)
		if s != "" and s != key:
			return s
	return fallback


func _lm() -> Node:
	return get_node_or_null("/root/LocaleManager")


# ─────────────────────────────────────────────────────────────────────────
# Bestätigungsdialog (Reset / ungespeicherte Änderungen)
# ─────────────────────────────────────────────────────────────────────────

func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.confirmed.connect(func():
		if _pending_confirm.is_valid():
			_pending_confirm.call()
		_pending_confirm = Callable()
	)
	_confirm_dialog.canceled.connect(func(): _pending_confirm = Callable())
	add_child(_confirm_dialog)


func _confirm(title: String, text: String, on_confirm: Callable) -> void:
	_confirm_dialog.title = title
	_confirm_dialog.dialog_text = text
	_pending_confirm = on_confirm
	_confirm_dialog.popup_centered()


# ── Tastenbelegung ────────────────────────────────────────────────────────────

func _inject_bindings_ui() -> void:
	_kbp_button = Button.new()
	_kbp_button.text = "⌨  Steuerung  /  Tastenbelegung"
	_kbp_button.pressed.connect(_show_bindings_overlay)
	var buttons_box := vbox.get_node_or_null("Buttons")
	if buttons_box:
		buttons_box.add_child(_kbp_button)
		buttons_box.move_child(_kbp_button, 0)
	else:
		vbox.add_child(_kbp_button)
		vbox.move_child(_kbp_button, maxi(0, vbox.get_child_count() - 1))
	_build_bindings_overlay()


## Lädt die Szene nur, falls sie tatsächlich existiert (ResourceLoader.exists
## prüft zur LAUFZEIT, nicht zur Parse-Zeit — dadurch kein harter Compile-Fehler
## mehr, falls die .tscn fehlt). Andernfalls reine Skript-Instanz.
func _create_kbp() -> KeyBindingsPanel:
	if ResourceLoader.exists(KEY_BINDINGS_SCENE_PATH):
		var packed: PackedScene = load(KEY_BINDINGS_SCENE_PATH)
		var inst := packed.instantiate()
		if inst is KeyBindingsPanel:
			return inst
		inst.queue_free()
	return KeyBindingsPanel.new()


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
	# Bugfix: vorher MOUSE_FILTER_PASS -> Klick auf den abgedunkelten
	# Hintergrund hatte keine Wirkung. Jetzt: Klick daneben schließt das Overlay.
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_overlay_bg_input)
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
	# Verhindert, dass Klicks auf das Panel selbst als "außerhalb" gewertet werden
	outer.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(outer)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	outer.add_child(v)

	_overlay_header_lbl = Label.new()
	_overlay_header_lbl.text = "STEUERUNG  /  TASTENBELEGUNG"
	_overlay_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_header_lbl.add_theme_font_size_override("font_size", 18)
	_overlay_header_lbl.add_theme_color_override("font_color", C_TITLE)
	v.add_child(_overlay_header_lbl)

	_overlay_hint_lbl = Label.new()
	_overlay_hint_lbl.text = "Klicke eine Taste zum Ändern  •  ESC = Schließen"
	_overlay_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_hint_lbl.add_theme_font_size_override("font_size", 11)
	_overlay_hint_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	v.add_child(_overlay_hint_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_kbp = _create_kbp()
	_kbp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_kbp)

	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.20, 0.16, 0.28, 1.0)
	cs.border_color = C_PANEL_BORD
	cs.set_border_width_all(1); cs.set_corner_radius_all(5)
	cs.content_margin_left = 14; cs.content_margin_right = 14
	cs.content_margin_top = 8;   cs.content_margin_bottom = 8

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	v.add_child(btn_row)

	_overlay_reset_btn = Button.new()
	_overlay_reset_btn.text = "↺  Standard"
	_overlay_reset_btn.custom_minimum_size = Vector2(0, 40)
	_overlay_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_reset_btn.add_theme_stylebox_override("normal", cs)
	_overlay_reset_btn.add_theme_color_override("font_color", C_TEXT)
	_overlay_reset_btn.pressed.connect(_on_reset_bindings)
	btn_row.add_child(_overlay_reset_btn)

	_overlay_close_btn = Button.new()
	_overlay_close_btn.text = "✕  Schließen"
	_overlay_close_btn.custom_minimum_size = Vector2(0, 40)
	_overlay_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_close_btn.add_theme_stylebox_override("normal", cs)
	_overlay_close_btn.add_theme_color_override("font_color", C_TEXT)
	_overlay_close_btn.pressed.connect(_hide_bindings_overlay)
	btn_row.add_child(_overlay_close_btn)


func _on_overlay_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_bindings_overlay()


func _on_reset_bindings() -> void:
	if not (_kbp and _kbp.has_method("reset_to_default")):
		return
	_confirm(
		_t("settings.reset_title", "Auf Standard zurücksetzen"),
		_t("settings.reset_bindings_body", "Tastenbelegung auf Standard zurücksetzen?"),
		func():
			_kbp.reset_to_default()
			if _kbp.has_method("refresh"):
				_kbp.refresh()
	)


func _show_bindings_overlay() -> void:
	if _kbp and _kbp.has_method("refresh"):
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