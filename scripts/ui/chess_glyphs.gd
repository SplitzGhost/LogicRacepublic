class_name ChessGlyphs
extends RefCounted
## Chess pieces as vector silhouettes, in the same hand-drawn style as the rest
## of the icon set. Filled with one colour and traced with a second so both
## colours read on either square shade.

const KING := 1
const QUEEN := 2
const ROOK := 3
const BISHOP := 4
const KNIGHT := 5
const PAWN := 6

const BODIES := {
	KING: [
		Vector2(-0.58, -0.40), Vector2(-0.32, -0.04), Vector2(0.00, -0.44),
		Vector2(0.32, -0.04), Vector2(0.58, -0.40), Vector2(0.50, 0.24),
		Vector2(0.58, 0.40), Vector2(0.58, 0.66), Vector2(-0.58, 0.66),
		Vector2(-0.58, 0.40), Vector2(-0.50, 0.24),
	],
	QUEEN: [
		Vector2(-0.60, -0.58), Vector2(-0.34, -0.10), Vector2(-0.17, -0.56),
		Vector2(0.00, -0.10), Vector2(0.17, -0.56), Vector2(0.34, -0.10),
		Vector2(0.60, -0.58), Vector2(0.50, 0.24), Vector2(0.58, 0.40),
		Vector2(0.58, 0.66), Vector2(-0.58, 0.66), Vector2(-0.58, 0.40),
		Vector2(-0.50, 0.24),
	],
	ROOK: [
		Vector2(-0.55, -0.62), Vector2(-0.30, -0.62), Vector2(-0.30, -0.42),
		Vector2(-0.12, -0.42), Vector2(-0.12, -0.62), Vector2(0.12, -0.62),
		Vector2(0.12, -0.42), Vector2(0.30, -0.42), Vector2(0.30, -0.62),
		Vector2(0.55, -0.62), Vector2(0.55, -0.20), Vector2(0.40, -0.06),
		Vector2(0.40, 0.32), Vector2(0.56, 0.48), Vector2(0.56, 0.66),
		Vector2(-0.56, 0.66), Vector2(-0.56, 0.48), Vector2(-0.40, 0.32),
		Vector2(-0.40, -0.06), Vector2(-0.55, -0.20),
	],
	BISHOP: [
		Vector2(0.00, -0.74), Vector2(0.25, -0.40), Vector2(0.30, -0.06),
		Vector2(0.18, 0.12), Vector2(0.34, 0.28), Vector2(0.34, 0.42),
		Vector2(0.54, 0.52), Vector2(0.54, 0.66), Vector2(-0.54, 0.66),
		Vector2(-0.54, 0.52), Vector2(-0.34, 0.42), Vector2(-0.34, 0.28),
		Vector2(-0.18, 0.12), Vector2(-0.30, -0.06), Vector2(-0.25, -0.40),
	],
	KNIGHT: [
		Vector2(-0.40, 0.66), Vector2(0.48, 0.66), Vector2(0.46, 0.44),
		Vector2(0.32, 0.20), Vector2(0.36, -0.10), Vector2(0.22, -0.42),
		Vector2(0.04, -0.58), Vector2(0.12, -0.76), Vector2(-0.08, -0.78),
		Vector2(-0.26, -0.56), Vector2(-0.48, -0.32), Vector2(-0.52, -0.02),
		Vector2(-0.30, -0.04), Vector2(-0.18, -0.20), Vector2(-0.08, -0.08),
		Vector2(-0.26, 0.20), Vector2(-0.38, 0.44),
	],
	PAWN: [
		Vector2(-0.20, -0.24), Vector2(0.20, -0.24), Vector2(0.32, 0.36),
		Vector2(0.50, 0.50), Vector2(0.50, 0.66), Vector2(-0.50, 0.66),
		Vector2(-0.50, 0.50), Vector2(-0.32, 0.36),
	],
}


static func draw_piece(ci: CanvasItem, code: int, center: Vector2, r: float,
		fill: Color, outline: Color) -> void:
	var kind := absi(code)
	var body: Array = BODIES.get(kind, [])
	if body.is_empty():
		return

	# Base plate first, so the body sits on top of it.
	var base := PackedVector2Array([
		center + Vector2(-0.68, 0.60) * r, center + Vector2(0.68, 0.60) * r,
		center + Vector2(0.60, 0.88) * r, center + Vector2(-0.60, 0.88) * r,
	])
	var base_loop := base.duplicate()
	base_loop.append(base[0])
	ci.draw_colored_polygon(base, fill)
	ci.draw_polyline(base_loop, outline, maxf(1.5, r * 0.075), true)

	var pts := PackedVector2Array()
	for p: Vector2 in body:
		pts.append(center + p * r)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(loop, outline, maxf(1.5, r * 0.075), true)

	match kind:
		PAWN:
			_disc(ci, center + Vector2(0.0, -0.50) * r, r * 0.30, fill, outline)
		BISHOP:
			_disc(ci, center + Vector2(0.0, -0.80) * r, r * 0.13, fill, outline)
			ci.draw_line(center + Vector2(-0.13, -0.30) * r,
					center + Vector2(0.13, -0.44) * r, outline, maxf(1.5, r * 0.07), true)
		QUEEN:
			for x in [-0.60, -0.17, 0.17, 0.60]:
				_disc(ci, center + Vector2(float(x), -0.62) * r, r * 0.12, fill, outline)
		KING:
			# The cross above the crown, outlined then filled so it reads on
			# either square colour.
			var w: float = maxf(3.0, r * 0.17)
			var v_top := center + Vector2(0.0, -0.98) * r
			var v_bottom := center + Vector2(0.0, -0.34) * r
			var h_left := center + Vector2(-0.26, -0.76) * r
			var h_right := center + Vector2(0.26, -0.76) * r
			ci.draw_line(v_top, v_bottom, outline, w * 1.85, true)
			ci.draw_line(h_left, h_right, outline, w * 1.85, true)
			ci.draw_line(v_top, v_bottom, fill, w, true)
			ci.draw_line(h_left, h_right, fill, w, true)


static func _disc(ci: CanvasItem, center: Vector2, r: float, fill: Color, outline: Color) -> void:
	ci.draw_circle(center, r, fill)
	ci.draw_arc(center, r, 0.0, TAU, 24, outline, maxf(1.2, r * 0.22), true)
