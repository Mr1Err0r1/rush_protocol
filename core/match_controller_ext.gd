extends Node
## MatchControllerExt — Null Protocol
## Erweiterte Spiellogik für den Casino-Ablauf.

enum MatchPhase { ENTRY_CHECK, EXPLORATION, HEIST, BOSS_FIGHT }

var current_phase: MatchPhase = MatchPhase.ENTRY_CHECK
var round_number: int = 1

func advance_phase() -> void:
	match current_phase:
		MatchPhase.ENTRY_CHECK:
			current_phase = MatchPhase.EXPLORATION
			EventBus.ui_toast.emit("Willkommen im Casino. Bleiben Sie unauffällig.", "info", 3.0)
		MatchPhase.EXPLORATION:
			current_phase = MatchPhase.HEIST
			EventBus.ui_toast.emit("Der Überfall beginnt!", "warn", 3.0)
		MatchPhase.HEIST:
			current_phase = MatchPhase.BOSS_FIGHT
			EventBus.ui_toast.emit("Der Casino-Boss erscheint!", "lose", 3.0)

func process_player_turn(player_id: int, action: String) -> void:
	# Hier wird die spezifische Logik für Aktionen wie "Russian Roulette" aufgerufen
	if action == "russian_roulette":
		_handle_russian_roulette(player_id)

func _handle_russian_roulette(player_id: int) -> void:
	var vfx = get_node_or_null("/root/VisualFX")
	
	# Dramatischer Effekt vor dem Schuss
	if vfx: vfx.shake(0.5, 1.0)
	
	# Logik für das russische Roulette
	var success = randf() > 0.166
	if not success:
		if vfx:
			vfx.flash(Color.RED, 0.5)
			vfx.shake(2.0, 0.5)
		EventBus.ui_toast.emit("Pech gehabt beim Russischen Roulette...", "lose", 3.0)
		# Spieler eliminieren Logik
	else:
		if vfx: vfx.flash(Color.WHITE, 0.1)
		EventBus.ui_toast.emit("Glück gehabt!", "win", 2.0)
