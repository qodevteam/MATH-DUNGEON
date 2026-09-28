extends Resource
class_name SettingsManager

var is_fullscreen: bool = false
var resolution_index: int = 2
var vsync_enabled: bool = true
var quality_level: int = 1
var render_distance: float = 133.0
var master_volume: float = 80.0
var music_volume: float = 70.0
var sfx_volume: float = 90.0
var is_muted: bool = false
var is_initialized: bool = false

var SETTINGS_FILE: String = "user://settings.cfg"

func _init() -> void:
	is_initialized = false

func load_settings() -> void:
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_FILE)
	if error != OK:
		return
	
	if config.has_section_key("video", "fullscreen"):
		is_fullscreen = config.get_value("video", "fullscreen")
	if config.has_section_key("video", "resolution_index"):
		resolution_index = config.get_value("video", "resolution_index")
	if config.has_section_key("video", "vsync"):
		vsync_enabled = config.get_value("video", "vsync")
	if config.has_section_key("video", "quality"):
		quality_level = config.get_value("video", "quality")
	if config.has_section_key("video", "render_distance"):
		render_distance = clampf(float(config.get_value("video", "render_distance")), 100.0, 1000.0)
	if config.has_section_key("audio", "master_volume"):
		master_volume = config.get_value("audio", "master_volume")
	if config.has_section_key("audio", "music_volume"):
		music_volume = config.get_value("audio", "music_volume")
	if config.has_section_key("audio", "sfx_volume"):
		sfx_volume = config.get_value("audio", "sfx_volume")
	if config.has_section_key("audio", "mute"):
		is_muted = config.get_value("audio", "mute")
	
	is_initialized = true

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("video", "fullscreen", is_fullscreen)
	config.set_value("video", "resolution_index", resolution_index)
	config.set_value("video", "vsync", vsync_enabled)
	config.set_value("video", "quality", quality_level)
	config.set_value("video", "render_distance", render_distance)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "mute", is_muted)
	
	var error = config.save(SETTINGS_FILE)
	if error != OK:
		push_error("Failed to save settings: " + str(error))

func save_fullscreen(value: bool) -> void:
	is_fullscreen = value
	save_settings()

func save_resolution(index: int) -> void:
	resolution_index = index
	save_settings()

func save_vsync(value: bool) -> void:
	vsync_enabled = value
	save_settings()

func save_quality(level: int) -> void:
	quality_level = level
	save_settings()

func save_render_distance(value: float) -> void:
	render_distance = clampf(value, 100.0, 1000.0)
	save_settings()

func get_render_scale() -> float:
	return clampf(lerpf(0.6, 1.0, (render_distance - 100.0) / 900.0), 0.6, 1.0)

func apply_render_distance(root: Node) -> void:
	if root == null:
		return
	_apply_range_recursive(root)
	var vp := root.get_viewport()
	if vp:
		vp.scaling_3d_scale = get_render_scale()

func apply_range_to(node: GeometryInstance3D) -> void:
	node.visibility_range_end = render_distance
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func apply_quality(root: Node, level: int) -> void:
	if root == null:
		return
	_apply_quality_recursive(root, level)

func apply_quality_to(node: Node, level: int) -> void:
	if node is WorldEnvironment:
		var env: Environment = (node as WorldEnvironment).environment
		if env:
			env.glow_enabled = level >= 1
	elif node is GPUParticles3D:
		var particles := node as GPUParticles3D
		if not particles.has_meta("original_emitting"):
			particles.set_meta("original_emitting", particles.emitting)
		var on := level >= 2
		particles.visible = on
		particles.emitting = bool(particles.get_meta("original_emitting")) if on else false
	elif node is DirectionalLight3D:
		(node as DirectionalLight3D).shadow_enabled = level >= 1
	elif String(node.name).to_lower() == "camera-effects":
		node.visible = level >= 1

func _apply_range_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		apply_range_to(node)
	for child in node.get_children():
		_apply_range_recursive(child)

func _apply_quality_recursive(node: Node, level: int) -> void:
	apply_quality_to(node, level)
	for child in node.get_children():
		_apply_quality_recursive(child, level)

func save_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 100.0)
	save_settings()

func save_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 100.0)
	save_settings()

func save_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 100.0)
	save_settings()

func save_mute(value: bool) -> void:
	is_muted = value
	save_settings()

func get_resolution() -> Vector2i:
	var resolutions: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(1600, 900),
		Vector2i(1366, 768),
		Vector2i(1280, 720),
		Vector2i(1024, 768),
		Vector2i(800, 600),
		Vector2i(640, 480)
	]
	if resolution_index < resolutions.size():
		return resolutions[resolution_index]
	return Vector2i(1366, 768)
