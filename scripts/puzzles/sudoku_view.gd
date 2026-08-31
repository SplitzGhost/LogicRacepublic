extends PuzzleView
## Mini sudoku. Tap a cell, tap a digit -- the cell flashes green or red at once,
## so you always know where you stand. A digit greys out on the pad as soon as
## all of its copies are on the board.
##
## A red flash is a wrong answer and costs a life, exactly like every other pool.

var _board: Board
var _keys: Array[PillButton] = []
var _locked_input := false


class Board:
	extends Control
	## The grid: given digits, the player's entries and the selection.

	signal cell_tapped(index: int)

	var n := 4
	var box_w := 2
	var box_h := 2
	var given: PackedInt32Array
	var values: PackedInt32Array
	var selected := -1
	var locked := false

	## Which cell is currently flashing, and how far the flash has faded.
	var flash_cell := -1
	var flash_key := "good"
	var flash_t := 0.0

	var _cell := 0.0
	var _origin := Vector2.ZERO
	var _gap := 6.0
	## Extra breathing room between boxes, so the sub-grids read at a glance.
	var _extra := 20.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)
		resized.connect(_measure)
		_measure()

	func _measure() -> void:
		var bx := n / box_w
		var by := n / box_h
		var cw: float = (size.x - _gap * float(n - 1) - _extra * float(bx - 1)) / float(n)
		var ch: float = (size.y - _gap * float(n - 1) - _extra * float(by - 1)) / float(n)
		_cell = maxf(10.0, minf(cw, ch))
		var total_w := _cell * float(n) + _gap * float(n - 1) + _extra * float(bx - 1)
		var total_h := _cell * float(n) + _gap * float(n - 1) + _extra * float(by - 1)
		_origin = Vector2((size.x - total_w) * 0.5, (size.y - total_h) * 0.5)
		queue_redraw()

	func cell_rect(idx: int) -> Rect2:
		var r := idx / n
		var c := idx % n
		var x := _origin.x + float(c) * (_cell + _gap) + float(c / box_w) * _extra
		var y := _origin.y + float(r) * (_cell + _gap) + float(r / box_h) * _extra
		return Rect2(Vector2(x, y), Vector2(_cell, _cell))

	func _gui_input(event: InputEvent) -> void:
		if locked or not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in n * n:
			if cell_rect(i).has_point(mb.position):
				cell_tapped.emit(i)
				return

	func set_flash(index: int, key: String) -> void:
		flash_cell = index
		flash_key = key
		flash_t = 1.0
		queue_redraw()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(_fade_flash, 1.0, 0.0, 0.75)

	func _fade_flash(v: float) -> void:
		flash_t = v
		queue_redraw()

	func _draw() -> void:
		for i in n * n:
			var rect := cell_rect(i)
			var is_given := given[i] != 0
			var filled := values[i] != 0
			# Givens sit on raised cards, blanks are recessed -- the contrast is
			# what makes the grid readable at a glance.
			var fill: Color = Palette.c("card") if filled else Palette.c("sunken")
			if i == selected:
				fill = Palette.c("accent_soft")
			if i == flash_cell and flash_t > 0.0:
				fill = fill.lerp(Palette.c(flash_key), flash_t)

			var sb := Palette.flat_box(minf(Palette.R_TILE, _cell * 0.26), fill)
			if i == selected:
				sb.set_border_width_all(3)
				sb.border_color = Palette.c("accent_hi")
			elif filled:
				sb.set_border_width_all(2)
				sb.border_color = Palette.c("glass")
				sb.shadow_color = Palette.c("shadow")
				sb.shadow_size = 8
				sb.shadow_offset = Vector2(0, 3)
			else:
				# Empty cells need an outline of their own, or the grid
				# disappears into the background.
				sb.set_border_width_all(2)
				sb.border_color = Palette.c("line")
			draw_style_box(sb, rect)

			var v := values[i]
			if v == 0:
				continue
			# The player's own answers stay tinted so progress is visible.
			var col: Color = Palette.c("text") if is_given else Palette.c("accent_hi")
			if i == flash_cell and flash_t > 0.4:
				col = Color.WHITE
			var font: Font = Palette.font_black if is_given else Palette.font_bold
			UiDraw.text_center(self, font, int(_cell * 0.54), rect, str(v), col)


func build(column: VBoxContainer) -> void:
	column.add_child(spacer(0.16))

	_board = Board.new()
	_board.n = int(data["size"])
	_board.box_w = int(data["box_w"])
	_board.box_h = int(data["box_h"])
	_board.given = data["given"]
	_board.values = (data["given"] as PackedInt32Array).duplicate()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_stretch_ratio = 3.2
	_board.cell_tapped.connect(_on_cell)
	column.add_child(_board)

	column.add_child(spacer(0.25))
	column.add_child(_keypad())
	column.add_child(spacer(0.1))
	_refresh_keys()


func _keypad() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 112
	var n := int(data["size"])
	for d in range(1, n + 1):
		var key := PillButton.new()
		key.text = str(d)
		key.variant = PillButton.Variant.SECONDARY
		key.radius = 24.0
		key.font_size = 42
		key.custom_minimum_size = Vector2(0, 112)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.pressed.connect(_on_key.bind(d))
		row.add_child(key)
		_keys.append(key)
	return row


## Greys out every digit that is already on the board `size` times.
func _refresh_keys() -> void:
	var n := _board.n
	var counts := PackedInt32Array()
	counts.resize(n + 1)
	counts.fill(0)
	for v in _board.values:
		if v > 0:
			counts[v] += 1
	for d in range(1, n + 1):
		_keys[d - 1].enabled = counts[d] < n


func _on_cell(index: int) -> void:
	if finished or _locked_input:
		return
	# Correct entries lock in, so only empty cells are selectable.
	if _board.values[index] != 0:
		Sfx.play("tick", 0.9, 0.5)
		return
	_board.selected = index if _board.selected != index else -1
	_board.queue_redraw()


func _on_key(digit: int) -> void:
	if finished or _locked_input or _board.selected < 0:
		return
	var idx := _board.selected
	var solution: PackedInt32Array = data["solution"]

	if digit != solution[idx]:
		# Immediate, unambiguous: the cell goes red and the life is gone.
		_locked_input = true
		_board.values[idx] = digit
		_board.selected = -1
		_board.set_flash(idx, "bad")
		Sfx.haptic(35)
		await get_tree().create_timer(0.35).timeout
		if not is_instance_valid(self):
			return
		_board.locked = true
		fail()
		return

	_board.values[idx] = digit
	_board.selected = -1
	_board.set_flash(idx, "good")
	Sfx.play("tick", 1.35, 0.6)
	_refresh_keys()
	_advance_selection(idx)
	_board.queue_redraw()

	for v in _board.values:
		if v == 0:
			return
	_board.locked = true
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		succeed()


## Jump to the next empty cell so the player keeps a rhythm.
func _advance_selection(from_index: int) -> void:
	var n := _board.n
	for step in range(1, n * n + 1):
		var i := (from_index + step) % (n * n)
		if _board.values[i] == 0:
			_board.selected = i
			return
	_board.selected = -1


func on_timeout() -> void:
	super()
	_board.locked = true
	_board.selected = -1
	_board.values = data["solution"]
	_board.queue_redraw()
