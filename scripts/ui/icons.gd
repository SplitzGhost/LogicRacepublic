class_name Icons
extends RefCounted
## Every icon in the game is drawn as vectors -- no image assets, so they stay
## crisp at any density and follow the palette automatically.

static func draw(ci: CanvasItem, name: String, center: Vector2, r: float,
		color: Color, w := 5.0) -> void:
	match name:
		"sun":
			ci.draw_arc(center, r * 0.46, 0.0, TAU, 32, color, w, true)
			for i in 8:
				var a := TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(center + d * r * 0.72, center + d * r * 1.02, color, w, true)
		"moon":
			# Crescent: a disc with a second disc punched out by drawing an arc band.
			var pts := PackedVector2Array()
			for i in 33:
				var a: float = lerpf(-PI * 0.42, PI * 0.42, float(i) / 32.0)
				pts.append(center + Vector2(cos(a), sin(a)) * r * 0.92)
			for i in 33:
				var a: float = lerpf(PI * 0.42, -PI * 0.42, float(i) / 32.0)
				pts.append(center + Vector2(-0.35, 0.0) * r + Vector2(cos(a), sin(a)) * r * 0.95)
			ci.draw_colored_polygon(pts, color)
		"sliders":
			for i in 2:
				var y := center.y + (-1.0 if i == 0 else 1.0) * r * 0.42
				ci.draw_line(Vector2(center.x - r * 0.9, y), Vector2(center.x + r * 0.9, y),
						color, w, true)
				var kx := center.x + (r * 0.35 if i == 0 else -r * 0.35)
				ci.draw_circle(Vector2(kx, y), w * 1.5, color)
		"back":
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(r * 0.35, -r * 0.62),
				center + Vector2(-r * 0.35, 0.0),
				center + Vector2(r * 0.35, r * 0.62),
			]), color, w, true)
		"close":
			ci.draw_line(center + Vector2(-r * 0.5, -r * 0.5), center + Vector2(r * 0.5, r * 0.5), color, w, true)
			ci.draw_line(center + Vector2(r * 0.5, -r * 0.5), center + Vector2(-r * 0.5, r * 0.5), color, w, true)
		"check":
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(-r * 0.55, r * 0.02),
				center + Vector2(-r * 0.16, r * 0.44),
				center + Vector2(r * 0.58, -r * 0.45),
			]), color, w, true)
		"undo":
			ci.draw_arc(center + Vector2(0.0, r * 0.1), r * 0.6, PI * 0.85, TAU + PI * 0.15, 26, color, w, true)
			var tip := center + Vector2(-r * 0.6, r * 0.1)
			ci.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-r * 0.26, -r * 0.06), tip + Vector2(r * 0.2, -r * 0.2),
				tip + Vector2(r * 0.14, r * 0.28),
			]), color)
		"flag":
			ci.draw_line(center + Vector2(-r * 0.36, -r * 0.62), center + Vector2(-r * 0.36, r * 0.66), color, w, true)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-r * 0.28, -r * 0.58),
				center + Vector2(r * 0.62, -r * 0.24),
				center + Vector2(-r * 0.28, r * 0.1),
			]), color)
		"mine":
			ci.draw_circle(center, r * 0.42, color)
			for i in 6:
				var a := TAU * float(i) / 6.0 + PI / 12.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(center + d * r * 0.36, center + d * r * 0.82, color, w * 0.8, true)
		"erase":
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(-r * 0.85, 0.0), center + Vector2(-r * 0.3, -r * 0.55),
				center + Vector2(r * 0.8, -r * 0.55), center + Vector2(r * 0.8, r * 0.55),
				center + Vector2(-r * 0.3, r * 0.55), center + Vector2(-r * 0.85, 0.0),
			]), color, w * 0.8, true)
			ci.draw_line(center + Vector2(-r * 0.05, -r * 0.24), center + Vector2(r * 0.42, r * 0.24), color, w * 0.8, true)
			ci.draw_line(center + Vector2(r * 0.42, -r * 0.24), center + Vector2(-r * 0.05, r * 0.24), color, w * 0.8, true)
		"heart":
			var pts2 := PackedVector2Array()
			for i in 40:
				var t := TAU * float(i) / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts2.append(center + Vector2(x, y) * (r / 17.0))
			ci.draw_colored_polygon(pts2, color)
		"trophy":
			# Cup, handles, stem and foot.
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-0.46, -0.72) * r, center + Vector2(0.46, -0.72) * r,
				center + Vector2(0.40, -0.18) * r, center + Vector2(0.16, 0.10) * r,
				center + Vector2(-0.16, 0.10) * r, center + Vector2(-0.40, -0.18) * r,
			]), color)
			ci.draw_arc(center + Vector2(-0.56, -0.50) * r, r * 0.26, -PI * 0.4, PI * 0.75,
					16, color, w * 0.8, true)
			ci.draw_arc(center + Vector2(0.56, -0.50) * r, r * 0.26, PI * 0.25, PI * 1.4,
					16, color, w * 0.8, true)
			ci.draw_line(center + Vector2(0.0, 0.06) * r, center + Vector2(0.0, 0.48) * r,
					color, w * 1.6, true)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-0.42, 0.50) * r, center + Vector2(0.42, 0.50) * r,
				center + Vector2(0.42, 0.74) * r, center + Vector2(-0.42, 0.74) * r,
			]), color)
		"wrench":
			ci.draw_line(center + Vector2(-0.5, 0.5) * r, center + Vector2(0.28, -0.28) * r,
					color, w * 1.7, true)
			ci.draw_arc(center + Vector2(0.42, -0.42) * r, r * 0.34, PI * 0.35, PI * 1.9,
					20, color, w * 1.5, true)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-r * 0.42, -r * 0.62),
				center + Vector2(r * 0.66, 0.0),
				center + Vector2(-r * 0.42, r * 0.62),
			]), color)
