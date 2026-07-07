extends Control
## MenuBackground — Null Protocol
## Ein dynamischer Hintergrund im "Elite Casino"-Stil (Gold/Schwarz).

@export var rotation_speed := 0.5
@export var accent_color := Color("d4af37") # Gold

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	# Hier könnte man Shader-Parameter oder Partikel-Positionen animieren
	# Für ein professionelles Menü empfiehlt sich ein sanftes Driften der Kamera oder von Partikeln
	queue_redraw()

func _draw() -> void:
	# Zeichne ein dezentes Muster oder animierte Linien im Hintergrund
	var center := size / 2.0
	var radius: float = min(size.x, size.y) * 0.4
	
	# Beispiel: Rotierende Goldene Linien
	for i in range(8):
		var angle := _time * rotation_speed + (i * PI / 4.0)
		var dir := Vector2.from_angle(angle)
		draw_line(center + dir * (radius * 0.8), center + dir * radius, accent_color, 2.0)
