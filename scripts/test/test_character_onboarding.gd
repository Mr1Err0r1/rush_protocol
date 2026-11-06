extends Node

func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var packed_scene: PackedScene = load("res://scenes/world/match_world.tscn")
	var match_scene: Node = packed_scene.instantiate()
	add_child(match_scene)
	await get_tree().process_frame
	var selector: CharacterSelectUI = match_scene.get_node("CharacterSelectLayer/CharacterSelectUI") as CharacterSelectUI
	_check(selector._selection_step == 0, "The onboarding flow must begin with faction selection")
	_check(selector.class_list.item_count >= 5, "At least five factions must be selectable")
	_check(selector._available_classes.size() >= 5, "At least five playable roles must be available")
	selector.class_list.select(0)
	selector._on_class_selected(0)
	selector._on_confirm_pressed()
	_check(selector._selection_step == 1, "Confirming a faction must advance to role selection")
	_check(selector.class_list.item_count >= 1, "A selected faction must expose its playable roles")
	_check(selector._selected_class_id != &"", "The first role must be selected for preview")
	print("PASS faction-first onboarding tests")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
