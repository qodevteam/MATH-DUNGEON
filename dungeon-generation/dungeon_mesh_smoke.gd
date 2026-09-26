extends SceneTree

# Temporary smoke test: DunMesh must produce a single "LEVEL" child made of
# local (non-instanced) mesh nodes with correct scene ownership, and that
# structure must survive save->reload (game load) and duplicate (copy/paste).
# Run: godot --headless --path <project> --script dungeon_mesh_smoke.gd

const SCENE := "res://dungeon-generation/dungeon_level_generation.tscn"
const RT_PATH := "user://dungeon_mesh_roundtrip.tscn"

var _done := false


func _init() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		print("SMOKE FAIL: could not load scene")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	var dm: Node = scene.get_node_or_null("DunMesh")
	if dm == null:
		print("SMOKE FAIL: DunMesh not found")
		quit(1)
		return

	dm.create_dungeon()

	var last := -1
	var stable := 0
	for i in 6000:
		await process_frame
		var lvl: Node = dm.get_node_or_null("LEVEL")
		var n: int = lvl.get_child_count() if lvl else -1
		if dm.get_child_count() == 1 and n == last and n >= 0:
			stable += 1
			if stable > 30:
				break
		else:
			stable = 0
			last = n

	_evaluate(scene, dm)


# Structural fingerprint of LEVEL: per-direct-child sorted descendant name
# lists plus aggregate counts. Two snapshots equal => identical geometry
# (removed walls/doors stay removed through save/load and copy).
func _snapshot(lvl: Node) -> Dictionary:
	var cells := {}
	var total := 0
	var meshes := 0
	var inst := 0
	for c in lvl.get_children():
		var names: Array[String] = []
		var stack: Array[Node] = [c]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			total += 1
			if n.scene_file_path != "":
				inst += 1
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				meshes += 1
			names.append(String(n.name))
			for k in n.get_children():
				stack.append(k)
		names.sort()
		cells[String(c.name)] = names
	return {"cells": cells, "total": total, "meshes": meshes, "instances": inst}


func _compare(tag: String, a: Dictionary, b: Dictionary) -> int:
	var fails := 0
	if a.total != b.total:
		print("SMOKE FAIL[", tag, "]: node total ", a.total, " -> ", b.total)
		fails += 1
	if a.meshes != b.meshes:
		print("SMOKE FAIL[", tag, "]: mesh total ", a.meshes, " -> ", b.meshes)
		fails += 1
	if b.instances != 0:
		print("SMOKE FAIL[", tag, "]: ", b.instances, " scene-file links after copy")
		fails += 1
	var ca: Dictionary = a.cells
	var cb: Dictionary = b.cells
	if ca.size() != cb.size():
		print("SMOKE FAIL[", tag, "]: cell count ", ca.size(), " -> ", cb.size())
		fails += 1
	for key in ca:
		if not cb.has(key):
			print("SMOKE FAIL[", tag, "]: missing cell ", key)
			fails += 1
		elif not _arr_eq(ca[key], cb[key]):
			print(
				"SMOKE FAIL[", tag, "]: cell ", key, " structure changed (", (ca[key] as Array).size(), " -> ", (cb[key] as Array).size(), " descendants)"
			)
			fails += 1
	return fails


func _arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true


func _get_level(from: Node) -> Node:
	var d: Node = from.get_node_or_null("DunMesh")
	return d.get_node_or_null("LEVEL") if d else null


func _evaluate(scene: Node, dm: Node) -> void:
	var fails := 0

	if dm.get_child_count() != 1 or dm.get_child(0).name != "LEVEL":
		print("SMOKE FAIL: DunMesh children != single LEVEL, got ", dm.get_child_count())
		quit(1)
		return

	var lvl: Node = dm.get_node("LEVEL")
	print("LEVEL child count: ", lvl.get_child_count())
	if lvl.get_child_count() == 0:
		print("SMOKE FAIL: LEVEL is empty")
		fails += 1

	var snap := _snapshot(lvl)
	print("nodes under LEVEL: ", snap.total, ", MeshInstance with mesh: ", snap.meshes)
	print("scene instances left: ", snap.instances)

	if snap.instances > 0:
		print("SMOKE FAIL: ", snap.instances, " nodes still reference external scenes")
		fails += 1
	if snap.meshes == 0:
		print("SMOKE FAIL: no local meshes found")
		fails += 1

	# ownership (only valid on the original in-tree build)
	var unowned := 0
	var stack: Array[Node] = [lvl]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.owner != scene and n != lvl:
			unowned += 1
		for c in n.get_children():
			stack.append(c)
	if unowned > 0:
		print("SMOKE FAIL: ", unowned, " nodes not owned by scene root (won't save)")
		fails += 1

	# deterministic names: cells are CELL 1..N, stairs keep stair_x_y_z
	var bad_names := 0
	var cell_re := RegEx.new()
	cell_re.compile("^CELL \\d+$")
	var stair_re := RegEx.new()
	stair_re.compile("^stair_-?\\d+_-?\\d+_-?\\d+$")
	for c in lvl.get_children():
		var nm := String(c.name)
		if not (cell_re.search(nm) or stair_re.search(nm)):
			bad_names += 1
			if bad_names <= 5:
				print("SMOKE FAIL: unexpected child name: ", nm)
	if bad_names > 0:
		fails += 1

	# ---- round trip: pack -> save -> reload -> instantiate (game load path)
	var ps := PackedScene.new()
	var err := ps.pack(scene)
	if err != OK:
		print("SMOKE FAIL: pack() error ", err)
		fails += 1
	else:
		err = ResourceSaver.save(ps, RT_PATH)
		if err != OK:
			print("SMOKE FAIL: ResourceSaver.save error ", err)
			fails += 1
		else:
			var reloaded: PackedScene = ResourceLoader.load(
				RT_PATH, "", ResourceLoader.CACHE_MODE_REPLACE
			)
			if reloaded == null:
				print("SMOKE FAIL: reload of saved scene failed")
				fails += 1
			else:
				var scene2: Node = reloaded.instantiate()
				var lvl2: Node = _get_level(scene2)
				if lvl2 == null:
					print("SMOKE FAIL: LEVEL missing after save/reload")
					fails += 1
				else:
					var snap2 := _snapshot(lvl2)
					fails += _compare("roundtrip", snap, snap2)
					if fails == 0:
						print(
							"ROUNDTRIP PASS: ", snap2.total, " nodes, ", snap2.meshes, " meshes survive save->reload"
						)
				scene2.free()

	# ---- duplicate: editor copy/paste proxy.
	# Duplicate LEVEL itself (scene_file_path == "", so no re-instantiation
	# of the on-disk scene can occur - github.com/godotengine/godot/issues/76593).
	var dup: Node = lvl.duplicate()
	var snap3 := _snapshot(dup)
	fails += _compare("duplicate", snap, snap3)
	dup.free()

	if fails == 0:
		print("SMOKE PASS")
		quit(0)
	else:
		print("SMOKE FAIL: ", fails, " failure(s)")
		quit(1)
