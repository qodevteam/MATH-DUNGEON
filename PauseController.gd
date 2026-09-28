extends Node

var menu: Control
var is_open := false
var _tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	menu = (load("res://pause_menu.tscn") as PackedScene).instantiate() as Control
	layer.add_child(menu)
	menu.visible = false
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.get_node("PAUSEPanel/VBoxContainer/RESUME").pressed.connect(close)
	menu.get_node("PAUSEPanel/CLOSE PAUSE MENU").pressed.connect(close)
	menu.get_node("PAUSEPanel/VBoxContainer/QUIT").pressed.connect(_on_quit)
	menu.get_node("PAUSEPanel/VBoxContainer/SETTINGS").pressed.connect(_on_settings)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open:
			close()
		else:
			open()

func _game_scene_active() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var path := str(scene.scene_file_path)
	return not path.ends_with("maaain-menu.scene.tscn") and not path.ends_with("pause_menu.tscn")

func open() -> void:
	if is_open or not _game_scene_active():
		return
	is_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu.visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var bg: ColorRect = menu.get_node("Background")
	var panel: Panel = menu.get_node("PAUSEPanel")
	bg.modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(bg, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween and _tween.is_valid():
		_tween.kill()
	var bg: ColorRect = menu.get_node("Background")
	var panel: Panel = menu.get_node("PAUSEPanel")
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(bg, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	_tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	_tween.tween_property(panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	menu.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_settings() -> void:
	pass

func _on_quit() -> void:
	is_open = false
	menu.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://maaain-menu.scene.tscn")
