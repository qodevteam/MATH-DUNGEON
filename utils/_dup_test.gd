extends SceneTree

## Temporary headless test: duplicate generated dungeon nodes and report
## "Child node disappeared while duplicating" errors. Run:
## godot --headless --path <proj> -s res://utils/_dup_test.gd -- <mode>
## modes: all | scene | gen | rc | rooms | pre | scenechildren | genchildren

var frame := 0
var scene: Node = null
var gen: Node = null
var done_frame := -1
var ran := false
var mode := "all"
var seeded := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if ["all", "scene", "gen", "rc", "rooms", "pre", "scenechildren", "genchildren"].has(a):
			mode = a
	scene = load("res://multiplayer_example/DungeonTest.tscn").instantiate()
	gen = scene.get_node_or_null("DungeonGenerator3D")
	if not gen:
		print("DUP_TEST_FAIL: no DungeonGenerator3D")
		quit(1)
		return
	# The scene wires RandomNumberMultiplayer.got_random_int -> generate(randi()).
	# Disconnect it so we can drive a fixed seed ourselves.
	var rnm = scene.get_node_or_null("RandomNumberMultiplayer")
	if rnm and rnm.is_connected("got_random_int", Callable(gen, "generate")):
		rnm.disconnect("got_random_int", Callable(gen, "generate"))
		print("SEED_WIRING_DISCONNECTED")
	root.add_child(scene)
	gen.generate(424242)
	print("SEED_REQUESTED")

func _process(_delta: float) -> bool:
	frame += 1
	if not gen:
		return false
	# Keep debug visuals forced on in game mode (they default off outside editor)
	if frame > 1:
		gen.show_debug_in_game = true
		gen.hide_debug_visuals_for_all_generated_rooms = false
		for c in gen.get_children():
			if c is DungeonRoom3D:
				c.show_debug_in_game = true
		var rc0 = gen.get_node_or_null("RoomsContainer")
		if rc0:
			for c in rc0.get_children():
				if c is DungeonRoom3D:
					c.show_debug_in_game = true
	if done_frame == -1 and frame > 5 and not gen.is_currently_generating:
		done_frame = frame
	if done_frame != -1 and frame >= done_frame + 8 and not ran:
		ran = true
		_run_tests()
		quit(0)
	elif frame > 900:
		if not ran:
			print("DUP_TEST_TIMEOUT")
			_run_tests()
		quit(2)
	return false

func _child_names(n: Node, include_internal: bool) -> PackedStringArray:
	var names := PackedStringArray()
	for c in n.get_children(include_internal):
		names.append(c.name)
	return names

func _dup(target: Node) -> void:
	var is_gen := target.name == "DungeonGenerator3D"
	if is_gen:
		print("GEN_ORIG all=", _child_names(target, true), " noninternal=", _child_names(target, false))
	var d = target.duplicate(15)
	if is_gen:
		if d:
			print("GEN_DUP  all=", _child_names(d, true), " noninternal=", _child_names(d, false))
		else:
			print("GEN_DUP <null - duplicate() failed>")
	if d:
		d.free()

func _run_tests() -> void:
	print("DUP_TEST_START mode=", mode, " done_frame=", done_frame)
	var targets: Array[Node] = []
	var rc = gen.get_node_or_null("RoomsContainer")
	match mode:
		"all":
			targets = [scene, gen]
			if rc: targets.append(rc)
			for c in (rc.get_children() if rc else []): targets.append(c)
			for c in gen.get_children():
				if c is DungeonRoom3D: targets.append(c)
		"scene":
			targets = [scene]
		"gen":
			targets = [gen]
		"rc":
			if rc: targets = [rc]
		"rooms":
			if rc:
				for c in rc.get_children(): targets.append(c)
		"pre":
			for c in gen.get_children():
				if c is DungeonRoom3D: targets.append(c)
		"scenechildren":
			for c in scene.get_children(): targets.append(c)
		"genchildren":
			for c in gen.get_children(): targets.append(c)
	for t in targets:
		print("DUPING: ", t.name)
		_dup(t)
	print("DUP_TEST_DONE mode=", mode, " targets=", targets.size())
