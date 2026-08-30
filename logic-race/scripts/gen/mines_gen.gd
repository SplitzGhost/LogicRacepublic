extends RefCounted
## Small minesweeper boards (5x5 up to 8x8).
##
## The first cell is always opened for the player and always sits in a zero
## region, and every board is run through a logic solver (single-cell rules,
## the subset rule and the global mine count) before it is handed out -- so a
## board that costs a life was always solvable without guessing.

const POOL := "mines"

const UNKNOWN := -1
const SAFE := 0
const MINE := 1


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var w := clampi(int(round(5.0 + diff * 3.4)), 5, 8)
	var h := w
	var density := lerpf(0.13, 0.215, diff)
	var mine_count := clampi(int(round(float(w * h) * density)), 3, w * h - 10)

	# The opening flood must not hand the player most of the board.
	var min_remaining := maxi(4, int(round(float(w * h - mine_count) * 0.22)))

	var fallback: Dictionary = {}
	for attempt in 90:
		var board := _layout(rng, w, h, mine_count)
		if board.is_empty():
			continue
		if fallback.is_empty():
			fallback = board
		if int(board["remaining"]) < min_remaining:
			continue
		fallback = board
		if _solvable(w, h, board["mines"], board["opened"], mine_count):
			break

	if fallback.is_empty():
		return {}

	var mines: PackedByteArray = fallback["mines"]
	var opened: PackedByteArray = fallback["opened"]
	var remaining: int = fallback["remaining"]

	var key := PackedStringArray()
	for i in w * h:
		if mines[i] == 1:
			key.append(str(i))
	return {
		"pool": POOL,
		"hash": ("m:%dx%d|%s|%d" % [w, h, ",".join(key), int(fallback["start"])]).hash(),
		"time": 30.0 + 1.15 * float(remaining),
		"title": "Minesweeper",
		"hint": "Clear every safe cell  ·  %d mines" % mine_count,
		"w": w,
		"h": h,
		"mine_count": mine_count,
		"mines": mines,
		"opened": opened,
		"start": int(fallback["start"]),
		"remaining": remaining,
	}


# ---------------------------------------------------------------- layout ---
func _layout(rng: RandomNumberGenerator, w: int, h: int, mine_count: int) -> Dictionary:
	var n := w * h
	var mines := PackedByteArray()
	mines.resize(n)
	mines.fill(0)

	var order: Array[int] = []
	for i in n:
		order.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := order[i]
		order[i] = order[j]
		order[j] = t
	for k in mine_count:
		mines[order[k]] = 1

	# Opening move: a cell with no adjacent mines, so the player gets a region.
	var zeros: Array[int] = []
	for i in n:
		if mines[i] == 0 and _adj_count(w, h, mines, i) == 0:
			zeros.append(i)
	if zeros.is_empty():
		return {}
	var start: int = zeros[rng.randi_range(0, zeros.size() - 1)]

	var opened := PackedByteArray()
	opened.resize(n)
	opened.fill(0)
	_flood(w, h, mines, opened, start)

	var remaining := 0
	for i in n:
		if mines[i] == 0 and opened[i] == 0:
			remaining += 1
	return {"mines": mines, "opened": opened, "start": start, "remaining": remaining}


func neighbours(w: int, h: int, idx: int) -> Array[int]:
	var out: Array[int] = []
	var x := idx % w
	var y := int(idx / w)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + int(dx)
			var ny: int = y + int(dy)
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				out.append(ny * w + nx)
	return out


func _adj_count(w: int, h: int, mines: PackedByteArray, idx: int) -> int:
	var c := 0
	for nb in neighbours(w, h, idx):
		if mines[nb] == 1:
			c += 1
	return c


func _flood(w: int, h: int, mines: PackedByteArray, opened: PackedByteArray, start: int) -> void:
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if opened[idx] == 1 or mines[idx] == 1:
			continue
		opened[idx] = 1
		if _adj_count(w, h, mines, idx) == 0:
			for nb in neighbours(w, h, idx):
				if opened[nb] == 0 and mines[nb] == 0:
					stack.append(nb)


# ---------------------------------------------------------------- solver ---
## Deterministic logic solver. Returns true when every safe cell can be proven
## safe without ever guessing.
func _solvable(w: int, h: int, mines: PackedByteArray, opened: PackedByteArray, mine_count: int) -> bool:
	var n := w * h
	var known := PackedInt32Array()
	known.resize(n)
	known.fill(UNKNOWN)
	for i in n:
		if opened[i] == 1:
			known[i] = SAFE

	var progress := true
	while progress:
		progress = false

		# Constraints seen by the player: every revealed number and its unknowns.
		var cons: Array = []
		for i in n:
			if known[i] != SAFE:
				continue
			var unknown: Array[int] = []
			var flagged := 0
			for nb in neighbours(w, h, i):
				if known[nb] == UNKNOWN:
					unknown.append(nb)
				elif known[nb] == MINE:
					flagged += 1
			if unknown.is_empty():
				continue
			var need := _adj_count(w, h, mines, i) - flagged
			if need == 0:
				for c in unknown:
					known[c] = SAFE
				progress = true
			elif need == unknown.size():
				for c in unknown:
					known[c] = MINE
				progress = true
			else:
				unknown.sort()
				cons.append({"cells": unknown, "need": need})
		if progress:
			continue

		# Subset rule: A subset of B => (B \ A) contains need_b - need_a mines.
		for a: Dictionary in cons:
			for b: Dictionary in cons:
				if a == b:
					continue
				var ca: Array = a["cells"]
				var cb: Array = b["cells"]
				if ca.size() >= cb.size():
					continue
				var contained := true
				for c in ca:
					if not cb.has(c):
						contained = false
						break
				if not contained:
					continue
				var diff_cells: Array = []
				for c in cb:
					if not ca.has(c):
						diff_cells.append(c)
				var need: int = int(b["need"]) - int(a["need"])
				if need == 0:
					for c in diff_cells:
						if known[c] == UNKNOWN:
							known[c] = SAFE
							progress = true
				elif need == diff_cells.size():
					for c in diff_cells:
						if known[c] == UNKNOWN:
							known[c] = MINE
							progress = true
			if progress:
				break
		if progress:
			continue

		# Global count: all remaining unknowns are mines, or none of them are.
		var unknown_all: Array[int] = []
		var found_mines := 0
		for i in n:
			if known[i] == UNKNOWN:
				unknown_all.append(i)
			elif known[i] == MINE:
				found_mines += 1
		if unknown_all.is_empty():
			break
		var left := mine_count - found_mines
		if left == 0:
			for c in unknown_all:
				known[c] = SAFE
			progress = true
		elif left == unknown_all.size():
			for c in unknown_all:
				known[c] = MINE
			progress = true

	for i in n:
		if mines[i] == 0 and known[i] != SAFE:
			return false
	return true
