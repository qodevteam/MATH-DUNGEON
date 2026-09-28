extends Control

signal door_unlocked(door_ref: Node)

@export var timer_duration: float = 15.0

var _player: CharacterBody3D = null
var _door_ref: Node = null
var _correct_index: int = -1
var _timer: float = 0.0
var _timer_running: bool = false
var _current_question_difficulty: int = 1

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var question_label: Label = $Panel/VBox/QuestionLabel
@onready var option_buttons: Array[Button] = [
	$Panel/VBox/OptionGrid/OptionButton1,
	$Panel/VBox/OptionGrid/OptionButton2,
	$Panel/VBox/OptionGrid/OptionButton3,
	$Panel/VBox/OptionGrid/OptionButton4,
]
@onready var timer_bar: ProgressBar = $Panel/VBox/TimerBar
@onready var skip_button: Button = $Panel/VBox/SkipButton

var _panel_target_scale: float = 0.0
var _panel_scale: float = 0.0
var _overlay_target_alpha: float = 0.0
var _overlay_alpha: float = 0.0

func _ready() -> void:
	_panel_target_scale = 0.0
	_panel_scale = 0.0
	_overlay_target_alpha = 0.0
	_overlay_alpha = 0.0
	panel.scale = Vector2.ZERO
	overlay.color = Color(0, 0, 0, 0)
	hide()
	skip_button.pressed.connect(_on_skip_pressed)

	_apply_theme()

	for i in range(option_buttons.size()):
		var btn = option_buttons[i]
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))

func _apply_theme() -> void:
	var title_font = preload("res://fonts/HomeVideo-Regular.ttf")
	if title_font:
		title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_font_size_override("font_size", 42)
		title_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4, 1))
		subtitle_label.add_theme_font_override("font", title_font)
		subtitle_label.add_theme_font_size_override("font_size", 20)
		subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))

	var question_font = preload("res://fonts/The Last Shuriken.ttf")
	if question_font:
		question_label.add_theme_font_override("font", question_font)
		question_label.add_theme_font_size_override("font_size", 36)
		question_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	var button_font = preload("res://fonts/The Last Shuriken.ttf")
	if button_font:
		for btn in option_buttons:
			btn.add_theme_font_override("font", button_font)
			btn.add_theme_font_size_override("font_size", 26)
		skip_button.add_theme_font_override("font", button_font)
		skip_button.add_theme_font_size_override("font_size", 20)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.97)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.85, 0.65, 0.2, 0.9)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel.add_theme_stylebox_override("panel", panel_style)

	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.18, 0.16, 0.12, 1)
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.85, 0.65, 0.2, 0.85)
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_right = 10
	button_style.corner_radius_bottom_left = 10

	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color(0.28, 0.24, 0.15, 1)
	button_hover.border_color = Color(1, 0.85, 0.4, 1)
	button_hover.corner_radius_top_left = 10
	button_hover.corner_radius_top_right = 10
	button_hover.corner_radius_bottom_right = 10
	button_hover.corner_radius_bottom_left = 10

	var button_disabled = StyleBoxFlat.new()
	button_disabled.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	button_disabled.border_color = Color(0.3, 0.3, 0.3, 0.4)
	button_disabled.corner_radius_top_left = 10
	button_disabled.corner_radius_top_right = 10
	button_disabled.corner_radius_bottom_right = 10
	button_disabled.corner_radius_bottom_left = 10

	for btn in option_buttons:
		btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.8))
		btn.add_theme_stylebox_override("normal", button_style)
		btn.add_theme_stylebox_override("hover", button_hover)
		btn.add_theme_stylebox_override("disabled", button_disabled)

	skip_button.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65, 1))
	skip_button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85, 1))
	skip_button.add_theme_stylebox_override("normal", button_style)
	skip_button.add_theme_stylebox_override("hover", button_hover)

	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.1, 0.08, 0.05, 1)
	progress_bg.border_width_left = 1
	progress_bg.border_width_top = 1
	progress_bg.border_width_right = 1
	progress_bg.border_width_bottom = 1
	progress_bg.border_color = Color(0.5, 0.4, 0.2, 0.8)
	progress_bg.corner_radius_top_left = 6
	progress_bg.corner_radius_top_right = 6
	progress_bg.corner_radius_bottom_right = 6
	progress_bg.corner_radius_bottom_left = 6

	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.85, 0.65, 0.2, 1)
	progress_fill.border_width_left = 1
	progress_fill.border_width_top = 1
	progress_fill.border_width_right = 1
	progress_fill.border_width_bottom = 1
	progress_fill.border_color = Color(1, 0.85, 0.4, 0.9)
	progress_fill.corner_radius_top_left = 6
	progress_fill.corner_radius_top_right = 6
	progress_fill.corner_radius_bottom_right = 6
	progress_fill.corner_radius_bottom_left = 6

	timer_bar.add_theme_stylebox_override("background", progress_bg)
	timer_bar.add_theme_stylebox_override("fill", progress_fill)

	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "Time Remaining"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if question_font:
		timer_label.add_theme_font_override("font", question_font)
		timer_label.add_theme_font_size_override("font_size", 16)
		timer_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65, 1))
	timer_bar.add_child(timer_label)
	timer_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_question(question_text: String, options: Array, correct_index: int, door_ref: Node, player: CharacterBody3D, difficulty: int = 1) -> void:
	_door_ref = door_ref
	_correct_index = correct_index
	_player = player
	_current_question_difficulty = difficulty

	if _player:
		_player.moveAllowed = false
		_player.lookAllowed = false
		_player.release_mouse()

	title_label.text = "LOCKED DOOR"
	subtitle_label.text = "Solve the equation to unlock"
	question_label.text = question_text
	for i in range(4):
		option_buttons[i].text = str(options[i])
		option_buttons[i].disabled = false
		option_buttons[i].modulate = Color.WHITE

	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_option_pressed.bind(i))

	timer_bar.max_value = timer_duration
	timer_bar.value = timer_duration
	_timer = timer_duration
	_timer_running = true

	show()
	_panel_target_scale = 1.0
	_overlay_target_alpha = 1.0

func _process(delta: float) -> void:
	_panel_scale = move_toward(_panel_scale, _panel_target_scale, delta * 12.0)
	panel.scale = Vector2.ONE * _panel_scale

	_overlay_alpha = move_toward(_overlay_alpha, _overlay_target_alpha, delta * 8.0)
	overlay.color = Color(0, 0, 0, _overlay_alpha * 0.85)

	if not _timer_running or not visible:
		return
	_timer -= delta
	timer_bar.value = maxf(_timer, 0.0)

	var ratio = clampf(_timer / timer_duration, 0.0, 1.0)
	if ratio > 0.5:
		timer_bar.modulate = Color.WHITE
		timer_bar.get_theme_stylebox("fill").bg_color = Color(0.85, 0.65, 0.2, 1)
	else:
		timer_bar.modulate = Color(1, 0.4 + ratio * 1.2, 0.2, 1)
		timer_bar.get_theme_stylebox("fill").bg_color = Color(1, 0.3, 0.2, 1)

	if _timer <= 0:
		_timer_running = false
		_close()

func _on_button_hover(btn: Button, hovered: bool) -> void:
	if btn.disabled:
		return
	var target_scale: float = 1.04 if hovered else 1.0
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE * target_scale, 0.15)

func _on_option_pressed(index: int) -> void:
	_timer_running = false

	if index == _correct_index:
		door_unlocked.emit(_door_ref)
		_pulse_panel(Color(0.2, 1.0, 0.4, 0.3))
		_flash_overlay(Color(0.2, 1.0, 0.4, 0.4))
		await get_tree().create_timer(0.5).timeout
		_close()
	else:
		_pulse_panel(Color(1.0, 0.2, 0.3, 0.4))
		_flash_overlay(Color(1.0, 0.2, 0.3, 0.5))
		option_buttons[index].disabled = true
		var wrong_btn = option_buttons[index]
		var shake_tween = create_tween()
		shake_tween.tween_property(wrong_btn, "position", wrong_btn.position + Vector2(10, 0), 0.05)
		shake_tween.tween_property(wrong_btn, "position", wrong_btn.position - Vector2(20, 0), 0.05)
		shake_tween.tween_property(wrong_btn, "position", wrong_btn.position + Vector2(10, 0), 0.05)
		shake_tween.tween_property(wrong_btn, "position", wrong_btn.position, 0.05)
		await get_tree().create_timer(0.6).timeout
		_new_question()

func _new_question() -> void:
	var q = generate_question(_current_question_difficulty)
	question_label.text = q.text
	for i in range(4):
		option_buttons[i].text = str(q.options[i])
		option_buttons[i].disabled = false
		option_buttons[i].modulate = Color.WHITE
	_correct_index = q.correct_index
	timer_bar.max_value = timer_duration
	timer_bar.value = timer_duration
	_timer = timer_duration
	_timer_running = true

func _on_skip_pressed() -> void:
	_close()

func _close() -> void:
	_timer_running = false
	_panel_target_scale = 0.0
	_overlay_target_alpha = 0.0

	if _player:
		_player.moveAllowed = true
		_player.lookAllowed = true
		_player.capture_mouse()

	for btn in option_buttons:
		if btn.pressed.is_connected(_on_option_pressed):
			btn.pressed.disconnect(_on_option_pressed)
		btn.modulate = Color.WHITE

	await get_tree().create_timer(0.25).timeout
	hide()

func _pulse_panel(color: Color) -> void:
	var tween = create_tween()
	tween.tween_property(panel, "modulate", color, 0.1)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.4)

func _flash_overlay(color: Color) -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color", color, 0.1)
	tween.tween_property(overlay, "color", Color(0, 0, 0, _overlay_alpha * 0.85), 0.4)

static func generate_question(difficulty: int = 1) -> Dictionary:
	var ops = ["+", "-"]
	if difficulty >= 2:
		ops.append_array(["×", "÷"])

	var op = ops.pick_random()
	var a = 0
	var b = 0
	var answer = 0
	var question = ""

	match op:
		"+":
			a = randi_range(1, 99)
			b = randi_range(1, 99)
			answer = a + b
			question = "%d + %d = ?" % [a, b]
		"-":
			a = randi_range(1, 99)
			b = randi_range(1, a)
			answer = a - b
			question = "%d - %d = ?" % [a, b]
		"×":
			a = randi_range(2, 12)
			b = randi_range(2, 12)
			answer = a * b
			question = "%d × %d = ?" % [a, b]
		"÷":
			b = randi_range(2, 12)
			answer = randi_range(2, 12)
			a = b * answer
			question = "%d ÷ %d = ?" % [a, b]

	var options = [answer]
	for i in range(3):
		var wrong = answer + randi_range(-10, 10)
		while wrong == answer or wrong < 0 or options.has(wrong):
			wrong = answer + randi_range(-15, 15)
			if wrong < 0:
				wrong = abs(wrong)
		options.append(wrong)

	options.shuffle()
	var correct_index = options.find(answer)

	return {
		"text": question,
		"options": options,
		"correct_index": correct_index
	}
