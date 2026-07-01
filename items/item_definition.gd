extends Resource
class_name ItemDefinition

@export var item_id:             StringName = &""
@export var display_name:        String     = "Unbekanntes Item"
@export_multiline var description: String   = ""
@export var icon:                Texture2D
@export var world_model:         PackedScene

@export_group("Kategorie")
@export var category:  String = "gadget"
@export var item_type: String = "generic"

@export_group("Schmuggel")
@export var can_be_smuggled:     bool  = true
@export var detection_weight:    int   = 5
@export var confiscation_chance: float = 0.5

@export_group("Verwendung")
@export var requires_target:       bool          = false
@export var can_target_self:       bool          = true
@export var can_target_enemies:    bool          = true
@export var can_target_allies:     bool          = false
@export var usable_in_zones:       Array[String] = []
@export var max_uses_per_match:    int           = -1
@export var suspicion_on_use:      int           = 0
@export var requires_chips_cost:   int           = 0

@export_group("Passiv")
@export var passive_effect_id:          StringName = &""
@export var grants_status_while_held:   StringName = &""
@export var special_action_id:          StringName = &""


func execute_effect(user_state: PlayerState, target_state: PlayerState,
		match_ctrl: Node) -> Dictionary:
	if special_action_id != &"":
		return _execute_special_action(special_action_id, user_state, target_state, match_ctrl)
	push_warning("ItemDefinition.execute_effect() nicht überschrieben: %s" % item_id)
	return {"success": false, "reason": "not_implemented"}


func _execute_special_action(_action_id: StringName, _user: PlayerState,
		_target: PlayerState, _ctrl: Node) -> Dictionary:
	return {"success": false, "reason": "no_special_action"}


func can_use(_user_state: PlayerState, _target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	return {"allowed": true, "reason": ""}


func get_entry_detection_roll() -> bool:
	return randf() < confiscation_chance
