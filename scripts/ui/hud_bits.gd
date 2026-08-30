class_name HudBits
extends RefCounted
## Namespace holder -- see LifeDots and TimerLine below.


class LifeDots:
	extends Control
	## Remaining lives as filled dots; a lost life pops and hollows out.

	var total := 2
	var left := 2
	var _pulse := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120, 40)

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)

	func set_lives(value: int, animate := true) -> void:
		var lost := value < left
		left = value
		queue_redraw()
		if lost and animate and not bool(SaveData.get_setting("reduce_motion", false)):
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_method(_set_pulse, 1.0, 0.0, 0.5)

	func _set_pulse(v: float) -> void:
		_pulse = v
		queue_redraw()

	func _draw() -> void:
		var r := 15.0
		var gap := 20.0
		var w := float(total) * (r * 2.0) + float(total - 1) * gap
		var x := size.x - w + r
		var y := size.y * 0.5
		for i in total:
			var cx := x + float(i) * (r * 2.0 + gap)
			if i < left:
				draw_circle(Vector2(cx, y), r, Palette.c("accent"))
			else:
				var flash: Color = Palette.c("line").lerp(Palette.c("bad"), _pulse)
				draw_arc(Vector2(cx, y), r - 2.0, 0.0, TAU, 28, flash, 4.0, true)
				if _pulse > 0.0:
					draw_arc(Vector2(cx, y), r + 10.0 * _pulse, 0.0, TAU, 28,
							Palette.c("bad") * Color(1, 1, 1, _pulse * 0.7), 3.0, true)


class TimerLine:
	extends Control
	## Hairline countdown. Stays quiet until the last quarter, then warms up.

	var ratio := 1.0:
		set(value):
			ratio = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 6)

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var track := Palette.flat_box(h * 0.5, Palette.c("line"))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		if ratio <= 0.0:
			return
		var col := Palette.c("accent")
		if ratio < 0.12:
			col = Palette.c("bad")
		elif ratio < 0.26:
			col = Palette.c("warn")
		var fill := Palette.flat_box(h * 0.5, col)
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.x * ratio, h), h)))
