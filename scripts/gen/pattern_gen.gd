extends RefCounted
## Pattern Snap: five elements of a sequence plus a blank. Pick the sixth.
##
## Three flavours, weighted towards the visual ones:
##   shape  (40%) -- rotation, shape cycles, fill, colour, repeat count, weaves
##   letter (30%) -- alphabet steps, growing steps, both-ends, pairs, squares
##   number (30%) -- arithmetic through to tribonacci and digit reversal
##
## A shape element carries five attributes (glyph, rotation, filled, repeat
## count, accent colour); a rule advances one or more of them, which is what
## makes the harder visual bands genuinely harder rather than just busier.

const POOL := "pattern"
const SHOWN := 5
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

## Shapes whose rotation is actually visible.
const ROT_SHAPES := [2, 5, 6, 7]
const ALL_SHAPES := [0, 1, 2, 3, 4, 5, 6, 7]

## rule id -> difficulty at which it unlocks.
const NUM_RULES := {
	"add": 0.00, "mul": 0.12, "alt": 0.18, "add2": 0.26, "fib": 0.34,
	"square": 0.40, "affine": 0.50, "weave": 0.54, "sqdiff": 0.58,
	"primes": 0.62, "altop": 0.66, "poly": 0.70, "dbl": 0.76,
	"digits": 0.82, "tri3": 0.88, "revadd": 0.94,
}
const LETTER_RULES := {
	"l_step": 0.00, "l_back": 0.10, "l_pair": 0.20, "l_grow": 0.30,
	"l_alt": 0.40, "l_ends": 0.50, "l_weave": 0.62, "l_fib": 0.74,
	"l_square": 0.84, "l_double": 0.92,
}
const SHAPE_RULES := {
	"s_rot": 0.00, "s_cycle": 0.06, "s_count": 0.16, "s_fill": 0.26,
	"s_both": 0.36, "s_accent": 0.46, "s_count_up": 0.54, "s_rot_fill": 0.62,
	"s_weave": 0.72, "s_count_cycle": 0.80, "s_triple": 0.90,
}


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var roll := rng.randf()
	var out: Dictionary
	if roll < 0.40:
		out = _shape_sequence(rng, diff)
	elif roll < 0.70:
		out = _letter_sequence(rng, diff)
	else:
		out = _number_sequence(rng, diff)
	if out.is_empty():
		return {}
	out["pool"] = POOL
	out["title"] = "Pattern Snap"
	out["hint"] = "Which element comes next?"
	out["time"] = 18.0 + 15.0 * diff
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
		if float(table[k]) >= diff - 0.35:
			recent.append(k)
	var pool: Array[String] = recent if recent.size() >= 2 else eligible
	return pool[rng.randi_range(0, pool.size() - 1)]


func _shuffle_int(rng: RandomNumberGenerator, src: Array[int]) -> Array[int]:
	var a: Array[int] = src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func _shuffled(rng: RandomNumberGenerator, src: Array) -> Array:
	var a := src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func _to_str(a: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v in a:
		out.append(str(v))
	return out


# ================================================================ numbers ===
func _number_sequence(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var rule := _pick_rule(rng, NUM_RULES, diff)
	var seq: Array[int] = _build_numbers(rng, rule)
	if seq.size() != SHOWN + 1:
		return {}
	for v in seq:
		if absi(v) > 999999:
			return {}
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
			var v := rng.randi_range(1, 6)
			var r := rng.randi_range(2, 4)
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
		"sqdiff":
			var k := rng.randi_range(2, 6)
			for i in n:
				var m := i + k
				s.append(m * m - m)
		"primes":
			var primes := [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61]
			var start := rng.randi_range(0, primes.size() - n - 1)
			for i in n:
				s.append(int(primes[start + i]))
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
		"tri3":
			var a := rng.randi_range(1, 5)
			var b := rng.randi_range(1, 6)
			var c := rng.randi_range(2, 8)
			for i in n:
				s.append(a)
				var d := a + b + c
				a = b
				b = c
				c = d
		"revadd":
			var v := rng.randi_range(12, 48)
			for i in n:
				s.append(v)
				v += _reversed(v)
	return s


func _digit_sum(v: int) -> int:
	var x := absi(v)
	var total := 0
	while x > 0:
		total += x % 10
		x = int(x / 10)
	return total


func _reversed(v: int) -> int:
	var x := absi(v)
	var out := 0
	while x > 0:
		out = out * 10 + x % 10
		x = int(x / 10)
	return out


func _number_options(rng: RandomNumberGenerator, shown: Array[int], answer: int) -> Array:
	var last: int = shown[SHOWN - 1]
	var prev: int = shown[SHOWN - 2]
	var d := last - prev
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


# ================================================================ letters ===
func _letter_sequence(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var rule := _pick_rule(rng, LETTER_RULES, diff)
	var seq: Array[String] = _build_letters(rng, rule)
	if seq.size() != SHOWN + 1:
		return {}
	var uniq := {}
	for v in seq:
		uniq[v] = true
	if uniq.size() < 4:
		return {}

	var shown: Array[String] = []
	for i in SHOWN:
		shown.append(seq[i])
	var answer: String = seq[SHOWN]
	var options := _letter_options(rng, answer, shown)
	return {
		"kind": "letter",
		"rule": rule,
		"shown": shown,
		"answer": answer,
		"options": options,
		"answer_index": options.find(answer),
		"hash": ("l:%s|%s|%s" % [rule, ",".join(shown), answer]).hash(),
	}


func _letter(position: int) -> String:
	return ALPHABET[posmod(position, 26)]


func _build_letters(rng: RandomNumberGenerator, rule: String) -> Array[String]:
	var s: Array[String] = []
	var n := SHOWN + 1
	match rule:
		"l_step":
			var p := rng.randi_range(0, 25)
			var step := rng.randi_range(1, 5)
			for i in n:
				s.append(_letter(p + i * step))
		"l_back":
			var p := rng.randi_range(0, 25)
			var step := rng.randi_range(1, 5)
			for i in n:
				s.append(_letter(p - i * step))
		"l_pair":
			var p := rng.randi_range(0, 25)
			var step := rng.randi_range(2, 4)
			for i in n:
				s.append(_letter(p + i * step) + _letter(p + i * step + 1))
		"l_grow":
			var p := rng.randi_range(0, 25)
			var step := rng.randi_range(1, 3)
			for i in n:
				s.append(_letter(p))
				p += step
				step += 1
		"l_alt":
			var p := rng.randi_range(4, 21)
			var up := rng.randi_range(3, 7)
			var down := rng.randi_range(1, 4)
			for i in n:
				s.append(_letter(p))
				p += up if i % 2 == 0 else -down
		"l_ends":
			var p := rng.randi_range(0, 4)
			for i in n:
				if i % 2 == 0:
					s.append(_letter(p + int(i / 2)))
				else:
					s.append(_letter(25 - p - int(i / 2)))
		"l_weave":
			var a := rng.randi_range(0, 12)
			var da := rng.randi_range(2, 4)
			var b := rng.randi_range(13, 25)
			var db := -rng.randi_range(2, 4)
			for i in n:
				if i % 2 == 0:
					s.append(_letter(a + int(i / 2) * da))
				else:
					s.append(_letter(b + int(i / 2) * db))
		"l_fib":
			var x := rng.randi_range(0, 3)
			var y := rng.randi_range(1, 4)
			for i in n:
				s.append(_letter(x))
				var z := x + y
				x = y
				y = z
		"l_square":
			var k := rng.randi_range(1, 3)
			for i in n:
				var m := i + k
				s.append(_letter(m * m))
		"l_double":
			var p := rng.randi_range(1, 6)
			for i in n:
				s.append(_letter(p))
				p *= 2
	return s


func _letter_options(rng: RandomNumberGenerator, answer: String, shown: Array[String]) -> Array:
	var opts: Array[String] = [answer]
	var seeds: Array[String] = []
	# Neighbours of the answer, plus the letters the sequence has already used.
	for offset in [1, -1, 2, -2, 3, -3, 5, -5]:
		var mutated := ""
		for i in answer.length():
			mutated += _letter(ALPHABET.find(answer[i]) + int(offset))
		seeds.append(mutated)
	for v in shown:
		seeds.append(v)

	seeds = _shuffled(rng, seeds)
	for v: String in seeds:
		if opts.size() >= 4:
			break
		if not opts.has(v):
			opts.append(v)
	var pad := 7
	while opts.size() < 4:
		opts.append(_letter(ALPHABET.find(answer[0]) + pad) + answer.substr(1))
		pad += 1

	var out: Array = []
	for v in _shuffled(rng, opts):
		out.append(v)
	return out


# ================================================================= shapes ===
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
		key.append(_key_of(e))
	return {
		"kind": "shape",
		"rule": rule,
		"shown": shown,
		"answer": answer,
		"options": options,
		"answer_index": idx,
		"hash": ("q:%s|%s" % [rule, ",".join(key)]).hash(),
	}


func _el(shape: int, rot: int, fill: bool, count := 1, accent := false) -> Dictionary:
	return {
		"shape": shape,
		"rot": posmod(rot, 4),
		"fill": fill,
		"count": clampi(count, 1, 3),
		"accent": accent,
	}


func _key_of(e: Dictionary) -> String:
	return "%d/%d/%d/%d/%d" % [
		int(e["shape"]), int(e["rot"]), 1 if e["fill"] else 0,
		int(e["count"]), 1 if e["accent"] else 0,
	]


func _same(a: Dictionary, b: Dictionary) -> bool:
	return _key_of(a) == _key_of(b)


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
		"s_count":
			var sh: int = ALL_SHAPES[rng.randi_range(0, ALL_SHAPES.size() - 1)]
			var pattern: Array = _shuffled(rng, [1, 2, 3])
			var fill := rng.randf() < 0.6
			for i in n:
				out.append(_el(sh, 0, fill, int(pattern[i % 3])))
		"s_fill":
			var cyc: Array = _shuffled(rng, ALL_SHAPES).slice(0, 3)
			for i in n:
				out.append(_el(int(cyc[i % cyc.size()]), 0, i % 2 == 0))
		"s_both":
			var cyc: Array = _shuffled(rng, ROT_SHAPES).slice(0, rng.randi_range(2, 3))
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			var fill := rng.randf() < 0.6
			for i in n:
				out.append(_el(int(cyc[i % cyc.size()]), i * rstep, fill))
		"s_accent":
			var cyc: Array = _shuffled(rng, ALL_SHAPES).slice(0, 2)
			var period := rng.randi_range(2, 3)
			for i in n:
				out.append(_el(int(cyc[i % cyc.size()]), 0, true, 1, i % period == 0))
		"s_count_up":
			var cyc: Array = _shuffled(rng, ALL_SHAPES).slice(0, 3)
			for i in n:
				out.append(_el(int(cyc[i % 3]), 0, true, (i % 3) + 1))
		"s_rot_fill":
			var sh: int = ROT_SHAPES[rng.randi_range(0, ROT_SHAPES.size() - 1)]
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			for i in n:
				out.append(_el(sh, i * rstep, i % 2 == 0))
		"s_weave":
			var a: Array = _shuffled(rng, ROT_SHAPES).slice(0, 2)
			var b: Array = _shuffled(rng, ALL_SHAPES).slice(0, 2)
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			var other: int = int(b[0]) if int(b[0]) != int(a[0]) else int(b[1])
			for i in n:
				if i % 2 == 0:
					out.append(_el(int(a[0]), int(i / 2) * rstep, true))
				else:
					out.append(_el(other, 0, false, 2))
		"s_count_cycle":
			var sh: int = ROT_SHAPES[rng.randi_range(0, ROT_SHAPES.size() - 1)]
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			for i in n:
				out.append(_el(sh, i * rstep, true, (i % 3) + 1))
		"s_triple":
			var cyc: Array = _shuffled(rng, ROT_SHAPES).slice(0, 2)
			var rstep: int = [1, 3][rng.randi_range(0, 1)]
			for i in n:
				out.append(_el(int(cyc[i % 2]), i * rstep, i % 2 == 0, (i % 3) + 1,
						i % 3 == 2))
	return out


func _shape_options(rng: RandomNumberGenerator, answer: Dictionary) -> Array:
	var opts: Array = [answer]
	var tries: Array = []
	# One attribute wrong at a time -- close enough to be tempting.
	for r in 4:
		if r != int(answer["rot"]):
			tries.append(_el(int(answer["shape"]), r, bool(answer["fill"]),
					int(answer["count"]), bool(answer["accent"])))
	tries.append(_el(int(answer["shape"]), int(answer["rot"]), not bool(answer["fill"]),
			int(answer["count"]), bool(answer["accent"])))
	for c in [1, 2, 3]:
		if int(c) != int(answer["count"]):
			tries.append(_el(int(answer["shape"]), int(answer["rot"]), bool(answer["fill"]),
					int(c), bool(answer["accent"])))
	tries.append(_el(int(answer["shape"]), int(answer["rot"]), bool(answer["fill"]),
			int(answer["count"]), not bool(answer["accent"])))
	for sh in ALL_SHAPES:
		if int(sh) != int(answer["shape"]):
			tries.append(_el(int(sh), int(answer["rot"]), bool(answer["fill"]),
					int(answer["count"]), bool(answer["accent"])))

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
