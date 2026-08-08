@warning_ignore_start("unused_signal")
extends Node
## EventBus — Null Protocol: Casino Heist
## Zentrale Signal-Drehscheibe. Alle Signale werden von anderen Klassen
## emit()t und connected — nicht von EventBus selbst.
## @warning_ignore_start("unused_signal") unterdrückt Godot-4.7-Warnings
## für dieses gültige Bus-Pattern.

# ── Spielphasen-Ablauf ────────────────────────────────────────────────────────
signal phase_changed(new_phase: String)
signal round_started(round_index: int, active_player_id: int)
signal turn_phase_changed(turn_phase: String)
signal turn_ended(player_id: int, reason: String)
signal match_over(winner_id: int, win_condition: String, stats: Dictionary)

# ── Einlass-Phase ────────────────────────────────────────────────────────────
signal entry_check_started(player_id: int)
signal entry_check_passed(player_id: int, suspicion_gained: int)
signal entry_check_failed(player_id: int, caught_item_id: StringName)
signal player_ejected(player_id: int, reason: String)

# ── Spieler ─────────────────────────────────────────────────────────────────
signal player_registered(player_id: int, data: Dictionary)
signal player_suspicion_changed(player_id: int, old_val: int, new_val: int)
signal player_heat_changed(player_id: int, old_val: int, new_val: int)
signal player_influence_changed(player_id: int, old_val: int, new_val: int)
signal player_health_changed(player_id: int, old_val: int, new_val: int)
signal player_chips_changed(player_id: int, old_val: int, new_val: int)
signal player_status_applied(player_id: int, status_id: StringName, rounds: int)
signal player_status_removed(player_id: int, status_id: StringName)
signal player_eliminated(player_id: int, killer_id: int, cause: String)
# Neues Signal für Treffer- / Schadens-Events (additiv)
signal player_hit(target_id: int, damage: int, headshot: bool, shooter_id: int)
signal player_disguise_changed(player_id: int, disguise_id: StringName)
signal player_location_changed(player_id: int, zone: String)

# ── Charakter-Auswahl ────────────────────────────────────────────────────────
signal character_selected(player_id: int, char_class_id: StringName)
signal loadout_confirmed(player_id: int, equipped_items: Array[StringName])

# ── Items ─────────────────────────────────────────────────────────────────
signal item_smuggled_in(player_id: int, item_id: StringName)
signal item_confiscated(player_id: int, item_id: StringName)
signal item_given(player_id: int, item_id: StringName, source: String)
signal item_used(player_id: int, item_id: StringName, target_id: int, result: Dictionary)
signal item_use_failed(player_id: int, item_id: StringName, reason: String)
signal item_stolen(thief_id: int, victim_id: int, item_id: StringName)
signal item_destroyed(player_id: int, item_id: StringName)

# ── Risiko-Mechanik ─────────────────────────────────────────────────────────
signal risk_pool_set(pos_count: int, neg_count: int, total: int)
signal risk_triggered(actor_id: int, target_id: int, outcome_id: StringName, value: int)
signal risk_peeked(viewer_id: int, outcome_id: StringName)
signal risk_forced(actor_id: int, outcome_id: StringName)
signal risk_pool_empty()

# ── Zonen & Kasino ─────────────────────────────────────────────────────────
signal zone_unlocked(zone_id: String, by_player_id: int)
signal zone_locked(zone_id: String, reason: String)
signal vault_door_state_changed(is_open: bool, opener_id: int)
signal boss_encounter_started(player_id: int)
signal boss_eliminated(by_player_id: int)
signal casino_won(winner_id: int)

# ── KI ──────────────────────────────────────────────────────────────────
signal ai_thinking_started(ai_id: int)
signal ai_decision_made(ai_id: int, action: Dictionary)
signal ai_suspicion_reaction(ai_id: int, target_id: int)

# ── Netzwerk ───────────────────────────────────────────────────────────
signal net_host_started(port: int)
signal net_client_connected(peer_id: int)
signal net_connection_failed(reason: String)
signal net_server_disconnected()
signal net_lobby_updated(players: Dictionary)
signal player_left_lobby(peer_id: int)
signal net_match_starting()

# ── UI ──────────────────────────────────────────────────────────────────
signal ui_toast(text: String, tone: String, duration: float)
signal ui_show_entry_result(player_id: int, passed: bool, detail: String)
signal ui_show_action_result(outcome_id: StringName, target_id: int, value: int)
signal ui_request_target(requester_id: int, valid_ids: Array[int], mode: String)
signal ui_target_confirmed(target_id: int)
signal ui_open_pause()
signal ui_close_pause()
signal ui_update_zone_map(unlocked_zones: Array[String])
signal ui_show_vault_countdown(rounds_left: int)
signal ui_animate_resource(player_id: int, resource_name: String, delta: int)

# ── Audio ─────────────────────────────────────────────────────────────────
signal audio_play_sfx(key: String)
signal audio_play_music(key: String)
signal audio_stop_music()

@warning_ignore_restore("unused_signal")
