class_name SliderRow
extends Control
## Labelled value slider used in the settings sheet.

signal value_changed(value: float)

var label := "Volume"
var value := 0.85
var _dragging := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 108)


func _ready() -> void:
	Palette.changed.connect(queue_redraw)


func _track() -> Rect2:
	return Rect2(Vector2(0.0, size.y - 34.0), Vector2(size.x, 14.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_dragging = mb.pressed
		if mb.pressed:
			_apply(mb.position.x)
			Sfx.haptic(6)
	elif event is InputEventMouseMotion and _dragging:
		_apply((event as InputEventMouseMotion).position.x)


func _apply(x: float) -> void:
	var track := _track()
	var v := clampf((x - track.position.x) / maxf(track.size.x, 1.0), 0.0, 1.0)
	if is_equal_approx(v, value):
		return
	value = v
	queue_redraw()
	value_changed.emit(value)


func _draw() -> void:
	draw_string(Palette.font_medium, Vector2(2.0, 34.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.c("text"))
	var pct := "%d%%" % int(round(value * 100.0))
	var w := Palette.font_bold.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
	draw_string(Palette.font_bold, Vector2(size.x - w, 34.0), pct,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Palette.c("text_dim"))

	var track := _track()
	draw_style_box(Palette.flat_box(track.size.y * 0.5, Palette.c("sunken")), track)
	var fw: float = maxf(track.size.x * value, track.size.y)
	draw_style_box(Palette.flat_box(track.size.y * 0.5, Palette.c("accent")),
			Rect2(track.position, Vector2(fw, track.size.y)))
	var kx: float = track.position.x + track.size.x * value
	var ky := track.position.y + track.size.y * 0.5
	draw_circle(Vector2(kx, ky + 2.0), 19.0, Color(0, 0, 0, 0.14))
	draw_circle(Vector2(kx, ky), 18.0, Color.WHITE)
