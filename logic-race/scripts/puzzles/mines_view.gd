extends PuzzleView
## Minesweeper. Tap to open, long-press (or the flag button) to mark a mine.

var _board: Board
var _flag_mode := false
var _flag_btn: IconButton
var _counter: Label


class Board:
	extends Control

	signal tapped(index: int)
	signal held(index: int)

	## Classic minesweeper digit colours, one per adjacency count.
	const NUM_COLS := ["#3b82f6", "#18b26b", "#f2415a", "#8b5cf6", "#f59e0b",
			"#06b6d4", "#ec4899", "#64748b"]
	const HOLD_TIME := 0.38

	var w := 5
	var h := 5
	var mines: PackedByteArray
	var opened: PackedByteArray
	var flags: PackedByteArray
	var exploded := -1
	var show_mines := false
	var locked := false

	var _cell := 0.0
	var _origin := Vector2.ZERO
	var _gap := 6.0
	var _press := -1
	var _press_t := 0.0
	var _fired := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)
		resized.connect(_measure)
		set_process(true)
		_measure()

	func _measure() -> void:
		var cw: float = (size.x - _gap * float(w - 1)) / float(w)
		var ch: float = (size.y - _gap * float(h - 1)) / float(h)
		_cell = maxf(10.0, minf(cw, ch))
		var tw := _cell * float(w) + _gap * float(w - 1)
		var th := _cell * float(h) + _gap * float(h - 1)
		_origin = Vector2((size.x - tw) * 0.5, (size.y - th) * 0.5)
		queue_redraw()

	func cell_rect(idx: int) -> Rect2:
		var r := idx / w
		var c := idx % w
		return Rect2(_origin + Vector2(float(c) * (_cell + _gap), float(r) * (_cell + _gap)),
				Vector2(_cell, _cell))

	func cell_at(pos: Vector2) -> int:
		for i in w * h:
			if cell_rect(i).has_point(pos):
				return i
		return -1

	func adjacent(idx: int) -> int:
		var count := 0
		for nb in neighbours(idx):
			if mines[nb] == 1:
				count += 1
		return count

	func neighbours(idx: int) -> Array[int]:
		var out: Array[int] = []
		var x := idx % w
		var y := idx / w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + int(dx)
				var ny: int = y + int(dy)
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					out.append(ny * w + nx)
		return out

	func _gui_input(event: InputEvent) -> void:
		if locked:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				_press = cell_at(mb.position)
				_press_t = 0.0
				_fired = false
			else:
				if _press >= 0 and not _fired and cell_at(mb.position) == _press:
					tapped.emit(_press)
				_press = -1

	func _process(delta: float) -> void:
		if _press < 0 or _fired:
			return
		_press_t += delta
		if _press_t >= HOLD_TIME:
			_fired = true
			held.emit(_press)

	func _draw() -> void:
		var radius: float = minf(Palette.R_TILE, _cell * 0.26)
		for i in w * h:
			var rect := cell_rect(i)
			var is_open := opened[i] == 1
			var fill: Color = Palette.c("sunken") if is_open else Palette.c("card")
			if i == exploded:
				fill = Palette.c("bad")
			var sb := Palette.flat_box(radius, fill)
			if not is_open and i != exploded:
				sb.shadow_color = Palette.c("shadow")
				sb.shadow_size = 8
				sb.shadow_offset = Vector2(0, 3)
			draw_style_box(sb, rect)

			var center := rect.position + rect.size * 0.5
			if is_open:
				var n := adjacent(i)
				if n > 0:
					UiDraw.text_center(self, Palette.font_black, int(_cell * 0.5), rect,
							str(n), Color(NUM_COLS[clampi(n - 1, 0, 7)]))
			elif flags[i] == 1:
				Icons.draw(self, "flag", center, _cell * 0.3, Palette.c("warn"), 4.0)
			elif show_mines and mines[i] == 1:
				Icons.draw(self, "mine", center, _cell * 0.3, Palette.c("text_dim"), 4.0)
			if i == exploded:
				Icons.draw(self, "mine", center, _cell * 0.32, Color.WHITE, 4.0)




func build(column: VBoxContainer) -> void:
	column.add_child(spacer(0.2))

	_board = Board.new()
	_board.w = int(data["w"])
	_board.h = int(data["h"])
	_board.mines = data["mines"]
	_board.opened = (data["opened"] as PackedByteArray).duplicate()
	_board.flags = PackedByteArray()
	_board.flags.resize(_board.w * _board.h)
	_board.flags.fill(0)
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_stretch_ratio = 3.4
	_board.tapped.connect(_on_tap)
	_board.held.connect(_on_hold)
	column.add_child(_board)

	column.add_child(spacer(0.15))
	column.add_child(_tools())
	column.add_child(spacer(0.1))
	_update_counter()


func _tools() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 96
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_flag_btn = IconButton.new()
	_flag_btn.icon = "flag"
	_flag_btn.custom_minimum_size = Vector2(96, 96)
	_flag_btn.tint = "text_dim"
	_flag_btn.pressed.connect(_toggle_flag_mode)
	row.add_child(_flag_btn)

	_counter = Label.new()
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", 27)
	_counter.add_theme_color_override("font_color", Palette.c("text_dim"))
	row.add_child(_counter)
	return row


func _toggle_flag_mode() -> void:
	_flag_mode = not _flag_mode
	_flag_btn.tint = "warn" if _flag_mode else "text_dim"
	_flag_btn.queue_redraw()


func _update_counter() -> void:
	var flagged := 0
	for f in _board.flags:
		if f == 1:
			flagged += 1
	_counter.text = "%d of %d marked" % [flagged, int(data["mine_count"])]


func _on_hold(index: int) -> void:
	if finished:
		return
	Sfx.haptic(18)
	_flag(index)


func _on_tap(index: int) -> void:
	if finished:
		return
	if _flag_mode:
		_flag(index)
		return
	if _board.flags[index] == 1 or _board.opened[index] == 1:
		Sfx.play("tick", 0.9, 0.5)
		return

	if _board.mines[index] == 1:
		_board.exploded = index
		_board.show_mines = true
		_board.locked = true
		_board.queue_redraw()
		fail()
		return

	Sfx.play("select", 1.1, 0.7)
	_open(index)
	_board.queue_redraw()
	_check_win()


func _flag(index: int) -> void:
	if _board.opened[index] == 1:
		return
	_board.flags[index] = 0 if _board.flags[index] == 1 else 1
	Sfx.play("toggle", 1.15, 0.6)
	_board.queue_redraw()
	_update_counter()


## Opens a cell and floods outward through the empty region, like the original.
func _open(start: int) -> void:
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if _board.opened[idx] == 1 or _board.mines[idx] == 1:
			continue
		_board.opened[idx] = 1
		_board.flags[idx] = 0
		if _board.adjacent(idx) == 0:
			for nb in _board.neighbours(idx):
				if _board.opened[nb] == 0 and _board.mines[nb] == 0:
					stack.append(nb)
	_update_counter()


func _check_win() -> void:
	for i in _board.w * _board.h:
		if _board.mines[i] == 0 and _board.opened[i] == 0:
			return
	_board.locked = true
	succeed()


func on_timeout() -> void:
	super()
	_board.locked = true
	_board.show_mines = true
	_board.queue_redraw()
