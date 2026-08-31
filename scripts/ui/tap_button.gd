class_name TapButton
extends Control
## Touch-first button base: a soft scale-down on press, release-outside cancels,
## and a single `pressed` signal. Everything clickable in LogicRace builds on it.

signal pressed

var press_scale := 0.955
var enabled := true:
	set(value):
		enabled = value
		modulate.a = 1.0 if value else 0.45
var sfx_name := "tap"
var haptic_ms := 8

var _down := false
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	resized.connect(_recenter)
	_recenter()


func _recenter() -> void:
	pivot_offset = size * 0.5


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			press_feedback(true)
			accept_event()
		elif _down:
			_down = false
			press_feedback(false)
			if Rect2(Vector2.ZERO, size).has_point(mb.position):
				activate()
			accept_event()
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if not Rect2(Vector2.ZERO, size).has_point(mm.position):
			_down = false
			press_feedback(false)


## What "pressed" looks like. The default is a gentle scale-down; PillButton
## overrides it to push the face down onto its own shadow plate instead.
func press_feedback(down: bool) -> void:
	_scale_to(press_scale if down else 1.0, 0.09 if down else 0.20)


func activate() -> void:
	if sfx_name != "":
		Sfx.play(sfx_name)
	if haptic_ms > 0:
		Sfx.haptic(haptic_ms)
	pressed.emit()


func _scale_to(target: float, dur: float) -> void:
	if bool(SaveData.get_setting("reduce_motion", false)):
		scale = Vector2.ONE * target
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE * target, dur)


## Small attention nudge, used when an answer is wrong.
func shake() -> void:
	if bool(SaveData.get_setting("reduce_motion", false)):
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var base := position
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_SINE)
	for offset in [14.0, -11.0, 7.0, -4.0, 0.0]:
		_tw.tween_property(self, "position", base + Vector2(float(offset), 0.0), 0.055)
