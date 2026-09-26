extends RigidBody3D

@export var lifetime: float = 2.0
@export var pellet_gravity: float = 0.4
@export var impact_particle: PackedScene

var _age: float = 0.0
var _can_collide: bool = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	gravity_scale = pellet_gravity
	await get_tree().create_timer(0.05).timeout
	_can_collide = true

func _process(delta):
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(_body):
	if not _can_collide:
		return
	var pos = global_position
	if impact_particle:
		var p = impact_particle.instantiate() as Node3D
		if p:
			get_tree().current_scene.add_child(p)
			p.global_position = pos
			await get_tree().create_timer(2.0).timeout
			if is_instance_valid(p):
				p.queue_free()
	queue_free()
