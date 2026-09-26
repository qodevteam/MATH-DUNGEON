class_name CursorManager extends Node

@export var speaker : AudioStreamPlayer2D
@export var cursor_point : CompressedTexture2D
@export var cursor_hover : CompressedTexture2D
@export var cursor_invalid : CompressedTexture2D
var cursor_visible = false
var controller_active = false
var locked := false  # free will mode cursor band karta hai
@export var force_captured := false  # redemption scene: block ALL mouse mode overrides
var _intended_mouse_mode := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if force_captured:
		_intended_mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	# If window is unfocused when this node is born (e.g. alt-tabbed before scene
	# loaded), don't set any mode — focus-in will restore when user returns.
	# GlobalVariables.window_focused persists across scene changes.
	if GlobalVariables.window_focused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_intended_mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		GlobalVariables.window_focused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		GlobalVariables.window_focused = true
		Input.set_mouse_mode(_intended_mouse_mode)

func _apply_mode(mode: int) -> void:
	_intended_mouse_mode = mode
	# Never apply CAPTURED/CONFINED while the window is unfocused,
	# otherwise the cursor gets trapped outside the game window.
	if not GlobalVariables.window_focused and mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(mode)

func SetCursor(_isVisible : bool, playSound : bool) -> void:
	if locked: return
	if force_captured: return
	if playSound and speaker: speaker.play()
	cursor_visible = true
	_apply_mode(Input.MOUSE_MODE_VISIBLE)

func SetCursorImage(alias : String) -> void:
	if locked: return
	if force_captured: return
	var texture : Texture2D = null
	match alias:
		"point": texture = cursor_point
		"hover": texture = cursor_hover
		"invalid": texture = cursor_invalid

	if texture:
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW as Input.CursorShape, Vector2(12, 0))

func ShowCursorForMenu() -> void:
	cursor_visible = true
	_apply_mode(Input.MOUSE_MODE_VISIBLE)

func HideCursorForGameplay() -> void:
	cursor_visible = false
	if locked:
		_apply_mode(Input.MOUSE_MODE_VISIBLE)
	elif force_captured:
		_apply_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		_apply_mode(Input.MOUSE_MODE_VISIBLE)
