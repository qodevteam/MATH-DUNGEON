@tool
extends Node3D

## Auto-attached by DungeonGenerator3D to its RoomsContainer.
## Hides SimpleDungeons debug/wireframe visuals in the 3D viewport.
@export var hide_debug_ui: bool = true:
	set(value):
		hide_debug_ui = value
		_apply()

func _ready() -> void:
	child_entered_tree.connect(_on_child_entered)
	_apply()

func _on_child_entered(node: Node) -> void:
	if node is DungeonRoom3D:
		_apply_to(node)

func _apply() -> void:
	var gen := get_parent()
	if gen is DungeonGenerator3D:
		_apply_to(gen)
		for c in gen.get_children():
			if c is DungeonRoom3D:
				_apply_to(c)
	for c in get_children():
		if c is DungeonRoom3D:
			_apply_to(c)

func _apply_to(node: Node) -> void:
	node.show_debug_in_editor = not hide_debug_ui
