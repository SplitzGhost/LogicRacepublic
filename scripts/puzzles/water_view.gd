extends PuzzleView
## Water Sort. Tap a tube to pick it up, tap another to pour. Undo is available;
## running the board into a dead end is the wrong answer that costs a life.

const WaterGen := preload("res://scripts/gen/water_gen.gd")

var _rack: Rack
var _undo_btn: PillButton
var _tubes: Array = []
var _history: Array = []
var _selected := -1
var _capacity := 4


class Rack:
	extends Control
	## The tubes: glass capsules with stacked colour bands.

	signal tube_tapped(index: int)

	var tubes: Array = []
	var capacity := 4
	var selected := -1
	var locked := false

	var _rects: Array[Rect2] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		_rects.clear()
		var n := tubes.size()
		if n == 0:
			return
		var per_row: int = int(ceil(float(n) / 2.0)) if n > 4 else n
		var rows: int = 2 if n > 4 else 1

		var gap := 22.0
		var tube_w: float = minf((size.x - gap * float(per_row - 1)) / float(per_row), 104.0)
		var tube_h: float = minf((size.y - 40.0) / float(rows) - 24.0, tube_w * 3.4)

		var index := 0
		for r in rows:
			var count: int = mini(per_row, n - index)
			var row_w := float(count) * tube_w + gap * float(count - 1)
			var x := (size.x - row_w) * 0.5
			var y := (size.y - (float(rows) * tube_h + 34.0 * float(rows - 1))) * 0.5 \
					+ float(r) * (tube_h + 34.0)
			for i in count:
				_rects.append(Rect2(Vector2(x + float(i) * (tube_w + gap), y),
						Vector2(tube_w, tube_h)))
				index += 1
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if locked or not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in _rects.size():
			# A generous hit box: the tubes are narrow.
			if _rects[i].grow(11.0).has_point(mb.position):
				tube_tapped.emit(i)
				return

	func _draw() -> void:
		for i in mini(_rects.size(), tubes.size()):
			var rect := _rects[i]
			if i == selected:
				rect.position.y -= 22.0
			_draw_tube(rect, tubes[i] as Array)

	func _draw_tube(rect: Rect2, tube: Array) -> void:
		var round_bottom: float = rect.size.x * 0.5
		var wall := maxf(3.0, rect.size.x * 0.055)

		# Glass: a dark well so the colours read on any background.
		var glass := StyleBoxFlat.new()
		glass.bg_color = Palette.c("sunken")
		glass.corner_radius_top_left = int(rect.size.x * 0.16)
		glass.corner_radius_top_right = int(rect.size.x * 0.16)
		glass.corner_radius_bottom_left = int(round_bottom)
		glass.corner_radius_bottom_right = int(round_bottom)
		glass.corner_detail = 12
		glass.shadow_color = Palette.c("shadow")
		glass.shadow_size = 14
		glass.shadow_offset = Vector2(0, 7)
		draw_style_box(glass, rect)

		var inner := rect.grow(-wall)
		var seg_h: float = inner.size.y / float(capacity)
		for level in tube.size():
			var colour: Color = Palette.CHIPS[int(tube[level]) % Palette.CHIPS.size()]
			var y := inner.position.y + inner.size.y - float(level + 1) * seg_h
			var seg := Rect2(Vector2(inner.position.x, y), Vector2(inner.size.x, seg_h + 1.0))
			var sb := StyleBoxFlat.new()
			sb.bg_color = colour
			sb.corner_detail = 12
			if level == 0:
				sb.corner_radius_bottom_left = int(round_bottom - wall)
				sb.corner_radius_bottom_right = int(round_bottom - wall)
			if level == capacity - 1:
				sb.corner_radius_top_left = 6
				sb.corner_radius_top_right = 6
			draw_style_box(sb, seg)
			# A lighter cap on each band gives the liquid a surface.
			draw_rect(Rect2(seg.position, Vector2(seg.size.x, maxf(3.0, seg_h * 0.14))),
					colour.lightened(0.28))

		# Rim and a highlight down the left wall.
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color(0, 0, 0, 0)
		outline.set_border_width_all(int(wall))
		outline.border_color = Color(1, 1, 1, 0.85)
		outline.corner_radius_top_left = int(rect.size.x * 0.16)
		outline.corner_radius_top_right = int(rect.size.x * 0.16)
		outline.corner_radius_bottom_left = int(round_bottom)
		outline.corner_radius_bottom_right = int(round_bottom)
		outline.corner_detail = 12
		draw_style_box(outline, rect)
		draw_line(rect.position + Vector2(rect.size.x * 0.26, rect.size.y * 0.12),
				rect.position + Vector2(rect.size.x * 0.26, rect.size.y * 0.72),
				Color(1, 1, 1, 0.22), maxf(2.0, rect.size.x * 0.07), true)


func build(column: VBoxContainer) -> void:
	_capacity = int(data["capacity"])
	for t: Array in (data["tubes"] as Array):
		_tubes.append(t.duplicate())

	column.add_child(spacer(0.2))

	_rack = Rack.new()
	_rack.tubes = _tubes
	_rack.capacity = _capacity
	_rack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rack.size_flags_stretch_ratio = 4.0
	_rack.tube_tapped.connect(_on_tube)
	column.add_child(_rack)

	column.add_child(spacer(0.12))

	_undo_btn = PillButton.new()
	_undo_btn.text = "Undo"
	_undo_btn.variant = PillButton.Variant.SECONDARY
	_undo_btn.font_size = 28
	_undo_btn.radius = 26.0
	_undo_btn.custom_minimum_size.y = 92
	_undo_btn.enabled = false
	_undo_btn.pressed.connect(_on_undo)
	column.add_child(_undo_btn)
	column.add_child(spacer(0.06))


func _on_tube(index: int) -> void:
	if finished:
		return
	if _selected < 0:
		if (_tubes[index] as Array).is_empty():
			return
		_selected = index
		_rack.selected = index
		_rack.queue_redraw()
		Sfx.play("tick", 1.15, 0.5)
		return

	if _selected == index:
		_selected = -1
		_rack.selected = -1
		_rack.queue_redraw()
		return

	if not WaterGen.can_pour(_tubes, _selected, index, _capacity):
		Sfx.play("tick", 0.75, 0.6)
		_selected = -1
		_rack.selected = -1
		_rack.queue_redraw()
		return

	_push_history()
	_tubes = WaterGen.pour(_tubes, _selected, index, _capacity)
	_selected = -1
	_rack.tubes = _tubes
	_rack.selected = -1
	_rack.queue_redraw()
	Sfx.play("select", 1.05, 0.75)
	_check()


func _push_history() -> void:
	var snapshot: Array = []
	for t: Array in _tubes:
		snapshot.append(t.duplicate())
	_history.append(snapshot)
	_undo_btn.enabled = true


func _check() -> void:
	if WaterGen.is_solved(_tubes, _capacity):
		_rack.locked = true
		succeed()
		return
	# A dead end with nothing left to undo is the wrong answer.
	if not WaterGen.has_move(_tubes, _capacity) and _history.is_empty():
		_rack.locked = true
		fail()


func _on_undo() -> void:
	if finished or _history.is_empty():
		return
	_tubes = _history.pop_back()
	_rack.tubes = _tubes
	_selected = -1
	_rack.selected = -1
	_rack.queue_redraw()
	_undo_btn.enabled = not _history.is_empty()
	Sfx.play("toggle", 0.9, 0.7)


func on_timeout() -> void:
	super()
	_rack.locked = true
	_rack.selected = -1
	_rack.queue_redraw()
