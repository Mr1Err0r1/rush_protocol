extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var manager := root.get_node("GameManager")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	var panel: Control = (load("res://scripts/ui/key_bindings_panel.gd") as Script).new()
	root.add_child(panel)
	await process_frame
	var capture_button := Button.new()
	manager.app_state = manager.AppState.MATCH
	panel.call("_start_rebind", "pause", capture_button)
	assert(manager.pause_rebind_capture, "Binding the pause action must temporarily capture Escape")
	manager._input(escape)
	assert(manager.app_state == manager.AppState.MATCH, "Escape must reach the key-binding capture without pausing")
	panel.call("_unhandled_input", escape)
	assert(not manager.pause_rebind_capture, "Completing pause rebinding must release input capture")
	assert(manager.app_state == manager.AppState.MATCH, "Rebinding Escape must not pause the match")
	panel.queue_free()
	capture_button.free()
	await process_frame

	manager.app_state = manager.AppState.MATCH
	manager._input(escape)
	assert(manager.app_state == manager.AppState.PAUSED, "ESC must pause an active match")
	assert(paused, "Pausing a match must pause the local SceneTree")

	escape.echo = true
	manager._input(escape)
	assert(manager.app_state == manager.AppState.PAUSED, "Key repeat must not toggle the pause state")
	escape.echo = false
	manager.toggle_pause()
	assert(manager.app_state == manager.AppState.MATCH, "Resume must restore the previous match state")
	assert(not paused, "Resume must unpause the local SceneTree")

	manager.app_state = manager.AppState.GAME_OVER
	manager._input(escape)
	assert(manager.app_state == manager.AppState.PAUSED, "ESC must open the menu after game over")
	manager.toggle_pause()
	assert(manager.app_state == manager.AppState.GAME_OVER, "Resume must restore the game-over state")
	assert(not paused, "Game-over resume must unpause the SceneTree")

	manager.app_state = manager.AppState.MENU
	print("PASS pause-transition tests")
	quit(0)
