extends TextureRect

@export var player: Node

@export var walk_spread: float = 8.0
@export var sprint_spread: float = 18.0
@export var lerp_speed: float = 22.0

@export var jump_rise_spread: float = 15.0
@export var jump_fall_spread: float = 30.0
@export var max_rise_speed: float = 18.0
@export var max_fall_speed: float = 25.0
@export var fall_lerp_multiplier: float = 1.25

@export_group("Shot Expand")
## How far the crosshair jumps apart on fire.
@export var shot_expand_spread: float = 40.0
## How fast the crosshair snaps open (higher = snappier).
@export var shot_expand_speed: float = 50.0
## How fast the crosshair returns to normal after shot (curve controls the feel).
@export var shot_return_speed: float = 6.0

@export_group("ADS Fade")
## Opacity when fully aimed down sights.
@export var ads_alpha: float = 0.0
## Speed of the fade transition.
@export var ads_fade_speed: float = 10.0

@onready var left2: Line2D = $left2
@onready var right2: Line2D = $right2

var base_left_x: float
var base_right_x: float

var _shot_offset: float = 0.0
var _ads_alpha: float = 1.0


func _ready() -> void:
	if not player:
		player = get_node_or_null("../../") as CharacterBody3D

	base_left_x = left2.position.x
	base_right_x = right2.position.x

	if player:
		var vm = player.get("weapon_viewmodel")
		if vm and vm.has_signal("fired"):
			vm.fired.connect(_on_player_fired)


func _on_player_fired() -> void:
	_shot_offset = shot_expand_spread


func _process(delta: float) -> void:
	if not player:
		return

	# ─── SHOT RETURN (exponential ease-back) ──────────────────────────────
	_shot_offset = lerp(_shot_offset, 0.0, float(clamp(shot_return_speed * delta, 0.0, 1.0)))

	# ─── ADS FADE ─────────────────────────────────────────────────────────
	var weapon_viewmodel = player.get("weapon_viewmodel")
	var is_ads := false
	if weapon_viewmodel and weapon_viewmodel.has_method("is_ads"):
		is_ads = weapon_viewmodel.is_ads()
	var target_alpha := 1.0 if not is_ads else ads_alpha
	_ads_alpha = move_toward(_ads_alpha, target_alpha, ads_fade_speed * delta)
	modulate.a = _ads_alpha

	# ─── SPREAD ───────────────────────────────────────────────────────────
	var target_offset := 0.0
	var current_lerp_speed := lerp_speed

	var h_vel = Vector2(player.velocity.x, player.velocity.z).length()
	var max_ground_speed = player.speed * player.sprint_speed
	var ground_factor = clamp(h_vel / max(1.0, max_ground_speed), 0.0, 1.0)
	var ground_spread = ground_factor * sprint_spread

	if not player.is_on_floor():
		if player.velocity.y > 0:
			var rise_factor = 1.0 - clamp(player.velocity.y / max_rise_speed, 0.0, 1.0)
			target_offset = lerp(ground_spread, jump_rise_spread, rise_factor)
		else:
			var fall_speed = -player.velocity.y
			var fall_factor = clamp(fall_speed / max_fall_speed, 0.0, 1.0)
			target_offset = lerp(jump_rise_spread, jump_fall_spread, fall_factor)
			current_lerp_speed = lerp_speed * fall_lerp_multiplier
	else:
		target_offset = ground_spread

	target_offset += _shot_offset

	var t := current_lerp_speed * delta

	left2.position.x = lerp(left2.position.x, base_left_x - target_offset, t)
	right2.position.x = lerp(right2.position.x, base_right_x + target_offset, t)
