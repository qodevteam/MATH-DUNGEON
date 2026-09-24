extends SceneTree

# Temporary self-test for the 3D dungeon generation pipeline.
# Run: godot --headless --script res://dungeon_selftest.gd
# Exit code 0 = all checks passed.


func _init() -> void:
	var failures := 0
	failures += _test_delaunay()
	failures += _test_pathfinder()
	failures += _test_generate()
	if failures == 0:
		print("SELFTEST: ALL PASSED")
	quit(1 if failures > 0 else 0)


func _test_delaunay() -> int:
	print("--- delaunay_3d ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pts := PackedVector3Array()
	for i in 16:
		pts.append(Vector3(rng.randf_range(0, 40), rng.randi_range(0, 2), rng.randf_range(0, 40)))

	var edges := DunDelaunay3D.triangulate(pts)
	if edges.is_empty():
		print("FAIL: no edges produced")
		return 1
	var seen := {}
	for e in edges:
		if e.x < 0 or e.y < 0 or e.x >= pts.size() or e.y >= pts.size():
			print("FAIL: edge out of range ", e)
			return 1
		if e.x == e.y:
			print("FAIL: self edge ", e)
			return 1
		if seen.has(e):
			print("FAIL: duplicate edge ", e)
			return 1
		seen[e] = true
	# connectivity sanity: every vertex should appear in at least one edge
	var used := {}
	for e in edges:
		used[e.x] = true
		used[e.y] = true
	if used.size() != pts.size():
		print("WARN: ", pts.size() - used.size(), " isolated vertices (may be normal)")
	print("OK: ", edges.size(), " unique edges over ", pts.size(), " points")
	return 0


func _test_pathfinder() -> int:
	print("--- pathfinder_3d ---")
	var pf := DunPathfinder3D.new(Vector3i(12, 2, 12))

	# border walls
	for x in 12:
		pf.set_cell(Vector3i(x, 0, 0), 3)
		pf.set_cell(Vector3i(x, 0, 11), 3)
		pf.set_cell(Vector3i(0, 0, x), 3)
		pf.set_cell(Vector3i(11, 0, x), 3)
	# room A on floor 0 (solid), with an open exit at (3, 0, 3)
	for x in range(1, 4):
		for z in range(1, 4):
			pf.set_cell(Vector3i(x, 0, z), 0)
	# room B on floor 1, open entry at (8, 1, 8)
	for x in range(8, 11):
		for z in range(8, 11):
			pf.set_cell(Vector3i(x, 1, z), 0)

	var start := Vector3i(3, 0, 3)
	var goal := Vector3i(8, 1, 8)
	pf.set_cell(start, 2)
	pf.set_cell(goal, 2)

	var path := pf.find_path(start, goal)
	if path.is_empty():
		print("FAIL: no path between floors")
		return 1
	if path[0] != start or path[path.size() - 1] != goal:
		print("FAIL: path endpoints wrong")
		return 1

	var vertical := 0
	for i in range(1, path.size()):
		if path[i].y != path[i - 1].y:
			vertical += 1
			var d: Vector3i = path[i] - path[i - 1]
			if absi(d.y) != 1 or maxi(absi(d.x), absi(d.z)) != 3:
				print("FAIL: vertical step has wrong shape: ", d)
				return 1
	if vertical == 0:
		print("FAIL: path never changed floors")
		return 1
	print("OK: path len=", path.size(), " stair jumps=", vertical)
	return 0


func _test_generate() -> int:
	print("--- dungeon.generate ---")
	var d = load("res://dungeon-generation/dungeon.gd").new()
	var gm := GridMap.new()
	d.grid_map = gm
	d.border_size = 24
	d.floor_count = 3
	d.room_number = 18
	d.min_room_size = 2
	d.max_room_size = 6
	d.survival_chance = 0.125
	d.custom_seed = "selftest"
	d.generate()

	var counts := {-1: 0, 0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	var room_y := {}
	for c in gm.get_used_cells():
		var item: int = gm.get_cell_item(c)
		if not counts.has(item):
			print("FAIL: unexpected item ", item, " at ", c)
			return 1
		counts[item] = counts[item] + 1
		if item == 0:
			room_y[c.y] = true

	print("counts: rooms=", counts[0], " halls=", counts[1], " doors=", counts[2],
		" border=", counts[3], " stairs=", counts[4])

	if counts[0] == 0:
		print("FAIL: no rooms")
		return 1
	if room_y.size() < 2:
		print("FAIL: rooms only on one floor")
		return 1
	if counts[1] == 0:
		print("FAIL: no hallways carved")
		return 1
	if counts[4] == 0:
		print("FAIL: no stair cells carved")
		return 1
	if counts[4] % 4 != 0:
		print("FAIL: stair cell count not a multiple of 4: ", counts[4])
		return 1
	if counts[2] < 2:
		print("FAIL: no doors")
		return 1
	print("OK: multi-floor dungeon generated with stairs")
	return 0
