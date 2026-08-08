extends RigidBody3D
class_name Bullet

@export var life_time: float = 4.0
@export var speed: float = 40.0
@export var damage: int = 1
@export var shooter_id: int = -1

func _ready() -> void:
	# Selbstzerstörung nach life_time Sekunden
	get_tree().create_timer(life_time).timeout.connect(Callable(self, "queue_free"))

func set_velocity(dir: Vector3, initial_speed: float=-1.0) -> void:
	if initial_speed > 0.0:
		linear_velocity = dir.normalized() * initial_speed
	else:
		linear_velocity = dir.normalized() * speed

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Einfache Kontaktabfrage: bei Kontakt zerstören und EventBus.player_hit emitten
	for i in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(i)
		if collider:
			# Versuche, target_id aus Node-Name Player_<id> zu extrahieren
			var node := collider
			var target_id := -1
			while node:
				if typeof(node.name) == TYPE_STRING and node.name.begins_with("Player_"):
					var parts := node.name.split("_")
					if parts.size() >= 2:
						target_id = int(parts[1])
						break
				node = node.get_parent()
			# Emit EventBus signal (falls Autoload vorhanden)
			if EventBus:
				# headshot/kill heuristics are intentionally simple here (false for now)
				EventBus.player_hit.emit(target_id, damage, false, shooter_id)
			queue_free()
			return
