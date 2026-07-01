extends Node
## VisualFX — Null Protocol
## Einfache UI-Animationen. Wird von main_menu_ui.gd genutzt (ui_wobble).
## Alle Methoden prüfen ob der Node noch im Baum ist bevor sie animieren.
##
## Zusätzlich: globale Signale für Welt-Effekte (Kamera-Shake, Bildschirm-Blitz),
## auf die game_camera.gd / screen_flash.gd lauschen.

signal request_shake(intensity: float, duration: float)
signal request_flash(color: Color, duration: float)

func shake(intensity: float, duration: float) -> void:
	request_shake.emit(intensity, duration)

func flash(color: Color, duration: float) -> void:
	request_flash.emit(color, duration)

func ui_wobble(node: Control) -> void:
	if not is_instance_valid(node):
		return
	# Skalierung passiert um pivot_offset — der ist standardmäßig (0,0), also
	# die obere linke Ecke. Ohne diese Zeile "wandert" der Button beim Skalieren
	# schräg nach unten-rechts statt symmetrisch zu wachsen.
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2(1.0,  1.0),  0.08).set_trans(Tween.TRANS_SINE)

func ui_flash(node: Control, color: Color = Color.WHITE, duration: float = 0.15) -> void:
	if not is_instance_valid(node):
		return
	var original := node.modulate
	var tw := create_tween()
	tw.tween_property(node, "modulate", color, duration * 0.4)
	tw.tween_property(node, "modulate", original, duration * 0.6)

func ui_shake(node: Control, strength: float = 6.0, duration: float = 0.3) -> void:
	if not is_instance_valid(node):
		return
	var original_pos := node.position
	var tw := create_tween()
	var steps := 8
	for i in steps:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tw.tween_property(node, "position", original_pos + offset, duration / steps)
	tw.tween_property(node, "position", original_pos, 0.05)

func fade_in(node: CanvasItem, duration: float = 0.4) -> void:
	if not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration)

func fade_out(node: CanvasItem, duration: float = 0.4) -> Tween:
	if not is_instance_valid(node):
		return null
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, duration)
	return tw
