class_name CameraSocket extends Resource

@export var socketName : String
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var pos : Vector3
@export var rot : Vector3
@export var fov : float

func _validate_property(property: Dictionary) -> void:
	if property.name == "rot":
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "-360,360,0.1,degrees"
