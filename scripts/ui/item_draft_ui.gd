extends CanvasLayer
class_name ItemDraftUI
## ItemDraftUI — Auswahl-Panel für den Item-Modus "draft" (komplett im Code gebaut).
## Zeigt dem Spieler sein Angebot; bei mehreren menschlichen Spielern (Hotseat) nacheinander.
## Bleibt unsichtbar, solange kein Angebot vorliegt.

var _mc: MatchController
var _queue: Array[int] = []
var _current: int = -1
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var _root: Control
var _title: Label
var _info: Label
var _list: VBoxContainer
var _done_btn: Button


func setup(match_ctrl: MatchController) -> void:
	_mc = match_ctrl


func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false
	EventBus.item_draft_offered.connect(_on_offered)
	EventBus.item_draft_finished.connect(_on_finished)
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)
	_info = Label.new()
	box.add_child(_info)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	_done_btn = Button.new()
	_done_btn.text = LocaleManager.translate("draft.done")
	_done_btn.pressed.connect(_on_done_pressed)
	box.add_child(_done_btn)


func _on_offered(player_id: int, _offers: Array, _picks: int) -> void:
	if not _queue.has(player_id) and player_id != _current:
		_queue.append(player_id)
	if _current == -1:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_current = -1
		if _root.visible:
			_root.visible = false
			Input.mouse_mode = _prev_mouse_mode
		return
	_current = _queue.pop_front()
	if not _root.visible:
		_prev_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_refresh()


func _refresh() -> void:
	if _mc == null or _current == -1:
		return
	var state := _mc.get_state(_current)
	var offers := _mc.get_draft_offers(_current)
	var picks := _mc.get_draft_picks_left(_current)
	if state == null or offers.is_empty() or picks <= 0:
		_show_next()
		return
	_title.text = LocaleManager.translate("draft.title", [state.player_name])
	var cap: int = _mc.match_config.get("inventory_capacity", ItemDraft.INVENTORY_CAPACITY)
	_info.text = LocaleManager.translate("draft.info", [picks, ItemDraft.free_slots(state, cap)])
	_done_btn.text = LocaleManager.translate("draft.done")
	for child in _list.get_children():
		child.queue_free()
	for item_id in offers:
		var idef := ItemDatabase.get_item(item_id) as ItemDefinition
		var btn := Button.new()
		var locale_id := _item_locale_id(item_id)
		var name_key := "item." + locale_id
		var item_name := LocaleManager.translate(name_key)
		if item_name == name_key and idef != null:
			item_name = idef.display_name
		var category_name := "?"
		var description := ""
		if idef != null:
			var category_key := "item.category." + idef.category
			category_name = LocaleManager.translate(category_key)
			if category_name == category_key:
				category_name = idef.category.capitalize()
			var description_key := "item." + locale_id + "_desc"
			description = LocaleManager.translate(description_key)
			if description == description_key:
				description = idef.description
		btn.text = "%s   [%s]" % [item_name, category_name]
		btn.tooltip_text = description
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.set_meta("item_id", item_id)
		btn.pressed.connect(_on_offer_pressed.bind(item_id))
		_list.add_child(btn)


func _on_offer_pressed(item_id: StringName) -> void:
	if _mc == null or _current == -1:
		return
	var pid := _current
	_mc.request_draft_pick(pid, item_id)
	if _current == pid:   # Draft nicht zwischenzeitlich beendet
		_refresh()


func _on_done_pressed() -> void:
	if _mc == null or _current == -1:
		return
	var pid := _current
	_mc.request_draft_done(pid)
	if _current == pid:
		_show_next()


func _on_finished(_round_index: int) -> void:
	_queue.clear()
	_current = -1
	if _root.visible:
		_root.visible = false
		Input.mouse_mode = _prev_mouse_mode


func _on_locale_changed(_locale: String) -> void:
	_done_btn.text = LocaleManager.translate("draft.done")
	if _root.visible:
		_refresh()


func _item_locale_id(item_id: StringName) -> String:
	if item_id in [&"magnifier", &"saw", &"handcuffs", &"medkit"]:
		return "roulette_" + str(item_id)
	return str(item_id)
