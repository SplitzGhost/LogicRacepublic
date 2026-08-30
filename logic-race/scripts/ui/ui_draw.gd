class_name UiDraw
extends RefCounted
## Small drawing helpers shared by the custom-drawn controls.

## Draws text centred inside `rect`, horizontally and on the cap height.
static func text_center(ci: CanvasItem, font: Font, size: int, rect: Rect2,
		text: String, color: Color) -> void:
	var dims := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var h := font.get_height(size)
	var asc := font.get_ascent(size)
	var pos := Vector2(
			rect.position.x + (rect.size.x - dims.x) * 0.5,
			rect.position.y + (rect.size.y - h) * 0.5 + asc)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Largest font size (<= `start`) at which `text` still fits into `max_w`.
static func fit_size(font: Font, text: String, max_w: float, start: int, floor_size := 14) -> int:
	var s := start
	while s > floor_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 2
	return s


## Eight glyphs for Pattern Snap. `rot` is 0..3 (multiples of 90 degrees).
## Shapes 2, 5, 6 and 7 change visibly when rotated.
static func glyph_points(shape: int, rot: int, center: Vector2, r: float) -> PackedVector2Array:
	var a0 := deg_to_rad(90.0 * float(rot))
	var pts := PackedVector2Array()
	match shape:
		0:  # circle
			for i in 44:
				var a := TAU * float(i) / 44.0
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		1:  # square
			for i in 4:
				var a := a0 + deg_to_rad(45.0 + 90.0 * float(i))
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		2:  # triangle
			for i in 3:
				var a := a0 + deg_to_rad(-90.0 + 120.0 * float(i))
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		3:  # diamond
			for i in 4:
				var a := a0 + deg_to_rad(-90.0 + 90.0 * float(i))
				pts.append(center + Vector2(cos(a), sin(a) * 1.28) * r * 0.86)
		4:  # hexagon
			for i in 6:
				var a := a0 + deg_to_rad(60.0 * float(i))
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		5:  # chevron / arrow
			var raw := PackedVector2Array([
				Vector2(0.0, -1.0), Vector2(0.95, 0.35), Vector2(0.42, 0.35),
				Vector2(0.42, 1.0), Vector2(-0.42, 1.0), Vector2(-0.42, 0.35),
				Vector2(-0.95, 0.35),
			])
			for p in raw:
				pts.append(center + p.rotated(a0) * r * 0.92)
		6:  # semicircle
			for i in 25:
				var a := a0 + PI * float(i) / 24.0
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		7:  # quarter pie
			pts.append(center + Vector2(0.0, 0.0).rotated(a0) * r)
			for i in 17:
				var a := a0 + (PI * 0.5) * float(i) / 16.0
				pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func draw_glyph(ci: CanvasItem, shape: int, rot: int, center: Vector2, r: float,
		color: Color, filled: bool, thickness := 7.0) -> void:
	var pts := glyph_points(shape, rot, center, r)
	if pts.is_empty():
		return
	var loop := pts.duplicate()
	loop.append(pts[0])
	if filled:
		ci.draw_colored_polygon(pts, color)
		# The compatibility renderer has no 2D MSAA, so trace the outline with an
		# anti-aliased line in the same colour to keep the edges smooth.
		ci.draw_polyline(loop, color, 1.6, true)
	else:
		ci.draw_polyline(loop, color, thickness, true)
