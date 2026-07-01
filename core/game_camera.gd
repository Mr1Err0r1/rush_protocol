extends Camera3D
## GameCamera — Null Protocol
## Unterstützt dynamisches Rütteln und Effekte.

var _shake_intensity := 0.0
var _shake_duration := 0.0
var _original_pos: Vector3

func _ready() -> void:
	_original_pos = position
	if has_node("/root/VisualFX"):
		get_node("/root/VisualFX").request_shake.connect(_on_shake_requested)

func _process(delta: float) -> void:
	if _shake_duration > 0:
		_shake_duration -= delta
		var offset = Vector3(
			randf_range(-1, 1) * _shake_intensity,
			randf_range(-1, 1) * _shake_intensity,
			0
		)
		position = _original_pos + offset
		
		if _shake_duration <= 0:
			position = _original_pos
			_shake_intensity = 0.0

func _on_shake_requested(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
