extends Resource
class_name SettingsManager

var is_fullscreen: bool = false
var resolution_index: int = 2
var vsync_enabled: bool = true
var quality_level: int = 1
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
