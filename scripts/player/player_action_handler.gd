extends Node
class_name PlayerActionHandler

@onready var controller: Node = get_parent()

var bound_player_id: int = -1
var match_ctrl: MatchController = null
var rpc_relay: Node = null

var selected_target_id: int = -1

var hotbar_slots: Array[StringName] = [
	&"",
	&"",
	&"",
	&""
]


func _ready() -> void:
	EventBus.ui_target_confirmed.connect(_on_target_confirmed)


func bind_player(id: int, match: MatchController) -> void:
	bound_player_id = id
	match_ctrl = match


func _unhandled_input(event: InputEvent) -> void:

	if not _is_authority():
		return

	if not _is_my_turn():
		return


	if event.is_action_pressed("use_item_1"):
		use_hotbar(0)

	elif event.is_action_pressed("use_item_2"):
		use_hotbar(1)

	elif event.is_action_pressed("use_item_3"):
		use_hotbar(2)

	elif event.is_action_pressed("use_item_4"):
		use_hotbar(3)


	elif event.is_action_pressed("primary_action"):
		do_risk_action()


	elif event.is_action_pressed("toggle_target"):
		cycle_target()


	elif event.is_action_pressed("end_turn"):
		end_turn()



func use_hotbar(slot: int) -> void:

	if slot < 0 or slot >= hotbar_slots.size():
		return


	var item: StringName = hotbar_slots[slot]

	if item == &"":
		return


	var target := selected_target_id

	if target == -1:
		target = bound_player_id


	send_item(item,target)



func do_risk_action() -> void:

	if selected_target_id == -1:
		selected_target_id = bound_player_id

	send_risk(selected_target_id)



func end_turn() -> void:

	if match_ctrl:
		match_ctrl.advance_turn_phase()
		match_ctrl.advance_turn_phase()



func cycle_target() -> void:

	if match_ctrl == null:
		return


	var ids: Array[int] = []

	for state in match_ctrl.get_all_states():

		if not state.is_eliminated:
			ids.append(state.player_id)


	if ids.is_empty():
		return


	var index: int = ids.find(selected_target_id)

	index += 1

	if index >= ids.size():
		index = 0


	selected_target_id = ids[index]



func send_item(item: StringName,target: int) -> void:

	if rpc_relay:
		rpc_relay.request_item_use(
			bound_player_id,
			item,
			target
		)

	elif match_ctrl:
		match_ctrl.request_use_item(
			bound_player_id,
			item,
			target
		)



func send_risk(target: int) -> void:

	if rpc_relay:
		rpc_relay.request_risk_action(
			bound_player_id,
			target
		)

	elif match_ctrl:
		match_ctrl.request_risk_action(
			bound_player_id,
			target
		)



func _is_authority() -> bool:

	if multiplayer.multiplayer_peer == null:
		return true


	if not controller.has_method("is_multiplayer_authority"):
		return true


	return controller.is_multiplayer_authority()



func _is_my_turn() -> bool:

	if match_ctrl == null:
		return false

	return match_ctrl.get_active_player_id() == bound_player_id



func _on_target_confirmed(id:int) -> void:
	selected_target_id = id



func set_hotbar_slot(index:int,item:StringName) -> void:

	if index >= 0 and index < hotbar_slots.size():
		hotbar_slots[index] = item
