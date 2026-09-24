@tool
extends Node3D

@export var start: bool = false:
	set = set_start

@export var border_size: int = 20:
	set = set_border_size

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


func set_seed(value: String) -> void:
	custom_seed = value
	seed(value.hash())


func visualize_border() -> void:
	grid_map.clear()
	for i in range(-1, border_size + 1):
		grid_map.set_cell_item(Vector3i(i, 0, -1), 3)
		grid_map.set_cell_item(Vector3i(i, 0, border_size), 3)
		grid_map.set_cell_item(Vector3i(-1, 0, i), 3)
		grid_map.set_cell_item(Vector3i(border_size, 0, i), 3)


func generate() -> void:
	if custom_seed != "":
		set_seed(custom_seed)

	room_tiles.clear()
	room_positions.clear()
	visualize_border()

	for i in room_number:
		make_room(room_recursion)

	print(room_positions)

	var room_positions_v2 := PackedVector2Array()
	for pos in room_positions:
		room_positions_v2.append(Vector2(pos.x, pos.z))

	var delaunay_graph := AStar2D.new()
	var mst_graph := AStar2D.new()

	for rp in room_positions_v2:
		delaunay_graph.add_point(delaunay_graph.get_available_point_id(), rp)
		mst_graph.add_point(mst_graph.get_available_point_id(), rp)

	var delaunay := Array(Geometry2D.triangulate_delaunay(room_positions_v2))
	for i in delaunay.size() / 3:
		delaunay_graph.connect_points(delaunay[i * 3], delaunay[i * 3 + 1])
		delaunay_graph.connect_points(delaunay[i * 3 + 1], delaunay[i * 3 + 2])
		delaunay_graph.connect_points(delaunay[i * 3 + 2], delaunay[i * 3])

	var visited_points := PackedInt32Array()
	visited_points.append(randi() % room_positions_v2.size())

	while visited_points.size() < mst_graph.get_point_count():
		var possible_connections: Array[PackedInt32Array] = []

		for visited_point in visited_points:
			for connection in delaunay_graph.get_point_connections(visited_point):
				if not visited_points.has(connection):
					var conn := PackedInt32Array([visited_point, connection])
					possible_connections.append(conn)

		var connection := possible_connections[randi() % possible_connections.size()]

		for pc in possible_connections:
			var pc_dist := delaunay_graph.get_point_position(pc[0]).distance_squared_to(
				delaunay_graph.get_point_position(pc[1])
			)
			var cur_dist := delaunay_graph.get_point_position(connection[0]).distance_squared_to(
				delaunay_graph.get_point_position(connection[1])
			)
			if cur_dist > pc_dist:
				connection = pc

		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0], connection[1])
		delaunay_graph.disconnect_points(connection[0], connection[1])

	var hallway_graph: AStar2D = mst_graph

	for point in delaunay_graph.get_point_ids():
		for connection in delaunay_graph.get_point_connections(point):
			if connection > point:
				var kill := randf()
				if survival_chance > kill:
					hallway_graph.connect_points(point, connection)

	draw_hallways(hallway_graph)


func make_room(recursion: int) -> void:
	if recursion <= 0:
		return

	var width: int = randi() % (max_room_size - min_room_size) + min_room_size
	var height: int = randi() % (max_room_size - min_room_size) + min_room_size

	var start_pos := Vector3i()
	start_pos.x = randi() % (border_size - width + 1)
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
	room_positions.append(Vector3(avg_x, 0, avg_z))


func draw_hallways(graph: AStar2D) -> void:
	var hallways: Array[PackedVector3Array] = []

	for point in graph.get_point_ids():
		for connection in graph.get_point_connections(point):
			if connection > point:
				var room_from: PackedVector3Array = room_tiles[point]
				var room_to: PackedVector3Array = room_tiles[connection]

				var tile_from: Vector3 = room_from[0]
				var tile_to: Vector3 = room_to[0]

				for tile in room_from:
					if tile.distance_to(room_positions[connection]) < tile_from.distance_to(
						room_positions[connection]
					):
						tile_from = tile

				for tile in room_to:
					if tile.distance_to(room_positions[point]) < tile_to.distance_to(
						room_positions[point]
					):
						tile_to = tile

				var temp_hallway := PackedVector3Array([tile_from, tile_to])
				hallways.append(temp_hallway)

				grid_map.set_cell_item(Vector3i(tile_from), 2)
				grid_map.set_cell_item(Vector3i(tile_to), 2)

	var a_star := AStarGrid2D.new()
	a_star.size = Vector2i.ONE * border_size
	a_star.update()
	a_star.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	a_star.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

	for tile in grid_map.get_used_cells_by_item(0):
		a_star.set_point_solid(Vector2i(tile.x, tile.z))

	for hallway in hallways:
		var pos_from := Vector2i(hallway[0].x, hallway[0].z)
		var pos_to := Vector2i(hallway[1].x, hallway[1].z)
		var path := a_star.get_id_path(pos_from, pos_to)

		for t in path:
			var position := Vector3i(t.x, 0, t.y)
			if grid_map.get_cell_item(position) == -1:
				grid_map.set_cell_item(position, 1)
