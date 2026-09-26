class_name PelletRaycast extends Node

signal pellet_results(hit_count, total_damage, hit_positions)

@export_category("Pellet Settings")
@export var pellet_count: int = 8
@export var spread_angle: float = 4.0
@export var max_range: float = 50.0
@export var damage_per_pellet: int = 1
@export var pellet_speed: float = 40.0

@export_category("Node References")
@export var barrel_origin: Node3D
@export var camera: Camera3D
@export var weapon_viewmodel: WeaponViewmodelController

@export_category("Visual")
@export var pellet_scene: PackedScene

var hit_positions: Array[Vector3] = []

func _ready():
	if weapon_viewmodel:
		weapon_viewmodel.fired.connect(_on_weapon_fired)
	call_deferred("_prime_pellet_scene")


func _prime_pellet_scene() -> void:
	if not pellet_scene:
		return
	var dummy = pellet_scene.instantiate() as RigidBody3D
	if not dummy:
		return
	dummy.freeze = true
	add_child(dummy)
	dummy.queue_free()

func _on_weapon_fired():
	var result = fire_pellets()
	print("[PelletRaycast] hit=%d dmg=%d pellets=%d" % [result["hit_count"], result["total_damage"], pellet_count])
	pellet_results.emit(result["hit_count"], result["total_damage"], result["hit_positions"])

func fire_pellets() -> Dictionary:
	var space_state = get_viewport().get_world_3d().direct_space_state
	var origin: Vector3
	var direction: Vector3

	if barrel_origin:
		origin = barrel_origin.global_position
		direction = -barrel_origin.global_transform.basis.z
	elif camera:
		origin = camera.global_position
		direction = -camera.global_transform.basis.z
	else:
		return { "hit_count": 0, "total_damage": 0, "hit_positions": [] }

	hit_positions.clear()
	var total_damage = 0
	var hit_count = 0
	var spread_rad = deg_to_rad(spread_angle)
	var cam_basis_x = camera.global_transform.basis.x if camera else Vector3.RIGHT

	for i in range(pellet_count):
		var spread_x = randf_range(-spread_rad, spread_rad)
		var spread_y = randf_range(-spread_rad, spread_rad)

		var dir = direction.rotated(Vector3.UP, spread_x)
		dir = dir.rotated(cam_basis_x, spread_y)
		dir = dir.normalized()

		var query = PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range)
		var result = space_state.intersect_ray(query)

		if result:
			var dist = origin.distance_to(result.position)
			var t = clamp(dist / max_range, 0.0, 1.0)
			var dmg = max(1, int(lerp(float(damage_per_pellet), 1.0, t)))
			total_damage += dmg
			hit_count += 1
			hit_positions.append(result.position)

		_spawn_visual_pellet(origin, dir)

	return {
		"hit_count": hit_count,
		"total_damage": total_damage,
		"hit_positions": hit_positions.duplicate()
	}

func _spawn_visual_pellet(origin: Vector3, dir: Vector3):
	if not pellet_scene:
		return
	var pellet = pellet_scene.instantiate() as RigidBody3D
	if not pellet:
		return
	get_tree().current_scene.add_child(pellet)
	pellet.global_position = origin
	pellet.linear_velocity = dir * pellet_speed
