extends RefCounted
## Mini sudoku generator: 4x4 (2x2 boxes) at low difficulty, 6x6 (3x2 boxes)
## above it. Every puzzle is dug out of a random full solution and is guaranteed
## to have exactly one solution.

const POOL := "sudoku"


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var size := 4 if diff < 0.42 else 6
	var bw := 2
	var bh := 2
	if size == 6:
		bw = 3
		bh = 2

	var solution := _full_grid(rng, size, bw, bh)
	if solution.is_empty():
		return {}

	var blanks_target: int
	if size == 4:
		blanks_target = int(round(lerpf(6.0, 11.0, clampf(diff / 0.42, 0.0, 1.0))))
	else:
		blanks_target = int(round(lerpf(12.0, 20.0, clampf((diff - 0.42) / 0.58, 0.0, 1.0))))

	var given := _dig(rng, solution, size, bw, bh, blanks_target)
	var blanks := 0
	for v in given:
		if v == 0:
			blanks += 1

	# Time grows with the amount of work, never shrinks as difficulty rises.
	var time_limit := (32.0 + 2.2 * blanks) if size == 4 else (60.0 + 2.6 * blanks)

	return {
		"pool": POOL,
		"hash": _fingerprint(size, given),
		"time": time_limit,
		"title": "Mini Sudoku",
		"hint": "Every row, column and box holds 1-%d" % size,
		"size": size,
		"box_w": bw,
		"box_h": bh,
		"given": given,
		"solution": solution,
		"blanks": blanks,
	}


func _fingerprint(size: int, given: PackedInt32Array) -> int:
	var parts := PackedStringArray()
	for v in given:
		parts.append(str(v))
	return ("s%d:%s" % [size, ",".join(parts)]).hash()


# ------------------------------------------------------------- full grid ---
func _full_grid(rng: RandomNumberGenerator, size: int, bw: int, bh: int) -> PackedInt32Array:
	var g := PackedInt32Array()
	g.resize(size * size)
	g.fill(0)
	if _fill(rng, g, 0, size, bw, bh):
		return g
	return PackedInt32Array()


func _fill(rng: RandomNumberGenerator, g: PackedInt32Array, idx: int, size: int, bw: int, bh: int) -> bool:
	if idx >= size * size:
		return true
	var cands: Array[int] = []
	for v in range(1, size + 1):
		if _allowed(g, idx, v, size, bw, bh):
			cands.append(v)
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	for v in cands:
		g[idx] = v
		if _fill(rng, g, idx + 1, size, bw, bh):
			return true
	g[idx] = 0
	return false


func _allowed(g: PackedInt32Array, idx: int, v: int, size: int, bw: int, bh: int) -> bool:
	var row := idx / size
	var col := idx % size
	for c in size:
		if g[row * size + c] == v:
			return false
	for r in size:
		if g[r * size + col] == v:
			return false
	var br := (row / bh) * bh
	var bc := (col / bw) * bw
	for r in range(br, br + bh):
		for c in range(bc, bc + bw):
			if g[r * size + c] == v:
				return false
	return true


# ------------------------------------------------------------------ dig ---
func _dig(rng: RandomNumberGenerator, solution: PackedInt32Array, size: int,
		bw: int, bh: int, blanks_target: int) -> PackedInt32Array:
	var g := solution.duplicate()
	var order: Array[int] = []
	for i in size * size:
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp

	var removed := 0
	for idx in order:
		if removed >= blanks_target:
			break
		var keep := g[idx]
		g[idx] = 0
		if _count_solutions(g, size, bw, bh, 2) == 1:
			removed += 1
		else:
			g[idx] = keep
	return g


func _count_solutions(g: PackedInt32Array, size: int, bw: int, bh: int, limit: int) -> int:
	var work := g.duplicate()
	return _count_rec(work, size, bw, bh, limit)


func _count_rec(g: PackedInt32Array, size: int, bw: int, bh: int, limit: int) -> int:
	# Pick the empty cell with the fewest candidates to keep the search shallow.
	var best := -1
	var best_cands: Array[int] = []
	for idx in size * size:
		if g[idx] != 0:
			continue
		var cands: Array[int] = []
		for v in range(1, size + 1):
			if _allowed(g, idx, v, size, bw, bh):
				cands.append(v)
		if cands.is_empty():
			return 0
		if best == -1 or cands.size() < best_cands.size():
			best = idx
			best_cands = cands
			if cands.size() == 1:
				break
	if best == -1:
		return 1

	var found := 0
	for v in best_cands:
		g[best] = v
		found += _count_rec(g, size, bw, bh, limit - found)
		g[best] = 0
		if found >= limit:
			break
	return found
