class_name IntroManager extends Node

@export var cameraParent : Node3D
@export var intbranch_bathroomdoor : InteractionBranch
@export var intbranch_backroomdoor: InteractionBranch
@export var intbranch_pillbottle : InteractionBranch
@export var parent_pills : Node3D
@export var cursor : CursorManager
@export var roundManager : RoundManager
@export var speaker_amb_restroom : AudioStreamPlayer2D
@export var viewblocker : Control
@export var animator_camera : AnimationPlayer
@export var animator_smokerdude : AnimationPlayer
@export var animator_darkguy : AnimationPlayer
@export var musicmanager : MusicManager
@export var filter : FilterController
@export var bpmlight : BpmLight
@export var smokerdude_revival : Node3D
@export var speaker_defib : AudioStreamPlayer2D
@export var animator_pp : AnimationPlayer
@export var cameraShaker : camerashaker
@export var dia : Dialogue
@export var blockout : Blockout
@export var animator_hint : AnimationPlayer
@export var animator_pillchoice : AnimationPlayer
@export var speaker_pillchoice : AudioStreamPlayer2D
@export var intbranch_pillyes : InteractionBranch
@export var intbranch_pillno : InteractionBranch
@export var intbranch_crt : InteractionBranch
@export var speaker_pillselect : AudioStreamPlayer2D
@export var anim_revert : AnimationPlayer
@export var endlessmode : Endless
@export var btn_bathroomdoor : Control
@export var btn_pills : Control
@export var btn_pillsYes : Control
@export var btn_pillsNo : Control
@export var btn_backroom : Control
@export var btn_screen : Control #append this with controller UI element
@export var controller : ControllerManager
@export var unlocker : Unlocker
@export var crtManager : CRT
@export var crtMonitor : Node3D
@export var col_pillchoice : Array[CollisionShape3D]
@export var anim_pillflicker : AnimationPlayer
@export var animator_intro : AnimationPlayer
@export var btn_undo : Control
@export var freeWillManager : FreeWillManager
@export var btn_skip_intro : Control
@export var player_ref : CharacterBody3D
@export var camera_manager : CameraManager
@export var root_canvas_layer : CanvasLayer   # (Optional) The main UI CanvasLayer. We no longer hide it for Free Will — we only hide the two specific buttons (btn_freewill / btn_escape) so other prompts stay usable.
@export var mouseRaycast : MouseRaycast


const BEGINNING_INTRO_FADE_DURATION: float = 2.1

var isFreeMode : bool = false
var mainGameStarted : bool = false
var _camera_mode : String = "normal"
var saved_camera_anim_position: float = 0.0
var saved_interaction_allowed = {}
var isCrtActive : bool = false
func IsCrtNotActive() -> bool:
	return !isCrtActive

@export var crt_screen_collision : CollisionShape3D
@export var crt_button_collisions : Array[CollisionShape3D] = []

var allowingPills = false
var root_ui_blocked : bool = false
var beginning_intro_active : bool = false
var beginning_intro_skipped : bool = false
var beginning_intro_fade_started : bool = false
var _interaction_unlocked : bool = false
var intro_skip_button_visible : bool = false
func _set_darkguy_text():
	var base_path = "../../Camera/dialogue UI/darkguy-dialogue/dialogue text"
	for i in range(5):
		var node_path = base_path if i == 0 else base_path + str(i + 1)
		var label = get_node(node_path) if has_node(node_path) else null
		if label and label is RichTextLabel:
			var key = ["DARKGUY_LAST_GUY", "DARKGUY_DONT_DIE", "DARKGUY_DIDNT_PAST_SECOND", "DARKGUY_PROBABLY_DIFFERENT", "DARKGUY_TRY_LONGER"][i]
			label.text = tr(key)

func _ready():
	get_window().title = "Deadshot Roulette"
	print("[INTRO] MANAGER ALIVE")
	_set_darkguy_text()
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = false

	if freeWillManager:
		freeWillManager.animator_camera = animator_camera
		freeWillManager.hide_all()
	_inject_call_method_track()
	if btn_skip_intro:
		btn_skip_intro.visible = false
		if not btn_skip_intro.pressed.is_connected(_on_skip_intro_pressed):
			btn_skip_intro.pressed.connect(_on_skip_intro_pressed)

		
	parent_pills.visible = false
	allowingPills = false
	SetControllerState()
	await get_tree().create_timer(.5, false).timeout
	if GlobalVariables.tempDeathCount == 0:
		_camera_mode = "first_time"
		MainBathroomStart()
	elif roundManager.playerData.enteringFromTrueDeath:
		_camera_mode = "after_heaven"
		RevivalBathroomStart()
	elif roundManager.playerData.playerEnteringFromDeath:
		_camera_mode = "normal"
		RevivalBathroomStart()
	else:
		_camera_mode = "normal"
		MainBathroomStart()
	if (roundManager.playerData.playerEnteringFromDeath or roundManager.playerData.enteringFromTrueDeath): 
		parent_pills.visible = false
		if crtMonitor: crtMonitor.visible = false
		allowingPills = false
	if (!roundManager.playerData.playerEnteringFromDeath && !roundManager.playerData.enteringFromTrueDeath):
		if (FileAccess.file_exists(unlocker.savepath)):
			parent_pills.visible = true
			if crtMonitor: crtMonitor.visible = true
			crtManager.SetCRT(true)
			allowingPills = true

	# RESTORE ENDLESS MODE AFTER DEATH RELOAD: re-apply all endless setup so the
	# run continues as "double or nothing" (endless=true, smokerdude hidden, amounts).
	if (GlobalVariables.endlessModeActive && endlessmode):
		endlessmode.SetupEndless()

	await get_tree().create_timer(3, false).timeout
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = true

var counting = false
var count_current = 0
var count_max = 60
var fs1 = false
func _process(_delta):
	if counting: 
		CountTimer()

	# Nuclear guard: keep mouse captured + cursor hidden while in free will
	# (but respect player's explicit unlock via Ctrl+Escape)
	if isFreeMode:
		if player_ref and player_ref.mouse_captured and GlobalVariables.window_focused:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Input.set_custom_mouse_cursor(null)

func _input(event: InputEvent):
	if _handle_intro_skip_input(event):
		return

	# Block FREE WILL / Escape keys when leaving bathroom OR during active rounds
	if root_ui_blocked or mainGameStarted:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("explore"):
			get_viewport().set_input_as_handled()
			return

	# Block all mouse clicks / touches while in free will (prevents accidental UI triggers)
	if isFreeMode:
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("explore"):
		if !isFreeMode && IsCrtNotActive():
			EnableFreeWill()

	# Escape key exits free mode
	if event.is_action_pressed("ui_cancel"):
		if isFreeMode:
			DisableFreeWill()

func _handle_intro_skip_input(event: InputEvent) -> bool:
	if not beginning_intro_active or beginning_intro_skipped or beginning_intro_fade_started or root_ui_blocked or isFreeMode or isCrtActive:
		return false

	if event is InputEventMouseButton and event.pressed:
		if _is_mouse_event_inside_skip_button(event):
			return false
		_show_intro_skip_button()
		get_viewport().set_input_as_handled()
		return true

	if event is InputEventKey and event.pressed and event.physical_keycode != 0:
		if intro_skip_button_visible:
			_on_skip_intro_pressed()
		else:
			_show_intro_skip_button()
		get_viewport().set_input_as_handled()
		return true

	return false

func _show_intro_skip_button():
	if btn_skip_intro:
		btn_skip_intro.visible = true
		intro_skip_button_visible = true

func _hide_intro_skip_button():
	if btn_skip_intro:
		btn_skip_intro.visible = false
	intro_skip_button_visible = false

func _is_mouse_event_inside_skip_button(event: InputEventMouseButton) -> bool:
	if not btn_skip_intro or not btn_skip_intro.visible:
		return false
	return btn_skip_intro.get_global_rect().has_point(event.position)

func EnableFreeWill():
	if not IsCrtNotActive():
		return
	isFreeMode = true

	if mouseRaycast and mouseRaycast.has_method("StopRaycastOverride"):
		mouseRaycast.StopRaycastOverride()

	# Direct capture (bypass any player_ref null issues)
	if GlobalVariables.window_focused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Input.set_custom_mouse_cursor(null)

	if cursor:
		cursor.locked = true

	if camera_manager:
		camera_manager.paused = true

	if player_ref != null:
		player_ref.moveAllowed = true
		player_ref.lookAllowed = true
		player_ref.mouse_captured = true

		# Activate player's gimbal camera for free look
		var gimbal_cam = player_ref.get_node_or_null("CameraGimbal/InnerGimbal/Camera3D")
		if gimbal_cam and gimbal_cam is Camera3D:
			gimbal_cam.current = true

	# Completely disable the intro/root camera so it cannot fight or render
	if cameraParent:
		if cameraParent is Camera3D:
			cameraParent.current = false
			cameraParent.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			for child in cameraParent.get_children():
				if child is Camera3D:
					child.current = false
					child.process_mode = Node.PROCESS_MODE_DISABLED
					break

	if animator_camera:
		saved_camera_anim_position = animator_camera.current_animation_position
		animator_camera.pause()

	if viewblocker:
		viewblocker.visible = false
		viewblocker.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Save current root camera interaction states before hiding buttons
	saved_interaction_allowed = {
		"bathroomdoor": intbranch_bathroomdoor.interactionAllowed if intbranch_bathroomdoor else false,
		"pillbottle": intbranch_pillbottle.interactionAllowed if intbranch_pillbottle else false,
		"crt": intbranch_crt.interactionAllowed if intbranch_crt else false,
		"backroomdoor": intbranch_backroomdoor.interactionAllowed if intbranch_backroomdoor else false,
		"pillyes": intbranch_pillyes.interactionAllowed if intbranch_pillyes else false,
		"pillno": intbranch_pillno.interactionAllowed if intbranch_pillno else false,
	}

	# Save CRT buttons array if present
	if "intbs_crtbuttons" in self and intbs_crtbuttons:
		saved_interaction_allowed["crtbuttons"] = []
		for b in intbs_crtbuttons:
			saved_interaction_allowed["crtbuttons"].append(b.interactionAllowed if b else false)

	# UI cleanup for free will (still hide restroom buttons)
	if btn_bathroomdoor: btn_bathroomdoor.visible = false
	if btn_pills: btn_pills.visible = false
	if btn_screen: btn_screen.visible = false
	if freeWillManager: freeWillManager.show_escape_button()

func DisableFreeWill():
	isFreeMode = false
	isCrtActive = false

	# Restore cursor and CameraManager
	if cursor:
		cursor.locked = false
		cursor.SetCursor(true, true)

	if camera_manager:
		camera_manager.paused = false

	# Deactivate player gimbal camera
	if player_ref != null:
		player_ref.moveAllowed = false
		player_ref.lookAllowed = false
		player_ref.release_mouse()

		# Clean sprint state so shift doesn't leak / break clicks after returning to root camera
		player_ref.speed_modifier = 1
		player_ref.sprint_on_cooldown = false
		if player_ref.sprint_timer and not player_ref.sprint_timer.is_stopped():
			player_ref.sprint_timer.stop()
		player_ref.sprint_time_remaining = player_ref.sprint_time

		var gimbal_cam = player_ref.get_node_or_null("CameraGimbal/InnerGimbal/Camera3D")
		if gimbal_cam and gimbal_cam is Camera3D:
			gimbal_cam.current = false

	# Only restore the cinematic restroom camera if the main game hasn't started yet
	if not mainGameStarted:
		# Re-enable intro camera
		if cameraParent:
			if cameraParent is Camera3D:
				cameraParent.process_mode = Node.PROCESS_MODE_INHERIT
				cameraParent.current = true
			else:
				for child in cameraParent.get_children():
					if child is Camera3D:
						child.process_mode = Node.PROCESS_MODE_INHERIT
						child.current = true
						break

		# Resume bathroom idle camera animation
		if animator_camera and animator_camera.has_animation("camera idle bathroom"):
			animator_camera.play("camera idle bathroom")
			animator_camera.seek(saved_camera_anim_position, true)

	if freeWillManager: freeWillManager.show_free_will_button()

	# Restore interactive buttons
	if btn_bathroomdoor: btn_bathroomdoor.visible = true

	if allowingPills:
		if btn_pills: btn_pills.visible = true
		if btn_screen: btn_screen.visible = true

	# Restore full interaction states for root camera interactables
	if intbranch_bathroomdoor:
		intbranch_bathroomdoor.interactionAllowed = saved_interaction_allowed.get("bathroomdoor", false)
	if intbranch_pillbottle:
		intbranch_pillbottle.interactionAllowed = saved_interaction_allowed.get("pillbottle", false)
	if intbranch_crt:
		intbranch_crt.interactionAllowed = saved_interaction_allowed.get("crt", false)
	if intbranch_backroomdoor:
		intbranch_backroomdoor.interactionAllowed = saved_interaction_allowed.get("backroomdoor", false)
	if intbranch_pillyes:
		intbranch_pillyes.interactionAllowed = saved_interaction_allowed.get("pillyes", false)
	if intbranch_pillno:
		intbranch_pillno.interactionAllowed = saved_interaction_allowed.get("pillno", false)

	# Restore CRT buttons array
	if "intbs_crtbuttons" in self and intbs_crtbuttons and "crtbuttons" in saved_interaction_allowed:
		for i in range(intbs_crtbuttons.size()):
			if i < saved_interaction_allowed["crtbuttons"].size():
				intbs_crtbuttons[i].interactionAllowed = saved_interaction_allowed["crtbuttons"][i]

	# Clear saved state
	saved_interaction_allowed.clear()


func CountTimer():
	if (counting): count_current += get_process_delta_time()
	if (count_current > count_max && !fs1):
		ach.UnlockAchievement("ach14")
		fs1 = true


func SetControllerState():
	if (GlobalVariables.controllerEnabled):
		controller.SetMainControllerState(true)

func MainBathroomStart():
	viewblocker.visible = false
	_interaction_unlocked = false
	MainTrackLoad()
	await PlayBeginningIntroThenIdle()

func PlayBeginningIntroThenIdle():
	beginning_intro_active = true
	beginning_intro_skipped = false
	beginning_intro_fade_started = false
	_hide_intro_skip_button()
	if animator_intro and animator_intro.has_animation("BEGINNING-INTRO"):
		animator_intro.play("BEGINNING-INTRO")
		var intro_duration := animator_intro.get_animation("BEGINNING-INTRO").length
		var fade_duration := minf(BEGINNING_INTRO_FADE_DURATION, intro_duration)
		await get_tree().create_timer(maxf(intro_duration - fade_duration, 0.0), false).timeout
		if beginning_intro_skipped and not beginning_intro_fade_started:
			return
		beginning_intro_fade_started = true
		_hide_intro_skip_button()
		animator_pp.play("brightness fade out")
		await get_tree().create_timer(fade_duration, false).timeout

	RestRoomIdle()
	animator_pp.play("brightness fade in")
	await get_tree().create_timer(BEGINNING_INTRO_FADE_DURATION, false).timeout
	beginning_intro_active = false
	beginning_intro_fade_started = false
	_hide_intro_skip_button()

func FinishBeginningIntro():
	_hide_intro_skip_button()
	Hint()
	cursor.SetCursor(true, true)
	intbranch_bathroomdoor.interactionAllowed = true
	if (allowingPills): 
		intbranch_pillbottle.interactionAllowed = true
		intbranch_crt.interactionAllowed = true
	if (cursor.controller_active): btn_bathroomdoor.grab_focus()
	controller.previousFocus = btn_bathroomdoor
	if (allowingPills): btn_pills.visible = true; btn_screen.visible = true
	btn_bathroomdoor.visible = true
	anim_pillflicker.play("flicker pill")

	# Re-enable F/ESC keys
	root_ui_blocked = false
	if freeWillManager: freeWillManager.show_free_will_button()

func UnlockBathroomInteraction() -> void:
	if _interaction_unlocked:
		return
	_interaction_unlocked = true
	FinishBeginningIntro()

func _inject_call_method_track() -> void:
	if not animator_camera:
		return
	var anim_name := &"camera idle bathroom"
	if not animator_camera.has_animation(anim_name):
		return
	var anim := animator_camera.get_animation(anim_name)
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_METHOD and anim.track_get_path(i) == NodePath("../intro manager"):
			anim.remove_track(i)
			break
	var idx := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(idx, NodePath("../intro manager"))
	anim.track_insert_key(idx, 0.0, "UnlockBathroomInteraction")

func Hint():
	await get_tree().create_timer(1, false).timeout
	if (!roundManager.playerData.seenHint):
		animator_hint.play("show")
		roundManager.playerData.seenHint = true

func RevivalBathroomStart():
	mainGameStarted = false
	root_ui_blocked = true
	if freeWillManager: freeWillManager.hide_all()
	if animator_camera:
		animator_camera.play("camera player revival")
	#animator_smokerdude.stop(true)
	smokerdude_revival.visible = true
	await get_tree().create_timer(1, false).timeout
	speaker_defib.play()
	await get_tree().create_timer(.85, false).timeout
	dia.speaker_click.stream = dia.soundArray_clicks[0]
	animator_smokerdude.play("revive player")
	cameraShaker.Shake()
	animator_pp.play("revival brightness")
	viewblocker.visible = false
	MainTrackLoad()
	await get_tree().create_timer(.5, false).timeout
	animator_smokerdude.play("revive player")
	dia.ShowText_Forever(tr("YOURE LUCKY"))
	var n = roundManager.playerData.playername
	var full = tr("GET UP") % [n]
	await get_tree().create_timer(4, false).timeout
	dia.ShowText_Forever(full)
	await get_tree().create_timer(4, false).timeout
	dia.HideText()
	animator_pp.play("brightness fade out")
	await get_tree().create_timer(2.05, false).timeout
	smokerdude_revival.visible = false
	RestRoomIdle()
	animator_pp.play("brightness fade in")
	dia.speaker_click.stream = dia.soundArray_clicks[3]
	await get_tree().create_timer(3, false).timeout
	cursor.SetCursor(true, true)
	if (allowingPills): 
		intbranch_pillbottle.interactionAllowed = true
		intbranch_crt.interactionAllowed = true
		btn_pills.visible = true
		btn_screen.visible = true
		anim_pillflicker.play("flicker pill")
	if (cursor.controller_active): btn_bathroomdoor.grab_focus()
	controller.previousFocus = btn_bathroomdoor
	btn_bathroomdoor.visible = true
	intbranch_bathroomdoor.interactionAllowed = true

	# Restore FREE WILL setup + re-enable F/ESC keys when player returns to the restroom after death
	root_ui_blocked = false
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = true
	if freeWillManager: freeWillManager.show_free_will_button()
	pass

func MainTrackLoad():
	var increment = musicmanager.trackArray[roundManager.playerData.currentBatchIndex].bpmIncrement
	bpmlight.delay = increment
	musicmanager.LoadTrack()
	bpmlight.BeginMainLoop()
	speaker_amb_restroom.play()

func Interaction_PillBottle():
	anim_pillflicker.play("RESET")
	cursor.SetCursor(false, false)
	intbranch_bathroomdoor.interactionAllowed = false
	intbranch_pillbottle.interactionAllowed = false
	intbranch_crt.interactionAllowed = false
	btn_pills.visible = false
	btn_screen.visible = false
	btn_bathroomdoor.visible = false
	animator_camera.play("camera check pills")
	await get_tree().create_timer(.6, false).timeout
	speaker_pillchoice.play()
	await get_tree().create_timer(.3, false).timeout
	animator_pillchoice.play("show")
	await get_tree().create_timer(.7, false).timeout
	cursor.SetCursor(true, true)
	
	if (cursor.controller_active): btn_pillsNo.grab_focus()
	controller.previousFocus = btn_pillsNo
	for c in col_pillchoice: c.disabled = false
	btn_pillsNo.visible = true
	btn_pillsYes.visible = true
	intbranch_pillyes.interactionAllowed = true
	intbranch_pillno.interactionAllowed = true

@export var intbs_crtbuttons : Array[InteractionBranch]
func Interaction_CRT():
	if isCrtActive:
		return
	if isFreeMode:
		DisableFreeWill()
	await get_tree().process_frame
	isCrtActive = true
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = false
	StartSound()
	anim_pillflicker.play("RESET")
	cursor.SetCursor(false, false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	intbranch_bathroomdoor.interactionAllowed = false
	intbranch_pillbottle.interactionAllowed = false
	intbranch_crt.interactionAllowed = false
	btn_pills.visible = false
	btn_bathroomdoor.visible = false
	btn_screen.visible = false
	animator_camera.play("camera check crt")
	await get_tree().create_timer(2.6, false).timeout
	crtManager.Bootup()
	await get_tree().create_timer(0.54, false).timeout

func StartSound():
	crtManager.speaker_playerwalk.play()
	await get_tree().create_timer(2.04, false).timeout
	crtManager.speaker_bootuploop.play()

func EnabledInteractionCRT():
	isCrtActive = true
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = false
	cursor.SetCursor(true, true)
	if crt_screen_collision:
		crt_screen_collision.disabled = true
	for collision in crt_button_collisions:
		collision.disabled = false
	for b in intbs_crtbuttons: b.interactionAllowed = true
	if animator_intro.has_animation("CRT-IDLE"):
		if animator_intro.current_animation != "CRT-IDLE" or not animator_intro.is_playing():
			animator_intro.play("CRT-IDLE")

func DisableInteractionCrt():
	isCrtActive = false
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = true
	cursor.SetCursor(false, false)
	for b in intbs_crtbuttons: b.interactionAllowed = false

@export var ach : Achievement
@export var pill_unlock : Unlocker
func SelectedPill(selected : bool):
	if (selected): 
		pill_unlock.IncrementAmount()
		anim_pillflicker.play("RESET")
	cursor.SetCursor(false, false)
	for c in col_pillchoice: c.disabled = true
	animator_pp.play("brightness fade out")
	anim_revert.play("revert")
	animator_pillchoice.play("hide")
	speaker_pillchoice.stop()
	speaker_pillselect.play()
	btn_pillsYes.visible = false
	btn_pillsNo.visible = false
	intbranch_pillyes.interactionAllowed = false
	intbranch_pillno.interactionAllowed = false
	await get_tree().create_timer(2.05, false).timeout
	if(selected): 
		parent_pills.visible = false
		endlessmode.SetupEndless()
	RestRoomIdle()
	if selected: crtManager.SetCRT(false)
	animator_pp.play("brightness fade in")
	await get_tree().create_timer(.6, false).timeout
	cursor.SetCursor(true, true)
	if (selected): ach.UnlockAchievement("ach3")
	intbranch_bathroomdoor.interactionAllowed = true
	btn_bathroomdoor.visible = true
	if(!selected): 
		intbranch_pillbottle.interactionAllowed = true
		intbranch_crt.interactionAllowed = true
		btn_pills.visible = true
		btn_screen.visible = true
		anim_pillflicker.play("flicker pill")
	if (cursor.controller_active): btn_bathroomdoor.grab_focus()
	controller.previousFocus = btn_bathroomdoor

	# Re-enable F/ESC keys after pill choice
	root_ui_blocked = false
	if freeWillManager: freeWillManager.show_free_will_button()
	pass

func RevertCRT():
	animator_pp.play("brightness fade out")
	#anim_revert.play("revert")
	btn_pillsYes.visible = false
	btn_pillsNo.visible = false
	intbranch_pillyes.interactionAllowed = false
	intbranch_pillno.interactionAllowed = false
	await get_tree().create_timer(2.05, false).timeout
	RestRoomIdle()
	animator_pp.play("brightness fade in")
	anim_pillflicker.play("flicker pill")
	await get_tree().create_timer(.6, false).timeout
	cursor.SetCursor(true, true)
	intbranch_bathroomdoor.interactionAllowed = true
	btn_bathroomdoor.visible = true
	intbranch_pillbottle.interactionAllowed = true
	intbranch_crt.interactionAllowed = true
	btn_pills.visible = true
	btn_screen.visible = true
	if (cursor.controller_active): btn_bathroomdoor.grab_focus()
	controller.previousFocus = btn_bathroomdoor

	# Re-enable F/ESC keys after CRT revert flow
	root_ui_blocked = false
	if freeWillManager: freeWillManager.show_free_will_button()

func Interaction_BackroomDoor():
	roundManager.playerData.stat_doorsKicked += 1
	match _camera_mode:
		"first_time":
			animator_camera.play("camera enter backroom first-time")
		"after_heaven":
			animator_camera.play("camera enter backroom after-heaven")
		_:
			animator_camera.play("camera enter backroom")
	intbranch_backroomdoor.interactionAllowed = false
	btn_backroom.visible = false
	cursor.SetCursor(false, false)
	counting = false

func Interaction_BathroomDoor():
	# CRITICAL FIX: Force exit free mode to stop player camera control
	if isFreeMode:
		DisableFreeWill()

	# Temporarily disable the Free Will / Escape buttons and block their keyboard keys (F + ESC).
	root_ui_blocked = true
	if freeWillManager: freeWillManager.hide_all()

	if btn_undo: btn_undo.visible = false
	if root_canvas_layer and is_instance_valid(root_canvas_layer):
		root_canvas_layer.visible = false

	intbranch_bathroomdoor.interactionAllowed = false
	cursor.SetCursor(false, false)
	btn_pills.visible = false
	btn_screen.visible = false
	btn_bathroomdoor.visible = false
	
	match _camera_mode:
		"first_time":
			animator_camera.play("camera exit bathroom first-time")
		"after_heaven":
			animator_camera.play("camera exit bathroom after-heaven")
		_:
			animator_camera.play("camera exit bathroom")
	
	await get_tree().create_timer(5, false).timeout

	cursor.SetCursor(true, true)
	if (cursor.controller_active): btn_backroom.grab_focus()
	controller.previousFocus = btn_backroom
	btn_backroom.visible = true
	
	if btn_undo: btn_undo.visible = false
	
	intbranch_backroomdoor.interactionAllowed = true
	intbranch_pillbottle.interactionAllowed = false
	intbranch_crt.interactionAllowed = false
	counting = true
	pass

func BeginGame():
	blockout.HideClub()
	roundManager.BeginMainGame()
	mainGameStarted = true
	if freeWillManager: freeWillManager.hide_all()
	if btn_undo: btn_undo.visible = false

func PanFilter():
	filter.BeginPan(filter.lowPassMaxValue, filter.lowPassDefaultValue)
	pass

func KickDoorBackroom():
	pass

func KickDoorLobby():
	roundManager.playerData.stat_doorsKicked += 1
	await get_tree().create_timer(.25, false).timeout
	filter.BeginPan(filter.lowPassDefaultValue, filter.lowPassMaxValue)
	speaker_amb_restroom.stop()

func RestRoomIdle():
	if cursor: cursor.SetCursor(true, false)
	if crt_screen_collision:
		crt_screen_collision.disabled = false
	for collision in crt_button_collisions:
		collision.disabled = true
	if intbranch_bathroomdoor: intbranch_bathroomdoor.interactionAllowed = true
	if allowingPills:
		if intbranch_pillbottle: intbranch_pillbottle.interactionAllowed = true
		if intbranch_crt: intbranch_crt.interactionAllowed = true
	animator_camera.play("camera idle bathroom")
	pass

func _on_skip_intro_pressed() -> void:
	await SkipBeginningIntro()

func SkipBeginningIntro():
	if not beginning_intro_active or beginning_intro_skipped or beginning_intro_fade_started:
		return

	beginning_intro_skipped = true
	_hide_intro_skip_button()

	if animator_intro and animator_intro.current_animation == "BEGINNING-INTRO":
		animator_intro.seek(animator_intro.current_animation_length, true)
		animator_intro.stop(true)

	RestRoomIdle()

	if animator_pp and animator_pp.has_animation("brightness fade out"):
		animator_pp.play("brightness fade out")
		await get_tree().create_timer(BEGINNING_INTRO_FADE_DURATION, false).timeout

	if animator_pp and animator_pp.has_animation("brightness fade in"):
		animator_pp.play("brightness fade in")
		await get_tree().create_timer(BEGINNING_INTRO_FADE_DURATION, false).timeout

	beginning_intro_active = false
	beginning_intro_fade_started = false
	_hide_intro_skip_button()

func _on_m_button_free_will_pressed() -> void:
	pass # Replace with function body.
