class_name MouseRaycast extends Camera3D
@export var checkingOverride : bool
@export var cursor : CursorManager
var mouse = Vector2()
var result = null
var controller_overriding = false
func _input(event):
	if event is InputEventMouse:
		if not controller_overriding:
			mouse = event.position
	elif event is InputEventScreenTouch:
		mouse = event.position
func _process(_delta):
	get_selection()
func get_selection():
	var worldspace = get_world_3d().direct_space_state
	var mouse_pos: Vector2 = mouse
	if not controller_overriding:
		mouse_pos = get_viewport().get_mouse_position()
	var start = project_ray_origin(mouse_pos)
	var end = project_position(mouse_pos, 20000)
	result = worldspace.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
func GetRaycastOverride(pos_override : Vector2):
	controller_overriding = true
	mouse = pos_override
func StopRaycastOverride():
	controller_overriding = false
