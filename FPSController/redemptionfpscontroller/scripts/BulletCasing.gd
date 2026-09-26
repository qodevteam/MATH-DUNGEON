extends Node3D

@export var impact_sounds: Array[AudioStream] = []
@export var lifetime: float = 8.0
@export var min_pitch: float = 0.85
@export var max_pitch: float = 1.15
@export var min_volume_db: float = -4.0
@export var max_volume_db: float = 2.0

@export_group("Ejection Push (meters)")
@export var ejection_force: Vector3 = Vector3(3.0, 0.8, 0.0)
@export var ejection_force_random: Vector3 = Vector3(0.5, 0.3, 0.5)
@export var ejection_torque: Vector3 = Vector3(-3.0, 0.0, 5.0)
@export var ejection_torque_random: Vector3 = Vector3(2.0, 3.0, 2.0)

var _has_collided: bool = false


func _ready() -> void:
	for child in get_children():
		if child is RigidBody3D:
			child.contact_monitor = true
			child.max_contacts_reported = 8
			child.body_entered.connect(_on_body_entered)
			break
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _on_body_entered(body: Node) -> void:
	if not is_inside_tree():
		return
	if _has_collided:
		return
	_has_collided = true

	if impact_sounds.is_empty():
		return

	var pos = global_position
	var audio := AudioStreamPlayer3D.new()
	audio.stream = impact_sounds[randi() % impact_sounds.size()]
	audio.pitch_scale = randf_range(min_pitch, max_pitch)
	audio.volume_db = randf_range(min_volume_db, max_volume_db)
	audio.global_position = pos
	get_tree().current_scene.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
