extends PuzzleView
## Pattern Snap: the sequence strip plus four options.

var _grid: ChoiceGrid
var _strip: Strip


class Strip:
	extends Control
	## Six slots: five known elements and the blank to fill.

	var kind := "number"
	var shown: Array = []
	var reveal_answer: Variant = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 132)

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)

	func _draw() -> void:
		var n := 6
		var gap := 12.0
		var w: float = (size.x - gap * float(n - 1)) / float(n)
		var h: float = minf(size.y, w * 1.18)
		var y := (size.y - h) * 0.5
		for i in n:
			var rect := Rect2(Vector2(float(i) * (w + gap), y), Vector2(w, h))
			var last := i == n - 1
			var fill: Color = Palette.c("card") if not last else Palette.c("accent_soft")
			var sb := Palette.flat_box(Palette.R_TILE, fill)
			if last:
				sb.set_border_width_all(3)
				sb.border_color = Palette.c("accent")
			else:
				sb.shadow_color = Palette.c("shadow")
				sb.shadow_size = 10
				sb.shadow_offset = Vector2(0, 4)
			draw_style_box(sb, rect)

			if last and reveal_answer == null:
				UiDraw.text_center(self, Palette.font_black, int(h * 0.42), rect, "?",
						Palette.c("accent"))
				continue
			var element: Variant = reveal_answer if last else shown[i]
			var col: Color = Palette.c("accent") if last else Palette.c("text")
			if kind == "number":
				var text := str(element)
				var fs := UiDraw.fit_size(Palette.font_bold, text, w - 12.0, int(h * 0.42), 13)
				UiDraw.text_center(self, Palette.font_bold, fs, rect, text, col)
			else:
				var g: Dictionary = element
				UiDraw.draw_glyph(self, int(g["shape"]), int(g["rot"]),
						rect.position + rect.size * 0.5, w * 0.29, col, bool(g["fill"]), 6.0)


func build(column: VBoxContainer) -> void:
	column.add_child(spacer(0.35))

	_strip = Strip.new()
	_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip.size_flags_stretch_ratio = 0.7
	_strip.kind = String(data["kind"])
	_strip.shown = data["shown"]
	column.add_child(_strip)

	column.add_child(spacer(0.3))

	_grid = ChoiceGrid.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_stretch_ratio = 1.7
	_grid.build(data["options"], String(data["kind"]) == "shape")
	_grid.chosen.connect(_on_chosen)
	column.add_child(_grid)
	column.add_child(spacer(0.12))


func _on_chosen(index: int) -> void:
	var correct := int(data["answer_index"])
	_grid.reveal(index, correct)
	_strip.reveal_answer = data["answer"]
	_strip.queue_redraw()
	if index == correct:
		succeed()
	else:
		fail()


func on_timeout() -> void:
	super()
	_grid.locked = true
	_grid.reveal(-1, int(data["answer_index"]))
	_strip.reveal_answer = data["answer"]
	_strip.queue_redraw()
