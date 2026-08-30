extends PuzzleView
## Target Number. Tap a value, an operator and a second value to fold them
## together. Reduce the four numbers to exactly the target.

const TargetGen := preload("res://scripts/gen/target_gen.gd")
const OP_LABELS := ["+", "−", "×", "÷"]

var values: Array[Vector2i] = []
var _history: Array = []
var _sel_a := -1
var _sel_op := -1

var _row: HBoxContainer
var _op_tiles: Array[Tile] = []
var _tiles: Array[Tile] = []
var _undo_btn: PillButton


class Tile:
	extends TapButton
	## A value or operator chip.

	var label := ""
	var selected := false:
		set(value):
			selected = value
			queue_redraw()
	var compact := false

	func _init() -> void:
		super()
		press_scale = 0.94
		sfx_name = "select"

	func _ready() -> void:
		super()
		Palette.changed.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var fill: Color = Palette.c("accent") if selected else Palette.c("card")
		var sb := Palette.flat_box(Palette.R_TILE + 2.0, fill)
		sb.shadow_color = Palette.c("accent") * Color(1, 1, 1, 0.3) if selected \
				else Palette.c("shadow")
		sb.shadow_size = 16 if selected else 12
		sb.shadow_offset = Vector2(0, 5)
		draw_style_box(sb, rect)
		var col: Color = Palette.c("on_accent") if selected else Palette.c("text")
		var base := int(rect.size.y * (0.44 if compact else 0.42))
		var fs := UiDraw.fit_size(Palette.font_bold, label, rect.size.x - 20.0, base, 18)
		UiDraw.text_center(self, Palette.font_bold, fs, rect, label, col)


func build(column: VBoxContainer) -> void:
	column.add_child(spacer(0.7))
	column.add_child(_target_badge())
	column.add_child(spacer(0.34))

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.custom_minimum_size.y = 150
	column.add_child(_row)

	column.add_child(spacer(0.26))
	column.add_child(_op_row())
	column.add_child(spacer(0.16))
	column.add_child(_tools())
	column.add_child(spacer(0.1))

	for v in (data["numbers"] as Array):
		values.append(Vector2i(int(v), 1))
	_rebuild()


func _target_badge() -> Control:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.custom_minimum_size = Vector2(268, 126)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grad := GradRect.new()
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.radius = 40.0
	grad.gloss = 0.06
	grad.set_colors(Palette.c("accent_hi"), Palette.c("accent"))
	box.add_child(grad)

	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = str(int(data["target"]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Palette.font_black)
	label.add_theme_font_size_override("font_size", 68)
	label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(label)

	Palette.changed.connect(func() -> void:
		grad.set_colors(Palette.c("accent_hi"), Palette.c("accent")))

	center.add_child(box)
	return center


func _op_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size.y = 112
	for i in 4:
		var t := Tile.new()
		t.label = OP_LABELS[i]
		t.compact = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size.y = 112
		t.pressed.connect(_on_op.bind(i))
		row.add_child(t)
		_op_tiles.append(t)
	return row


func _tools() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size.y = 92

	_undo_btn = PillButton.new()
	_undo_btn.text = "Undo"
	_undo_btn.variant = PillButton.Variant.SECONDARY
	_undo_btn.font_size = 28
	_undo_btn.radius = 26.0
	_undo_btn.custom_minimum_size.y = 92
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(_on_undo)
	row.add_child(_undo_btn)

	var reset := PillButton.new()
	reset.text = "Reset"
	reset.variant = PillButton.Variant.GHOST
	reset.font_size = 28
	reset.custom_minimum_size.y = 92
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_on_reset)
	row.add_child(reset)
	return row


# ------------------------------------------------------------------ state ---
func _rebuild() -> void:
	for t in _tiles:
		t.queue_free()
	_tiles.clear()
	_sel_a = -1
	_sel_op = -1
	for t in _op_tiles:
		t.selected = false

	var width: float = clampf(620.0 / float(maxi(values.size(), 1)) - 18.0, 96.0, 190.0)
	for i in values.size():
		var tile := Tile.new()
		tile.label = TargetGen.rat_to_string(values[i])
		tile.custom_minimum_size = Vector2(width, 150)
		tile.pressed.connect(_on_value.bind(i))
		_row.add_child(tile)
		_tiles.append(tile)

	if _undo_btn != null:
		_undo_btn.enabled = not _history.is_empty()


func _on_value(index: int) -> void:
	if finished:
		return
	if _sel_a == -1 or _sel_op == -1:
		_sel_a = -1 if _sel_a == index else index
		_refresh_selection()
		return
	if _sel_a == index:
		_sel_a = -1
		_refresh_selection()
		return
	_apply(_sel_a, _sel_op, index)


func _on_op(op: int) -> void:
	if finished:
		return
	_sel_op = -1 if _sel_op == op else op
	_refresh_selection()


func _refresh_selection() -> void:
	for i in _tiles.size():
		_tiles[i].selected = i == _sel_a
	for i in _op_tiles.size():
		_op_tiles[i].selected = i == _sel_op


func _apply(a: int, op: int, b: int) -> void:
	var result: Variant = TargetGen.apply_op(values[a], values[b], op)
	if result == null:
		# Division by zero -- refuse politely instead of consuming a life.
		_tiles[b].shake()
		Sfx.play("tick", 0.8, 0.7)
		_sel_op = -1
		_refresh_selection()
		return

	_history.append(values.duplicate())
	var merged: Array[Vector2i] = []
	for i in values.size():
		if i == mini(a, b):
			merged.append(result)
		elif i != a and i != b:
			merged.append(values[i])
	values = merged
	Sfx.play("select", 1.15, 0.8)
	_rebuild()

	if values.size() == 1:
		_finish()


func _finish() -> void:
	var target := Vector2i(int(data["target"]), 1)
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or finished:
		return
	if values[0] == target:
		_tiles[0].selected = true
		succeed()
	else:
		_tiles[0].shake()
		fail()


func _on_undo() -> void:
	if finished or _history.is_empty():
		return
	values = _restore(_history.pop_back())
	Sfx.play("toggle", 0.9, 0.7)
	_rebuild()


func _restore(snapshot: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(snapshot)
	return out


func _on_reset() -> void:
	if finished or _history.is_empty():
		return
	values = _restore(_history[0])
	_history.clear()
	Sfx.play("toggle", 0.8, 0.7)
	_rebuild()


func on_timeout() -> void:
	super()
	for t in _tiles:
		t.enabled = false
	for t in _op_tiles:
		t.enabled = false
