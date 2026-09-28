extends Node

var settings: SettingsManager

func _ready() -> void:
	settings = SettingsManager.new()
	settings.load_settings()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_initial_apply")

func _initial_apply() -> void:
	for i in 10:
		await get_tree().process_frame
		if get_tree().current_scene:
			break
	_apply_current_scene()

func reload_settings() -> void:
	settings.load_settings()
	_apply_current_scene()

func _apply_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	settings.apply_render_distance(scene)
	settings.apply_quality(scene, settings.quality_level)

func _on_node_added(node: Node) -> void:
	if settings == null:
		return
	if node is GeometryInstance3D:
		settings.apply_range_to(node)
	settings.apply_quality_to(node, settings.quality_level)
