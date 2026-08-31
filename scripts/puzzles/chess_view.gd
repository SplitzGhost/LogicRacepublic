extends PuzzleView
## Chess mate puzzles. Tap a white piece, tap a square. Every move has to keep
## the forced mate alive -- anything else is a wrong answer.

const ChessGen := preload("res://scripts/gen/chess_gen.gd")

var _board: Board
var _engine: RefCounted
var _depth_left := 1
var _busy := false


class Board:
	extends Control
	## Squares, pieces, selection and move hints.

	signal square_tapped(index: int)

	var w := 5
	var h := 5
	var pieces := PackedInt32Array()
	var selected := -1
	var targets := PackedInt32Array()
	var highlight_from := -1
	var highlight_to := -1
	var locked := false

	## The board keeps its own palette so it always reads as a chessboard,
	## whichever app theme is active.
	const LIGHT_SQ := Color("#ece9f8")
	const DARK_SQ := Color("#9c93d8")
	const FRAME := Color("#7f74c2")
	const FRAME_EDGE := Color("#5c4f9e")
	const PIECE_DARK := Color("#252244")
	const FILES := "abcdefgh"

	var _cell := 0.0
	var _origin := Vector2.ZERO
	var _band := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		Palette.changed.connect(queue_redraw)
		resized.connect(_measure)
		_measure()

	func _measure() -> void:
		# The coordinate band around the board eats into the available box.
		var raw: float = minf(size.x / float(w), size.y / float(h))
		_band = raw * 0.30
		_cell = maxf(10.0, minf((size.x - _band * 2.0) / float(w),
				(size.y - _band * 2.0) / float(h)))
		_band = _cell * 0.30
		_origin = Vector2((size.x - _cell * float(w)) * 0.5,
				(size.y - _cell * float(h)) * 0.5)
		queue_redraw()

	func cell_rect(idx: int) -> Rect2:
		var r := idx / w
		var c := idx % w
		return Rect2(_origin + Vector2(float(c) * _cell, float(r) * _cell),
				Vector2(_cell, _cell))

	func _gui_input(event: InputEvent) -> void:
		if locked or not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in w * h:
			if cell_rect(i).has_point(mb.position):
				square_tapped.emit(i)
				return

	func _draw() -> void:
		var board_rect := Rect2(_origin, Vector2(_cell * float(w), _cell * float(h)))

		# Frame with the coordinate band, then a darker inner edge around the grid.
		var frame := Palette.flat_box(_band * 0.7, FRAME)
		frame.shadow_color = Palette.c("shadow")
		frame.shadow_size = 26
		frame.shadow_offset = Vector2(0, 12)
		draw_style_box(frame, board_rect.grow(_band))

		var edge := Palette.flat_box(4.0, Color(0, 0, 0, 0))
		edge.set_border_width_all(maxf(2.0, _cell * 0.035))
		edge.border_color = FRAME_EDGE
		draw_style_box(edge, board_rect.grow(maxf(2.0, _cell * 0.035)))

		var label_size := int(maxf(11.0, _band * 0.62))
		for c in w:
			var text := FILES[c]
			var x := _origin.x + float(c) * _cell
			UiDraw.text_center(self, Palette.font_bold, label_size,
					Rect2(Vector2(x, _origin.y - _band), Vector2(_cell, _band)), text, LIGHT_SQ)
			UiDraw.text_center(self, Palette.font_bold, label_size,
					Rect2(Vector2(x, _origin.y + _cell * float(h)), Vector2(_cell, _band)),
					text, LIGHT_SQ)
		for r in h:
			# Rank 1 is White's home row, which sits at the bottom of the board.
			var text := str(h - r)
			var y := _origin.y + float(r) * _cell
			UiDraw.text_center(self, Palette.font_bold, label_size,
					Rect2(Vector2(_origin.x - _band, y), Vector2(_band, _cell)), text, LIGHT_SQ)
			UiDraw.text_center(self, Palette.font_bold, label_size,
					Rect2(Vector2(_origin.x + _cell * float(w), y), Vector2(_band, _cell)),
					text, LIGHT_SQ)

		for i in w * h:
			var rect := cell_rect(i)
			var dark := ((i / w) + (i % w)) % 2 == 1
			var fill: Color = DARK_SQ if dark else LIGHT_SQ
			if i == highlight_from or i == highlight_to:
				fill = fill.lerp(Palette.c("gold"), 0.45)
			if i == selected:
				fill = fill.lerp(Palette.c("accent_hi"), 0.5)
			draw_rect(rect, fill)

			var piece := pieces[i]
			if piece != 0:
				var white := piece > 0
				ChessGlyphs.draw_piece(self, absi(piece), rect.position + rect.size * 0.5,
						_cell * 0.36,
						Color.WHITE if white else PIECE_DARK,
						PIECE_DARK if white else Color("#e8e5f6"))

		# Move hints go on top of the pieces they can capture.
		for t in targets:
			var rect := cell_rect(t)
			var center := rect.position + rect.size * 0.5
			if pieces[t] != 0:
				draw_arc(center, _cell * 0.42, 0.0, TAU, 32, Palette.c("accent_hi"),
						maxf(3.0, _cell * 0.07), true)
			else:
				draw_circle(center, _cell * 0.14, Color(0.35, 0.18, 0.62, 0.55))


func build(column: VBoxContainer) -> void:
	_engine = ChessGen.new()
	_depth_left = int(data["depth"])

	column.add_child(spacer(0.8))

	_board = Board.new()
	_board.w = int(data["w"])
	_board.h = int(data["h"])
	_board.pieces = (data["board"] as PackedInt32Array).duplicate()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_stretch_ratio = 2.3
	_board.square_tapped.connect(_on_square)
	column.add_child(_board)

	column.add_child(spacer(1.2))


func _on_square(index: int) -> void:
	if finished or _busy:
		return
	var piece := _board.pieces[index]

	if _board.selected >= 0 and _board.targets.has(index):
		_play(_board.selected, index)
		return
	if piece > 0:
		_board.selected = index
		_board.targets = _targets_from(index)
		_board.queue_redraw()
		Sfx.play("tick", 1.1, 0.5)
		return
	_board.selected = -1
	_board.targets = PackedInt32Array()
	_board.queue_redraw()


func _targets_from(from_sq: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in _engine.call("moves_for", _board.pieces, _board.w, _board.h, ChessGen.WHITE):
		if ChessGen.move_from(m) == from_sq:
			out.append(ChessGen.move_to(m))
	return out


func _play(from_sq: int, to_sq: int) -> void:
	_busy = true
	_board.selected = -1
	_board.targets = PackedInt32Array()

	# Find the actual move object (a pawn reaching the far rank promotes).
	var chosen := -1
	for m in _engine.call("moves_for", _board.pieces, _board.w, _board.h, ChessGen.WHITE):
		if ChessGen.move_from(m) == from_sq and ChessGen.move_to(m) == to_sq:
			chosen = m
			break
	if chosen < 0:
		_busy = false
		return

	var keeps_mate := false
	for m in _engine.call("winning_moves", _board.pieces, _board.w, _board.h, _depth_left):
		if m == chosen:
			keeps_mate = true
			break

	_board.pieces = _engine.call("play", _board.pieces, _board.w, _board.h, chosen)
	_board.highlight_from = from_sq
	_board.highlight_to = to_sq
	_board.queue_redraw()

	if _engine.call("mated", _board.pieces, _board.w, _board.h, ChessGen.BLACK):
		_board.locked = true
		succeed()
		return

	if not keeps_mate:
		# The move was legal but throws the mate away.
		_board.locked = true
		Sfx.play("wrong")
		fail()
		return

	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self) or finished:
		return
	_reply()


## Black defends with a move that survives as long as possible.
func _reply() -> void:
	var reply: int = _engine.call("best_defence", _board.pieces, _board.w, _board.h, _depth_left)
	if reply < 0:
		_board.locked = true
		succeed()
		return
	_board.pieces = _engine.call("play", _board.pieces, _board.w, _board.h, reply)
	_board.highlight_from = ChessGen.move_from(reply)
	_board.highlight_to = ChessGen.move_to(reply)
	_depth_left = maxi(1, _depth_left - 1)
	_board.queue_redraw()
	Sfx.play("select", 0.85, 0.6)
	_busy = false


func on_timeout() -> void:
	super()
	_board.locked = true
	_board.selected = -1
	_board.targets = PackedInt32Array()
	var solution := int(data["solution"])
	_board.highlight_from = ChessGen.move_from(solution)
	_board.highlight_to = ChessGen.move_to(solution)
	_board.queue_redraw()
