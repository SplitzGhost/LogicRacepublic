extends Control
## Root controller: owns the background, the safe-area frame and the screen
## stack, and performs the cross-fades between screens.

const MainMenuScreen := preload("res://scripts/screens/main_menu.gd")
const GameScreen := preload("res://scripts/screens/game_screen.gd")
const ResultScreen := preload("res://scripts/screens/result_screen.gd")
const SettingsSheet := preload("res://scripts/screens/settings_sheet.gd")

var inset_top := 0.0
var inset_bottom := 0.0

var _frame: Control
var _current: Control
var _sheet: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(Backdrop.new())

	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_apply_insets()
	get_viewport().size_changed.connect(_apply_insets)

	go_menu(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _back() -> void:
	if _sheet != null:
		close_settings()
	elif _current is GameScreen:
		# Same two-tap arming as the on-screen back control: quitting scores the
		# round, so it must not happen on a stray system gesture.
		_current.call("_on_quit")

# ------------------------------------------------------------- safe area ---
func _apply_insets() -> void:
	var win := DisplayServer.window_get_size()
	var vp := get_viewport_rect().size
	inset_top = 0.0
	inset_bottom = 0.0
	if win.y > 0 and OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var scale := vp.y / float(win.y)
		inset_top = maxf(0.0, float(safe.position.y) * scale)
		inset_bottom = maxf(0.0, float(win.y - (safe.position.y + safe.size.y)) * scale)
	if _frame != null:
		_frame.offset_top = inset_top
		_frame.offset_bottom = -inset_bottom

# --------------------------------------------------------------- screens ---
func go_menu(animate := true) -> void:
	_swap(MainMenuScreen.new(), animate)

func go_game() -> void:
	_swap(GameScreen.new())

func go_result(summary: Dictionary) -> void:
	var screen: Control = ResultScreen.new()
	screen.set("summary", summary)
	_swap(screen)

func _swap(next: Control, animate := true) -> void:
	next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(next)
	var prev := _current
	_current = next

	if not animate or bool(SaveData.get_setting("reduce_motion", false)):
		if prev != null:
			prev.queue_free()
		return

	Sfx.play("whoosh", 1.0, 0.6)
	next.modulate.a = 0.0
	next.position.y = 30.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(next, "modulate:a", 1.0, 0.30)
	tw.parallel().tween_property(next, "position:y", 0.0, 0.38)
	if prev != null:
		prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw2.tween_property(prev, "modulate:a", 0.0, 0.20)
		tw2.parallel().tween_property(prev, "position:y", -22.0, 0.24)
		tw2.tween_callback(prev.queue_free)

# -------------------------------------------------------------- settings ---
func open_settings() -> void:
	if _sheet != null:
		return
	_sheet = SettingsSheet.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sheet)
	_sheet.connect("closed", close_settings)
	get_tree().paused = true

func close_settings() -> void:
	if _sheet == null:
		return
	var sheet := _sheet
	_sheet = null
	get_tree().paused = false
	sheet.call("dismiss")
