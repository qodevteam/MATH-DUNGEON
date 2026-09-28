extends Node3D
class_name Coin

signal collected(value: int)

@export var coin_value: int = 1
@export var collection_radius: float = 1.2

var _collected: bool = false
var _area: Area3D
var _particles: GPUParticles3D
var _mesh: MeshInstance3D
var _anim: AnimationPlayer

func _ready() -> void:
	_mesh = get_node_or_null("Coin_MESH") as MeshInstance3D
	_anim = get_node_or_null("Coin_MESH/AnimationPlayer") as AnimationPlayer
	_setup_collection_area()
	_setup_particles()

func _setup_collection_area() -> void:
	_area = Area3D.new()
	_area.name = "CollectionArea"
	add_child(_area)

	var shape = SphereShape3D.new()
	shape.radius = collection_radius
	var collision = CollisionShape3D.new()
	collision.shape = shape
	_area.add_child(collision)

	_area.body_entered.connect(_on_body_entered)

func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "CollectParticles"
	_particles.amount = 16
	_particles.one_shot = true
	_particles.explosiveness = 0.9
	_particles.emitting = false
	_particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 360.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.5
	material.gravity = Vector3(0, -6.0, 0)
	material.scale_min = 0.08
	material.scale_max = 0.2

	var gradient = Gradient.new()
	gradient.add_color_stop(0.0, Color(1.0, 0.9, 0.2, 1.0))
	gradient.add_color_stop(0.5, Color(1.0, 0.6, 0.1, 0.8))
	gradient.add_color_stop(1.0, Color(0.8, 0.3, 0.0, 0.0))
	material.color = gradient

	_particles.process_material = material

	var sphere = SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	_particles.draw_pass_1 = sphere

	add_child(_particles)

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not body is CharacterBody3D:
		return
	if body.name.to_lower().find("player") == -1:
		return

	_collect(body)

func _collect(player: CharacterBody3D) -> void:
	_collected = true

	_area.monitoring = false
	_area.monitorable = false

	collected.emit(coin_value)
	print("Coin collected! +%d" % coin_value)

	if _anim and _anim.has_animation("COIN FLIP"):
		_anim.stop()
	if _mesh:
		_mesh.visible = false

	if _particles:
		_particles.emitting = true

	await get_tree().create_timer(0.4).timeout
	queue_free()
