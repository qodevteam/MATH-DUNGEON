@tool
extends Node3D

@export var dungeon_cell_scene: PackedScene
@export var grid_map_path: NodePath
@export var hide_grid_map_after_build := true
@export var remove_cell_collision := false

@onready var grid_map: GridMap = get_node(grid_map_path)

@export var start: bool = false:
	set = set_start

var directions := {
	"up": Vector3i.FORWARD,
	"down": Vector3i.BACK,
	"left": Vector3i.LEFT,
	"right": Vector3i.RIGHT,
}


func set_start(value: bool) -> void:
	if Engine.is_editor_hint() and grid_map:
		create_dungeon()


func create_dungeon() -> void:
	if dungeon_cell_scene == null:
		return

	for c in get_children():
		remove_child(c)
		c.queue_free()

	var t := 0

	for cell in grid_map.get_used_cells():
		t += 1

		var cell_index: int = grid_map.get_cell_item(cell)
		if cell_index < 0 or cell_index > 2:
			continue

		var dun_cell: Node3D = dungeon_cell_scene.instantiate()
		dun_cell.position = Vector3(cell) * grid_map.cell_size.x
		add_child(dun_cell)
		dun_cell.set_owner(owner)

		var dir_keys := directions.keys()
		var dir_values := directions.values()

		for i in 4:
			var cell_n: Vector3i = cell + dir_values[i]
			var cell_n_index: int = grid_map.get_cell_item(cell_n)
			var direction: String = dir_keys[i]

			if cell_n_index < 0 or cell_n_index == 3:
				handle_none(dun_cell, direction)
			else:
				var key: String = str(cell_index) + str(cell_n_index)
				call("handle_" + key, dun_cell, direction)

		if t % 10 == 9:
			await get_tree().process_frame


func handle_none(cell: Node3D, direction: String) -> void:
	cell.call("remove_door_" + direction)


func handle_00(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)
	cell.call("remove_door_" + direction)


func handle_01(cell: Node3D, direction: String) -> void:
	cell.call("remove_door_" + direction)


func handle_02(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)
	cell.call("remove_door_" + direction)


func handle_10(cell: Node3D, direction: String) -> void:
	cell.call("remove_door_" + direction)


func handle_11(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)
	cell.call("remove_door_" + direction)


func handle_12(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)
	cell.call("remove_door_" + direction)


func handle_20(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)
	cell.call("remove_door_" + direction)


func handle_21(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)


func handle_22(cell: Node3D, direction: String) -> void:
	cell.call("remove_wall_" + direction)
	cell.call("remove_door_" + direction)
