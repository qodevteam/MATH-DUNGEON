@tool
extends Node3D

@export var start: bool = false:
	set = set_start

@export var border_size: int = 20:
	set = set_border_size

@export var floor_count: int = 3:
	set = set_floor_count

@export var min_room_size: int = 2
@export var max_room_size: int = 4
@export var room_number: int = 4
@export var room_margin: int = 1
@export var room_recursion: int = 15

@export_range(0.0, 1.0) var survival_chance: float = 0.25

@export var custom_seed: String = "":
	set = set_seed

@onready var grid_map: GridMap = $GridMap

var room_tiles: Array[PackedVector3Array] = []
var room_positions: PackedVector3Array = []


func set_start(value: bool) -> void:
	if Engine.is_editor_hint() and grid_map:
		generate()


func set_border_size(value: int) -> void:
	border_size = value
	if Engine.is_editor_hint() and grid_map:
		visualize_border()


func set_floor_count(value: int) -> void:
	floor_count = maxi(value, 1)
	if Engine.is_editor_hint() and grid_map:
		visualize_border()


func set_seed(value: String) -> void:
	custom_seed = value
	seed(value.hash())


func visualize_border() -> void:
	grid_map.clear()
	for y in floor_count:
		for i in range(-1, border_size + 1):
			grid_map.set_cell_item(Vector3i(i, y, -1), 3)
			grid_map.set_cell_item(Vector3i(i, y, border_size), 3)
			grid_map.set_cell_item(Vector3i(-1, y, i), 3)
			grid_map.set_cell_item(Vector3i(border_size, y, i), 3)


func generate() -> void:
	if custom_seed != "":
		set_seed(custom_seed)

	room_tiles.clear()
	room_positions.clear()
	visualize_border()

	for i in room_number:
		make_room(room_recursion)

	if room_positions.size() < 2:
		print("dungeon: not enough rooms")
		return

	var edges := _compute_room_edges()
	if edges.is_empty():
		print("dungeon: no room edges")
		return

	var selected := _select_hallway_edges(edges)
	_pathfind_hallways(selected)


func make_room(recursion: int) -> void:
	if recursion <= 0:
		return

	var width: int = randi() % (max_room_size - min_room_size) + min_room_size
	var height: int = randi() % (max_room_size - min_room_size) + min_room_size

	var start_pos := Vector3i()
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.y = randi() % floor_count
	start_pos.z = randi() % (border_size - height + 1)

	for row in range(-room_margin, height + room_margin):
		for col in range(-room_margin, width + room_margin):
			var check_pos := start_pos + Vector3i(col, 0, row)
			if grid_map.get_cell_item(check_pos) == 0:
				make_room(recursion - 1)
				return

	var room := PackedVector3Array()
	for row in height:
		for col in width:
			var pos := start_pos + Vector3i(col, 0, row)
			grid_map.set_cell_item(pos, 0)
			room.append(Vector3(pos))

	room_tiles.append(room)

	var avg_x: float = start_pos.x + width / 2.0
	var avg_z: float = start_pos.z + height / 2.0
	room_positions.append(Vector3(avg_x, start_pos.y, avg_z))


# Builds the potential-hallway edge list from room centers.
# 3D tetrahedralization when rooms sit on different floors,
# 2D delaunay fallback when everything is on one floor (coplanar).
func _compute_room_edges() -> Array[Vector2i]:
	var unique := {}
	var empty: Array[Vector2i] = []
	var n := room_positions.size()
	if n < 2:
		return empty
	if n == 2:
		unique[Vector2i(0, 1)] = true

	var coplanar := true
	var y0 := room_positions[0].y
	for p in room_positions:
		if not is_equal_approx(p.y, y0):
			coplanar = false
			break

	if n >= 4 and not coplanar:
		for e in DunDelaunay3D.triangulate(room_positions):
			unique[e] = true
	else:
		var pts := PackedVector2Array()
		for p in room_positions:
			pts.append(Vector2(p.x, p.z))
		var tri := Geometry2D.triangulate_delaunay(pts)
		for i in tri.size() / 3:
			_add_edge(unique, tri[i * 3], tri[i * 3 + 1])
			_add_edge(unique, tri[i * 3 + 1], tri[i * 3 + 2])
			_add_edge(unique, tri[i * 3 + 2], tri[i * 3])

	var out: Array[Vector2i] = []
	for key in unique:
		out.append(key as Vector2i)
	return out


func _add_edge(edges: Dictionary, a: int, b: int) -> void:
	edges[Vector2i(mini(a, b), maxi(a, b))] = true


# Prim's MST over 3D edges, then re-add leftover triangulation edges
# with probability survival_chance (adds loops to the dungeon).
func _select_hallway_edges(all_edges: Array[Vector2i]) -> Array[Vector2i]:
	var n := room_positions.size()
	var visited := {0: true}
	var mst: Array[Vector2i] = []

	while visited.size() < n:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for e in all_edges:
			var a_in: bool = visited.has(e.x)
			var b_in: bool = visited.has(e.y)
			if a_in == b_in:
				continue
			var d: float = room_positions[e.x].distance_squared_to(room_positions[e.y])
			if d < best_d:
				best_d = d
				best = e
		if best.x < 0:
			break  # disconnected (should not happen)
		mst.append(best)
		if visited.has(best.x):
			visited[best.y] = true
		else:
			visited[best.x] = true

	var selected := mst.duplicate()
	var mst_keys := {}
	for e in mst:
		mst_keys[e] = true
	for e in all_edges:
		if mst_keys.has(e):
			continue
		if randf() < survival_chance:
			selected.append(e)
	return selected


# Runs the stair-aware 3D pathfinder for every selected edge and commits
# doors, hallways and stair cells to the GridMap. Edges that fail to
# pathfind are skipped (same as the reference algorithm).
func _pathfind_hallways(selected: Array[Vector2i]) -> void:
	var pf := DunPathfinder3D.new(Vector3i(border_size, floor_count, border_size))
	for c in grid_map.get_used_cells():
		pf.set_cell(c, grid_map.get_cell_item(c))

	var carved := 0
	var failed := 0
	var stair_cells := 0

	for e in selected:
		var room_from: PackedVector3Array = room_tiles[e.x]
		var room_to: PackedVector3Array = room_tiles[e.y]
		var tile_from := _perimeter_tile(room_from, room_positions[e.y])
		var tile_to := _perimeter_tile(room_to, room_positions[e.x])
		var from := Vector3i(tile_from)
		var to := Vector3i(tile_to)
		if from == to:
			failed += 1
			continue

		# temporarily mark endpoints as doors so they are traversable
		var prev_from := pf.get_cell(from)
		var prev_to := pf.get_cell(to)
		pf.set_cell(from, 2)
		pf.set_cell(to, 2)

		var path := pf.find_path(from, to)
		if path.is_empty():
			pf.set_cell(from, prev_from)
			pf.set_cell(to, prev_to)
			failed += 1
			continue

		grid_map.set_cell_item(from, 2)
		grid_map.set_cell_item(to, 2)

		for i in path.size():
			var p: Vector3i = path[i]
			if pf.get_cell(p) == -1:
				pf.set_cell(p, 1)
				grid_map.set_cell_item(p, 1)

			if i > 0:
				var prev: Vector3i = path[i - 1]
				var d := p - prev
				if d.y != 0:
					var h := Vector3i(signi(d.x), 0, signi(d.z))
					var v := Vector3i(0, d.y, 0)
					for cp: Vector3i in [prev + h, prev + h * 2, prev + v + h, prev + v + h * 2]:
						pf.set_cell(cp, 4)
						grid_map.set_cell_item(cp, 4)
						stair_cells += 1

		carved += 1

	print(
		"dungeon: %d rooms, %d edges selected, %d paths carved, %d failed, %d stair cells"
		% [room_positions.size(), selected.size(), carved, failed, stair_cells]
	)


# Closest room-border tile to the target point (room centers are used as
# targets; interior tiles are skipped so paths always leave through a wall).
func _perimeter_tile(room: PackedVector3Array, target: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	var best_any := Vector3.ZERO
	var best_any_d := INF

	for tile in room:
		var d := tile.distance_squared_to(target)
		if d < best_any_d:
			best_any_d = d
			best_any = tile
		if not _is_perimeter(Vector3i(tile)):
			continue
		if d < best_d:
			best_d = d
			best = tile

	return best if best_d < INF else best_any


func _is_perimeter(p: Vector3i) -> bool:
	for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if grid_map.get_cell_item(p + d) != 0:
			return true
	return false
