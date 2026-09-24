@tool
extends Node3D

@export var dungeon_cell_scene: PackedScene
@export var dungeon_stair_scene: PackedScene
@export var grid_map_path: NodePath
@export var hide_grid_map_after_build := true
@export var remove_cell_collision := false

@onready var grid_map: GridMap = get_node(grid_map_path)

@export var start: bool = false:
	set = set_start

# dungeon_stair.tscn ascends along +X (rotation X = -90 deg, origin bottom-center).
# Set to false if placed stairs run downhill instead of uphill.
const STAIR_ASCENDS_ALONG_POSITIVE_X := true

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

	grid_map.visible = true

	for c in get_children():
		remove_child(c)
		c.queue_free()

	var t := 0

	for cell in grid_map.get_used_cells():
		var cell_index: int = grid_map.get_cell_item(cell)
		if cell_index < 0 or cell_index == 3:
			continue
		if cell_index > 2 and cell_index != 4:
			continue

		# stairs reuse the hallway wall/door rules in the handle matrix
		var cell_type := 1 if cell_index == 4 else cell_index

		var dun_cell: Node3D = dungeon_cell_scene.instantiate()
		dun_cell.position = Vector3(cell) * grid_map.cell_size
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
				var n_type := 1 if cell_n_index == 4 else cell_n_index
				var key: String = str(cell_type) + str(n_type)
				call("handle_" + key, dun_cell, direction)

		if cell_index == 4:
			_open_stair_shaft(cell, dun_cell)
			_maybe_place_stair(cell)

		if remove_cell_collision:
			for body in dun_cell.find_children("*", "StaticBody3D", true, false):
				body.free()

		t += 1
		if t % 10 == 0:
			await get_tree().process_frame

	if remove_cell_collision:
		grid_map.use_collision = false

	if hide_grid_map_after_build:
		grid_map.hide()


# Stair cell vertical openings: the ramp and the standing player pass through
# the ceiling of the lower stair row and the floor of the upper stair row.
func _open_stair_shaft(cell: Vector3i, dun_cell: Node3D) -> void:
	if grid_map.get_cell_item(cell + Vector3i(0, 1, 0)) == 4:
		dun_cell.call("remove_ceiling")
	if grid_map.get_cell_item(cell + Vector3i(0, -1, 0)) == 4:
		dun_cell.call("remove_floor")


# Places one stair mesh per 2x2 stair block (cell "c1" = lower-row cell next to
# the entry hallway). Grid layout carved by dungeon.gd:
#   lower floor y:   [entry] [c1] [c2]          exit lives at y+1 beyond c2
#   upper floor y+1:        [c1 up] [c2 up]
func _maybe_place_stair(cell: Vector3i) -> void:
	if dungeon_stair_scene == null:
		return
	# lower row only (has stair cells above it)
	if grid_map.get_cell_item(cell + Vector3i(0, 1, 0)) != 4:
		return

	# find the direction toward the partner lower-row stair cell
	var s := Vector3i.ZERO
	for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if (
			grid_map.get_cell_item(cell + d) == 4
			and grid_map.get_cell_item(cell + d + Vector3i(0, 1, 0)) == 4
		):
			s = d
			break
	if s == Vector3i.ZERO:
		return

	# c1 is the cell with the entry hallway behind it (-s) and the exit
	# hallway at upper floor beyond its partner (+2s, y+1)
	var entry := grid_map.get_cell_item(cell - s)
	if entry != 1 and entry != 2:
		return
	var exit := grid_map.get_cell_item(cell + s * 2 + Vector3i(0, 1, 0))
	if exit != 1 and exit != 2:
		return

	var partner := cell + s
	var center := Vector3(cell + partner) * 0.5 * grid_map.cell_size

	var stair: Node3D = dungeon_stair_scene.instantiate()
	stair.position = center
	stair.rotation = Vector3(0, _stair_yaw(s), 0)
	add_child(stair)
	stair.set_owner(owner)


# Yaw that points the scene's +X ascent along grid direction s.
func _stair_yaw(s: Vector3i) -> float:
	var yaw := 0.0
	if s == Vector3i(1, 0, 0):
		yaw = 0.0
	elif s == Vector3i(-1, 0, 0):
		yaw = PI
	elif s == Vector3i(0, 0, 1):
		yaw = -PI / 2.0
	else:
		yaw = PI / 2.0
	if not STAIR_ASCENDS_ALONG_POSITIVE_X:
		yaw += PI
	return yaw


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
