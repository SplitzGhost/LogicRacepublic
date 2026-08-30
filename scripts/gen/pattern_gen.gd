extends RefCounted
## Pattern Snap: five elements of a sequence plus a blank. Pick the sixth.
## Two flavours -- number sequences (arithmetic, geometric, Fibonacci-like,
## second-order, interleaved, digit-sum ...) and shape sequences (rotation,
## shape cycles, fill alternation, interleaving).

const POOL := "pattern"
const SHOWN := 5

## Shapes whose rotation is actually visible.
const ROT_SHAPES := [2, 5, 6, 7]
const ALL_SHAPES := [0, 1, 2, 3, 4, 5, 6, 7]

## rule id -> difficulty at which it unlocks.
const NUM_RULES := {
	"add": 0.00, "mul": 0.12, "alt": 0.18, "add2": 0.26, "fib": 0.34,
	"square": 0.40, "affine": 0.50, "weave": 0.56, "altop": 0.64,
	"poly": 0.70, "dbl": 0.76, "digits": 0.84,
}
const SHAPE_RULES := {
	"s_rot": 0.00, "s_cycle": 0.08, "s_both": 0.30, "s_fill": 0.46, "s_weave": 0.62,
}


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var shape_mode := rng.randf() < 0.35
	var out: Dictionary = _shape_sequence(rng, diff) if shape_mode else _number_sequence(rng, diff)
	if out.is_empty():
		return {}
	out["pool"] = POOL
	out["title"] = "Pattern Snap"
	out["hint"] = "Which element comes next?"
	out["time"] = 18.0 + 14.0 * diff
	return out


func _pick_rule(rng: RandomNumberGenerator, table: Dictionary, diff: float) -> String:
	var eligible: Array[String] = []
	for k: String in table:
		if float(table[k]) <= diff + 0.001:
			eligible.append(k)
	if eligible.is_empty():
		eligible.append(String(table.keys()[0]))
	# Bias hard: drop rules that are far below the current difficulty.
	var recent: Array[String] = []
	for k in eligible:
		if float(table[k]) >= diff - 0.40:
			recent.append(k)
	var pool: Array[String] = recent if recent.size() >= 2 else eligible
	return pool[rng.randi_range(0, pool.size() - 1)]


# --------------------------------------------------------------- numbers ---
func _number_sequence(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var rule := _pick_rule(rng, NUM_RULES, diff)
	var seq: Array[int] = _build_numbers(rng, rule)
	if seq.size() != SHOWN + 1:
		return {}
	for v in seq:
		if absi(v) > 999999:
			return {}
	# Reject degenerate sequences: too few distinct values reads as "no pattern".
	var uniq := {}
	for v in seq:
		uniq[v] = true
	if uniq.size() < 3:
		return {}

	var shown: Array[int] = []
	for i in SHOWN:
		shown.append(seq[i])
	var answer: int = seq[SHOWN]
	var options := _number_options(rng, shown, answer)
	return {
		"kind": "number",
		"rule": rule,
		"shown": shown,
		"answer": answer,
		"options": options,
		"answer_index": options.find(answer),
		"hash": ("p:%s|%s|%d" % [rule, ",".join(_to_str(shown)), answer]).hash(),
	}


func _to_str(a: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v in a:
		out.append(str(v))
	return out


func _build_numbers(rng: RandomNumberGenerator, rule: String) -> Array[int]:
	var s: Array[int] = []
	var n := SHOWN + 1
	match rule:
		"add":
			var a := rng.randi_range(2, 40)
			var d := rng.randi_range(2, 13) * (1 if rng.randf() < 0.75 else -1)
			for i in n:
				s.append(a + i * d)
		"mul":
			var a := rng.randi_range(1, 6)
			var r := rng.randi_range(2, 4)
			var v := a
			for i in n:
				s.append(v)
				v *= r
		"alt":
			var v := rng.randi_range(8, 45)
			var up := rng.randi_range(4, 16)
			var down := rng.randi_range(1, 11)
			for i in n:
				s.append(v)
				v += up if i % 2 == 0 else -down
		"add2":
			var v := rng.randi_range(1, 14)
			var d := rng.randi_range(1, 7)
			var e := rng.randi_range(1, 6)
			for i in n:
				s.append(v)
				v += d + i * e
		"fib":
			var x := rng.randi_range(1, 9)
			var y := rng.randi_range(2, 12)
			for i in n:
				s.append(x)
				var z := x + y
				x = y
				y = z
		"square":
			var k := rng.randi_range(1, 5)
			var c := rng.randi_range(-4, 9)
			for i in n:
				s.append((i + k) * (i + k) + c)
		"affine":
			var v := rng.randi_range(1, 7)
			var r := rng.randi_range(2, 3)
			var c := rng.randi_range(1, 9) * (1 if rng.randf() < 0.7 else -1)
			for i in n:
				s.append(v)
				v = v * r + c
		"weave":
			var a := rng.randi_range(2, 25)
			var da := rng.randi_range(2, 12)
			var b := rng.randi_range(30, 80)
			var db := -rng.randi_range(2, 11)
			for i in n:
				if i % 2 == 0:
					s.append(a + int(i / 2) * da)
				else:
					s.append(b + int(i / 2) * db)
		"altop":
			var v := rng.randi_range(2, 9)
			var r := rng.randi_range(2, 3)
			var c := rng.randi_range(2, 12)
			for i in n:
				s.append(v)
				v = v * r if i % 2 == 0 else v + c
		"poly":
			if rng.randf() < 0.5:
				var c := rng.randi_range(0, 6)
				for i in n:
					var k := i + 1
					s.append(k * k * k + c)
			else:
				var c2 := rng.randi_range(0, 9)
				var k0 := rng.randi_range(1, 4)
				for i in n:
					var k := i + k0
					s.append(int(k * (k + 1) / 2) + c2)
		"dbl":
			var v := rng.randi_range(5, 30)
			var c := rng.randi_range(1, 9)
			for i in n:
				s.append(v)
				v = v * 2 - c
		"digits":
			var v := rng.randi_range(11, 60)
			for i in n:
				s.append(v)
				v += _digit_sum(v)
	return s


func _digit_sum(v: int) -> int:
	var x := absi(v)
	var total := 0
	while x > 0:
		total += x % 10
		x = int(x / 10)
	return total


func _number_options(rng: RandomNumberGenerator, shown: Array[int], answer: int) -> Array:
	var last: int = shown[SHOWN - 1]
	var prev: int = shown[SHOWN - 2]
	var d := last - prev
	# Plausible wrong answers: the same rule mis-applied by one step.
	var seeds: Array[int] = [
		last + d, answer + d, answer - d, answer + 1, answer - 1,
		last * 2, answer + 10, answer - 10, answer + maxi(2, int(absi(d) / 2)),
	]
	seeds = _shuffle_int(rng, seeds)
	var opts: Array[int] = [answer]
	for v in seeds:
		if opts.size() >= 4:
			break
		if not opts.has(v) and absi(v) <= 9999999:
			opts.append(v)
	var pad := 2
	while opts.size() < 4:
		if not opts.has(answer + pad):
			opts.append(answer + pad)
		pad += 1
	opts = _shuffle_int(rng, opts)
	var out: Array = []
	for v in opts:
		out.append(v)
	return out


func _shuffle_int(rng: RandomNumberGenerator, src: Array[int]) -> Array[int]:
	var a: Array[int] = src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = a[i]
		a[i] = a[j]
		a[j] = t
	return a


# ---------------------------------------------------------------- shapes ---
func _shape_sequence(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var rule := _pick_rule(rng, SHAPE_RULES, diff)
	var seq: Array = _build_shapes(rng, rule)
	if seq.size() != SHOWN + 1:
		return {}
	var shown: Array = []
	for i in SHOWN:
		shown.append(seq[i])
	var answer: Dictionary = seq[SHOWN]
	var options := _shape_options(rng, answer)
	var idx := -1
	for i in options.size():
		if _same(options[i], answer):
			idx = i
			break
	var key := PackedStringArray()
	for e: Dictionary in seq:
		key.append("%d/%d/%d" % [e["shape"], e["rot"], 1 if e["fill"] else 0])
	return {
		"kind": "shape",
		"rule": rule,
		"shown": shown,
		"answer": answer,
		"options": options,
		"answer_index": idx,
		"hash": ("q:%s|%s" % [rule, ",".join(key)]).hash(),
	}


func _el(shape: int, rot: int, fill: bool) -> Dictionary:
	return {"shape": shape, "rot": posmod(rot, 4), "fill": fill}


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a["shape"] == b["shape"] and a["rot"] == b["rot"] and a["fill"] == b["fill"]


func _shuffled(rng: RandomNumberGenerator, src: Array) -> Array:
	var a := src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func _build_shapes(rng: RandomNumberGenerator, rule: String) -> Array:
	var out: Array = []
	var n := SHOWN + 1
	match rule:
		"s_rot":
			var sh: int = ROT_SHAPES[rng.randi_range(0, ROT_SHAPES.size() - 1)]
			var step: int = [1, 3][rng.randi_range(0, 1)]
			var fill := rng.randf() < 0.6
			for i in n:
				out.append(_el(sh, i * step, fill))
		"s_cycle":
			var cyc: Array = _shuffled(rng, ALL_SHAPES).slice(0, rng.randi_range(3, 4))
			var step: int = 1 if cyc.size() == 3 else [1, 3][rng.randi_range(0, 1)]
			var fill := rng.randf() < 0.6
			for i in n:
				out.append(_el(int(cyc[(i * step) % cyc.size()]), 0, fill))
		"s_both":
			var cyc: Array = _shuffled(rng, ROT_SHAPES).slice(0, rng.randi_range(2, 3))
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			var fill := rng.randf() < 0.6
			for i in n:
				out.append(_el(int(cyc[i % cyc.size()]), i * rstep, fill))
		"s_fill":
			var cyc: Array = _shuffled(rng, ALL_SHAPES).slice(0, 3)
			for i in n:
				out.append(_el(int(cyc[i % cyc.size()]), 0, i % 2 == 0))
		"s_weave":
			var a: Array = _shuffled(rng, ROT_SHAPES).slice(0, 2)
			var b: Array = _shuffled(rng, ALL_SHAPES).slice(0, 2)
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			var other: int = int(b[0]) if int(b[0]) != int(a[0]) else int(b[1])
			for i in n:
				if i % 2 == 0:
					out.append(_el(int(a[0]), int(i / 2) * rstep, true))
				else:
					out.append(_el(other, 0, false))
	return out


func _shape_options(rng: RandomNumberGenerator, answer: Dictionary) -> Array:
	var opts: Array = [answer]
	var tries: Array = []
	for r in 4:
		if r != int(answer["rot"]):
			tries.append(_el(int(answer["shape"]), r, bool(answer["fill"])))
	tries.append(_el(int(answer["shape"]), int(answer["rot"]), not bool(answer["fill"])))
	for sh in ALL_SHAPES:
		if int(sh) != int(answer["shape"]):
			tries.append(_el(int(sh), int(answer["rot"]), bool(answer["fill"])))
	tries = _shuffled(rng, tries)
	for t: Dictionary in tries:
		if opts.size() >= 4:
			break
		var dup := false
		for o: Dictionary in opts:
			if _same(o, t):
				dup = true
				break
		if not dup:
			opts.append(t)
	return _shuffled(rng, opts)
