extends Node3D

class_name MathDoor

signal door_unlocked

@export var difficulty: int = 1
@export var question_duration: float = 15.0
@export var area_3d: Area3D
@export var interactable: InteractableComponent
@export var animation_player: AnimationPlayer
@export var collision_shape: CollisionShape3D
@export var door_mesh: Node3D
@export var player: CharacterBody3D
@export var static_collision_shape: CollisionShape3D

var _math_ui: Control = null
var _area: Area3D = null
var _interactable: InteractableComponent = null

func _ready() -> void:
	_area = area_3d if area_3d else _find_area3d()
	if not _area:
		push_error("MathDoor: No Area3D found in MathDoor")
		return

	_interactable = _area.get_node_or_null("InteractableComponent") as InteractableComponent
	if not _interactable:
		print("MathDoor: Adding InteractableComponent to %s" % _area.get_path())
		_interactable = InteractableComponent.new()
		_interactable.name = "InteractableComponent"
		_area.add_child(_interactable)

	if not _interactable.interacted.is_connected(_on_interacted):
		_interactable.interacted.connect(_on_interacted)
		print("MathDoor: Connected to Area3D InteractableComponent at %s" % _interactable.get_path())

	if interactable and interactable != _interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
		print("MathDoor: Also connected to exported InteractableComponent at %s" % interactable.get_path())

func _find_area3d() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child
		var found := _find_area3d_recursive(child)
		if found:
			return found
	return null

func _find_area3d_recursive(node: Node) -> Area3D:
	for child in node.get_children():
		if child is Area3D:
			return child
		var found := _find_area3d_recursive(child)
		if found:
			return found
	return null

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
	var resolved_player = player if player else _find_player()
	print("MathDoor: showing question '%s', player=%s" % [q.text, resolved_player.get_path() if resolved_player else "NONE"])
	_math_ui.show_question(q.text, q.options, q.correct_index, self, resolved_player, difficulty)

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

	if static_collision_shape:
		static_collision_shape.disabled = true
		print("MathDoor: Disabled static collision at %s" % static_collision_shape.get_path())

	print("✅ Door collision disabled")
