extends RefCounted
## Target Number (24-game style): combine four numbers with + - * / so that
## exactly one value is left and it equals the target.
##
## Everything is evaluated with exact rationals (Vector2i = numerator/denominator)
## so that solutions requiring intermediate fractions are found reliably and the
## board never drifts because of floating point.

const POOL := "target"
const ALT_TARGETS := [12, 18, 20, 21, 27, 30, 36, 42, 48]
const MEMO_CAP := 30000
## Highest solution count any difficulty window distinguishes; counting stops there.
const COUNT_CAP := 33

## Analysing one hand costs a few thousand rational operations, and the search
## re-draws the same multiset often, so results are cached for the lifetime of
## the generator (one instance lives in PuzzleFactory for the whole session).
var _memo: Dictionary = {}


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var hi := int(round(lerpf(9.0, 13.0, diff)))
	var best: Dictionary = {}
	var strict := diff >= 0.82

	for attempt in 260:
		# After a while, stop insisting on the ideal solution-count window.
		var relaxed := attempt > 190
		var nums: Array[int] = []
		for i in 4:
			nums.append(rng.randi_range(1, hi))
		var target := 24
		if diff > 0.35 and rng.randf() < 0.25:
			target = int(ALT_TARGETS[rng.randi_range(0, ALT_TARGETS.size() - 1)])

		var info := _analyse(nums, target, false)
		var count: int = info["count"]
		if count == 0:
			continue
		if best.is_empty():
			best = {"numbers": nums, "target": target, "count": count}
		if relaxed:
			break
		if not _fits(count, diff):
			continue
		# The very hardest band should mostly force a fractional detour.
		if strict:
			info = _analyse(nums, target, true)
			if int(info["int_count"]) > 0 and rng.randf() < 0.7:
				continue
		best = {"numbers": nums, "target": target, "count": count,
				"frac_only": int(info["int_count"]) == 0}
		break

	if best.is_empty():
		return {}

	var nums: Array[int] = best["numbers"]
	var target: int = best["target"]
	var sorted_nums := nums.duplicate()
	sorted_nums.sort()
	return {
		"pool": POOL,
		"hash": ("t:%s>%d" % [",".join(_to_str(sorted_nums)), target]).hash(),
		"time": 40.0 + 20.0 * diff,
		"title": "Target Number",
		"hint": "Use all four numbers exactly once",
		"numbers": nums,
		"target": target,
		"solutions": int(best["count"]),
		"frac_only": bool(best.get("frac_only", false)),
	}


## Solution count for one hand, plus (on demand) the count of solutions that
## never leave the integers. `int_count` is -1 when it was not needed.
func _analyse(nums: Array[int], target: int, want_int_count: bool) -> Dictionary:
	var sorted_nums: Array = nums.duplicate()
	sorted_nums.sort()
	var key := "%s>%d" % [",".join(_to_str(sorted_nums)), target]

	var info: Dictionary = _memo.get(key, {})
	if info.is_empty():
		if _memo.size() > MEMO_CAP:
			_memo.clear()
		var vals: Array = []
		for v in sorted_nums:
			vals.append(Vector2i(int(v), 1))
		info = {"count": _count(vals, Vector2i(target, 1), false, COUNT_CAP), "int_count": -1}
		_memo[key] = info

	if want_int_count and int(info["int_count"]) < 0 and int(info["count"]) > 0:
		var vals2: Array = []
		for v in sorted_nums:
			vals2.append(Vector2i(int(v), 1))
		info["int_count"] = _count(vals2, Vector2i(target, 1), true, 1)
	return info


func _to_str(a: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v in a:
		out.append(str(v))
	return out


## Fewer distinct solution paths == harder to spot.
func _fits(count: int, diff: float) -> bool:
	if diff < 0.20:
		return count >= 20
	if diff < 0.40:
		return count >= 10 and count <= 32
	if diff < 0.60:
		return count >= 5 and count <= 15
	if diff < 0.80:
		return count >= 2 and count <= 8
	return count >= 1 and count <= 4


# ------------------------------------------------------------- rationals ---
static func gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := a % b
		a = b
		b = t
	return maxi(a, 1)


static func rat(n: int, d: int) -> Vector2i:
	if d < 0:
		n = -n
		d = -d
	var g := gcd(n, d)
	return Vector2i(n / g, d / g)


static func apply_op(a: Vector2i, b: Vector2i, op: int) -> Variant:
	# op: 0 = a+b, 1 = a-b, 2 = a*b, 3 = a/b
	match op:
		0:
			return rat(a.x * b.y + b.x * a.y, a.y * b.y)
		1:
			return rat(a.x * b.y - b.x * a.y, a.y * b.y)
		2:
			return rat(a.x * b.x, a.y * b.y)
		3:
			if b.x == 0:
				return null
			return rat(a.x * b.y, a.y * b.x)
	return null


static func rat_to_string(v: Vector2i) -> String:
	if v.y == 1:
		return str(v.x)
	return "%d/%d" % [v.x, v.y]


# ---------------------------------------------------------------- search ---
func _combine(a: Vector2i, b: Vector2i, int_only: bool) -> Array:
	var out: Array = []
	_push(out, rat(a.x * b.y + b.x * a.y, a.y * b.y), int_only)
	_push(out, rat(a.x * b.x, a.y * b.y), int_only)
	_push(out, rat(a.x * b.y - b.x * a.y, a.y * b.y), int_only)
	_push(out, rat(b.x * a.y - a.x * b.y, a.y * b.y), int_only)
	if b.x != 0:
		_push(out, rat(a.x * b.y, a.y * b.x), int_only)
	if a.x != 0:
		_push(out, rat(b.x * a.y, b.y * a.x), int_only)
	return out


func _push(out: Array, v: Vector2i, int_only: bool) -> void:
	if int_only and v.y != 1:
		return
	if absi(v.x) > 100000 or v.y > 100000:
		return
	out.append(v)


## Number of ways two values combine straight into the target. Inlined because
## this is the innermost loop of the search by two orders of magnitude.
func _pair_hits(a: Vector2i, b: Vector2i, target: Vector2i, int_only: bool) -> int:
	var hits := 0
	if _hit(rat(a.x * b.y + b.x * a.y, a.y * b.y), target, int_only):
		hits += 1
	if _hit(rat(a.x * b.x, a.y * b.y), target, int_only):
		hits += 1
	if _hit(rat(a.x * b.y - b.x * a.y, a.y * b.y), target, int_only):
		hits += 1
	if _hit(rat(b.x * a.y - a.x * b.y, a.y * b.y), target, int_only):
		hits += 1
	if b.x != 0 and _hit(rat(a.x * b.y, a.y * b.x), target, int_only):
		hits += 1
	if a.x != 0 and _hit(rat(b.x * a.y, b.y * a.x), target, int_only):
		hits += 1
	return hits


func _hit(v: Vector2i, target: Vector2i, int_only: bool) -> bool:
	if int_only and v.y != 1:
		return false
	return v == target


## Counts reduction paths that hit the target, stopping once `limit` is reached.
## The difficulty windows only distinguish small counts, so the cap turns a full
## tree walk into an early exit for the many hands that have dozens of solutions.
func _count(vals: Array, target: Vector2i, int_only: bool, limit: int) -> int:
	if vals.size() == 1:
		return 1 if vals[0] == target else 0
	if vals.size() == 2:
		return _pair_hits(vals[0], vals[1], target, int_only)
	var total := 0
	for i in vals.size():
		for j in range(i + 1, vals.size()):
			var rest: Array = []
			for k in vals.size():
				if k != i and k != j:
					rest.append(vals[k])
			for r: Vector2i in _combine(vals[i], vals[j], int_only):
				rest.append(r)
				total += _count(rest, target, int_only, limit - total)
				rest.pop_back()
				if total >= limit:
					return total
	return total


## Public helper so the view can tell the player whether a state is still alive.
func reachable(vals: Array, target: Vector2i) -> bool:
	return _count(vals, target, false, 1) > 0
