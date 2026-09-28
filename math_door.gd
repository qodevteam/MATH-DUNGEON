extends Node3D

class_name MathDoor

signal door_unlocked

@export var difficulty: int = 1
@export var question_duration: float = 15.0
@export var animation_player: AnimationPlayer
@export var interactable: InteractableComponent
@export var collision_shape: CollisionShape3D
@export var door_mesh: Node3D

var _math_ui: Control = null

func _ready() -> void:
	var area := get_node_or_null("Area3D") as Area3D
	if not area:
		for child in get_children():
			if child is Area3D:
				area = child
				break

	if area:
		var area_comp := area.get_node_or_null("InteractableComponent") as InteractableComponent
		if not area_comp:
			print("MathDoor: Adding InteractableComponent to %s" % area.get_path())
			area_comp = InteractableComponent.new()
			area_comp.name = "InteractableComponent"
			area.add_child(area_comp)

		area_comp.interacted.connect(_on_interacted)
		print("MathDoor: Connected to Area3D InteractableComponent at %s" % area_comp.get_path())
	else:
		push_error("MathDoor: No Area3D found in DoorInteractable")

	if interactable and interactable != area.get_node_or_null("InteractableComponent"):
		interactable.interacted.connect(_on_interacted)
		print("MathDoor: Also connected to exported InteractableComponent at %s" % interactable.get_path())

func _on_interacted() -> void:
	print("MathDoor: interacted signal received")

	if not _math_ui:
		var existing = get_tree().root.find_child("MathUIEquationDisplayer", true, false)
		if existing and existing is Control:
			_math_ui = existing
			_math_ui.visible = true
		else:
			var ui_scene = preload("res://math_ui_equation_displayer.tscn")
			if not ui_scene:
				push_error("MathDoor: math_ui_equation_displayer.tscn not found")
				return
			_math_ui = ui_scene.instantiate()
			get_tree().root.add_child(_math_ui)

	if not _math_ui.door_unlocked.is_connected(_unlock):
		_math_ui.door_unlocked.connect(_unlock)

	var q = _math_ui.generate_question(difficulty)
	var player = _find_player()
	print("MathDoor: showing question '%s', player=%s" % [q.text, player.get_path() if player else "NONE"])
	_math_ui.show_question(q.text, q.options, q.correct_index, self, player, difficulty)

func _find_player() -> CharacterBody3D:
	var root := get_tree().root
	for child in root.get_children():
		if child is CharacterBody3D and child.name.to_lower().find("player") != -1:
			return child
		var found := _find_player_recursive(child)
		if found:
			return found
	return null

func _find_player_recursive(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D and node.name.to_lower().find("player") != -1:
		return node
	for child in node.get_children():
		var found := _find_player_recursive(child)
		if found:
			return found
	return null

func _unlock(_door_ref: Node) -> void:
	door_unlocked.emit()
	print("✅ Door unlocked signal emitted")

	if animation_player and animation_player.has_animation("UNLOCK DOOR"):
		print("MathDoor: Playing UNLOCK DOOR animation")
		animation_player.play("UNLOCK DOOR")
		await animation_player.animation_finished
	else:
		print("MathDoor: Skipping animation (animation_player=%s)" % (animation_player.get_path() if animation_player else "NONE"))

	if collision_shape:
		collision_shape.disabled = true
		print("MathDoor: Disabled trigger collision at %s" % collision_shape.get_path())

	var static_body := get_node_or_null("StaticBody3D") as StaticBody3D
	if static_body:
		var static_shape := static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if static_shape:
			static_shape.disabled = true
			print("MathDoor: Disabled static collision at %s" % static_shape.get_path())

	print("✅ Door collision disabled")
