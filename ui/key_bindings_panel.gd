extends VBoxContainer
class_name KeyBindingsPanel

## KeyBindingsPanel — Rush Protocol
## Wiederverwendbare Tastenbelegungs-Liste.
## Einbetten: parent.add_child(KeyBindingsPanel.new())
## Vor Anzeige refresh() aufrufen (InputMap muss befüllt sein).
##
## Eltern-Node ist verantwortlich für ScrollContainer-Wrapper und Navigation.
## Dieses Node behandelt nur das Rebind-Input — kein ESC-Navigieren.

# ── Bindbare Aktionen ────────────────────────────────────────────────────────
const BINDABLE: Array = [
	{ "action": "move_forward",    "label": "Vorwärts" },
	{ "action": "move_back",       "label": "Rückwärts" },
	{ "action": "move_left",       "label": "Links" },
	{ "action": "move_right",      "label": "Rechts" },
	{ "action": "jump",            "label": "Springen" },
	{ "action": "sprint",          "label": "Sprinten" },
	{ "action": "interact",        "label": "Interagieren  (E)" },
	{ "action": "primary_action",  "label": "Hauptaktion" },
	{ "action": "secondary_action","label": "Sekundäraktion" },
	{ "action": "end_turn",        "label": "Zug beenden" },
	{ "action": "toggle_target",   "label": "Ziel wechseln" },
	{ "action": "use_item_1",      "label": "Item 1" },
	{ "action": "use_item_2",      "label": "Item 2" },
	{ "action": "use_item_3",      "label": "Item 3" },
	{ "action": "use_item_4",      "label": "Item 4" },
]

# ── Farben (Casino-Dunkel-Theme) ─────────────────────────────────────────────
const C_BTN       := Color(0.15, 0.12, 0.20, 1.0)
const C_BTN_HOV   := Color(0.26, 0.20, 0.34, 1.0)
const C_BTN_PRESS := Color(0.36, 0.26, 0.08, 1.0)
const C_BTN_RB    := Color(0.55, 0.36, 0.04, 1.0)   # Aktiver Rebind-Button
const C_GOLD      := Color(0.62, 0.46, 0.10, 1.0)
const C_TEXT      := Color(0.92, 0.88, 0.84, 1.0)
const C_TEXT_DIM  := Color(0.56, 0.50, 0.44, 1.0)
const C_ROW_ALT   := Color(0.16, 0.12, 0.21, 0.45)

# ── Zustand ──────────────────────────────────────────────────────────────────
var _rebinding: String = ""    # action-Name der gerade geändert wird
var _rebind_btn: Button = null

# ── Styles (einmal erstellt, dann geteilt) ───────────────────────────────────
var _sty_n:  StyleBoxFlat   # normal
var _sty_h:  StyleBoxFlat   # hover
var _sty_p:  StyleBoxFlat   # pressed
var _sty_rb: StyleBoxFlat   # rebind aktiv


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_styles()
	refresh()


## Baut die Liste neu aus der aktuellen InputMap.
## Aufrufen wenn die Seite gezeigt wird, damit Sprint/Jump sicher geladen sind.
func refresh() -> void:
	# Alte Zeilen sofort entfernen
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rebinding = ""
	_rebind_btn = null

	var alt := false
	for entry in BINDABLE:
		var action: String = entry["action"]
		var row := _make_row(entry["label"], action, alt)
		add_child(row)
		alt = not alt


## Gibt zurück ob gerade auf eine Taste gewartet wird.
func is_rebinding() -> bool:
	return _rebinding != ""


# ── Input: Rebind-Capture ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _rebinding == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_apply_rebind(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_apply_rebind(event)
		get_viewport().set_input_as_handled()


# ── Zeilen-Bau ────────────────────────────────────────────────────────────────

func _make_row(label_txt: String, action: String, alt: bool) -> Control:
	var row_bg := PanelContainer.new()
	row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if alt:
		var s := StyleBoxFlat.new()
		s.bg_color = C_ROW_ALT
		s.set_corner_radius_all(3)
		row_bg.add_theme_stylebox_override("panel", s)
	else:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0,0,0,0)
		row_bg.add_theme_stylebox_override("panel", s)

	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size.y = 38
	hbox.add_theme_constant_override("separation", 0)
	row_bg.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TEXT)
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = _key_label(action)
	btn.custom_minimum_size = Vector2(180, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_stylebox_override("normal",  _sty_n)
	btn.add_theme_stylebox_override("hover",   _sty_h)
	btn.add_theme_stylebox_override("pressed", _sty_p)
	btn.add_theme_stylebox_override("focus",   _sty_h)
	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.96, 0.82, 0.22, 1.0))
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_start_rebind.bind(action, btn))
	hbox.add_child(btn)

	return row_bg


# ── Rebind-Logik ──────────────────────────────────────────────────────────────

func _start_rebind(action: String, btn: Button) -> void:
	if _rebinding == action:    # nochmal klicken = abbrechen
		_cancel_rebind()
		return
	_cancel_rebind()
	_rebinding  = action
	_rebind_btn = btn
	btn.add_theme_stylebox_override("normal", _sty_rb)
	btn.add_theme_stylebox_override("hover",  _sty_rb)
	btn.text = "[ Taste drücken … ]"


func _apply_rebind(event: InputEvent) -> void:
	var action := _rebinding
	var btn    := _rebind_btn
	_rebinding  = ""
	_rebind_btn = null

	# ESC = Abbrechen (ESC selbst bleibt nicht bindbar)
	if event is InputEventKey:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_ESCAPE:
			_reset_btn_style(btn, action)
			return

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_reset_btn_style(btn, action)


func _cancel_rebind() -> void:
	if _rebind_btn != null and is_instance_valid(_rebind_btn):
		_reset_btn_style(_rebind_btn, _rebinding)
	_rebinding  = ""
	_rebind_btn = null


func _reset_btn_style(btn: Button, action: String) -> void:
	btn.add_theme_stylebox_override("normal", _sty_n)
	btn.add_theme_stylebox_override("hover",  _sty_h)
	btn.text = _key_label(action)


# ── Hilfsmethoden ─────────────────────────────────────────────────────────────

func _key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		var kc: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(kc)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:   return "Maus Links"
			MOUSE_BUTTON_RIGHT:  return "Maus Rechts"
			MOUSE_BUTTON_MIDDLE: return "Maus Mitte"
			_:                   return "Maus %d" % ev.button_index
	return "?"


func _make_styles() -> void:
	_sty_n  = _flat(C_BTN,     1)
	_sty_h  = _flat(C_BTN_HOV, 1)
	_sty_p  = _flat(C_BTN_PRESS, 1)
	_sty_rb = _flat(C_BTN_RB,  2)
	_sty_rb.border_color = Color(0.96, 0.82, 0.22, 1.0)


func _flat(bg: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_GOLD
	s.set_border_width_all(bw)
	s.set_corner_radius_all(4)
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 5
	s.content_margin_bottom = 5
	return s
