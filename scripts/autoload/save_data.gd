extends Node
## Account-free local persistence.
##
## Everything the player owns lives in a single JSON file inside `user://`
## (Android: app-private storage, iOS: the app sandbox), so progress survives a
## restart on the same device without any login. No cross-device sync by design.

const SAVE_PATH := "user://logicrace.save"
## How many puzzle fingerprints we remember per pool. Once the cap is hit the
## oldest entries are dropped first (a player who burns through 8000 puzzles of
## one pool is far past the point where a repeat is noticeable).
const HISTORY_CAP := 8000

signal settings_changed(key: String)
signal progress_changed

var iq: int = 0
var best_level: int = 1
var rounds_played: int = 0
var puzzles_solved: int = 0

var settings := {
	"dark": false,
	"sfx": true,
	"volume": 0.85,
	"haptics": true,
	"reduce_motion": false,
	"timer_bar": true,
}

## Developer switches. These never touch the player's real progress: turning dev
## mode on takes a snapshot, turning it off puts the snapshot back.
var dev := {
	"enabled": false,
	"start_level": 1,
	"infinite_lives": false,
	"freeze_timer": false,
	"pool": "",
}

var _hist: Dictionary = {}      # pool -> Array[int], insertion ordered (FIFO)
var _hist_set: Dictionary = {}  # pool -> Dictionary[int, bool] for O(1) lookup
var _dev_backup: Dictionary = {}
var _autosave_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_PREDELETE:
			if _autosave_pending:
				save_game()


# ---------------------------------------------------------------- settings ---
func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	_autosave_pending = true
	settings_changed.emit(key)
	save_game()


# ---------------------------------------------------------------- progress ---
func apply_round(new_iq: int, level_reached: int, solved: int) -> void:
	iq = maxi(0, new_iq)
	best_level = maxi(best_level, level_reached)
	rounds_played += 1
	puzzles_solved += solved
	_autosave_pending = true
	progress_changed.emit()
	save_game()


func reset_progress() -> void:
	iq = 0
	best_level = 1
	rounds_played = 0
	puzzles_solved = 0
	_hist.clear()
	_hist_set.clear()
	_dev_backup = {}
	_autosave_pending = true
	progress_changed.emit()
	save_game()


# --------------------------------------------------------------- dev mode ---
func dev_enabled() -> bool:
	return bool(dev.get("enabled", false))


func dev_get(key: String, fallback: Variant = null) -> Variant:
	return dev.get(key, fallback)


func dev_set(key: String, value: Variant) -> void:
	if dev.get(key) == value:
		return
	dev[key] = value
	_autosave_pending = true
	settings_changed.emit("dev/" + key)
	save_game()


## Turning developer mode on parks the real progress; turning it off restores it,
## so nothing done while testing can leak into the player's record.
func set_dev_mode(on: bool) -> void:
	if bool(dev["enabled"]) == on:
		return
	if on:
		_dev_backup = _snapshot()
	elif not _dev_backup.is_empty():
		_restore(_dev_backup)
		_dev_backup = {}
	dev["enabled"] = on
	_autosave_pending = true
	settings_changed.emit("dev/enabled")
	progress_changed.emit()
	save_game()


func _snapshot() -> Dictionary:
	var hist_copy := {}
	for pool: String in _hist:
		hist_copy[pool] = (_hist[pool] as Array).duplicate()
	return {
		"iq": iq,
		"best_level": best_level,
		"rounds_played": rounds_played,
		"puzzles_solved": puzzles_solved,
		"history": hist_copy,
	}


func _restore(snap: Dictionary) -> void:
	iq = int(snap.get("iq", 0))
	best_level = int(snap.get("best_level", 1))
	rounds_played = int(snap.get("rounds_played", 0))
	puzzles_solved = int(snap.get("puzzles_solved", 0))
	_hist.clear()
	_hist_set.clear()
	var hist: Dictionary = snap.get("history", {})
	for pool: String in hist:
		var arr: Array = (hist[pool] as Array).duplicate()
		var set_d := {}
		for v in arr:
			set_d[int(v)] = true
		_hist[pool] = arr
		_hist_set[pool] = set_d


# ----------------------------------------------------------------- history ---
func seen(pool: String, fingerprint: int) -> bool:
	var s: Dictionary = _hist_set.get(pool, {})
	return s.has(fingerprint)


func remember(pool: String, fingerprint: int) -> void:
	var arr: Array = _hist.get(pool, [])
	var s: Dictionary = _hist_set.get(pool, {})
	if s.has(fingerprint):
		return
	arr.append(fingerprint)
	s[fingerprint] = true
	while arr.size() > HISTORY_CAP:
		s.erase(arr.pop_front())
	_hist[pool] = arr
	_hist_set[pool] = s
	_autosave_pending = true


func history_size() -> int:
	var n := 0
	for pool: String in _hist:
		n += (_hist[pool] as Array).size()
	return n


# -------------------------------------------------------------------- i/o ---
func save_game() -> void:
	var hist_out := {}
	for pool: String in _hist:
		hist_out[pool] = _hist[pool]
	var payload := {
		"version": 1,
		"iq": iq,
		"best_level": best_level,
		"rounds_played": rounds_played,
		"puzzles_solved": puzzles_solved,
		"settings": settings,
		"history": hist_out,
		"dev": dev,
		"dev_backup": _dev_backup,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("LogicRace: could not write save file (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(payload))
	f.close()
	_autosave_pending = false


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LogicRace: save file unreadable, starting fresh.")
		return
	var d: Dictionary = parsed
	# "mmr" is the pre-1.1 key for the same value.
	iq = int(d.get("iq", d.get("mmr", 0)))
	best_level = maxi(1, int(d.get("best_level", 1)))
	rounds_played = int(d.get("rounds_played", 0))
	puzzles_solved = int(d.get("puzzles_solved", 0))

	var s: Dictionary = d.get("settings", {})
	for key: String in settings.keys():
		if s.has(key):
			var v: Variant = s[key]
			if typeof(settings[key]) == TYPE_BOOL:
				settings[key] = bool(v)
			elif typeof(settings[key]) == TYPE_FLOAT:
				settings[key] = float(v)
			else:
				settings[key] = v

	var dv: Dictionary = d.get("dev", {})
	for key: String in dev.keys():
		if dv.has(key):
			dev[key] = dv[key]
	_dev_backup = d.get("dev_backup", {})

	_hist.clear()
	_hist_set.clear()
	var h: Dictionary = d.get("history", {})
	for pool: String in h.keys():
		var arr: Array = []
		var set_d := {}
		for v: Variant in (h[pool] as Array):
			var iv := int(v)
			if not set_d.has(iv):
				arr.append(iv)
				set_d[iv] = true
		_hist[pool] = arr
		_hist_set[pool] = set_d
