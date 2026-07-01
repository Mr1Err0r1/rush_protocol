extends Control
class_name MatchHUD

# MatchHUD — Null Protocol
# Purely event-driven HUD. Listens to EventBus signals only.
# Displays: player stats, suspicion bar, item hotbar, zone label,
#            turn phase, toast messages, risk outcome feedback.

# ── Node references ───────────────────────────────────────────────────────────
@onready var turn_phase_lbl:    Label         = $TopBar/TurnPhaseLabel
@onready var active_player_lbl: Label         = $TopBar/ActivePlayerLabel
@onready var round_lbl:         Label         = $TopBar/RoundLabel

@onready var player_panels:     VBoxContainer = $LeftPanel/PlayerList

@onready var hotbar_row:        HBoxContainer = $BottomBar/HotbarRow
@onready var target_lbl:        Label         = $BottomBar/TargetLabel
@onready var end_turn_btn:      Button        = $BottomBar/EndTurnBtn

@onready var zone_lbl:          Label         = $RightPanel/RightVBox/ZoneLabel
@onready var suspicion_bar:     ProgressBar   = $RightPanel/RightVBox/SuspicionBar
@onready var heat_bar:          ProgressBar   = $RightPanel/RightVBox/HeatBar
@onready var chips_lbl:         Label         = $RightPanel/RightVBox/ChipsLabel

@onready var toast_container:   VBoxContainer = $ToastContainer
@onready var outcome_panel:     Panel         = $OutcomeReveal
@onready var outcome_lbl:       Label         = $OutcomeReveal/OutcomeLabel

@onready var game_over_panel:   Panel         = $GameOverPanel
@onready var game_over_lbl:     Label         = $GameOverPanel/GameOverLabel
@onready var winner_lbl:        Label         = $GameOverPanel/WinnerLabel
@onready var stats_container:   VBoxContainer = $GameOverPanel/StatsContainer
@onready var menu_btn:          Button        = $GameOverPanel/MenuBtn

# ── State ─────────────────────────────────────────────────────────────────────
var _local_player_id: int = -1
var _player_panel_map: Dictionary = {}   # player_id → PanelContainer
var _hotbar_slots:     Array       = []
var _outcome_timer:    Timer


func _ready() -> void:
	_local_player_id = NetworkManager.get_local_id()
	game_over_panel.visible = false
	outcome_panel.visible   = false

	_outcome_timer = Timer.new()
	_outcome_timer.wait_time = 2.5
	_outcome_timer.one_shot  = true
	_outcome_timer.timeout.connect(func(): outcome_panel.visible = false)
	add_child(_outcome_timer)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	menu_btn.pressed.connect(GameManager.return_to_menu)

	# EventBus subscriptions
	EventBus.round_started.connect(_on_round_started)
	EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
	EventBus.player_registered.connect(_on_player_registered)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_suspicion_changed.connect(_on_player_suspicion_changed)
	EventBus.player_chips_changed.connect(_on_player_chips_changed)
	EventBus.player_eliminated.connect(_on_player_eliminated)
	EventBus.player_location_changed.connect(_on_player_location_changed)
	EventBus.risk_triggered.connect(_on_risk_triggered)
	EventBus.item_used.connect(_on_item_used)
	EventBus.item_given.connect(_on_item_given)
	EventBus.match_over.connect(_on_match_over)
	EventBus.ui_toast.connect(_show_toast)
	EventBus.phase_changed.connect(_on_phase_changed)

	_build_hotbar()


# ── Round / phase ─────────────────────────────────────────────────────────────

func _on_round_started(round_idx: int, active_id: int) -> void:
	round_lbl.text = "Round %d" % round_idx
	var is_my_turn := (active_id == _local_player_id)
	if is_my_turn:
		active_player_lbl.text     = "⚡ YOUR TURN"
		active_player_lbl.modulate = Color(1.0, 0.85, 0.1)
		end_turn_btn.disabled      = false
	else:
		active_player_lbl.text     = "Waiting for player %d…" % active_id
		active_player_lbl.modulate = Color(0.6, 0.6, 0.6)
		end_turn_btn.disabled      = true


func _on_turn_phase_changed(phase: String) -> void:
	match phase:
		"ITEM":    turn_phase_lbl.text = "Phase: Use item (1/2)"
		"ACTION":  turn_phase_lbl.text = "Phase: Main action (2/2)"
		"RESOLVE": turn_phase_lbl.text = "Phase: Resolving…"


func _on_phase_changed(phase: String) -> void:
	match phase:
		"CHARACTER_SELECT":
			_show_toast("Choose your character!", "info", 3.0)
		"ENTRY_CHECK":
			_show_toast("Entry check in progress…", "warn", 3.0)
		"CASINO_FLOOR":
			_show_toast("You're in. The game begins.", "info", 3.0)
			EventBus.audio_play_music.emit("match")
		"VAULT_RUN":
			_show_toast("VAULT OPEN — Move in!", "win", 4.0)
		"BOSS_ENCOUNTER":
			_show_toast("BOSS ENCOUNTER!", "warn", 4.0)


# ── Player panels ─────────────────────────────────────────────────────────────

func _on_player_registered(player_id: int, data: Dictionary) -> void:
	var panel := _create_player_panel(player_id, data)
	player_panels.add_child(panel)
	_player_panel_map[player_id] = panel


func _create_player_panel(player_id: int, data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var vbox  := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	var is_local  := player_id == _local_player_id
	name_lbl.text = ("%s [YOU]" % data.get("player_name", "?")) if is_local else data.get("player_name", "?")
	vbox.add_child(name_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.name                = "HPBar"
	hp_bar.min_value           = 0
	hp_bar.max_value           = data.get("max_health", 5)
	hp_bar.value               = data.get("health", 3)
	hp_bar.custom_minimum_size = Vector2(140, 14)
	vbox.add_child(hp_bar)

	return panel


func _on_player_health_changed(player_id: int, old_val: int, new_val: int) -> void:
	if not _player_panel_map.has(player_id):
		return
	var panel: PanelContainer = _player_panel_map[player_id]
	var bar := panel.find_child("HPBar", true, false) as ProgressBar
	if bar:
		bar.value = new_val
	if player_id == _local_player_id:
		EventBus.ui_animate_resource.emit(player_id, "health", new_val - old_val)


func _on_player_suspicion_changed(player_id: int, _old_val: int, new_val: int) -> void:
	if player_id != _local_player_id:
		return
	suspicion_bar.value = new_val
	if new_val >= 8:
		suspicion_bar.modulate = Color(1, 0.2, 0.2)
		_show_toast("⚠ Suspicion critical!", "warn", 2.0)
	elif new_val >= 5:
		suspicion_bar.modulate = Color(1, 0.65, 0.1)
	else:
		suspicion_bar.modulate = Color.WHITE


func _on_player_chips_changed(player_id: int, _old: int, new_val: int) -> void:
	if player_id == _local_player_id:
		chips_lbl.text = "💰 %d Chips" % new_val


func _on_player_eliminated(player_id: int, _killer: int, cause: String) -> void:
	if _player_panel_map.has(player_id):
		var panel: PanelContainer = _player_panel_map[player_id]
		panel.modulate = Color(0.4, 0.4, 0.4)
	var cause_text := {"killed": "shot", "ejected": "ejected", "poisoned": "poisoned"}
	_show_toast("Player %d — %s" % [player_id, cause_text.get(cause, cause)], "lose", 3.0)
	if player_id == _local_player_id:
		_show_toast("You were eliminated!", "lose", 5.0)
		end_turn_btn.disabled = true


func _on_player_location_changed(player_id: int, zone: String) -> void:
	if player_id == _local_player_id:
		zone_lbl.text = "📍 Zone: %s" % _zone_display_name(zone)


# ── Risk & items ──────────────────────────────────────────────────────────────

func _on_risk_triggered(_actor_id: int, _target_id: int, oid: StringName, value: int) -> void:
	var text: String
	var tone: String

	if value > 0:
		text = "✨ %s — +%d Chips!" % [_outcome_display(oid), value]
		tone = "win"
	elif value < 0:
		text = "💀 %s — %d Chips." % [_outcome_display(oid), value]
		tone = "lose"
	else:
		text = "— %s — No effect." % _outcome_display(oid)
		tone = "info"

	_show_toast(text, tone, 3.0)  # default display duration for risk outcomes

	outcome_lbl.text       = text
	outcome_panel.visible  = true
	outcome_panel.modulate = Color(1, 1, 0.5) if value > 0 else Color(1, 0.4, 0.4)
	_outcome_timer.start()


func _on_item_used(player_id: int, item_id: StringName, _target_id: int, result: Dictionary) -> void:
	if not result.get("success", false):
		return
	var idef  := ItemDatabase.get_item(item_id) as ItemDefinition
	var iname := idef.display_name if idef else str(item_id)
	var is_me := player_id == _local_player_id
	_show_toast("%s used: %s" % ["You" if is_me else "Player %d" % player_id, iname], "info", 2.0)
	_update_hotbar_from_state()

	# Private feedback: AI Lens reveals target info only to the local player
	if item_id == &"ai_lens" and is_me and result.has("revealed"):
		_show_lens_result(result["revealed"])


func _on_item_given(player_id: int, item_id: StringName, _source: String) -> void:
	if player_id != _local_player_id:
		return
	var idef  := ItemDatabase.get_item(item_id) as ItemDefinition
	var iname := idef.display_name if idef else str(item_id)
	_show_toast("➕ Received: %s" % iname, "info", 2.0)
	_update_hotbar_from_state()


# ── Hotbar ────────────────────────────────────────────────────────────────────

func _build_hotbar() -> void:
	for i in 4:
		var btn := Button.new()
		btn.text                = "—"
		btn.custom_minimum_size = Vector2(80, 64)
		btn.tooltip_text        = "[%d] Empty" % (i + 1)
		hotbar_row.add_child(btn)
		_hotbar_slots.append(btn)


func _update_hotbar_from_state() -> void:
	if GameManager.active_match == null:
		return
	var state: PlayerState = GameManager.active_match.get_state(_local_player_id)
	if state == null:
		return
	var items := state.inventory.keys()
	for i in _hotbar_slots.size():
		var btn: Button = _hotbar_slots[i]
		if i < items.size():
			var idef         := ItemDatabase.get_item(items[i]) as ItemDefinition
			btn.text         = idef.display_name if idef else str(items[i])
			btn.tooltip_text = "[%d] %s" % [i + 1, idef.description if idef else ""]
		else:
			btn.text         = "—"
			btn.tooltip_text = "[%d] Empty" % (i + 1)


# ── Toast system ──────────────────────────────────────────────────────────────

# tone: "win" | "lose" | "warn" | "info"
func _show_toast(text: String, tone: String, duration: float = 2.5) -> void:
	var lbl := Label.new()
	lbl.text = text
	match tone:
		"win":  lbl.modulate = Color(0.4, 1.0, 0.5)
		"lose": lbl.modulate = Color(1.0, 0.3, 0.3)
		"warn": lbl.modulate = Color(1.0, 0.7, 0.1)
		_:      lbl.modulate = Color.WHITE
	toast_container.add_child(lbl)

	var tw := create_tween()
	tw.tween_interval(duration - 0.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


# ── Special feedback ──────────────────────────────────────────────────────────

# Decodes and displays AI Lens scan result as individual toasts
func _show_lens_result(revealed: Dictionary) -> void:
	var lines: Array[String] = ["🔍 AI Lens result:"]
	if revealed.has("health"):
		lines.append("  HP: %d" % revealed["health"])
	if revealed.has("suspicion"):
		lines.append("  Suspicion: %d" % revealed["suspicion"])
	if revealed.get("disguise_exposed", false):
		lines.append("  ⚠ Disguise exposed!")
	if revealed.get("cheat_detected", false):
		lines.append("  🃏 CHEATING active! Culprit: P.%d" % revealed["cheater_id"])
	if revealed.has("inventory_categories"):
		lines.append("  Inventory types: " + ", ".join(revealed["inventory_categories"]))
	for line in lines:
		_show_toast(line, "info", 4.0)


# ── Game over ─────────────────────────────────────────────────────────────────

func _on_match_over(winner_id: int, condition: String, stats: Dictionary) -> void:
	game_over_panel.visible = true
	end_turn_btn.disabled   = true

	var cond_texts := {
		"last_standing":   "Last standing",
		"vault_reached":   "Vault reached",
		"casino_takeover": "Casino takeover",
	}
	game_over_lbl.text = cond_texts.get(condition, condition)

	if winner_id == _local_player_id:
		winner_lbl.text     = "🏆 YOU WIN!"
		winner_lbl.modulate = Color(1, 0.85, 0.1)
	elif winner_id == -1:
		winner_lbl.text = "Draw"
	else:
		winner_lbl.text = "Player %d wins." % winner_id

	for stat_pid in stats.keys():
		var data := stats[stat_pid] as Dictionary
		var row  := Label.new()
		var mark := "🏆" if stat_pid == winner_id else ("❌" if data.get("eliminated") else "")
		row.text = "%s %s | %d chips | %d rounds | %d hits" % [
			mark, data.get("name", "?"), data.get("final_chips", 0),
			data.get("rounds", 0), data.get("hits", 0)
		]
		stats_container.add_child(row)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _zone_display_name(zone: String) -> String:
	var names := {
		"entrance":       "Entrance",
		"lobby":          "Lobby",
		"floor":          "Casino Floor",
		"bar":            "Bar",
		"vault_corridor": "Vault Corridor",
		"vault":          "VAULT 🔐",
		"boss_office":    "Boss Office",
		"backroom":       "Back Room",
		"rooftop":        "Rooftop",
		"exit":           "Exit",
	}
	return names.get(zone, zone)


func _outcome_display(oid: StringName) -> String:
	match oid:
		&"jackpot":        return "JACKPOT"
		&"house_wins":     return "House wins"
		&"forced_jackpot": return "JACKPOT [CHEAT]"
		&"forced_loss":    return "Loss [RIGGED]"
		_:                 return str(oid)


func _on_end_turn_pressed() -> void:
	if GameManager.active_match != null:
		GameManager.active_match.advance_turn_phase()
		GameManager.active_match.advance_turn_phase()
