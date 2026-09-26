class_name Achievement extends Node
signal achievement_unlocked(apiname: String)
const SAVE_PATH := "user://buckshotroulette_achievements.dat"
const ALL_ACHIEVEMENTS: Array[String] = [
	"ach1", "ach2", "ach3", "ach4", "ach5", "ach6", "ach7", "ach8",
	"ach9", "ach10", "ach11", "ach12", "ach13", "ach14", "ach15", "ach16"
]
var _local: Dictionary = {}
var _steam_was_running := false
var _check_timer: Timer

func _ready():
	_load_local()
	_steam_was_running = Steam.isSteamRunning()
	# Defer sync_achievements() — the 16+ Steam FFI calls block the
	# main thread and are not needed until gameplay.  A 3-second
	# delay pushes them well past the boot/splash sequence.
	var deferred_timer := Timer.new()
	deferred_timer.wait_time = 3.0
	deferred_timer.one_shot = true
	deferred_timer.timeout.connect(func():
		sync_achievements()
		deferred_timer.queue_free()
	)
	add_child(deferred_timer)
	deferred_timer.start()

	# Was polling Steam.isSteamRunning() (FFI call) every _process frame.
	# Steam running-state doesn't need frame-rate polling — check every 5s.
	_check_timer = Timer.new()
	_check_timer.wait_time = 5.0
	_check_timer.autostart = true
	_check_timer.timeout.connect(_on_check_timer)
	add_child(_check_timer)

func _on_check_timer():
	var steam_running = Steam.isSteamRunning()
	if steam_running and not _steam_was_running:
		sync_achievements()
	_steam_was_running = steam_running

func sync_achievements():
	if not Steam.isSteamRunning():
		return
	_pull_from_steam()
	_push_pending_to_steam()
	_save_local()

func _pull_from_steam():
	for apiname in ALL_ACHIEVEMENTS:
		if _local.get(apiname, false):
			continue
		var result = Steam.getAchievement(apiname)
		if result.get("ret", false):
			_local[apiname] = result.get("achieved", false)

func _push_pending_to_steam():
	for apiname in ALL_ACHIEVEMENTS:
		if not _local.get(apiname, false):
			continue
		var result = Steam.getAchievement(apiname)
		if result.get("ret", false) and result.get("achieved", false):
			continue
		Steam.setAchievement(apiname)
	Steam.storeStats()

func UnlockAchievement(apiname: String):
	if is_unlocked(apiname):
		return
	_local[apiname] = true
	_save_local()
	_push_to_steam(apiname)
	achievement_unlocked.emit(apiname)

func ClearAchievement(apiname: String):
	_local[apiname] = false
	_save_local()
	if Steam.isSteamRunning():
		Steam.clearAchievement(apiname)
		Steam.storeStats()

func _push_to_steam(apiname: String):
	if not Steam.isSteamRunning():
		return
	Steam.setAchievement(apiname)
	Steam.storeStats()

func is_unlocked(apiname: String) -> bool:
	return _local.get(apiname, false)

func _save_local():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(_local)
		file.close()

func _load_local():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				_local = data
			else:
				_local = {}
	else:
		_local = {}
