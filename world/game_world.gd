extends Node3D

## Minimalistische "leere" Welt: schwarzer Boden + Lichtsetup.
## Goldener Akzent passend zum Menü-Look. Physik läuft automatisch
## über StaticBody3D (Boden) und CharacterBody3D (Player).

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED