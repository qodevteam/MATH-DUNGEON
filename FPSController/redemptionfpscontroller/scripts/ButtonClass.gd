class_name ButtonClass extends Node

# --- Exports ---
@export var cursor : CursorManager
@export var alias : String
@export var isActive : bool = true
@export var isDynamic : bool = true

# Use @export_node_path or direct export, but DO NOT overwrite it in _ready
@export var target_control : Control 
@export var ui : CanvasItem
@export var resetting : bool

@export var speaker_press : AudioStreamPlayer2D
@export var speaker_hover : AudioStreamPlayer2D

@export var rebind : Node
@export var language : bool
@export var options : OptionsManager
@export var rebindManager : Rebinding

@export var playing : bool
@export var altsound : bool

@export var ui_opacity_inactive : float = 1.0
@export var ui_opacity_active : float = 0.78
@export var tab_hover : TextureRect
@export var hover_color : Color = Color.WHITE
@export var focus_color : Color = Color.WHITE
@export var use_custom_colors : bool = false

# --- Internal Vars ---
var mainActive : bool = true
var slider_option : Node
var slider_label : Label

signal is_pressed

func _ready() -> void:
	# Fallback to parent ONLY if target_control wasn't assigned in Inspector
	if target_control == null:
		target_control = get_parent() as Control
		
	# CRITICAL: Ensure parent is actually a Control before connecting UI signals
	if target_control == null:
		push_error("ButtonClass: No valid Control node assigned or found in parent!")
		return

	target_control.focus_entered.connect(_on_focus_hover)
	target_control.focus_exited.connect(_on_focus_exit)
	target_control.mouse_entered.connect(_on_mouse_hover)
	target_control.mouse_exited.connect(_on_mouse_exit)
	
	if target_control is BaseButton: # BaseButton covers Button, CheckButton, etc.
		target_control.pressed.connect(_on_press)
		
	if isDynamic and ui: 
		ui.modulate.a = ui_opacity_inactive

# --- Public API ---
func SetSliderOption(node : Node) -> void:
	slider_option = node

func UpdateSliderLabel(value : float) -> void:
	if slider_label:
		slider_label.text = str(round(value * 100)) + "%"

func SetFilter(filter_type : String) -> void:
	if target_control == null: return
	
	match(filter_type):
		"ignore":
			target_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		"stop":
			target_control.mouse_filter = Control.MOUSE_FILTER_STOP

# --- Internal Logic ---
func _on_mouse_hover() -> void:
	if not (isActive and mainActive): return
	
	if isDynamic and ui:
		if speaker_hover:
			speaker_hover.pitch_scale = randf_range(0.95, 1.0)
			speaker_hover.play()
		if use_custom_colors:
			ui.modulate = Color(hover_color.r, hover_color.g, hover_color.b, ui_opacity_active)
		else:
			ui.modulate.a = ui_opacity_active
		
	if cursor: 
		cursor.SetCursorImage("hover")
	
	if tab_hover and tab_hover.has_method("show_hover"):
		tab_hover.shift_to(target_control)
		tab_hover.show_hover(true, false)

func _on_mouse_exit() -> void:
	if not (isActive and mainActive): return
	
	if isDynamic and ui:
		if use_custom_colors:
			ui.modulate = Color.WHITE
			ui.modulate.a = ui_opacity_inactive
		else:
			ui.modulate.a = ui_opacity_inactive
		
	if cursor: 
		cursor.SetCursorImage("point")
	
	if tab_hover and tab_hover.has_method("hide_hover"):
		tab_hover.hide_hover(true, false)

func _on_focus_hover() -> void:
	if not (isActive and mainActive): return
	
	if isDynamic and ui:
		if speaker_hover:
			speaker_hover.pitch_scale = randf_range(0.95, 1.0)
			speaker_hover.play()
		if use_custom_colors:
			ui.modulate = Color(focus_color.r, focus_color.g, focus_color.b, ui_opacity_active)
		else:
			ui.modulate.a = ui_opacity_active
		
	if cursor: 
		cursor.SetCursorImage("hover")
	
	if tab_hover and tab_hover.has_method("show_hover"):
		tab_hover.shift_to(target_control)
		tab_hover.show_hover(false, true)

func _on_focus_exit() -> void:
	if not (isActive and mainActive): return
	
	if isDynamic and ui:
		if use_custom_colors:
			ui.modulate = Color.WHITE
			ui.modulate.a = ui_opacity_inactive
		else:
			ui.modulate.a = ui_opacity_inactive
		
	if cursor: 
		cursor.SetCursorImage("point")
	
	if tab_hover and tab_hover.has_method("hide_hover"):
		tab_hover.hide_hover(false, true)

func OnExit() -> void:
	_on_mouse_exit()
	_on_focus_exit()

func _on_press() -> void:
	if not (isActive and mainActive): return
	
	# FIXED: Use elif to prevent double audio playback
	if altsound and speaker_press: 
		speaker_press.play()
	elif isDynamic and playing and speaker_press: 
		speaker_press.play()
		
	if rebind != null and rebindManager: 
		rebindManager.GetRebind(rebind)
		
	if language and options: 
		options.AdjustLanguage(alias)
		
	is_pressed.emit() # Godot 4 syntax
