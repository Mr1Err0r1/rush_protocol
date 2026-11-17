extends Node
## Test-Host: lädt das per Kommandozeile übergebene Test-Skript als Node und startet es.
## Dadurch sind Autoloads (EventBus, ItemDatabase, …) wie im echten Spiel verfügbar.
## Aufruf: godot --headless --path . res://tests/host.tscn -- tests/test_xyz.gd


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Kein Test-Skript angegeben")
		get_tree().quit(2)
		return
	var script: GDScript = load("res://" + args[0])
	if script == null:
		push_error("Test-Skript nicht ladbar: " + args[0])
		get_tree().quit(2)
		return
	add_child(script.new())
