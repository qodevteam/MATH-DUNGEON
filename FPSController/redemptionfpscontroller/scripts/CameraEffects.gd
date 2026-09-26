class_name CameraEffects extends Node

@export_category("References")
@export var camera: Camera3D
@export var player: CharacterBody3D

@export_category("Master")
@export var enabled: bool = true

@export_category("Directional Tilt")
@export var tilt_enabled: bool = true
@export var tilt_max_angle: float = deg_to_rad(3.0)
@export var tilt_smooth_speed: float = 8.0

@export_category("Fall Kick")
@export var fall_kick_enabled: bool = true
@export var fall_kick_threshold: float = -5.0
@export var fall_kick_pitch_amount: float = deg_to_rad(4.0)
@export var fall_kick_pos_amount: float = -0.08
@export var fall_kick_recovery: float = 6.0

@export_category("Damage Kick")
@export var damage_kick_enabled: bool = true
@export var damage_kick_strength: float = deg_to_rad(8.0)
@export var damage_kick_decay: float = 5.0

@export_category("Weapon Recoil")
@export var recoil_enabled: bool = true
@export var recoil_pitch_min: float = deg_to_rad(1.0)
@export var recoil_pitch_max: float = deg_to_rad(2.5)
@export var recoil_yaw_range: float = deg_to_rad(0.8)
@export var recoil_decay: float = 7.0

@export_category("Screen Shake")
@export var shake_enabled: bool = true

@export_category("Head Bob")
@export var headbob_enabled: bool = true
@export var headbob_amplitude: float = 0.06
@export var headbob_amplitude_crouched: float = 0.025
@export var headbob_base_frequency: float = 7.0
@export var headbob_speed_mod: float = 1.5
@export var headbob_shape: float = 0.5

@export_category("Walking Sway")
@export var walk_sway_enabled: bool = true
@export var walk_sway_reference_speed: float = 4.5
@export var walk_strafe_roll: float = deg_to_rad(2.5)
@export var walk_strafe_pos_x: float = 0.04
@export var walk_forward_pitch: float = deg_to_rad(2.0)
@export var walk_forward_pos_y: float = 0.03
@export var walk_sway_return_speed: float = 14.0
@export var walk_sway_smooth_speed: float = 10.0
@export var walk_sway_deadzone: float = 0.08

@export_category("Step Wobble (Rotation)")
@export var wobble_enabled: bool = true
@export var wobble_blend_speed: float = 6.0

@export_group("Gait Cadence (beats per second)")
@export var wobble_walk_cadence: float = 1.8
@export var wobble_sprint_cadence: float = 2.8

@export_group("Rotation Amplitudes (degrees)")
@export var wobble_walk_pitch: float = deg_to_rad(0.3)
@export var wobble_sprint_pitch: float = deg_to_rad(0.6)
@export var wobble_walk_yaw: float = deg_to_rad(0.12)
@export var wobble_sprint_yaw: float = deg_to_rad(0.28)

@export_group("Micro Variation (noise on top)")
@export var wobble_noise_intensity: float = 0.15
@export var wobble_noise_speed: float = 1.2

@export_category("Crouch")
@export var crouch_height_reduction: float = 0.8

@export var weapon_viewmodel: WeaponViewmodelController

var original_camera_y: float
var original_camera_position: Vector3
var was_on_floor: bool = true

var tilt_roll: float = 0.0

var fall_kick_pitch: float = 0.0
var fall_kick_pos: float = 0.0

var damage_kick_rot: Vector2

var recoil_offset: Vector2

var shake_timer: float = 0.0
var shake_intensity: float = 0.0

var headbob_time: float = 0.0
var headbob_offset: float = 0.0

var walk_strafe_roll_offset: float = 0.0
var walk_strafe_pos_offset: float = 0.0
var walk_forward_pitch_offset: float = 0.0
var walk_forward_pos_offset: float = 0.0

var crouched: bool = false

var wobble_sprint_blend: float = 0.0
var wobble_rot_offset: Vector2 = Vector2.ZERO
var wobble_time: float = 0.0
var wobble_noise: FastNoiseLite
var wobble_noise_time: float = 0.0


func _ready():
	if not camera:
		camera = get_parent() as Camera3D
	if camera:
		original_camera_y = camera.position.y
		original_camera_position = camera.position
	if not player:
		player = _find_player()
	if not weapon_viewmodel:
		weapon_viewmodel = _find_weapon_viewmodel()

	wobble_noise = FastNoiseLite.new()
	wobble_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wobble_noise.frequency = 1.0
	wobble_noise.seed = randi()


func _find_player() -> CharacterBody3D:
	var p = get_parent()
	while p:
		if p is CharacterBody3D:
			return p
		p = p.get_parent()
	return null


func _find_weapon_viewmodel() -> WeaponViewmodelController:
	var p = get_parent()
	while p:
		for child in p.get_children():
			if child is WeaponViewmodelController:
				return child
		p = p.get_parent()
	return null


func _process(delta: float):
	if not enabled or not camera or not is_instance_valid(player):
		return

	var vel: Vector3 = player.velocity
	var on_floor: bool = player.is_on_floor()
	var speed: float = vel.length()
	var speed_norm: float = clampf(speed / 10.0, 0.0, 1.0)
	var local_vel: Vector3 = player.global_transform.basis.inverse() * vel

	_update_headbob(delta, on_floor, speed, speed_norm)
	_update_step_wobble(delta, on_floor, speed, speed_norm)
	_update_directional_tilt(delta, on_floor, speed, vel)
	_update_walking_sway(delta, on_floor, local_vel)
	_update_fall_kick(on_floor, vel.y)
	_update_recoil(delta)
	_update_damage_kick(delta)
	_update_shake(delta)
	_apply(delta)


func _update_headbob(delta: float, on_floor: bool, speed: float, speed_norm: float):
	if not headbob_enabled or not on_floor or speed < 0.1:
		headbob_offset = move_toward(headbob_offset, 0.0, 12.0 * delta)
		headbob_time = 0.0
		return

	var amplitude = headbob_amplitude if not crouched else headbob_amplitude_crouched
	var freq = headbob_base_frequency + speed_norm * headbob_speed_mod

	headbob_time = fmod(headbob_time + delta * freq, TAU)

	var wave = sin(headbob_time)
	var stepped = abs(sin(headbob_time)) * 2.0 - 1.0
	var bob = lerp(wave, stepped, headbob_shape)

	headbob_offset = bob * amplitude * speed_norm


func _update_step_wobble(delta: float, on_floor: bool, speed: float, speed_norm: float):
	if not wobble_enabled or not on_floor or speed < 0.1 or crouched:
		wobble_rot_offset = wobble_rot_offset.lerp(Vector2.ZERO, wobble_blend_speed * delta)
		wobble_time = 0.0
		wobble_noise_time = 0.0
		return

	var is_sprinting: bool = is_instance_valid(player) and player.has_method("is_sprinting") and player.is_sprinting()
	var sprint_target: float = 1.0 if is_sprinting else 0.0
	wobble_sprint_blend = lerpf(wobble_sprint_blend, sprint_target, wobble_blend_speed * delta)

	# Interpolate cadence between walk and sprint
	var cadence: float = lerpf(wobble_walk_cadence, wobble_sprint_cadence, wobble_sprint_blend)

	# Advance time proportional to cadence
	wobble_time += delta * cadence * TAU
	var t: float = wobble_time

	# Sine waves for pitch (X) and yaw (Y) rotation
	# Vertical figure-8: sin(2t) on X, sin(t) on Y — gives a tall "8" shape
	var sin_t: float = sin(t)
	var sin_2t: float = sin(t * 2.0)

	# Interpolate amplitudes between walk and sprint
	var pitch_amp: float = lerpf(wobble_walk_pitch, wobble_sprint_pitch, wobble_sprint_blend)
	var yaw_amp: float = lerpf(wobble_walk_yaw, wobble_sprint_yaw, wobble_sprint_blend)

	# Rotation only: pitch (X) and yaw (Y) — no roll
	# Vertical 8: X gets sin(2t) (fast horizontal), Y gets sin(t) (slow vertical)
	var rot_base := Vector2(
		sin_2t * pitch_amp,
		sin_t * yaw_amp
	)

	# Micro-variation: subtle noise to break the perfect periodicity
	wobble_noise_time += delta * wobble_noise_speed
	var noise_amount: float = wobble_noise_intensity
	var noise_rot := Vector2(
		wobble_noise.get_noise_1d(wobble_noise_time) * pitch_amp * noise_amount,
		wobble_noise.get_noise_1d(wobble_noise_time + 100.0) * yaw_amp * noise_amount
	)

	var rot_target: Vector2 = rot_base + noise_rot

	# Smooth blend towards target
	var blend := clampf(wobble_blend_speed * delta, 0.0, 1.0)
	wobble_rot_offset = wobble_rot_offset.lerp(rot_target, blend)


func _update_directional_tilt(delta: float, on_floor: bool, speed: float, vel: Vector3):
	if not tilt_enabled or not on_floor or speed < 0.1:
		tilt_roll = lerp(tilt_roll, 0.0, tilt_smooth_speed * delta)
		return

	var vel_norm = vel.normalized()
	var right = camera.global_transform.basis.x
	var strafe = vel_norm.dot(right)

	tilt_roll = lerp(tilt_roll, -strafe * tilt_max_angle, tilt_smooth_speed * delta)


func _is_walk_sway_blocked() -> bool:
	if crouched:
		return true
	if is_instance_valid(player) and player.has_method("is_crouch_drifting") and player.is_crouch_drifting():
		return true
	if is_instance_valid(weapon_viewmodel) and weapon_viewmodel.has_method("is_ads") and weapon_viewmodel.is_ads():
		return true
	return false


func _update_walking_sway(delta: float, on_floor: bool, local_vel: Vector3) -> void:
	var blocked := _is_walk_sway_blocked()

	if not walk_sway_enabled or not on_floor or blocked:
		walk_strafe_roll_offset = move_toward(walk_strafe_roll_offset, 0.0, walk_sway_return_speed * delta)
		walk_strafe_pos_offset = move_toward(walk_strafe_pos_offset, 0.0, walk_sway_return_speed * delta)
		walk_forward_pitch_offset = move_toward(walk_forward_pitch_offset, 0.0, walk_sway_return_speed * delta)
		walk_forward_pos_offset = move_toward(walk_forward_pos_offset, 0.0, walk_sway_return_speed * delta)
		return

	var strafe := clampf(local_vel.x / walk_sway_reference_speed, -1.0, 1.0)
	var forward := clampf(-local_vel.z / walk_sway_reference_speed, -1.0, 1.0)

	var target_strafe_roll := 0.0
	var target_strafe_pos_x := 0.0
	var target_forward_pitch := 0.0
	var target_forward_pos_y := 0.0

	if absf(strafe) > walk_sway_deadzone:
		target_strafe_roll = -strafe * walk_strafe_roll
		target_strafe_pos_x = -strafe * walk_strafe_pos_x

	if absf(forward) > walk_sway_deadzone:
		target_forward_pitch = forward * walk_forward_pitch
		target_forward_pos_y = forward * walk_forward_pos_y

	var t := clampf(walk_sway_smooth_speed * delta, 0.0, 1.0)
	walk_strafe_roll_offset = lerp(walk_strafe_roll_offset, target_strafe_roll, t)
	walk_strafe_pos_offset = lerp(walk_strafe_pos_offset, target_strafe_pos_x, t)
	walk_forward_pitch_offset = lerp(walk_forward_pitch_offset, target_forward_pitch, t)
	walk_forward_pos_offset = lerp(walk_forward_pos_offset, target_forward_pos_y, t)


func _update_fall_kick(on_floor: bool, vel_y: float):
	if not fall_kick_enabled:
		return
	if not was_on_floor and on_floor and vel_y < fall_kick_threshold:
		var intensity = clampf(abs(vel_y) / 15.0, 0.3, 1.5)
		fall_kick_pitch = -fall_kick_pitch_amount * intensity
		fall_kick_pos = fall_kick_pos_amount * intensity
	was_on_floor = on_floor


func _update_recoil(delta: float):
	if not recoil_enabled:
		return
	recoil_offset.x = move_toward(recoil_offset.x, 0.0, recoil_decay * delta)
	recoil_offset.y = move_toward(recoil_offset.y, 0.0, recoil_decay * delta)


func _update_damage_kick(delta: float):
	if not damage_kick_enabled:
		return
	damage_kick_rot.x = move_toward(damage_kick_rot.x, 0.0, damage_kick_decay * delta)
	damage_kick_rot.y = move_toward(damage_kick_rot.y, 0.0, damage_kick_decay * delta)


func _update_shake(delta: float):
	if not shake_enabled or shake_timer <= 0:
		shake_timer = 0
		shake_intensity = 0
		camera.h_offset = move_toward(camera.h_offset, 0.0, 20.0 * delta)
		camera.v_offset = move_toward(camera.v_offset, 0.0, 20.0 * delta)
		return

	shake_timer -= delta
	camera.h_offset = randf_range(-shake_intensity, shake_intensity)
	camera.v_offset = randf_range(-shake_intensity, shake_intensity)


func _apply(delta: float):
	fall_kick_pitch = move_toward(fall_kick_pitch, 0.0, fall_kick_recovery * delta)
	fall_kick_pos = move_toward(fall_kick_pos, 0.0, fall_kick_recovery * delta)

	camera.rotation = Vector3(
		recoil_offset.x + damage_kick_rot.x + fall_kick_pitch + walk_forward_pitch_offset + wobble_rot_offset.x,
		recoil_offset.y + damage_kick_rot.y + wobble_rot_offset.y,
		tilt_roll + walk_strafe_roll_offset
	)

	var target_pos := original_camera_position
	if crouched:
		target_pos.y -= crouch_height_reduction

	target_pos.x += walk_strafe_pos_offset
	target_pos.y += headbob_offset + fall_kick_pos + walk_forward_pos_offset
	target_pos.z += 0.0

	camera.position = camera.position.move_toward(target_pos, 35.0 * delta)


func add_recoil():
	if not recoil_enabled:
		return
	recoil_offset.x += randf_range(recoil_pitch_min, recoil_pitch_max)
	recoil_offset.y += randf_range(-recoil_yaw_range, recoil_yaw_range)


func trigger_shake(intensity: float = 0.3, duration: float = 0.2):
	if not shake_enabled:
		return
	shake_intensity = intensity
	shake_timer = duration


func trigger_damage_kick(damage_origin: Vector3):
	if not damage_kick_enabled or not camera:
		return
	var dir = (camera.global_transform.origin - damage_origin).normalized()
	var local_dir = camera.global_transform.basis.inverse() * dir
	damage_kick_rot.x = -local_dir.y * damage_kick_strength
	damage_kick_rot.y = local_dir.x * damage_kick_strength * 0.5
