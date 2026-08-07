extends RigidBody3D
class_name Bullet

@export var life_time: float = 4.0
@export var speed: float = 40.0
@export var damage: int = 1

func _ready() -> void:
	# Selbstzerstörung nach life_time Sekunden
	get_tree().create_timer(life_time).timeout.connect(funcref(self, "queue_free"))

func set_velocity(dir: Vector3, initial_speed: float=-1.0) -> void:
	if initial_speed > 0.0:
		linear_velocity = dir.normalized() * initial_speed
	else:
		linear_velocity = dir.normalized() * speed

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Einfache Kontaktabfrage: bei Kontakt zerstören
	for i in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(i)
		if collider:
			# Optional: apply damage oder EventBus.emit
			queue_free()
			return
