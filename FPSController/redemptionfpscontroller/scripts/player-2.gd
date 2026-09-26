extends CharacterBody3D

@export_category("Player")
## Maximum movement speed in meters/sec.
@export_range(1, 35, 1) var speed: float = 10
## How fast the player accelerates to target velocity.
@export_range(10, 400, 1) var acceleration: float = 100
## Height of the jump in meters.
@export_range(0.1, 15.0, 0.1) var jump_height: float = 1
## Mouse look sensitivity.
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1
## Enable or disable camera looking.
@export var lookAllowed: bool
## Enable or disable player movement.
@export var moveAllowed: bool

@export_category("Sprint")
## Allow sprinting when enabled.
@export var enable_sprint: bool = true
## Cooldown in seconds after sprint stamina runs out.
@export var sprint_cooldown_time: float = 2.0
## How long the player can sprint in seconds.
@export var sprint_time: float = 3.0
## How fast stamina recharges per second when on the ground.
@export var sprint_replenish_rate: float = 2.0
## Speed multiplier while sprinting.
@export_range(1.0, 3.0) var sprint_speed: float = 2.0

@export_category("Crouch")
## Allow crouching when enabled.
@export var enable_crouch: bool = true
## Speed multiplier while crouched (lower = slower).
@export var crouch_speed_multiplier: float = 0.55
## Speed multiplier while aiming down sights.
@export var ads_speed_multiplier: float = 0.6
## The player's collision shape node.
@export var collision_shape: CollisionShape3D
## How much the collision capsule shrinks when crouching.
@export var crouch_height_reduction: float = 0.8
## AnimationPlayer that plays crouch/uncrouch animations.
@export var crouch_animation_player: AnimationPlayer
## Names of crouch and uncrouch animations.
@export var crouch_animations: Array[String] = ["crouch", "uncrouch"]
## Camera effects node for recoil, bob, shake, etc.
@export var camera_effects: CameraEffects
## Weapon viewmodel controller for shoot/reload/ADS.
@export var weapon_viewmodel: WeaponViewmodelController

@export_category("Crouch Drift")
## How long the crouch drift (slide) lasts in seconds.
@export var drift_duration: float = 0.8
## How fast the drift decelerates per second.
@export var drift_deceleration: float = 18.0
## How strongly the player can steer the drift direction.
@export var drift_steer_strength: float = 10.0

@export_category("Step Climbing")
## Maximum height the player can auto-climb (in meters).
@export var step_max_height: float = 0.3

var drift_velocity: Vector3 = Vector3.ZERO

enum MoveState { IDLE, WALK, SPRINT, CROUCH, CROUCH_DRIFT, AIR }

var move_state: MoveState = MoveState.IDLE
var drift_timer: float = 0.0

## Maximum ammo capacity of the shotgun.
@export var ammo_max: int = 8
var current_ammo: int = 8

# Hardcoded — Player > CameraGimbal > InnerGimbal > Camera3D
var gimbal_h : Node3D
var gimbal_v : Node3D
var camera   : Camera3D

var jumping       : bool  = false
var mouse_captured: bool  = false
var isMoving      : bool  = false
var gravity       : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var move_dir      : Vector2
var look_dir      : Vector2
var walk_vel      : Vector3
var grav_vel      : Vector3
var jump_vel      : Vector3

# Footstep noise — enemies hear the player walking/running
var _footstep_timer := 0.0
@export var footstep_interval_walk: float = 0.5
@export var footstep_interval_sprint: float = 0.3
@export var footstep_interval_crouch: float = 1.2
@export var crouch_silent: bool = true

var original_collision_height: float = 0.0
var original_collision_position_y: float = 0.0

const NORMAL_speed: int = 1
var speed_modifier: float = NORMAL_speed
var sprint_on_cooldown: bool = false
var sprint_time_remaining: float = 3.0
var crouched: bool = false
var _sprint_cooldown_remaining: float = 0.0
var _pending_auto_reload: bool = false
@onready var sprint_bar: Range = get_node_or_null(^"CanvasLayer/SprintBar2/SprintBar") as Range
@onready var debug_panel: Label

func _ready() -> void:
	gimbal_h = get_node_or_null("CameraGimbal")                     as Node3D
	gimbal_v = get_node_or_null("CameraGimbal/InnerGimbal")         as Node3D
	camera   = get_node_or_null("CameraGimbal/InnerGimbal/Camera3D") as Camera3D

	if camera:
		camera.current = true

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		original_collision_height = collision_shape.shape.height
		original_collision_position_y = collision_shape.position.y

	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(45)
	floor_constant_speed = true

	if not camera_effects:
		camera_effects = get_node_or_null("CameraGimbal/InnerGimbal/Camera3D/CameraEffects") as CameraEffects
	if not weapon_viewmodel:
		weapon_viewmodel = get_node_or_null("CameraGimbal/InnerGimbal/Camera3D/player-shotgun-main/WeaponViewmodel") as WeaponViewmodelController

	print("✅ gimbal_h → ", gimbal_h)
	print("✅ gimbal_v → ", gimbal_v)
	print("✅ camera   → ", camera)
	print("✅ cam fx   → ", camera_effects)
	print("✅ vm model → ", weapon_viewmodel)

	call_deferred("capture_mouse")
	_ready_sprint()
	_update_ammo_display()
	_init_debug_panel()
	_fix_skeleton_binding()

func _fix_skeleton_binding() -> void:
	await get_tree().process_frame
	var shotgun_player = get_node_or_null("CameraGimbal/InnerGimbal/Camera3D/player-shotgun-main/SHOTGUN-PLAYER") as AnimationPlayer
	if shotgun_player and shotgun_player.has_animation("RESET"):
		shotgun_player.play("RESET")

# ═══════════════════════════════════════════════════════════════════════════
# STEP CLIMBING — Exact Andicraft/stairs-character logic
# step_up BEFORE move_and_slide, step_down AFTER move_and_slide
# ═══════════════════════════════════════════════════════════════════════════

var _collider_margin: float = 0.01
var _step_grounded: bool = false
var _step_desired_velocity: Vector3 = Vector3.ZERO
const _STEP_HORIZONTAL := Vector3(1, 0, 1)


func move_and_stair_step() -> void:
	_stair_step_up()
	move_and_slide()


func _stair_step_up() -> void:
	if not _step_grounded:
		return

	var horizontal_velocity := velocity * _STEP_HORIZONTAL
	var testing_velocity := horizontal_velocity if horizontal_velocity != Vector3.ZERO else _step_desired_velocity

	if testing_velocity == Vector3.ZERO:
		return

	var result := PhysicsTestMotionResult3D.new()
	var params := PhysicsTestMotionParameters3D.new()
	params.margin = _collider_margin

	var motion_transform := global_transform
	var distance := testing_velocity * get_physics_process_delta_time()
	params.from = motion_transform
	params.motion = distance

	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return

	var remainder := result.get_remainder()
	motion_transform = motion_transform.translated(result.get_travel())

	var step_up := step_max_height * Vector3.UP
	params.from = motion_transform
	params.motion = step_up
	PhysicsServer3D.body_test_motion(get_rid(), params, result)
	motion_transform = motion_transform.translated(result.get_travel())
	var step_up_distance := result.get_travel().length()

	params.from = motion_transform
	params.motion = remainder
	PhysicsServer3D.body_test_motion(get_rid(), params, result)
	motion_transform = motion_transform.translated(result.get_travel())

	params.from = motion_transform
	params.motion = Vector3.DOWN * step_up_distance

	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return

	motion_transform = motion_transform.translated(result.get_travel())

	var surface_normal: Vector3 = result.get_collision_normal(0)
	if surface_normal.angle_to(Vector3.UP) > floor_max_angle:
		return

	global_position.y = motion_transform.origin.y



func _physics_process(delta: float) -> void:
	if mouse_captured: _handle_joypad_camera_rotation(delta)

	_handle_sprint(delta)
	apply_crouch_effects()

	if _pending_auto_reload and weapon_viewmodel and weapon_viewmodel.state == WeaponViewmodelController.State.IDLE:
		_pending_auto_reload = false
		weapon_viewmodel.start_reload()

	_step_grounded = is_on_floor()

	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	_step_desired_velocity = velocity * _STEP_HORIZONTAL

	if moveAllowed:
		move_and_stair_step()

	_update_move_state()
	_handle_footstep_noise(delta)


# ─── _input NOT _unhandled_input ───────────────────────────────────────────
# _unhandled_input Control nodes block karte hain. _input seedha aata hai.
func _input(event: InputEvent) -> void:
	# ─── Unlock Mouse (Ctrl+Escape) ────────────────────────────────────────
	if Input.is_action_just_pressed("unlock-mouse"):
		if mouse_captured:
			release_mouse()
		else:
			capture_mouse()

	if event is InputEventMouseMotion and mouse_captured:
		look_dir = event.relative * 0.001
		_rotate_camera()

	# ─── Jump ────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("jump") and moveAllowed:
		jumping = true

	# ─── Crouch / Crouch Drift (C key) ──────────────────────────────────────
	if enable_crouch and Input.is_action_just_pressed("crouch"):
		var holding_sprint := Input.is_action_pressed("sprint") and not sprint_on_cooldown
		match move_state:
			MoveState.CROUCH_DRIFT:
				_finish_drift_to_crouch()
			MoveState.CROUCH:
				_exit_crouch()
			_:
				if holding_sprint and is_on_floor():
					_enter_crouch_drift()
				else:
					_enter_crouch()

	# ─── Sprint (Shift) ─────────────────────────────────────────────────────
	if enable_sprint and moveAllowed and Input.is_action_just_pressed("sprint"):
		match move_state:
			MoveState.IDLE, MoveState.WALK:
				_enter_sprint()

	if Input.is_action_just_released("sprint"):
		if move_state == MoveState.SPRINT:
			_exit_sprint_to_walk()

	# ─── ADS (RMB) ───────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("aiming") and mouse_captured:
		if weapon_viewmodel:
			weapon_viewmodel.set_aiming(true)
	if Input.is_action_just_released("aiming"):
		if weapon_viewmodel:
			weapon_viewmodel.set_aiming(false)

	# ─── Undo (U / Joystick X) ─────────────────────────────────────────────
	if event.is_action_pressed("undo-action"):
		var btn = get_node_or_null("CanvasLayer-1/m button_undo")
		if btn and btn.visible and not btn.disabled:
			btn.button_pressed = false
			btn.pressed.emit()

	# ─── Shoot (LMB) ──────────────────────────────────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and mouse_captured:
		if weapon_viewmodel and weapon_viewmodel.reloading:
			weapon_viewmodel.cancel_reload()
		else:
			use_ammo()

	# ─── Reload (R) ───────────────────────────────────────────────────────────
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and mouse_captured:
		if current_ammo < ammo_max:
			if weapon_viewmodel and not weapon_viewmodel.reloading and not weapon_viewmodel.shooting:
				weapon_viewmodel.start_reload()

func _process(delta: float) -> void:
	CheckIfMoving()

	if camera_effects:
		camera_effects.crouched = move_state == MoveState.CROUCH or move_state == MoveState.CROUCH_DRIFT

	if move_state == MoveState.CROUCH_DRIFT:
		drift_timer -= delta
		var drift_speed: float = drift_velocity.length()
		var crouch_speed: float = speed * crouch_speed_multiplier
		if drift_timer <= 0.0 or drift_speed <= crouch_speed:
			_finish_drift_to_crouch()

	_update_debug_panel()

# ═══════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════
#
#  IDLE ←→ WALK ←→ SPRINT ──C──→ CROUCH_DRIFT ──→ CROUCH ←→ IDLE
#   ↑       ↑       ↑  ←──────      ↑   ←──────      ↑
#   │       │       │   Shift+WASD  │   Shift+WASD   │
#   │       │       │               │                │
#   │       │       │  release C → SPRINT            │
#   │       │       │  release Shift → CROUCH        │
#   │       │       │               │                │
#   └───────┴────────── JUMP ──→ AIR ──→ any state ───┘
#
# ═══════════════════════════════════════════════════════════════════════════

func _update_move_state() -> void:
	var on_floor := is_on_floor()
	var moving := move_dir.length() > 0.01
	var pressing_sprint := Input.is_action_pressed("sprint") and not sprint_on_cooldown

	if not on_floor:
		if move_state != MoveState.AIR:
			move_state = MoveState.AIR
		return

	if move_state == MoveState.AIR:
		if crouched:
			move_state = MoveState.CROUCH
		elif moving and pressing_sprint:
			_enter_sprint()
		elif moving:
			move_state = MoveState.WALK
			speed_modifier = NORMAL_speed
		else:
			move_state = MoveState.IDLE
			speed_modifier = NORMAL_speed
		return

	match move_state:
		MoveState.CROUCH_DRIFT:
			pass  # exits only via _input() (release C → sprint, release Shift → crouch) or drift_timer expiry

		MoveState.CROUCH:
			if moving and pressing_sprint:
				_exit_crouch()
				_enter_sprint()

		MoveState.SPRINT:
			if not moving:
				move_state = MoveState.IDLE
				speed_modifier = NORMAL_speed
			elif not Input.is_action_pressed("sprint"):
				_exit_sprint_to_walk()

		MoveState.WALK:
			if moving and pressing_sprint:
				_enter_sprint()
			elif not moving:
				move_state = MoveState.IDLE
				speed_modifier = NORMAL_speed

		MoveState.IDLE:
			if moving and pressing_sprint:
				_enter_sprint()
			elif moving:
				move_state = MoveState.WALK
				speed_modifier = NORMAL_speed

# ═══════════════════════════════════════════════════════════════════════════
# STATE ENTER / EXIT
# ═══════════════════════════════════════════════════════════════════════════

func _enter_sprint() -> void:
	if sprint_on_cooldown:
		return
	move_state = MoveState.SPRINT
	speed_modifier = sprint_speed
	crouched = false

func _exit_sprint_to_walk() -> void:
	speed_modifier = NORMAL_speed
	move_state = MoveState.WALK

func _enter_crouch() -> void:
	crouched = true
	move_state = MoveState.CROUCH
	speed_modifier = NORMAL_speed

func _exit_crouch() -> void:
	crouched = false
	move_state = MoveState.IDLE
	speed_modifier = NORMAL_speed

func is_crouching() -> bool:
	return move_state == MoveState.CROUCH

func is_crouch_drifting() -> bool:
	return move_state == MoveState.CROUCH_DRIFT

func is_sprinting() -> bool:
	return move_state == MoveState.SPRINT

func _enter_crouch_drift() -> void:
	if not is_on_floor():
		_enter_crouch()
		return

	move_state = MoveState.CROUCH_DRIFT
	crouched = false
	drift_timer = drift_duration
	speed_modifier = sprint_speed

	drift_velocity = Vector3(velocity.x, 0.0, velocity.z)

	if drift_velocity.length() < 0.1:
		var seed_dir := _get_move_world_dir(Input.get_vector("move_left", "move_right", "move_forward", "move_backwards"))
		if seed_dir.length() > 0.01:
			drift_velocity = seed_dir * (speed * sprint_speed)


func force_crouch_drift() -> void:
	_enter_crouch_drift()


func _finish_drift_to_crouch() -> void:
	move_state = MoveState.CROUCH
	crouched = true
	speed_modifier = NORMAL_speed
	drift_velocity = Vector3.ZERO

func CheckIfMoving() -> void:
	var avg = (velocity.x + velocity.y + velocity.z) / 3.0
	isMoving = (avg != 0.0 and moveAllowed)

func _handle_footstep_noise(delta: float) -> void:
	if not is_on_floor():
		return
	if not (move_dir.length() > 0.01):
		_footstep_timer = 0.0
		return
	if crouched and crouch_silent:
		return

	var interval := footstep_interval_walk
	match move_state:
		MoveState.SPRINT:
			interval = footstep_interval_sprint
		MoveState.CROUCH, MoveState.CROUCH_DRIFT:
			interval = footstep_interval_crouch

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = interval
		_emit_footstep_noise()

func _emit_footstep_noise() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("on_noise"):
			enemy.on_noise(global_position)

func capture_mouse() -> void:
	mouse_captured = true
	# Don't capture while window is unfocused — mouse would be trapped
	if GlobalVariables.window_focused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func release_mouse() -> void:
	mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _rotate_camera(sens_mod: float = 1.0) -> void:
	if not lookAllowed: return
	if gimbal_h:
		gimbal_h.rotation.y -= look_dir.x * camera_sens * sens_mod
	if gimbal_v:
		gimbal_v.rotation.x = clamp(
			gimbal_v.rotation.x - look_dir.y * camera_sens * sens_mod,
			-1.5, 1.5
		)

func _handle_joypad_camera_rotation(delta: float, sens_mod: float = 1.0) -> void:
	var joypad_dir := Input.get_vector("look_left","look_right","look_up","look_down")
	if joypad_dir.length() > 0:
		look_dir += joypad_dir * delta
		_rotate_camera(sens_mod)
		look_dir = Vector2.ZERO

func _get_move_world_dir(input_dir: Vector2) -> Vector3:
	if gimbal_h == null:
		return Vector3.ZERO
	if input_dir.length() <= 0.01:
		return Vector3.ZERO
	var basis := gimbal_h.global_transform.basis
	var forward := -basis.z
	var right := basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (forward * -input_dir.y + right * input_dir.x).normalized()


func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector("move_left","move_right","move_forward","move_backwards")
	if gimbal_h == null: return Vector3.ZERO

	var walk_dir := _get_move_world_dir(move_dir)

	if move_state == MoveState.CROUCH_DRIFT:
		if walk_dir.length() > 0.01:
			var steer_target := walk_dir * drift_velocity.length()
			drift_velocity = drift_velocity.move_toward(steer_target, drift_steer_strength * delta)

		drift_velocity = drift_velocity.move_toward(Vector3.ZERO, drift_deceleration * delta)
		drift_velocity.y = 0.0
		return drift_velocity

	var final_speed: float = speed * speed_modifier
	if crouched:
		final_speed *= crouch_speed_multiplier
	elif weapon_viewmodel and weapon_viewmodel.is_ads():
		final_speed *= ads_speed_multiplier

	var target_vel := walk_dir * final_speed
	var accel := acceleration * delta

	if walk_dir.length() > 0.01:
		walk_vel = walk_vel.move_toward(target_vel, accel * 12.0)
	else:
		walk_vel = walk_vel.move_toward(Vector3.ZERO, accel * 6.0)

	return walk_vel

func _gravity(delta: float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else \
		grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta)
	return grav_vel

func _jump(delta: float) -> Vector3:
	if jumping and is_on_floor():
		# Perform the jump
		jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
		jumping = false
	elif is_on_floor():
		jump_vel = Vector3.ZERO
	else:
		# Apply gravity to current jump velocity while in air
		jump_vel = jump_vel.move_toward(Vector3.ZERO, gravity * delta)

	return jump_vel


func apply_crouch_effects() -> void:
	if not collision_shape or not collision_shape.shape is CapsuleShape3D:
		return

	var shape := collision_shape.shape as CapsuleShape3D
	var target_height: float = original_collision_height

	if move_state == MoveState.CROUCH or move_state == MoveState.CROUCH_DRIFT:
		target_height = maxf(original_collision_height - crouch_height_reduction, 0.1)

	shape.height = target_height

	var height_delta := original_collision_height - target_height
	collision_shape.position.y = original_collision_position_y - (height_delta * 0.5)


# ═══════════════════════════════════════════════════════════════════════════
# SPRINT — smooth delta-based depletion & replenish
# ═══════════════════════════════════════════════════════════════════════════

func _handle_sprint(delta: float) -> void:
	if move_state == MoveState.SPRINT and sprint_time_remaining > 0.0:
		sprint_time_remaining = maxf(sprint_time_remaining - delta, 0.0)
		if sprint_time_remaining <= 0.0:
			sprint_on_cooldown = true
			_sprint_cooldown_remaining = sprint_cooldown_time
			_exit_sprint_to_walk()
	elif sprint_on_cooldown:
		_sprint_cooldown_remaining = maxf(_sprint_cooldown_remaining - delta, 0.0)
		if _sprint_cooldown_remaining <= 0.0:
			sprint_on_cooldown = false
	elif is_on_floor() and move_state != MoveState.CROUCH_DRIFT:
		sprint_time_remaining = minf(sprint_time_remaining + delta * sprint_replenish_rate, sprint_time)

	if sprint_bar:
		sprint_bar.value = (sprint_time_remaining / sprint_time) * 100.0

func _ready_sprint() -> void:
	sprint_time_remaining = sprint_time
	if sprint_bar:
		sprint_bar.value = 100.0
		sprint_bar.show()


func use_ammo() -> bool:
	if current_ammo <= 0:
		return false
	if weapon_viewmodel and (weapon_viewmodel.reloading or weapon_viewmodel.shooting):
		return false
	current_ammo -= 1
	_update_ammo_display()
	if camera_effects:
		camera_effects.add_recoil()
	if weapon_viewmodel:
		weapon_viewmodel.play_shoot()
		if current_ammo <= 0:
			_pending_auto_reload = true
	return true


func reload_ammo():
	current_ammo = ammo_max
	_update_ammo_display()
	if weapon_viewmodel:
		weapon_viewmodel.finish_reload()


func reload_one_bullet():
	if current_ammo >= ammo_max:
		return
	current_ammo += 1
	_update_ammo_display()


func get_ammo() -> int:
	return current_ammo


func get_ammo_max() -> int:
	return ammo_max


func has_ammo() -> bool:
	return current_ammo > 0


func _init_debug_panel() -> void:
	var existing := get_node_or_null("CanvasLayer/DEBUGPANEL") as Label
	if existing:
		debug_panel = existing
		return
	var canvas := get_node("CanvasLayer")
	if not canvas:
		return
	var label := Label.new()
	label.name = "DEBUGPANEL"
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_color", Color(0, 1, 0.3))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	canvas.add_child(label)
	debug_panel = label


func _update_debug_panel() -> void:
	if not debug_panel:
		return

	var state_names := ["IDLE", "WALK", "SPRINT", "CROUCH", "CROUCH_DRIFT", "AIR"]
	var state_name: String = state_names[move_state] if move_state < state_names.size() else "???"
	var hvel := Vector3(velocity.x, 0.0, velocity.z)

	var kb := ""
	kb += _key_tag("SHIFT", "sprint")
	kb += _key_tag("C", "crouch")
	kb += _key_tag("W", "move_forward")
	kb += _key_tag("A", "move_left")
	kb += _key_tag("S", "move_backwards")
	kb += _key_tag("D", "move_right")
	kb += _key_tag("SPC", "jump")
	kb += _key_tag("RMB", "aiming")

	var txt := ""
	txt += ">> %s\n" % state_name
	txt += "vel: %5.1f  hvel: %5.1f\n" % [velocity.length(), hvel.length()]
	txt += "spd: %.2f  crouch: %s\n" % [speed_modifier, "Y" if crouched else "N"]
	txt += "drift_v: %5.1f  drift_t: %.2f\n" % [drift_velocity.length(), drift_timer]
	txt += "sprint: %.1f/%.1f  cd: %s (%.1f)\n" % [sprint_time_remaining, sprint_time, "Y" if sprint_on_cooldown else "N", _sprint_cooldown_remaining]
	txt += "ammo: %d/%d\n" % [current_ammo, ammo_max]
	txt += kb
	debug_panel.text = txt


func _key_tag(display: String, action: String) -> String:
	if Input.is_action_pressed(action):
		return "[%s]" % display
	return " %s " % display


func _update_ammo_display():
	var ammo_label = get_node_or_null("CanvasLayer/CurrentAmmo2") as Label
	if ammo_label:
		ammo_label.add_theme_color_override("font_color", Color.WHITE)
		ammo_label.text = str(current_ammo)
