extends RefCounted
## Mate-in-N puzzles on a miniature board (3x3 up to 6x6).
##
## Contains a small but complete chess engine for the reduced board: legal move
## generation for K/Q/R/B/N/P, check and mate detection, and a forced-mate
## search. Simplifications, all well defined on a board this size: no castling,
## no en passant, no double pawn step. Pawns promote to a queen on the far rank.
##
## Positions are generated at random and then proved: accepted only when White
## can force mate in exactly N and exactly one first move does it.
##
## The search mutates a single board in place (make/unmake) instead of copying,
## and asks "is Black in check?" before it ever enumerates Black's replies --
## between them those two things are what make a depth-3 search affordable in
## GDScript.

const POOL := "chess"
const TT_CAP := 120000

const KING := 1
const QUEEN := 2
const ROOK := 3
const BISHOP := 4
const KNIGHT := 5
const PAWN := 6

const WHITE := 1
const BLACK := -1

const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ALL8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const KNIGHT_JUMPS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1),
]

var _w := 5
var _h := 5
var _b := PackedInt32Array()
var _wk := -1
var _bk := -1
## Transposition table for the forced-mate search, cleared per candidate.
var _tt := {}


# ============================================================ generation ===
func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var plan := _plan(rng, diff)
	_w = int(plan["w"])
	_h = int(plan["h"])
	var depth := int(plan["depth"])
	var budget := 400 if depth < 3 else 90

	var made := _attempt(rng, plan, depth, budget)
	if made.is_empty() and depth == 3:
		# Depth 3 is the expensive band; rather than burn the frame budget, fall
		# back to a mate in 2 on the same board size.
		made = _attempt(rng, plan, 2, 200)
	return made


func _attempt(rng: RandomNumberGenerator, plan: Dictionary, depth: int, budget: int) -> Dictionary:
	for attempt in budget:
		if not _random_position(rng, plan, depth):
			continue
		# White is to move, so Black must not already be in check, and White's
		# own king must not be hanging either.
		if _in_check(BLACK) or _in_check(WHITE):
			continue
		# A king with room to run is almost never mated. Counting its free
		# squares costs eight attack tests and throws out the great majority of
		# candidates before the forced-mate search ever starts.
		if _escape_count() > (2 if depth < 3 else 4):
			continue

		# Cheapest test first: if a shorter mate exists this is not a mate in N,
		# and the shallower search costs a fraction of the deep one.
		_tt.clear()
		if depth > 1 and not _winning_moves(depth - 1).is_empty():
			continue
		var wins := _winning_moves(depth)
		if wins.size() != 1:
			continue

		var board := _b.duplicate()
		var key := PackedStringArray()
		for i in board.size():
			key.append(str(board[i]))
		return {
			"pool": POOL,
			"hash": ("c%dx%d:%s>%d" % [_w, _h, ",".join(key), depth]).hash(),
			"time": 35.0 + 27.0 * float(depth - 1) + 0.5 * float(_w * _h),
			"title": "Chess Mate",
			"hint": "White to move  ·  mate in %d" % depth,
			"w": _w,
			"h": _h,
			"board": board,
			"depth": depth,
			"solution": wins[0],
		}
	return {}


## Board size, mate depth and material for a difficulty.
func _plan(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var w := 4
	var depth := 1
	var attackers := 1
	var blockers := 0

	if diff < 0.16:
		w = 3 if rng.randf() < 0.35 else 4
		depth = 1
		attackers = 1
	elif diff < 0.34:
		w = 4 if rng.randf() < 0.6 else 5
		depth = 1
		attackers = 2
	elif diff < 0.52:
		w = 5
		depth = 2
		attackers = 1 if rng.randf() < 0.4 else 2
	elif diff < 0.72:
		w = 5 if rng.randf() < 0.75 else 6
		depth = 2
		attackers = 2
		blockers = 1 if rng.randf() < 0.5 else 0
	else:
		# Mate in three is the expensive band: keep the board small and the
		# material light, or the search tree stops fitting in a frame budget.
		w = 4
		depth = 3
		attackers = 1 if rng.randf() < 0.55 else 2
	return {"w": w, "h": w, "depth": depth, "attackers": attackers, "blockers": blockers}


## Fills `_b` with a random legal-looking position. Returns false when the draw
## did not work out (kings adjacent, no room left).
func _random_position(rng: RandomNumberGenerator, plan: Dictionary, depth: int) -> bool:
	var n := _w * _h
	_b.resize(n)
	_b.fill(0)

	var free: Array[int] = []
	for i in n:
		free.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := free[i]
		free[i] = free[j]
		free[j] = t

	# Deep mates need the defending king cornered, otherwise almost no random
	# position has a forced mate at all and the search is spent proving that.
	var bk := -1
	if depth >= 3:
		for i in range(free.size() - 1, -1, -1):
			if _on_edge(free[i]):
				bk = free[i]
				free.remove_at(i)
				break
	if bk < 0:
		bk = free.pop_back()
	_b[bk] = -KING
	_bk = bk

	var wk := -1
	for i in range(free.size() - 1, -1, -1):
		if not _adjacent(free[i], bk):
			wk = free[i]
			free.remove_at(i)
			break
	if wk < 0:
		return false
	_b[wk] = KING
	_wk = wk

	var heavy: Array[int] = [QUEEN, ROOK, ROOK, BISHOP, KNIGHT]
	for k in int(plan["attackers"]):
		if free.is_empty():
			return false
		var piece: int = heavy[rng.randi_range(0, heavy.size() - 1)]
		if depth >= 3 and k == 0:
			piece = QUEEN if rng.randf() < 0.6 else ROOK
		elif _w >= 5 and rng.randf() < 0.18:
			piece = PAWN
		var sq := _pick_square(rng, free, bk, depth >= 3)
		if piece == PAWN and _row(sq) <= 1:
			piece = ROOK
		_b[sq] = piece

	for k in int(plan["blockers"]):
		if free.is_empty():
			break
		var piece: int = [ROOK, BISHOP, KNIGHT, PAWN][rng.randi_range(0, 3)]
		var sq: int = free.pop_back()
		if piece == PAWN and _row(sq) >= _h - 2:
			piece = KNIGHT
		_b[sq] = -piece
	return true


## Takes a free square, preferring ones near the black king when `close` is set.
func _pick_square(rng: RandomNumberGenerator, free: Array[int], bk: int, close: bool) -> int:
	if close:
		for i in range(free.size() - 1, -1, -1):
			if _distance(free[i], bk) <= 3:
				var sq := free[i]
				free.remove_at(i)
				return sq
	return free.pop_back()


## Squares next to the black king that are free and not covered by White.
## Deliberately approximate (it ignores x-rays through the king); it only has to
## be a filter, the forced-mate search decides.
func _escape_count() -> int:
	if _bk < 0:
		return 9
	var r := _row(_bk)
	var c := _col(_bk)
	var n := 0
	for d in ALL8:
		var nr := r + d.y
		var nc := c + d.x
		if not _inside(nr, nc):
			continue
		var target := _at(nr, nc)
		if _b[target] < 0:
			continue
		if not _attacked(target, WHITE):
			n += 1
	return n


func _on_edge(idx: int) -> bool:
	var r := _row(idx)
	var c := _col(idx)
	return r == 0 or c == 0 or r == _h - 1 or c == _w - 1


func _distance(a: int, b: int) -> int:
	return maxi(absi(_row(a) - _row(b)), absi(_col(a) - _col(b)))


# ================================================================= board ===
func _row(idx: int) -> int:
	return idx / _w


func _col(idx: int) -> int:
	return idx % _w


func _adjacent(a: int, b: int) -> bool:
	return absi(_row(a) - _row(b)) <= 1 and absi(_col(a) - _col(b)) <= 1


func _at(r: int, c: int) -> int:
	return r * _w + c


func _inside(r: int, c: int) -> bool:
	return r >= 0 and r < _h and c >= 0 and c < _w


static func move_from(m: int) -> int:
	return m & 0xff


static func move_to(m: int) -> int:
	return (m >> 8) & 0xff


static func move_promo(m: int) -> int:
	return (m >> 16) & 0xff


static func make_move(from_sq: int, to_sq: int, promo := 0) -> int:
	return from_sq | (to_sq << 8) | (promo << 16)


## Applies `m` to `_b` and returns what is needed to take it back.
## King squares are tracked here rather than searched for: `_in_check` runs tens
## of thousands of times per position and a board scan each time dominated.
func _make(m: int) -> Vector2i:
	var from_sq := m & 0xff
	var to_sq := (m >> 8) & 0xff
	var moved := _b[from_sq]
	var captured := _b[to_sq]
	_b[from_sq] = 0
	_b[to_sq] = (QUEEN * signi(moved)) if ((m >> 16) & 0xff) != 0 else moved

	if moved == KING:
		_wk = to_sq
	elif moved == -KING:
		_bk = to_sq
	if captured == KING:
		_wk = -1
	elif captured == -KING:
		_bk = -1
	return Vector2i(moved, captured)


func _unmake(m: int, undo: Vector2i) -> void:
	var from_sq := m & 0xff
	var to_sq := (m >> 8) & 0xff
	_b[from_sq] = undo.x
	_b[to_sq] = undo.y
	if undo.x == KING:
		_wk = from_sq
	elif undo.x == -KING:
		_bk = from_sq
	if undo.y == KING:
		_wk = to_sq
	elif undo.y == -KING:
		_bk = to_sq


# =============================================================== movegen ===
func _pseudo_moves(side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for sq in _b.size():
		var piece := _b[sq]
		if piece == 0 or signi(piece) != side:
			continue
		match absi(piece):
			KING:
				_step_moves(sq, side, ALL8, out)
			QUEEN:
				_ray_moves(sq, side, ALL8, out)
			ROOK:
				_ray_moves(sq, side, ORTHO, out)
			BISHOP:
				_ray_moves(sq, side, DIAG, out)
			KNIGHT:
				_step_moves(sq, side, KNIGHT_JUMPS, out)
			PAWN:
				_pawn_moves(sq, side, out)
	return out


func _step_moves(sq: int, side: int, offsets: Array[Vector2i], out: PackedInt32Array) -> void:
	var r := _row(sq)
	var c := _col(sq)
	for d in offsets:
		var nr := r + d.y
		var nc := c + d.x
		if not _inside(nr, nc):
			continue
		var target := _at(nr, nc)
		if _b[target] != 0 and signi(_b[target]) == side:
			continue
		out.append(sq | (target << 8))


func _ray_moves(sq: int, side: int, dirs: Array[Vector2i], out: PackedInt32Array) -> void:
	var r := _row(sq)
	var c := _col(sq)
	for d in dirs:
		var nr := r
		var nc := c
		while true:
			nr += d.y
			nc += d.x
			if not _inside(nr, nc):
				break
			var target := _at(nr, nc)
			if _b[target] == 0:
				out.append(sq | (target << 8))
				continue
			if signi(_b[target]) != side:
				out.append(sq | (target << 8))
			break


func _pawn_moves(sq: int, side: int, out: PackedInt32Array) -> void:
	var r := _row(sq)
	var c := _col(sq)
	# White marches towards row 0, Black towards the last row.
	var dr := -1 if side == WHITE else 1
	var last := 0 if side == WHITE else _h - 1
	var nr := r + dr
	if not _inside(nr, c):
		return

	if _b[_at(nr, c)] == 0:
		out.append(make_move(sq, _at(nr, c), 1 if nr == last else 0))
	for dc in [-1, 1]:
		var nc: int = c + int(dc)
		if not _inside(nr, nc):
			continue
		var target := _at(nr, nc)
		if _b[target] != 0 and signi(_b[target]) != side:
			out.append(make_move(sq, target, 1 if nr == last else 0))


func _king_square(side: int) -> int:
	return _wk if side == WHITE else _bk


func _rescan_kings() -> void:
	_wk = -1
	_bk = -1
	for i in _b.size():
		if _b[i] == KING:
			_wk = i
		elif _b[i] == -KING:
			_bk = i


## Is `sq` attacked by `side`?
func _attacked(sq: int, side: int) -> bool:
	var r := _row(sq)
	var c := _col(sq)

	for d in KNIGHT_JUMPS:
		if _inside(r + d.y, c + d.x) and _b[_at(r + d.y, c + d.x)] == KNIGHT * side:
			return true
	for d in ALL8:
		if _inside(r + d.y, c + d.x) and _b[_at(r + d.y, c + d.x)] == KING * side:
			return true

	for d in ORTHO:
		if _ray_hits(r, c, d, side, ROOK):
			return true
	for d in DIAG:
		if _ray_hits(r, c, d, side, BISHOP):
			return true

	# A pawn of `side` attacks the square it could capture on.
	var pawn_dr := -1 if side == WHITE else 1
	for dc in [-1, 1]:
		var pr := r - pawn_dr
		var pc: int = c + int(dc)
		if _inside(pr, pc) and _b[_at(pr, pc)] == PAWN * side:
			return true
	return false


## Walks one ray; true when the first piece met is a queen or `slider` of `side`.
func _ray_hits(r: int, c: int, d: Vector2i, side: int, slider: int) -> bool:
	var nr := r
	var nc := c
	while true:
		nr += d.y
		nc += d.x
		if not _inside(nr, nc):
			return false
		var piece := _b[_at(nr, nc)]
		if piece == 0:
			continue
		if signi(piece) != side:
			return false
		var kind := absi(piece)
		return kind == QUEEN or kind == slider
	return false


func _in_check(side: int) -> bool:
	var king := _king_square(side)
	if king < 0:
		return false
	return _attacked(king, -side)


func _legal_moves(side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in _pseudo_moves(side):
		var undo := _make(m)
		if not _in_check(side):
			out.append(m)
		_unmake(m, undo)
	return out


## Cheap "does this side have any legal move at all" test.
func _has_legal_move(side: int) -> bool:
	for m in _pseudo_moves(side):
		var undo := _make(m)
		var ok := not _in_check(side)
		_unmake(m, undo)
		if ok:
			return true
	return false


# ================================================================ search ===
## Every White move that forces mate in at most `depth` White moves.
func _winning_moves(depth: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in _legal_moves(WHITE):
		var undo := _make(m)
		var wins := _forces_mate(depth)
		_unmake(m, undo)
		if wins:
			out.append(m)
	return out


## Black is to move. True when Black is lost within `depth` further White moves.
func _forces_mate(depth: int) -> bool:
	# Asking about check first is the whole optimisation: at the last ply, the
	# overwhelming majority of positions are not check and cost one test.
	var checked := _in_check(BLACK)
	if depth <= 1:
		return checked and not _has_legal_move(BLACK)

	# Move orders transpose constantly on a board this small, so remembering
	# results is worth far more than the cost of hashing the board.
	var key := _position_key(depth)
	var cached: Variant = _tt.get(key)
	if cached != null:
		return bool(cached)
	var verdict := _forces_mate_uncached(depth, checked)
	if _tt.size() < TT_CAP:
		_tt[key] = verdict
	return verdict


func _position_key(depth: int) -> int:
	var key := depth
	for v in _b:
		key = key * 31 + v + 7
	return key


func _forces_mate_uncached(depth: int, checked: bool) -> bool:
	var replies := _legal_moves(BLACK)
	if replies.is_empty():
		# Mate counts, stalemate does not.
		return checked

	for reply in replies:
		var undo := _make(reply)
		var refuted := true
		for m in _legal_moves(WHITE):
			var undo2 := _make(m)
			var wins := _forces_mate(depth - 1)
			_unmake(m, undo2)
			if wins:
				refuted = false
				break
		_unmake(reply, undo)
		if refuted:
			return false
	return true


# ======================================================== public helpers ===
func _load(board: PackedInt32Array, w: int, h: int) -> void:
	_w = w
	_h = h
	_b = board.duplicate()
	_rescan_kings()


func winning_moves(board: PackedInt32Array, w: int, h: int, depth: int) -> PackedInt32Array:
	_load(board, w, h)
	return _winning_moves(depth)


func moves_for(board: PackedInt32Array, w: int, h: int, side: int) -> PackedInt32Array:
	_load(board, w, h)
	return _legal_moves(side)


func mated(board: PackedInt32Array, w: int, h: int, side: int) -> bool:
	_load(board, w, h)
	return _in_check(side) and not _has_legal_move(side)


func stalemated(board: PackedInt32Array, w: int, h: int, side: int) -> bool:
	_load(board, w, h)
	return not _in_check(side) and not _has_legal_move(side)


func in_check(board: PackedInt32Array, w: int, h: int, side: int) -> bool:
	_load(board, w, h)
	return _in_check(side)


## Applies a move to a copy of `board` and returns the result.
func play(board: PackedInt32Array, w: int, h: int, m: int) -> PackedInt32Array:
	_load(board, w, h)
	_make(m)
	return _b.duplicate()


## Black's reply: any legal move, preferring one that survives longest.
func best_defence(board: PackedInt32Array, w: int, h: int, depth: int) -> int:
	_load(board, w, h)
	var replies := _legal_moves(BLACK)
	if replies.is_empty():
		return -1
	var best := replies[0]
	for reply in replies:
		var undo := _make(reply)
		var survives := depth <= 1
		if not survives:
			survives = _winning_moves(depth - 1).is_empty()
		_unmake(reply, undo)
		if survives:
			best = reply
			break
	return best
