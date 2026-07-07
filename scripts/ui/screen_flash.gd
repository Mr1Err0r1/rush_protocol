extends ColorRect
## ScreenFlash — Null Protocol
## Ein einfaches Overlay für Blitze (z.B. bei Schüssen oder Entdeckungen).

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color.a = 0
	var vfx = get_node_or_null("/root/VisualFX")
	if vfx:
		vfx.request_flash.connect(_on_flash_requested)

func _on_flash_requested(flash_color: Color, duration: float) -> void:
	var c = flash_color
	c.a = 0.5
	color = c
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "color:a", 0.0, duration)
