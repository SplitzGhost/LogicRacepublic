extends RefCounted
## Water Sort: tubes of stacked colour units. Pour the top run of one tube onto a
## tube whose top is the same colour (or into an empty one) until every tube
## holds a single colour.
##
## Deals are random, then *proved* with a depth-first search over canonical
## states before they are handed out -- an unsolvable deal never reaches the
## player.

const POOL := "water"
const CAPACITY := 4
## Ceiling on the search so an awkward deal cannot stall a frame.
const NODE_CAP := 45000
const DEPTH_CAP := 90


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var colors := clampi(3 + int(floor(diff * 4.6)), 3, 7)
	var empties := 2
	if diff >= 0.78 and rng.randf() < 0.5:
		empties = 1

	for attempt in 80:
		var tubes := _deal(rng, colors, empties)
		# No free wins: nothing may already be sorted.
		if _uniform_count(tubes) > 0:
			continue
		if not _solvable(tubes):
			continue

		return {
			"pool": POOL,
			"hash": ("v:%s" % _key(tubes)).hash(),
			"time": 38.0 + 10.0 * float(colors),
			"title": "Water Sort",
			"hint": "Sort every colour into its own tube",
			"tubes": tubes,
			"capacity": CAPACITY,
			"colors": colors,
			"empties": empties,
		}
	return {}


## Shuffles all colour units and deals them into the filled tubes.
func _deal(rng: RandomNumberGenerator, colors: int, empties: int) -> Array:
	var bag: Array[int] = []
	for c in colors:
		for k in CAPACITY:
			bag.append(c)
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := bag[i]
		bag[i] = bag[j]
		bag[j] = t

	var tubes: Array = []
	for c in colors:
		var tube: Array[int] = []
		for k in CAPACITY:
			tube.append(bag[c * CAPACITY + k])
		tubes.append(tube)
	for e in empties:
		tubes.append([] as Array[int])
	return tubes


# ================================================================== rules ===
static func top_color(tube: Array) -> int:
	return -1 if tube.is_empty() else int(tube[tube.size() - 1])


## How many units of the top colour sit on top of `tube`.
static func top_run(tube: Array) -> int:
	if tube.is_empty():
		return 0
	var colour := int(tube[tube.size() - 1])
	var n := 0
	for i in range(tube.size() - 1, -1, -1):
		if int(tube[i]) != colour:
			break
		n += 1
	return n


static func can_pour(tubes: Array, from_i: int, to_i: int, cap: int) -> bool:
	if from_i == to_i:
		return false
	var src: Array = tubes[from_i]
	var dst: Array = tubes[to_i]
	if src.is_empty() or dst.size() >= cap:
		return false
	# Pointless: a full single-colour tube has nowhere better to go.
	if dst.is_empty():
		return top_run(src) < src.size()
	return top_color(dst) == top_color(src)


## Returns a fresh state with the pour applied.
static func pour(tubes: Array, from_i: int, to_i: int, cap: int) -> Array:
	var out: Array = []
	for t: Array in tubes:
		out.append(t.duplicate())
	var src: Array = out[from_i]
	var dst: Array = out[to_i]
	var moving: int = mini(top_run(src), cap - dst.size())
	for i in moving:
		dst.append(src.pop_back())
	return out


static func is_solved(tubes: Array, cap: int) -> bool:
	for t: Array in tubes:
		if t.is_empty():
			continue
		if t.size() != cap:
			return false
		for v in t:
			if int(v) != int(t[0]):
				return false
	return true


func _uniform_count(tubes: Array) -> int:
	var n := 0
	for t: Array in tubes:
		if t.size() < 2:
			continue
		var same := true
		for v in t:
			if int(v) != int(t[0]):
				same = false
				break
		if same:
			n += 1
	return n


# ================================================================= solver ===
## Canonical key: tubes are interchangeable, so sorting their contents collapses
## every permutation of the same position onto one state.
func _key(tubes: Array) -> String:
	var parts := PackedStringArray()
	for t: Array in tubes:
		var s := ""
		for v in t:
			s += char(65 + int(v))
		parts.append(s)
	parts.sort()
	return "|".join(parts)


func _solvable(tubes: Array) -> bool:
	var visited := {}
	return _dfs(tubes, visited, 0)


func _dfs(tubes: Array, visited: Dictionary, depth: int) -> bool:
	if is_solved(tubes, CAPACITY):
		return true
	if depth >= DEPTH_CAP or visited.size() >= NODE_CAP:
		return false
	var key := _key(tubes)
	if visited.has(key):
		return false
	visited[key] = true

	# Try the pours that actually make progress first: completing a tube, then
	# stacking onto the same colour, and only then spending an empty tube.
	var moves: Array = []
	for from_i in tubes.size():
		for to_i in tubes.size():
			if not can_pour(tubes, from_i, to_i, CAPACITY):
				continue
			var dst: Array = tubes[to_i]
			var run: int = top_run(tubes[from_i])
			var score := 0
			if not dst.is_empty():
				score = 2
				if dst.size() + run == CAPACITY:
					score = 3
			moves.append({"from": from_i, "to": to_i, "score": score})
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) > int(b["score"]))

	for m: Dictionary in moves:
		if _dfs(pour(tubes, int(m["from"]), int(m["to"]), CAPACITY), visited, depth + 1):
			return true
	return false


## The actual move list that sorts `tubes`, as (from, to) pairs. Empty when the
## search finds nothing inside its budget.
func find_solution(tubes: Array) -> Array:
	var path: Array = []
	var visited := {}
	if _search_path(tubes, visited, path, 0):
		return path
	return []


func _search_path(tubes: Array, visited: Dictionary, path: Array, depth: int) -> bool:
	if is_solved(tubes, CAPACITY):
		return true
	if depth >= DEPTH_CAP or visited.size() >= NODE_CAP:
		return false
	var key := _key(tubes)
	if visited.has(key):
		return false
	visited[key] = true

	for from_i in tubes.size():
		for to_i in tubes.size():
			if not can_pour(tubes, from_i, to_i, CAPACITY):
				continue
			path.append(Vector2i(from_i, to_i))
			if _search_path(pour(tubes, from_i, to_i, CAPACITY), visited, path, depth + 1):
				return true
			path.pop_back()
	return false


## Public: is there any legal pour left?
static func has_move(tubes: Array, cap: int) -> bool:
	for from_i in tubes.size():
		for to_i in tubes.size():
			if can_pour(tubes, from_i, to_i, cap):
				return true
	return false
