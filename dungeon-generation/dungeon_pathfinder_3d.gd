class_name DunPathfinder3D
extends RefCounted

# 3D dungeon pathfinder with staircase support.
# Ported from https://github.com/vazgriz/DungeonGenerator
# (Scripts3D/DungeonPathfinder3D.cs + cost function from Generator3D.cs).
#
# Differences vs vanilla A*:
# - stair "jump" neighbors: 3 horizontal + 1 vertical (rise:run = 1:3 cell offset)
# - every node keeps PreviousSet (flat indices of its whole path); a neighbor is
#   rejected if it lies on the current node's path (keeps one search from cutting
#   through a staircase it just created)
# - stair cells are added to PreviousSet when a stair move is accepted
#
# Cell types: -1 None, 0 Room, 1 Hallway, 2 Door, 3 Border, 4 Stairs.

const NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(3, 1, 0), Vector3i(-3, 1, 0), Vector3i(0, 1, 3), Vector3i(0, 1, -3),
	Vector3i(3, -1, 0), Vector3i(-3, -1, 0), Vector3i(0, -1, 3), Vector3i(0, -1, -3),
]

var size: Vector3i
var cells: PackedInt32Array

var costs := PackedFloat32Array()
var prevs := PackedInt32Array()
var prev_sets: Array = []
var closed := PackedByteArray()
var open: Array[int] = []
var open_has := {}


func _init(p_size: Vector3i) -> void:
	size = p_size
	var n := size.x * size.y * size.z
	cells = PackedInt32Array()
	cells.resize(n)
	cells.fill(-1)
	costs.resize(n)
	prevs.resize(n)
	closed.resize(n)
	prev_sets.resize(n)


func in_bounds(p: Vector3i) -> bool:
	return (
		p.x >= 0 and p.x < size.x
		and p.y >= 0 and p.y < size.y
		and p.z >= 0 and p.z < size.z
	)


func get_cell(p: Vector3i) -> int:
	if not in_bounds(p):
		return 3
	return cells[_idx(p)]


func set_cell(p: Vector3i, value: int) -> void:
	if in_bounds(p):
		cells[_idx(p)] = value


# Returns the path as grid positions, or an empty array if no path exists.
func find_path(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not in_bounds(start) or not in_bounds(end):
		return result
	if start == end:
		result.append(start)
		return result

	var n := cells.size()
	costs.fill(INF)
	prevs.fill(-1)
	closed.fill(0)
	prev_sets.clear()
	prev_sets.resize(n)
	open.clear()
	open_has.clear()

	var si := _idx(start)
	costs[si] = 0.0
	open.append(si)
	open_has[si] = true

	while not open.is_empty():
		# linear min-extract (grid is small; runs once per edge at generation time)
		var best := 0
		for i in range(1, open.size()):
			if costs[open[i]] < costs[open[best]]:
				best = i
		var cur: int = open[best]
		open.remove_at(best)
		open_has.erase(cur)
		closed[cur] = 1

		if cur == _idx(end):
			return _reconstruct(cur)

		var cpos := _pos(cur)
		var cset: Dictionary = prev_sets[cur] if prev_sets[cur] != null else {}

		for offset in NEIGHBORS:
			var np := cpos + offset
			if not in_bounds(np):
				continue
			var ni := _idx(np)
			if closed[ni] == 1:
				continue
			if cset.has(ni):
				continue

			var is_stairs := false
			var stair_cells: Array[int] = []
			var step := 0.0

			if offset.y == 0:
				# flat hallway move
				var t := cells[ni]
				if t == 0 or t == 3:
					continue  # rooms and borders are solid
				step = Vector3(cpos).distance_to(Vector3(np))
				if t == -1:
					step += 1.0  # carving new hallway costs extra
				# hallway / door / existing stairs: no extra cost
			else:
				# staircase move: endpoints must be plain None/Hallway
				var a_t := cells[cur]
				var b_t := cells[ni]
				if a_t != -1 and a_t != 1:
					continue
				if b_t != -1 and b_t != 1:
					continue
				var h := Vector3i(signi(offset.x), 0, signi(offset.z))
				var v := Vector3i(0, offset.y, 0)
				var s1 := cpos + h
				var s2 := cpos + h * 2
				var s3 := cpos + v + h
				var s4 := cpos + v + h * 2
				if not in_bounds(s1) or not in_bounds(s2) or not in_bounds(s3) or not in_bounds(s4):
					continue
				# all four stair cells must be fresh empty cells
				if cells[_idx(s1)] != -1 or cells[_idx(s2)] != -1:
					continue
				if cells[_idx(s3)] != -1 or cells[_idx(s4)] != -1:
					continue
				# ... and none may lie on this search's own path
				if cset.has(_idx(s1)) or cset.has(_idx(s2)):
					continue
				if cset.has(_idx(s3)) or cset.has(_idx(s4)):
					continue
				stair_cells = [_idx(s1), _idx(s2), _idx(s3), _idx(s4)]
				step = 100.0 + Vector3(cpos).distance_to(Vector3(np))
				is_stairs = true

			var new_cost := costs[cur] + step
			if new_cost >= costs[ni]:
				continue
			costs[ni] = new_cost
			prevs[ni] = cur

			var ns: Dictionary = cset.duplicate()
			ns[cur] = true
			if is_stairs:
				for sc in stair_cells:
					ns[sc] = true
			prev_sets[ni] = ns

			if not open_has.has(ni):
				open.append(ni)
				open_has[ni] = true

	return result


func _reconstruct(i: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	while i >= 0:
		path.append(_pos(i))
		i = prevs[i]
	path.reverse()
	return path


func _idx(p: Vector3i) -> int:
	return p.x + size.x * p.y + size.x * size.y * p.z


func _pos(i: int) -> Vector3i:
	@warning_ignore("integer_division")
	var y := i / size.x
	@warning_ignore("integer_division")
	var z := i / (size.x * size.y)
	return Vector3i(i % size.x, y % size.y, z)
