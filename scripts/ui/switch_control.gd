class_name SwitchControl
extends TapButton
## iOS-style toggle: a track that fills with the accent colour while the knob
## slides across.

signal toggled(on: bool)

var on := false:
	set(value):
		if on == value:
			return
		on = value
		_animate()

var _t := 0.0
var _tw2: Tween


func _init() -> void:
	super()
	custom_minimum_size = Vector2(104, 60)
	press_scale = 0.94
	sfx_name = "toggle"


func _ready() -> void:
	super()
	_t = 1.0 if on else 0.0
	Palette.changed.connect(queue_redraw)


## Sets the state without animating.
func set_on_silent(value: bool) -> void:
	on = value
	if _tw2 != null and _tw2.is_valid():
		_tw2.kill()
	_t = 1.0 if value else 0.0
	queue_redraw()


func activate() -> void:
	super()
	on = not on
	toggled.emit(on)


func _animate() -> void:
	var target := 1.0 if on else 0.0
	# Switches are configured before they are parented; a tween needs the tree.
	if not is_inside_tree() or bool(SaveData.get_setting("reduce_motion", false)):
		_t = target
		queue_redraw()
		return
	if _tw2 != null and _tw2.is_valid():
		_tw2.kill()
	_tw2 = create_tween()
	_tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw2.tween_method(_set_t, _t, target, 0.24)


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var track := Rect2(Vector2.ZERO, size)
	var off_col := Palette.c("sunken") if not Palette.is_dark() else Palette.c("card_alt")
	var sb := Palette.flat_box(h * 0.5, off_col.lerp(Palette.c("accent"), _t))
	draw_style_box(sb, track)

	var pad := h * 0.09
	var knob_r := h * 0.5 - pad
	var x: float = lerpf(pad + knob_r, size.x - pad - knob_r, _t)
	var shadow := Palette.flat_box(knob_r, Color(0, 0, 0, 0.16))
	draw_style_box(shadow, Rect2(Vector2(x - knob_r, h * 0.5 - knob_r + 3.0),
			Vector2(knob_r * 2.0, knob_r * 2.0)))
	draw_circle(Vector2(x, h * 0.5), knob_r, Color.WHITE)
