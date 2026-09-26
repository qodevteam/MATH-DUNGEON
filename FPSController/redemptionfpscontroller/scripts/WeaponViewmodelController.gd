class_name WeaponViewmodelController extends Node

signal fired
signal reload_started
signal bullet_loaded(step: int)
signal reload_finished
signal state_changed(new_state: State)

enum State { IDLE, FIRING, RELOADING }

## The weapon mesh/model node to animate and sway.
@export var weapon_node: Node3D
## AnimationPlayer containing shoot/reload animations.
@export var animator: AnimationPlayer
## The player CharacterBody3D this weapon belongs to.
@export var player: CharacterBody3D
## Optional GunRecoil node for procedural recoil.
@export var recoil: GunRecoil

@export_group("Baked Animations")
## Name of the shooting animation.
@export var shoot_anim: String = "ONE SHOT"
## Name of the reload-start animation.
@export var start_reload_anim: String = "START RELOAD"
## Name of the per-shell reload animation.
@export var reload_bullet_anim: String = "RELOAD BULLET ONE"
## Name of the post-reload animation.
@export var after_reload_anim: String = "AFTER RELOAD SHOTGUN"
## Name of the reset animation.
@export var reset_anim: String = "RESET"
## Safety cap for reload steps to prevent infinite loops.
@export var max_reload_steps: int = 8

@export_group("Mouse Look Sway")
## How much the weapon sways with mouse movement.
@export var mouse_sensitivity: float = 0.15
## How fast the weapon sway returns to center.
@export var sway_return_speed: float = 20.0
## Maximum sway angle in degrees.
@export var sway_max_angle_deg: float = 24.0
## Clamp mouse delta per frame to prevent extreme sway spikes.
@export var max_mouse_delta_per_frame: float = 50.0

@export_group("Procedural Idle Sway")
## Position amplitude of idle sway per axis (X=lateral, Y=vertical, Z=forward).
@export var idle_pos_amplitude: Vector3 = Vector3(0.0015, 0.0025, 0.001)
## Speed of idle position sway per axis.
@export var idle_pos_speed: Vector3 = Vector3(0.8, 1.2, 0.6)
## Rotation amplitude of idle sway per axis in degrees.
@export var idle_rot_amplitude_deg: Vector3 = Vector3(0.057, 0.086, 0.115)
## Speed of idle rotation sway per axis.
@export var idle_rot_speed: Vector3 = Vector3(0.5, 0.7, 0.9)

@export_group("Movement Bob")
## Base frequency of the bob cycle (scales with speed).
@export var bob_frequency: float = 8.0
## X = lateral offset, Y = vertical offset.
@export var bob_amplitude: Vector2 = Vector2(0.002, 0.003)
## How quickly the weapon returns to rest when stopping.
@export var bob_return_speed: float = 15.0
## Player speed that maps to 100% bob amplitude.
@export var bob_reference_speed: float = 5.0
## Per-step vertical camera/weapon jolt. This is what makes you "feel" each footstep.
@export var bob_step_impulse: float = 0.003
## How quickly the step jolt decays.
@export var bob_step_decay: float = 12.0
## Random variation per step (0 = none, 1 = full). Makes walk feel organic.
@export var bob_step_randomness: float = 0.4
## Rotational bob (Euler degrees) — weapon pitches forward and rolls slightly during walk.
@export var bob_rotation_deg: Vector3 = Vector3(0.3, 0.0, 0.15)

@export_group("Walk Tilt")
@export var tilt_amount_deg: float = 0.8
@export var forward_tilt_deg: float = 1.5
@export var tilt_return_speed: float = 18.0

@export_group("Procedural Blend")
@export var procedural_blend_speed: float = 6.0

@export_group("Aim Down Sights (optional)")
## Position offset of weapon_node when aiming.
@export var ads_position_offset: Vector3 = Vector3.ZERO
## Rotation offset of weapon_node when aiming (displayed as degrees in inspector).
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees") var ads_rotation_offset: Vector3 = Vector3.ZERO
## Overall influence — 0 = no ADS effect, 1 = full offset applied.
@export var ads_influence: float = 1.0
@export var ads_blend_speed: float = 10.0
## Multiplier for mouse-look sway while aiming (lower = steadier).
@export var ads_sway_multiplier: float = 0.35

@export_group("Sprint Weapon Tilt")
## Position offset of weapon_node when sprinting.
@export var sprint_position_offset: Vector3 = Vector3(0.02, -0.02, -0.04)
## Rotation offset of weapon_node when sprinting (displayed as degrees in inspector).
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees") var sprint_rotation_offset: Vector3 = Vector3(deg_to_rad(-5.0), deg_to_rad(15.0), deg_to_rad(3.0))
## How quickly the weapon blends into/out of sprint pose.
@export var sprint_blend_speed: float = 8.0

@export_group("Gunfire Audio")
@export var gunfire_sounds: Array[AudioStream] = []
@export var gunfire_player: AudioStreamPlayer3D

@export_group("Bullet Casing Ejection")
@export var casing_scene: PackedScene
@export var ejection_port: Node3D
@export var ejection_impulse: Vector3 = Vector3(2.0, 3.0, -1.0)

var original_transform: Transform3D
var reload_step: int = 0

var state: State = State.IDLE:
	set(value):
		if state == value:
			return
		state = value
		state_changed.emit(state)

var shooting: bool:
	get:
		return state == State.FIRING
var reloading: bool:
	get:
		return state == State.RELOADING

var _idle_time: float = 0.0
var _idle_amount: float = 1.0
var _idle_pos: Vector3 = Vector3.ZERO
var _idle_rot: Vector3 = Vector3.ZERO

var _bob_time: float = 0.0
var _current_bob_pos: Vector3 = Vector3.ZERO
var _current_bob_rot: Vector3 = Vector3.ZERO
var _bob_step_jolt: float = 0.0
var _bob_last_step: int = 0
var _bob_random_amp: Vector3 = Vector3.ONE

var _current_tilt_rot: Vector2 = Vector2.ZERO

var _current_sway_rot: Vector2 = Vector2.ZERO
var _mouse_delta: Vector2 = Vector2.ZERO

var _is_ads: bool = false
var _ads_weight: float = 0.0
var _sprint_weight: float = 0.0


func _ready() -> void:
	if not weapon_node:
		weapon_node = get_parent() as Node3D
	if not animator:
		animator = get_parent().get_node_or_null("SHOTGUN-PLAYER") as AnimationPlayer
	if not player:
		var p := get_parent()
		while p:
			if p is CharacterBody3D:
				player = p
				break
			p = p.get_parent()

	if not weapon_node:
		push_error("WeaponViewmodelController: no weapon_node assigned and parent is not a Node3D.")
		set_process(false)
		set_process_input(false)
		return
	if not is_instance_valid(player):
		push_warning("WeaponViewmodelController: no CharacterBody3D player found - movement bob and strafe tilt will stay neutral.")

	if not gunfire_player and not gunfire_sounds.is_empty():
		gunfire_player = AudioStreamPlayer3D.new()
		gunfire_player.name = "GunfirePlayer"
		add_child(gunfire_player)

	original_transform = weapon_node.transform

	if animator:
		animator.animation_finished.connect(_on_anim_finished)
		_strip_stale_idle_track()
		_warn_if_animator_targets_weapon_node()
		animator.stop()
		animator.speed_scale = 1.3
	else:
		push_warning("WeaponViewmodelController: no AnimationPlayer found - baked fire/reload animations are disabled, procedural motion only.")

	_preinit_audio()


func _preinit_audio() -> void:
	if not gunfire_player or gunfire_sounds.is_empty():
		return
	var prev_stream = gunfire_player.stream
	var prev_volume = gunfire_player.volume_db
	var prev_pitch = gunfire_player.pitch_scale
	gunfire_player.stream = gunfire_sounds[0]
	gunfire_player.volume_db = -80
	gunfire_player.pitch_scale = 1.0
	gunfire_player.play()
	gunfire_player.stop()
	gunfire_player.stream = prev_stream
	gunfire_player.volume_db = prev_volume
	gunfire_player.pitch_scale = prev_pitch


func _strip_stale_idle_track() -> void:
	for lib_name in animator.get_animation_library_list():
		var lib := animator.get_animation_library(lib_name)
		if lib and lib.has_animation("SHOTGUN IDLE"):
			lib.remove_animation("SHOTGUN IDLE")


func _warn_if_animator_targets_weapon_node() -> void:
	var anim_root := animator.get_node_or_null(animator.root_node)
	if not anim_root:
		return
	for lib_name in animator.get_animation_library_list():
		var lib := animator.get_animation_library(lib_name)
		if not lib:
			continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			for track_idx in range(anim.get_track_count()):
				var node_only := str(anim.track_get_path(track_idx)).split(":")[0]
				if anim_root.get_node_or_null(NodePath(node_only)) == weapon_node:
					push_warning("WeaponViewmodelController: animation '%s' has a track targeting weapon_node directly - retarget it to a child mesh/skeleton or it will fight procedural sway every frame." % anim_name)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative


func _process(delta: float) -> void:
	if not weapon_node:
		return

	var baked_playing := animator != null and animator.is_playing()
	var moving := is_instance_valid(player) and player.is_on_floor() and player.velocity.length() > 0.1

	_update_idle(delta, moving or baked_playing)
	_update_bob(delta, moving, baked_playing or _is_ads)
	_update_tilt(delta, baked_playing)
	_update_sway(delta)
	_ads_weight = float(move_toward(_ads_weight, 1.0 if _is_ads else 0.0, ads_blend_speed * delta))
	var sprinting: bool = is_instance_valid(player) and player.has_method("is_sprinting") and player.is_sprinting() and state == State.IDLE and not _is_ads and state == State.IDLE and not _is_ads
	_sprint_weight = float(move_toward(_sprint_weight, 1.0 if sprinting else 0.0, sprint_blend_speed * delta))
	_compose_transform()


func _update_idle(delta: float, suppress: bool) -> void:
	_idle_time += delta
	_idle_amount = float(move_toward(_idle_amount, 0.0 if suppress else 1.0, procedural_blend_speed * delta))
	_idle_pos = Vector3(
		float(sin(_idle_time * idle_pos_speed.x) * idle_pos_amplitude.x),
		float(sin(_idle_time * idle_pos_speed.y) * idle_pos_amplitude.y),
		float(cos(_idle_time * idle_pos_speed.z) * idle_pos_amplitude.z)
	) * _idle_amount
	_idle_rot = Vector3(
		float(sin(_idle_time * idle_rot_speed.x) * deg_to_rad(idle_rot_amplitude_deg.x)),
		float(sin(_idle_time * idle_rot_speed.y) * deg_to_rad(idle_rot_amplitude_deg.y)),
		float(sin(_idle_time * idle_rot_speed.z) * deg_to_rad(idle_rot_amplitude_deg.z))
	) * _idle_amount


func _update_bob(delta: float, moving: bool, suppress: bool) -> void:
	var active := moving and not suppress
	_bob_time += delta if active else 0.0

	var speed_factor: float = 1.0
	if is_instance_valid(player) and bob_reference_speed > 0.0:
		speed_factor = float(clamp(player.velocity.length() / bob_reference_speed, 0.0, 1.0))

	var freq: float = bob_frequency * speed_factor

	# ── Position bob (lateral + vertical) ──────────────────────────────────
	var pos_target: Vector3 = Vector3.ZERO
	if active:
		pos_target = Vector3(
			float(sin(_bob_time * freq) * bob_amplitude.x * _bob_random_amp.x),
			float(abs(cos(_bob_time * freq)) * bob_amplitude.y * _bob_random_amp.y),
			0.0
		)
	_current_bob_pos = _current_bob_pos.lerp(pos_target, float(clamp(bob_return_speed * delta, 0.0, 1.0)))

	# ── Rotational bob (pitch forward + roll) ──────────────────────────────
	var rot_target: Vector3 = Vector3.ZERO
	if active:
		var rot_amp: Vector3 = Vector3(
			float(deg_to_rad(bob_rotation_deg.x)),
			float(deg_to_rad(bob_rotation_deg.y)),
			float(deg_to_rad(bob_rotation_deg.z))
		)
		rot_target = Vector3(
			float(sin(_bob_time * freq) * rot_amp.x * _bob_random_amp.x),
			0.0,
			float(sin(_bob_time * freq * 0.5) * rot_amp.z * _bob_random_amp.z)
		)
	_current_bob_rot = _current_bob_rot.lerp(rot_target, float(clamp(bob_return_speed * delta, 0.0, 1.0)))

	# ── Step impulse jolt (per footstep) ───────────────────────────────────
	# Each half-cycle of the sine wave is one step.
	var current_step: int = int(_bob_time * freq / PI)
	if active and current_step != _bob_last_step:
		_bob_last_step = current_step
		_bob_step_jolt = bob_step_impulse * (1.0 + float(randf_range(-bob_step_randomness, bob_step_randomness)))
		# Re-roll random amplitude variation per step
		_bob_random_amp = Vector3(
			1.0 + float(randf_range(-bob_step_randomness, bob_step_randomness)),
			1.0 + float(randf_range(-bob_step_randomness, bob_step_randomness)),
			1.0 + float(randf_range(-bob_step_randomness, bob_step_randomness))
		)
	_bob_step_jolt = float(move_toward(_bob_step_jolt, 0.0, bob_step_decay * delta))
	_current_bob_pos.y += _bob_step_jolt


func _update_tilt(delta: float, suppress: bool) -> void:
	var target := Vector2.ZERO
	if is_instance_valid(player) and not suppress:
		var ads_suppress := _is_ads
		var drift_suppress: bool = player.has_method("is_crouch_drifting") and player.is_crouch_drifting()
		if not ads_suppress and not drift_suppress:
			var local_vel: Vector3 = player.transform.basis.inverse() * player.velocity
			var abs_x := absf(local_vel.x)
			var abs_z := absf(local_vel.z)
			if abs_z > abs_x:
				# Dominant direction is forward/back — pitch only
				var pitch := float(clamp(local_vel.z / bob_reference_speed, -1.0, 1.0) * deg_to_rad(forward_tilt_deg))
				target = Vector2(pitch, 0.0)
			elif abs_x > abs_z:
				# Dominant direction is left/right — roll only
				var roll := float(-clamp(local_vel.x / bob_reference_speed, -1.0, 1.0) * deg_to_rad(tilt_amount_deg))
				target = Vector2(0.0, roll)
	var w := float(clamp(tilt_return_speed * delta, 0.0, 1.0))
	_current_tilt_rot = _current_tilt_rot.lerp(target, w)


func _update_sway(delta: float) -> void:
	var clamped: Vector2 = Vector2(
		float(clamp(_mouse_delta.x, -max_mouse_delta_per_frame, max_mouse_delta_per_frame)),
		float(clamp(_mouse_delta.y, -max_mouse_delta_per_frame, max_mouse_delta_per_frame))
	)
	_mouse_delta = Vector2.ZERO

	var max_rad: float = float(deg_to_rad(sway_max_angle_deg))
	var ads_mult: float = float(lerp(1.0, ads_sway_multiplier, _ads_weight * ads_influence))
	var target_yaw: float = float(clamp(deg_to_rad(clamped.x * mouse_sensitivity), -max_rad, max_rad) * ads_mult)
	var target_pitch: float = float(clamp(deg_to_rad(clamped.y * mouse_sensitivity), -max_rad, max_rad) * ads_mult)

	var w: float = float(clamp(sway_return_speed * delta, 0.0, 1.0))
	_current_sway_rot.x = float(clamp(lerp(_current_sway_rot.x, target_pitch, w), -max_rad, max_rad))
	_current_sway_rot.y = float(clamp(lerp(_current_sway_rot.y, target_yaw, w), -max_rad, max_rad))


func _compose_transform() -> void:
	var ads_blend := _ads_weight * ads_influence
	var sprint_blend := _sprint_weight
	var pos: Vector3 = _idle_pos + _current_bob_pos + ads_position_offset * ads_blend + sprint_position_offset * sprint_blend
	var base_euler: Vector3 = _idle_rot + Vector3(_current_sway_rot.x + _current_tilt_rot.x, _current_sway_rot.y, _current_tilt_rot.y) + _current_bob_rot
	var ads_rot: Basis = Basis.from_euler(ads_rotation_offset * ads_blend)
	var sprint_rot: Basis = Basis.from_euler(sprint_rotation_offset * sprint_blend)
	var rot: Basis = Basis.from_euler(base_euler) * ads_rot * sprint_rot
	var offset := Transform3D(rot, pos)
	weapon_node.transform = original_transform * offset


func set_aiming(value: bool) -> void:
	_is_ads = value


func is_ads() -> bool:
	return _is_ads


func play_shoot() -> void:
	if state != State.IDLE:
		return
	if not animator or not animator.has_animation(shoot_anim):
		push_warning("WeaponViewmodelController: shoot_anim '%s' not found." % shoot_anim)
		return
	state = State.FIRING
	if recoil and recoil.has_method("start"):
		recoil.start()
	animator.play(shoot_anim)
	_play_gunfire()
	fired.emit()


func _play_gunfire() -> void:
	if gunfire_sounds.is_empty() or not gunfire_player:
		return
	gunfire_player.stream = gunfire_sounds[randi() % gunfire_sounds.size()]
	gunfire_player.play()
	# EnemyNoise.emit(gunfire_player.global_position)  # TODO: not needed for now


func _spawn_casing() -> void:
	eject_casing()


func _eject_casing() -> void:
	eject_casing()


func eject_casing() -> void:
	if not casing_scene or not ejection_port:
		return
	var casing := casing_scene.instantiate() as Node3D
	if not casing:
		return
	get_tree().current_scene.add_child(casing)
	casing.global_transform = ejection_port.global_transform

	var force: Vector3 = casing.get("ejection_force") if casing.get("ejection_force") != null else Vector3(3.0, 0.8, 0.0)
	var force_rand: Vector3 = casing.get("ejection_force_random") if casing.get("ejection_force_random") != null else Vector3(0.5, 0.3, 0.5)
	var torque: Vector3 = casing.get("ejection_torque") if casing.get("ejection_torque") != null else Vector3(-3.0, 0.0, 5.0)
	var torque_rand: Vector3 = casing.get("ejection_torque_random") if casing.get("ejection_torque_random") != null else Vector3(2.0, 3.0, 2.0)

	force += Vector3(
		randf_range(-force_rand.x, force_rand.x),
		randf_range(-force_rand.y, force_rand.y),
		randf_range(-force_rand.z, force_rand.z)
	)
	torque += Vector3(
		randf_range(-torque_rand.x, torque_rand.x),
		randf_range(-torque_rand.y, torque_rand.y),
		randf_range(-torque_rand.z, torque_rand.z)
	)

	for child in casing.get_children():
		if child is RigidBody3D:
			child.apply_central_impulse(ejection_port.global_transform.basis * force)
			child.apply_torque_impulse(torque)
			break


func start_reload() -> void:
	if state != State.IDLE:
		return
	if not animator or not animator.has_animation(start_reload_anim):
		push_warning("WeaponViewmodelController: start_reload_anim '%s' not found." % start_reload_anim)
		return
	state = State.RELOADING
	reload_step = 0
	animator.play(start_reload_anim)
	reload_started.emit()


func _reload_next_bullet() -> void:
	if state != State.RELOADING:
		return
	if reload_step >= max_reload_steps:
		push_warning("WeaponViewmodelController: max_reload_steps (%d) reached without the magazine reporting full - check player.get_ammo()/get_ammo_max(). Forcing the reload to finish." % max_reload_steps)
		_finish_reload()
		return
	if not animator or not animator.has_animation(reload_bullet_anim):
		_finish_reload()
		return
	reload_step += 1
	animator.play(reload_bullet_anim)
	bullet_loaded.emit(reload_step)


func increase_ammo() -> void:
	if is_instance_valid(player) and player.has_method("reload_one_bullet"):
		player.reload_one_bullet()


func _is_magazine_full() -> bool:
	if is_instance_valid(player) and player.has_method("get_ammo") and player.has_method("get_ammo_max"):
		return player.get_ammo() >= player.get_ammo_max()
	return false


func _finish_reload() -> void:
	if state != State.RELOADING:
		return
	reload_step = 0
	if animator and animator.has_animation(after_reload_anim):
		animator.play(after_reload_anim)
	else:
		state = State.IDLE
		reload_finished.emit()


func cancel_reload() -> void:
	_finish_reload()


func reset_viewmodel() -> void:
	state = State.IDLE
	reload_step = 0
	if animator and animator.has_animation(reset_anim):
		animator.play(reset_anim)


func _reset_bones() -> void:
	if animator:
		animator.stop(true)


func _on_anim_finished(anim_name: String) -> void:
	if anim_name == shoot_anim:
		state = State.IDLE
		_reset_bones()
	elif anim_name == start_reload_anim:
		_reload_next_bullet()
	elif anim_name == reload_bullet_anim:
		if _is_magazine_full():
			_finish_reload()
		else:
			_reload_next_bullet()
	elif anim_name == after_reload_anim:
		state = State.IDLE
		_reset_bones()
		reload_finished.emit()
	elif anim_name == reset_anim:
		state = State.IDLE
		_reset_bones()
