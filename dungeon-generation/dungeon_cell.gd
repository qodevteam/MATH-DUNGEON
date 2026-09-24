@tool
extends Node3D


func remove_wall_up() -> void:
	_remove("WallUp")


func remove_door_up() -> void:
	_remove("DoorUp")


func remove_wall_down() -> void:
	_remove("WallDown")


func remove_door_down() -> void:
	_remove("DoorDown")


func remove_wall_left() -> void:
	_remove("WallLeft")


func remove_door_left() -> void:
	_remove("DoorLeft")


func remove_wall_right() -> void:
	_remove("WallRight")


func remove_door_right() -> void:
	_remove("DoorRight")


func _remove(node_name: String) -> void:
	var n := get_node_or_null(node_name)
	if n:
		n.queue_free()
