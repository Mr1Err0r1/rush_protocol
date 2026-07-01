extends CharacterBody3D
class_name PlayerController

@export var move_speed := 5.5
@export var sprint_speed := 9.0
@export var acceleration := 14.0
@export var friction := 12.0
@export var jump_velocity := 5.2
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var mesh_root: Node3D = $MeshRoot

# ── Animation ───────────────────────────────────────────────────────────
# TODO: Pfad prüfen, sobald businessman_animation.glb neu instanziert ist
@onready var anim_player: AnimationPlayer = get_node_or_null("MeshRoot/Model/AnimationPlayer")

# TODO: Clip-Namen im Animation-Panel (unten in Godot) nachsehen und eintragen
const ANIM_IDLE   := "Idle"
const ANIM_WALK   := "Walk"
const ANIM_RUN    := "Run"
const ANIM_ATTACK := "Attack"

var _attacking := false

enum CameraMode { THIRD, FRONT, FIRST }
var camera_mode: CameraMode = CameraMode.FIRST

var yaw: float = 0.0
var pitch: float = -0.25
var skeleton: Skeleton3D = null
var head_bone: int = -1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_input()
	_find_head_bone.call_deferred()
	_apply_camera_mode()


func seat_at(t: Transform3D) -> void:
	global_transform = t
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		yaw -= mouse.relative.x * mouse_sensitivity
		pitch = clamp(pitch - mouse.relative.y * mouse_sensitivity, -1.2, 0.6)
		rotation.y = yaw
		camera_pivot.rotation.x = pitch
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				GameManager.toggle_pause()
			KEY_F5:
				change_camera()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var is_sprinting := Input.is_action_pressed("sprint")
	var speed: float = sprint_speed if is_sprinting else move_speed

	velocity.x = lerp(velocity.x, dir.x * speed, acceleration * delta)
	velocity.z = lerp(velocity.z, dir.z * speed, acceleration * delta)
	move_and_slide()
	update_head(delta)

	_update_animation(input, is_sprinting)
	if Input.is_action_just_pressed("attack"):
		_try_attack()


func change_camera() -> void:
	camera_mode = (camera_mode + 1) as CameraMode
	if camera_mode > CameraMode.FIRST:
		camera_mode = CameraMode.THIRD
	_apply_camera_mode()


func _apply_camera_mode() -> void:
	match camera_mode:
		CameraMode.THIRD:
			spring_arm.spring_length = 4.5
			spring_arm.rotation.y = 0
			mesh_root.visible = true
		CameraMode.FRONT:
			spring_arm.spring_length = 4.5
			spring_arm.rotation.y = PI
			mesh_root.visible = true
		CameraMode.FIRST:
			spring_arm.spring_length = 0.05
			mesh_root.visible = false


# ── Animation-Logik ──────────────────────────────────────────────────────

func _update_animation(input_dir: Vector2, is_sprinting: bool) -> void:
	if anim_player == null or _attacking:
		return
	if input_dir.length() < 0.1:
		_play_anim(ANIM_IDLE)
	elif is_sprinting:
		_play_anim(ANIM_RUN)
	else:
		_play_anim(ANIM_WALK)


func _play_anim(clip_name: String) -> void:
	if anim_player.current_animation != clip_name:
		anim_player.play(clip_name)


func _try_attack() -> void:
	if anim_player == null or _attacking:
		return
	_attacking = true
	anim_player.play(ANIM_ATTACK)
	await anim_player.animation_finished
	_attacking = false


# ── Kopf-Blick (Bone-basiert) ────────────────────────────────────────────

func _find_head_bone() -> void:
	skeleton = find_skeleton(mesh_root)
	if skeleton == null:
		return
	for bone_name in ["Head", "head", "mixamorig:Head", "mixamorig:Neck", "Neck"]:
		var id := skeleton.find_bone(bone_name)
		if id >= 0:
			head_bone = id
			return


func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := find_skeleton(child)
		if result:
			return result
	return null


func update_head(delta: float) -> void:
	if skeleton == null or head_bone < 0:
		return
	var target := Quaternion.from_euler(Vector3(pitch * 0.65, -yaw * 0.15, 0))
	var current := skeleton.get_bone_pose_rotation(head_bone)
	skeleton.set_bone_pose_rotation(head_bone, current.slerp(target, delta * 8))


func _setup_input() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"attack": KEY_V,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var e := InputEventKey.new()
			e.physical_keycode = keys[action]
			InputMap.action_add_event(action, e)

