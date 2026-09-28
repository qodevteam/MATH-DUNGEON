extends CharacterBody3D

signal enemy_died(enemy: Node)

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }

const STATE_MACHINE_STATES: Array[StringName] = [
	&"Idle", &"Walk", &"Run", &"Attack", &"Attack2", &"Attack3",
	&"Attack Block", &"Impact Absorb", &"Death"
]
const COMBO_ANIMS: Array[StringName] = [&"Attack", &"Attack2", &"Attack3"]

@export_category("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 3.5
@export var run_speed: float = 6.0
@export var attack_damage: float = 15.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 0.55
@export var detection_range: float = 15.0
@export var chase_range: float = 20.0
@export var run_threshold: float = 8.0

@export_category("Behaviour")
@export var turn_speed: float = 8.0
@export var hurt_duration: float = 0.8
@export var hit_flash_time: float = 0.15
@export var knockback_speed: float = 5.0
@export var death_despawn_delay: float = 0.6
@export var repath_interval: float = 0.5

var current_health: float
var state: State = State.IDLE
var player: Node3D
var gravity: float = 9.8
var knockback := Vector3.ZERO

var _agent: NavigationAgent3D
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _playback: AnimationNodeStateMachinePlayback
var _shape: CollisionShape3D
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D
var _flash_timer := 0.0
var _hurt_timer := 0.0
var _death_timer := 0.0
var _repath_timer := 0.0
var _rescan_timer := 0.0
var _attack_cd := 0.0
var _swing_time := -1.0
var _swing_hit_done := false
var _swing_index := 0
var _attack_anim_length := 1.4333
var _death_anim_length := 2.4
var _noise_pos := Vector3.ZERO
var _has_noise := false
var _exclude_rids: Array[RID] = []


func _ready() -> void:
	current_health = max_health
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	floor_snap_length = 0.3
	add_to_group("enemies")
	_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_anim_player = get_node_or_null("enemy/AnimationPlayer") as AnimationPlayer
	_anim_tree = get_node_or_null("enemy/AnimationTree") as AnimationTree
	if _anim_tree:
		_anim_tree.active = true
		_resolve_playback()
		_fix_animation_setup()
	if _anim_player:
		if _anim_player.has_animation("Attack"):
			_attack_anim_length = _anim_player.get_animation("Attack").length
		if _anim_player.has_animation("Death"):
			_death_anim_length = _anim_player.get_animation("Death").length
	_meshes = _collect_meshes(self)
	_exclude_rids = _collect_own_rids(self)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.7)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 1.5
	_agent.radius = 0.4
	_agent.height = 1.8
	add_child(_agent)
	_acquire_player()
	_play_anim("Idle")


func _resolve_playback() -> void:
	_playback = _anim_tree.get("parameters/playback")
	if _playback == null:
		_playback = _anim_tree.get("parameters/StateMachine/playback")
	if _playback == null:
		for p in _anim_tree.get_property_list():
			var pname := String(p["name"])
			if pname.begins_with("parameters/") and pname.contains("playback"):
				_playback = _anim_tree.get(pname)
				if _playback != null:
					break


func _fix_animation_setup() -> void:
	if _anim_player:
		for anim_name in ["Idle", "Walk", "Run"]:
			if _anim_player.has_animation(anim_name):
				_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	var sm := _anim_tree.tree_root as AnimationNodeStateMachine
	if sm == null:
		return
	for i in range(sm.get_transition_count() - 1, -1, -1):
		if not sm.has_node(sm.get_transition_from(i)) or not sm.has_node(sm.get_transition_to(i)):
			sm.remove_transition_by_index(i)
	for i in sm.get_transition_count():
		var tr := sm.get_transition(i)
		var from := sm.get_transition_from(i)
		if from == &"Start":
			tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
			tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			tr.xfade_time = 0.1
			continue
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		tr.xfade_time = 0.1 if _is_combat_state(from) or _is_combat_state(sm.get_transition_to(i)) else 0.15
	for from in STATE_MACHINE_STATES:
		if from == &"Death":
			continue
		for to in STATE_MACHINE_STATES:
			if to == from:
				continue
			if not sm.has_transition(from, to):
				var tr := AnimationNodeStateMachineTransition.new()
				tr.xfade_time = 0.12
				sm.add_transition(from, to, tr)
	for to in STATE_MACHINE_STATES:
		if to != &"Death" and sm.has_transition(&"Death", to):
			sm.remove_transition(&"Death", to)
	sm.set_allow_transition_to_self(false)


func _is_combat_state(state_name: StringName) -> bool:
	return state_name != &"Idle" and state_name != &"Walk" and state_name != &"Run"


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_meshes(child))
	return out


func _collect_own_rids(node: Node) -> Array[RID]:
	var out: Array[RID] = []
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		out.append_array(_collect_own_rids(child))
	return out


func _physics_process(delta: float) -> void:
	_tick_feedback(delta)
	if player == null:
		_rescan_timer -= delta
		if _rescan_timer <= 0.0:
			_rescan_timer = 1.0
			_acquire_player()
	match state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead(delta)


func _state_idle(delta: float) -> void:
	_integrate(Vector3.ZERO, delta)
	_play_anim("Idle")
	if _detect_player():
		_enter_chase()


func _state_chase(delta: float) -> void:
	if player == null and not _has_noise:
		_enter_idle()
		return
	if player != null:
		if _player_dead() or _player_dist() > chase_range:
			_enter_idle()
			return
		if _player_dist() <= attack_range and _has_line_of_sight():
			_enter_attack()
			return
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = repath_interval
		_agent.target_position = _chase_goal()
	var goal := _chase_goal()
	if not _agent.is_navigation_finished():
		var next_pos := _agent.get_next_path_position()
		if next_pos.distance_to(global_position) > 0.3:
			goal = next_pos
	var dir := goal - global_position
	dir.y = 0.0
	if player == null and dir.length() < 1.5:
		_has_noise = false
		_enter_idle()
		return
	var use_run := player != null and dir.length() > run_threshold
	_integrate(dir.normalized() * (run_speed if use_run else move_speed) if dir.length() > 0.001 else Vector3.ZERO, delta)
	_face(dir, delta)
	_play_anim("Run" if use_run else "Walk")


func _state_attack(delta: float) -> void:
	if player == null:
		_enter_idle()
		return
	if _player_dead() or _player_dist() > attack_range * 1.2 or not _has_line_of_sight():
		_enter_chase()
		return
	_face(player.global_position - global_position, delta)
	_integrate(Vector3.ZERO, delta)
	if _swing_time >= 0.0:
		_swing_time += delta
		if not _swing_hit_done and _swing_time >= attack_windup:
			_swing_hit_done = true
			_apply_strike()
		if _swing_time >= _attack_anim_length:
			_swing_time = -1.0
			_attack_cd = attack_cooldown
	else:
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_start_swing()


func _state_hurt(delta: float) -> void:
	_integrate(Vector3.ZERO, delta)
	_play_anim("Impact Absorb")
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		if player != null and not _player_dead() and _player_dist() <= chase_range:
			_enter_chase()
		else:
			_enter_idle()


func _state_dead(delta: float) -> void:
	_integrate(Vector3.ZERO, delta)
	_death_timer -= delta
	if _death_timer <= 0.0:
		queue_free()


func _chase_goal() -> Vector3:
	if player != null:
		return player.global_position
	return _noise_pos


func _detect_player() -> bool:
	if player == null or _player_dead():
		return false
	if _player_dist() > detection_range:
		return false
	return _has_line_of_sight()


func _player_dist() -> float:
	if player == null:
		return INF
	var dx := global_position.x - player.global_position.x
	var dz := global_position.z - player.global_position.z
	return sqrt(dx * dx + dz * dz)


func _player_dead() -> bool:
	if player == null:
		return false
	return player.get("is_dead") == true


func _acquire_player() -> void:
	var node := get_tree().get_first_node_in_group("player")
	if node is Node3D:
		player = node


func _player_aim_point() -> Vector3:
	if "collision_shape" in player:
		var shape = player.collision_shape
		if shape is Node3D:
			return shape.global_position
	return player.global_position + Vector3.UP * 1.2


func _has_line_of_sight() -> bool:
	if player == null:
		return false
	var space := get_world_3d().direct_space_state
	var from := _shape.global_position if _shape else global_position + Vector3.UP * 1.5
	var exclude: Array[RID] = _exclude_rids.duplicate()
	var query := PhysicsRayQueryParameters3D.create(from, _player_aim_point(), collision_mask, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	if collider == null:
		return true
	if collider == player or player.is_ancestor_of(collider) or is_ancestor_of(collider):
		return true
	return collider.is_in_group("enemies")


func _start_swing() -> void:
	_swing_time = 0.0
	_swing_hit_done = false
	var anim_name: StringName = COMBO_ANIMS[_swing_index % COMBO_ANIMS.size()]
	_swing_index += 1
	if _anim_player and _anim_player.has_animation(anim_name):
		_attack_anim_length = _anim_player.get_animation(anim_name).length
	_play_anim(anim_name, true)


func _apply_strike() -> void:
	if player == null or _player_dead():
		return
	if _player_dist() <= attack_range * 1.25 and player.has_method("take_damage"):
		player.call("take_damage", attack_damage, global_position)


func take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO) -> void:
	if state == State.DEAD:
		return
	current_health -= amount
	_flash_timer = hit_flash_time
	_set_flash(true)
	_spawn_damage_label(amount, hit_pos)
	if hit_pos != Vector3.ZERO:
		var away := global_position - hit_pos
		away.y = 0.0
		if away.length_squared() > 0.0001:
			knockback = away.normalized() * knockback_speed
	if current_health <= 0.0:
		_enter_death()
	elif state == State.HURT:
		_hurt_timer = hurt_duration
	else:
		_enter_hurt()


func on_noise(pos: Vector3) -> void:
	_noise_pos = pos
	_has_noise = true
	if state == State.IDLE:
		_enter_chase()


func _enter_idle() -> void:
	state = State.IDLE
	_swing_time = -1.0
	_play_anim("Idle")


func _enter_chase() -> void:
	state = State.CHASE
	_repath_timer = 0.0
	_play_anim("Walk")


func _enter_attack() -> void:
	state = State.ATTACK
	_attack_cd = 0.0
	_swing_time = -1.0
	_play_anim("Attack")


func _enter_hurt() -> void:
	state = State.HURT
	_hurt_timer = hurt_duration
	_swing_time = -1.0
	_play_anim("Impact Absorb", true)


func _enter_death() -> void:
	state = State.DEAD
	current_health = 0.0
	_swing_time = -1.0
	_set_flash(false)
	collision_layer = 0
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	_death_timer = _death_anim_length + death_despawn_delay
	_play_anim("Death", true)
	enemy_died.emit(self)


func _integrate(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x + knockback.x
	velocity.z = horizontal.z + knockback.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	knockback = knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _play_anim(anim_name: String, force := false) -> void:
	if _playback == null:
		return
	var target := StringName(anim_name)
	if not force and _playback.get_current_node() == target:
		return
	_playback.travel(target)


func _tick_feedback(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_flash(false)


func _set_flash(on: bool) -> void:
	for mesh in _meshes:
		mesh.material_overlay = _flash_mat if on else null


func _spawn_damage_label(amount: float, hit_pos: Vector3) -> void:
	var spawn := hit_pos
	if spawn == Vector3.ZERO:
		spawn = global_position + Vector3.UP * 2.0
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.font_size = 128
	label.pixel_size = 0.004
	label.outline_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_modulate = Color(0.1, 0.0, 0.0, 1.0)
	label.modulate = Color(1.0, 0.9, 0.2, 1.0) if current_health > 0.0 else Color(1.0, 0.25, 0.2, 1.0)
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	parent.add_child(label)
	label.global_position = spawn
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position", label.position + Vector3.UP * 1.1, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)
