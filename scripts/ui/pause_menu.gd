extends CanvasLayer
class_name PauseMenu

## PauseMenu — Rush Protocol
## CanvasLayer layer=100, process_mode=ALWAYS → aktiv auch bei pausiertem Tree.
## Nutzt KeyBindingsPanel für Tastenbelegung (kein Code-Duplikat mit Settings).
##
## ESC-Verhalten:
##   Hauptseite      → Weiterspielen
##   Steuerungsseite → zurück zur Hauptseite
##   Rebind aktiv    → Rebind abbrechen (KeyBindingsPanel konsumiert Event)

const KeyBindingsPanel = preload("res://scripts/ui/key_bindings_panel.gd")

# ── Farben ────────────────────────────────────────────────────────────────────
const C_OVERLAY    := Color(0.04, 0.03, 0.05, 0.88)
const C_PANEL      := Color(0.10, 0.08, 0.13, 1.0)
const C_PANEL_BORD := Color(0.62, 0.46, 0.10, 1.0)
const C_TITLE      := Color(0.96, 0.82, 0.22, 1.0)
const C_BTN        := Color(0.15, 0.12, 0.20, 1.0)
const C_BTN_HOV    := Color(0.26, 0.20, 0.34, 1.0)
const C_BTN_PRESS  := Color(0.36, 0.26, 0.08, 1.0)
const C_TEXT       := Color(0.92, 0.88, 0.84, 1.0)
const C_TEXT_DIM   := Color(0.56, 0.50, 0.44, 1.0)
const C_DIVIDER    := Color(0.40, 0.28, 0.06, 0.55)

# ── Node-Refs ─────────────────────────────────────────────────────────────────
var _page_main: Control = null
var _page_ctrl: Control = null
var _kbp:       KeyBindingsPanel = null   # KeyBindingsPanel-Instanz

# ── Styles ────────────────────────────────────────────────────────────────────
var _sty_panel: StyleBoxFlat
var _sty_btn_n: StyleBoxFlat
var _sty_btn_h: StyleBoxFlat
var _sty_btn_p: StyleBoxFlat


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_make_styles()
	_build_ui()
	EventBus.ui_open_pause.connect(_open)
	EventBus.ui_close_pause.connect(_close)


func _open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()


func _close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# KeyBindingsPanel konsumiert Events selbst wenn rebinding aktiv ist
	if _kbp != null and _kbp.is_rebinding():
		return
	if event is InputEventKey and event.pressed:
		var kc: int = event.keycode if event.physical_keycode == 0 else event.physical_keycode
		if kc == KEY_ESCAPE:
			if _page_ctrl != null and _page_ctrl.visible:
				_show_main()
			else:
				_on_resume()
			get_viewport().set_input_as_handled()


# ── UI-Aufbau ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Hintergrund
	var bg := ColorRect.new()
	bg.color = C_OVERLAY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	# Haupt-Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	panel.add_theme_stylebox_override("panel", _sty_panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# Titel
	var title := Label.new()
	title.text = "— P A U S E —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)
	vbox.add_child(_divider(10, 16))

	# Hauptseite
	_page_main = _build_main_page()
	vbox.add_child(_page_main)

	# Steuerungsseite
	_page_ctrl = _build_ctrl_page()
	_page_ctrl.visible = false
	vbox.add_child(_page_ctrl)


func _build_main_page() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top",    16)
	m.add_theme_constant_override("margin_bottom", 8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	_main_btn(v, "▶   Weiterspielen",  _on_resume)
	_main_btn(v, "⌨   Steuerung",      _show_ctrl)
	_main_btn(v, "✕   Hauptmenü",      _on_menu)
	return m


func _main_btn(parent: Control, txt: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 58)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_stylebox_override("normal",  _sty_btn_n)
	btn.add_theme_stylebox_override("hover",   _sty_btn_h)
	btn.add_theme_stylebox_override("pressed", _sty_btn_p)
	btn.add_theme_stylebox_override("focus",   _sty_btn_h)
	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", C_TITLE)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(cb)
	parent.add_child(btn)


func _build_ctrl_page() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)

	# Kopfzeile
	var hdr := Label.new()
	hdr.text = "STEUERUNG"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 17)
	hdr.add_theme_color_override("font_color", C_TITLE)
	v.add_child(hdr)

	var hint := Label.new()
	hint.text = "Klicke eine Taste zum Ändern  •  ESC = Abbrechen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", C_TEXT_DIM)
	v.add_child(hint)

	v.add_child(_divider(4, 6))

	# Spalten-Labels
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 0)
	var ca := Label.new()
	ca.text = "AKTION"
	ca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ca.add_theme_font_size_override("font_size", 11)
	ca.add_theme_color_override("font_color", C_TEXT_DIM)
	cols.add_child(ca)
	var ct := Label.new()
	ct.text = "TASTE"
	ct.custom_minimum_size = Vector2(180, 0)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct.add_theme_font_size_override("font_size", 11)
	ct.add_theme_color_override("font_color", C_TEXT_DIM)
	cols.add_child(ct)
	v.add_child(cols)

	# Scroll + KeyBindingsPanel
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_kbp = KeyBindingsPanel.new()
	_kbp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_kbp)

	v.add_child(_divider(4, 4))

	# Zurück
	var back := Button.new()
	back.text = "◀   Zurück"
	back.custom_minimum_size = Vector2(0, 44)
	back.add_theme_stylebox_override("normal",  _sty_btn_n)
	back.add_theme_stylebox_override("hover",   _sty_btn_h)
	back.add_theme_stylebox_override("pressed", _sty_btn_p)
	back.add_theme_stylebox_override("focus",   _sty_btn_h)
	back.add_theme_color_override("font_color",         C_TEXT)
	back.add_theme_color_override("font_hover_color",   Color.WHITE)
	back.add_theme_font_size_override("font_size", 15)
	back.pressed.connect(_show_main)
	v.add_child(back)

	return m


func _divider(mt: int = 8, mb: int = 8) -> Control:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(0, 1)
	var s := StyleBoxFlat.new()
	s.bg_color = C_DIVIDER
	line.add_theme_stylebox_override("panel", s)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top",    mt)
	m.add_theme_constant_override("margin_bottom", mb)
	m.add_child(line)
	return m


# ── Seiten ────────────────────────────────────────────────────────────────────

func _show_main() -> void:
	_page_main.visible = true
	_page_ctrl.visible = false


func _show_ctrl() -> void:
	_page_main.visible = false
	_page_ctrl.visible = true
	_kbp.refresh()   # Immer frisch lesen (sprint/jump kommen erst nach PlayerController._ready)


# ── Aktionen ─────────────────────────────────────────────────────────────────

func _on_resume() -> void:
	GameManager.toggle_pause()


func _on_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# game_manager.gd setzt paused = false selbst — hier zur Sicherheit nochmals
	get_tree().paused = false
	GameManager.return_to_menu()


# ── Styles ────────────────────────────────────────────────────────────────────

func _make_styles() -> void:
	_sty_panel = StyleBoxFlat.new()
	_sty_panel.bg_color = C_PANEL
	_sty_panel.border_color = C_PANEL_BORD
	_sty_panel.set_border_width_all(2)
	_sty_panel.set_corner_radius_all(8)
	_sty_panel.content_margin_left   = 36
	_sty_panel.content_margin_right  = 36
	_sty_panel.content_margin_top    = 28
	_sty_panel.content_margin_bottom = 28

	_sty_btn_n = _flat(C_BTN)
	_sty_btn_h = _flat(C_BTN_HOV)
	_sty_btn_p = _flat(C_BTN_PRESS)


func _flat(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_PANEL_BORD
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s
