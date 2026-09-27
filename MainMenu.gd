extends Control

@export var main_scene_path: String = "res://FPSController/FPSController.tscn"

var settings_manager: SettingsManager = null
var current_tab: int = 0
var is_fullscreen: bool = false
var current_resolution: int = 2
var vsync_enabled: bool = true
var current_quality: int = 1
var is_muted: bool = false

var settings_panel: Panel
var settings_tab_container: TabContainer
var fullscreen_button: Button
var resolution_option: OptionButton
var vsync_button: Button
var quality_option: OptionButton
var master_volume_slider: HSlider
var master_volume_label: Label
var music_volume_slider: HSlider
var music_volume_label: Label
var sfx_volume_slider: HSlider
var sfx_volume_label: Label
var mute_button: Button

var resolutions: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(1024, 768),
	Vector2i(800, 600),
	Vector2i(640, 480)
]

func _enter_tree() -> void:
	call_deferred("init_nodes")

func init_nodes() -> void:
	settings_manager = SettingsManager.new()
	settings_manager.load_settings()
	settings_panel = get_node_or_null("SettingsPanel") as Panel
	if not settings_panel:
		return
	settings_tab_container = get_node_or_null("SettingsPanel/SettingsTabContainer") as TabContainer
	fullscreen_button = get_node_or_null("SettingsPanel/SettingsTabContainer/VideoTab/FullscreenButton") as Button
	resolution_option = get_node_or_null("SettingsPanel/SettingsTabContainer/VideoTab/ResolutionOption") as OptionButton
	vsync_button = get_node_or_null("SettingsPanel/SettingsTabContainer/VideoTab/VSyncButton") as Button
	quality_option = get_node_or_null("SettingsPanel/SettingsTabContainer/VideoTab/QualityOption") as OptionButton
	master_volume_slider = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/MasterVolume") as HSlider
	master_volume_label = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/MasterVolumeLabel") as Label
	music_volume_slider = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/MusicVolume") as HSlider
	music_volume_label = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/MusicVolumeLabel") as Label
	sfx_volume_slider = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/SFXVolume") as HSlider
	sfx_volume_label = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/SFXVolumeLabel") as Label
	mute_button = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/MuteButton") as Button
	
	setup_audio_buses()
	_populate_options()
	apply_settings()
	_update_slider_labels()
	
	if fullscreen_button:
		fullscreen_button.pressed.connect(_on_fullscreen_toggled)
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_changed)
	if vsync_button:
		vsync_button.pressed.connect(_on_vsync_toggled)
	if quality_option:
		quality_option.item_selected.connect(_on_quality_changed)
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if mute_button:
		mute_button.pressed.connect(_on_mute_toggled)
	var play_btn = get_node_or_null("PlayButton")
	if not play_btn:
		play_btn = get_node_or_null("MenuButtons/PlayButton")
	if not play_btn:
		play_btn = get_node_or_null("MenuContainer/PlayButton")
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	else:
		push_error("MainMenu: PlayButton not found!")

	var settings_btn = get_node_or_null("SettingsButton")
	if not settings_btn:
		settings_btn = get_node_or_null("MenuButtons/SettingsButton")
	if not settings_btn:
		settings_btn = get_node_or_null("MenuContainer/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	else:
		push_error("MainMenu: SettingsButton not found!")

	var quit_btn = get_node_or_null("QuitButton")
	if not quit_btn:
		quit_btn = get_node_or_null("MenuButtons/QuitButton")
	if not quit_btn:
		quit_btn = get_node_or_null("MenuContainer/QuitButton")
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
	else:
		push_error("MainMenu: QuitButton not found!")

	var vid_back = get_node_or_null("SettingsPanel/SettingsTabContainer/VideoTab/VideoBackButton")
	if not vid_back:
		vid_back = get_node_or_null("SettingsPanel/SettingsTabContainer/VideoTab/MarginContainer/VideoBackButton")
	if vid_back:
		vid_back.pressed.connect(_on_settings_back_pressed)
	var aud_back = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/AudioBackButton")
	if not aud_back:
		aud_back = get_node_or_null("SettingsPanel/SettingsTabContainer/AudioTab/MarginContainer/AudioBackButton")
	if aud_back:
		aud_back.pressed.connect(_on_audio_back_pressed)

	if settings_tab_container:
		settings_tab_container.tab_changed.connect(_on_tab_changed)

func _process(_delta: float) -> void:
	pass

func setup_audio_buses() -> void:
	if AudioServer.get_bus_count() < 2:
		AudioServer.add_bus()
		AudioServer.set_bus_name(1, "Music")
	if AudioServer.get_bus_count() < 3:
		AudioServer.add_bus()
		AudioServer.set_bus_name(2, "SFX")

func _populate_options() -> void:
	if resolution_option:
		resolution_option.clear()
		for res in resolutions:
			resolution_option.add_item("%dx%d" % [res.x, res.y])
	if quality_option:
		quality_option.clear()
		quality_option.add_item("Low")
		quality_option.add_item("Medium")
		quality_option.add_item("High")
		quality_option.add_item("Ultra")

func _on_play_pressed() -> void:
	print("MainMenu: Play pressed, switching to: ", main_scene_path)
	var err = get_tree().change_scene_to_file(main_scene_path)
	if err != OK:
		push_error("MainMenu: Failed to switch scene to " + main_scene_path + ", error code: " + str(err))

func _on_settings_pressed() -> void:
	print("MainMenu: Settings pressed")
	if settings_panel:
		settings_panel.visible = true
	if settings_tab_container:
		settings_tab_container.current_tab = current_tab
	if current_tab == 0:
		_load_video_settings()
	elif current_tab == 1:
		_load_audio_settings()

func _on_quit_pressed() -> void:
	print("MainMenu: Quit pressed")
	get_tree().quit()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	current_tab = settings_tab_container.current_tab

func _on_audio_back_pressed() -> void:
	settings_panel.visible = false
	current_tab = settings_tab_container.current_tab

func _on_fullscreen_toggled() -> void:
	is_fullscreen = not is_fullscreen
	fullscreen_button.text = "Fullscreen: " + ("ON" if is_fullscreen else "OFF")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_manager.save_fullscreen(is_fullscreen)

func _on_resolution_changed(index: int) -> void:
	if index < resolutions.size():
		var res = resolutions[index]
		DisplayServer.window_set_size(Vector2i(res.x, res.y))
		settings_manager.save_resolution(index)

func _on_vsync_toggled() -> void:
	vsync_enabled = not vsync_enabled
	vsync_button.text = "V-Sync: " + ("ON" if vsync_enabled else "OFF")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	settings_manager.save_vsync(vsync_enabled)

func _on_quality_changed(index: int) -> void:
	current_quality = index
	apply_quality_settings(index)
	settings_manager.save_quality(index)

func _on_master_volume_changed(value: float) -> void:
	if master_volume_label:
		master_volume_label.text = "Master: " + str(int(value)) + "%"
	var db = linear_to_db(value / 100.0)
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(0, db)
	settings_manager.save_master_volume(value)

func _on_music_volume_changed(value: float) -> void:
	if music_volume_label:
		music_volume_label.text = "Music: " + str(int(value)) + "%"
	var db = linear_to_db(value / 100.0)
	if AudioServer.get_bus_count() > 1:
		AudioServer.set_bus_volume_db(1, db)
	settings_manager.save_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	if sfx_volume_label:
		sfx_volume_label.text = "SFX: " + str(int(value)) + "%"
	var db = linear_to_db(value / 100.0)
	if AudioServer.get_bus_count() > 2:
		AudioServer.set_bus_volume_db(2, db)
	settings_manager.save_sfx_volume(value)

func _on_mute_toggled() -> void:
	is_muted = not is_muted
	if mute_button:
		mute_button.text = "Mute: " + ("ON" if is_muted else "OFF")
	if is_muted:
		if AudioServer.get_bus_count() > 0:
			AudioServer.set_bus_volume_db(0, -80.0)
		if AudioServer.get_bus_count() > 1:
			AudioServer.set_bus_volume_db(1, -80.0)
		if AudioServer.get_bus_count() > 2:
			AudioServer.set_bus_volume_db(2, -80.0)
	else:
		_apply_volume_from_settings()
	settings_manager.save_mute(is_muted)

func _load_video_settings() -> void:
	is_fullscreen = settings_manager.is_fullscreen
	fullscreen_button.text = "Fullscreen: " + ("ON" if is_fullscreen else "OFF")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	current_resolution = settings_manager.resolution_index
	if current_resolution < resolutions.size():
		resolution_option.select(current_resolution)
		var res = resolutions[current_resolution]
		DisplayServer.window_set_size(Vector2i(res.x, res.y))
	vsync_enabled = settings_manager.vsync_enabled
	vsync_button.text = "V-Sync: " + ("ON" if vsync_enabled else "OFF")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	current_quality = settings_manager.quality_level
	quality_option.select(current_quality)
	apply_quality_settings(current_quality)

func _load_audio_settings() -> void:
	master_volume_slider.value = settings_manager.master_volume
	master_volume_label.text = "Master: " + str(int(settings_manager.master_volume)) + "%"
	_on_master_volume_changed(settings_manager.master_volume)
	music_volume_slider.value = settings_manager.music_volume
	music_volume_label.text = "Music: " + str(int(settings_manager.music_volume)) + "%"
	_on_music_volume_changed(settings_manager.music_volume)
	sfx_volume_slider.value = settings_manager.sfx_volume
	sfx_volume_label.text = "SFX: " + str(int(settings_manager.sfx_volume)) + "%"
	_on_sfx_volume_changed(settings_manager.sfx_volume)
	is_muted = settings_manager.is_muted
	mute_button.text = "Mute: " + ("ON" if is_muted else "OFF")
	if is_muted:
		AudioServer.set_bus_volume_db(0, -80.0)
		AudioServer.set_bus_volume_db(1, -80.0)
		AudioServer.set_bus_volume_db(2, -80.0)

func _update_slider_labels() -> void:
	master_volume_label.text = "Master: " + str(int(master_volume_slider.value)) + "%"
	music_volume_label.text = "Music: " + str(int(music_volume_slider.value)) + "%"
	sfx_volume_label.text = "SFX: " + str(int(sfx_volume_slider.value)) + "%"

func apply_settings() -> void:
	_load_video_settings()
	_load_audio_settings()

func apply_quality_settings(level: int) -> void:
	match level:
		0:
			pass
		1:
			pass
		2:
			DisplayServer.window_set_size(Vector2i(1366, 768))
		3:
			DisplayServer.window_set_size(Vector2i(800, 600))
		_:
			pass

func _apply_volume_from_settings() -> void:
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(0, linear_to_db(settings_manager.master_volume / 100.0))
	if AudioServer.get_bus_count() > 1:
		AudioServer.set_bus_volume_db(1, linear_to_db(settings_manager.music_volume / 100.0))
	if AudioServer.get_bus_count() > 2:
		AudioServer.set_bus_volume_db(2, linear_to_db(settings_manager.sfx_volume / 100.0))

func _on_tab_changed(tab_index: int) -> void:
	current_tab = tab_index
	if tab_index == 0:
		_load_video_settings()
	elif tab_index == 1:
		_load_audio_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		settings_manager.save_settings()
