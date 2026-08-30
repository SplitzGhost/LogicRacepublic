extends RefCounted
## Mental arithmetic: one expression, four answers.
## Eight difficulty bands, from two-digit sums up to mixed multi-operator terms
## with precedence. Distractors are the mistakes the expression invites --
## off-by-one factors, ignored precedence, sign slips.

const POOL := "math"


func generate(rng: RandomNumberGenerator, diff: float) -> Dictionary:
	var band := clampi(int(floor(diff * 8.0)), 0, 7)
	var made := _make(rng, band)
	if made.is_empty():
		return {}

	var answer: int = made["answer"]
	var near: Array = made.get("near", [])
	var options := _options(rng, answer, near)

	return {
		"pool": POOL,
		"hash": ("k:%s=%d" % [made["text"], answer]).hash(),
		"time": 11.0 + 9.0 * diff,
		"title": "Mental Math",
		"hint": "Pick the correct result",
		"text": made["text"],
		"answer": answer,
		"options": options,
		"answer_index": options.find(answer),
	}


func _make(rng: RandomNumberGenerator, band: int) -> Dictionary:
	match band:
		0:
			var a := rng.randi_range(12, 89)
			var b := rng.randi_range(7, 79)
			if rng.randf() < 0.5:
				return {"text": "%d + %d" % [a, b], "answer": a + b, "near": [a + b + 10, a + b - 10]}
			var hi := maxi(a, b)
			var lo := mini(a, b)
			return {"text": "%d − %d" % [hi, lo], "answer": hi - lo, "near": [lo - hi, hi - lo + 10]}
		1:
			if rng.randf() < 0.6:
				var a := rng.randi_range(3, 9)
				var b := rng.randi_range(4, 19)
				return {"text": "%d × %d" % [a, b], "answer": a * b, "near": [a * b + a, a * b - a, a * b + b]}
			var q := rng.randi_range(3, 12)
			var d := rng.randi_range(3, 9)
			return {"text": "%d ÷ %d" % [q * d, d], "answer": q, "near": [q + 1, q - 1, d]}
		2:
			if rng.randf() < 0.5:
				var a := rng.randi_range(21, 88)
				var b := rng.randi_range(11, 60)
				var c := rng.randi_range(9, 45)
				return {"text": "%d + %d − %d" % [a, b, c], "answer": a + b - c, "near": [a + b + c, a - b + c]}
			var x := rng.randi_range(6, 12)
			var y := rng.randi_range(6, 12)
			return {"text": "%d × %d" % [x, y], "answer": x * y, "near": [x * y + x, x * y - y]}
		3:
			if rng.randf() < 0.5:
				var a := rng.randi_range(4, 13)
				var b := rng.randi_range(4, 12)
				var c := rng.randi_range(7, 49)
				return {"text": "%d × %d + %d" % [a, b, c], "answer": a * b + c, "near": [a * (b + c), a * b - c]}
			var x := rng.randi_range(7, 24)
			var y := rng.randi_range(6, 19)
			var k := rng.randi_range(3, 8)
			return {"text": "(%d + %d) × %d" % [x, y, k], "answer": (x + y) * k, "near": [x + y * k, (x + y) * k - k]}
		4:
			var pick := rng.randi_range(0, 2)
			if pick == 0:
				var p: int = [5, 10, 15, 20, 25, 40, 50, 75][rng.randi_range(0, 7)]
				var n := rng.randi_range(2, 24) * 20
				return {"text": "%d%% of %d" % [p, n], "answer": int(p * n / 100), "near": [int(p * n / 10), int(p * n / 1000)]}
			if pick == 1:
				var s := rng.randi_range(11, 25)
				return {"text": "%d²" % s, "answer": s * s, "near": [s * s + s, s * s - s, s * 2]}
			var a := rng.randi_range(6, 19)
			var b := rng.randi_range(6, 14)
			return {"text": "%d × %d" % [a, b], "answer": a * b, "near": [a * b + b, a * b - a]}
		5:
			if rng.randf() < 0.5:
				var a := rng.randi_range(5, 15)
				var b := rng.randi_range(4, 12)
				var c := rng.randi_range(3, 11)
				var d := rng.randi_range(3, 9)
				return {"text": "%d × %d − %d × %d" % [a, b, c, d],
						"answer": a * b - c * d, "near": [(a * b - c) * d, a * b + c * d]}
			var x := rng.randi_range(120, 899)
			var y := rng.randi_range(80, 640)
			return {"text": "%d − %d" % [x, y], "answer": x - y, "near": [y - x, x - y + 100, x - y - 10]}
		6:
			if rng.randf() < 0.5:
				var a := rng.randi_range(12, 29)
				var b := rng.randi_range(11, 24)
				return {"text": "%d × %d" % [a, b], "answer": a * b, "near": [a * b + a, a * b - b, a * b + 100]}
			var m := rng.randi_range(9, 26)
			var n := rng.randi_range(2, 8)
			return {"text": "%d² − %d²" % [m, n], "answer": m * m - n * n, "near": [(m - n) * (m - n), m * m + n * n]}
		_:
			var pick := rng.randi_range(0, 2)
			if pick == 0:
				var a := rng.randi_range(6, 16)
				var b := rng.randi_range(5, 13)
				var c := rng.randi_range(4, 12)
				var d := rng.randi_range(3, 9)
				var e := rng.randi_range(11, 60)
				return {"text": "%d × %d + %d × %d − %d" % [a, b, c, d, e],
						"answer": a * b + c * d - e, "near": [a * b + c * (d - e), a * b + c * d + e]}
			if pick == 1:
				var x := rng.randi_range(13, 39)
				var y := rng.randi_range(9, 28)
				var k := rng.randi_range(3, 9)
				var s := rng.randi_range(20, 120)
				return {"text": "(%d + %d) × %d − %d" % [x, y, k, s],
						"answer": (x + y) * k - s, "near": [x + y * k - s, (x + y) * (k - 1) - s]}
			var f := rng.randi_range(6, 18)
			var g := rng.randi_range(4, 14)
			var h := rng.randi_range(2, 9)
			return {"text": "%d × %d ÷ %d" % [f * h, g, h], "answer": f * g, "near": [f * g * h, int(f * g / h) if h != 0 else f]}
	return {}


func _options(rng: RandomNumberGenerator, answer: int, near: Array) -> Array:
	var seeds: Array[int] = []
	for v: Variant in near:
		seeds.append(int(v))
	seeds.append_array([
		answer + 1, answer - 1, answer + 2, answer - 2,
		answer + 10, answer - 10, _swap_digits(answer),
		answer + maxi(3, int(absi(answer) / 10)),
		answer - maxi(3, int(absi(answer) / 10)),
	])
	for i in range(seeds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := seeds[i]
		seeds[i] = seeds[j]
		seeds[j] = t

	var opts: Array[int] = [answer]
	for v in seeds:
		if opts.size() >= 4:
			break
		if v != answer and not opts.has(v) and absi(v) < 10000000:
			opts.append(v)
	var pad := 3
	while opts.size() < 4:
		if not opts.has(answer + pad):
			opts.append(answer + pad)
		pad += 1

	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := opts[i]
		opts[i] = opts[j]
		opts[j] = t
	var out: Array = []
	for v in opts:
		out.append(v)
	return out


func _swap_digits(v: int) -> int:
	var s := str(absi(v))
	if s.length() < 2:
		return v + 5
	var swapped := int(s.substr(1, 1) + s.substr(0, 1) + s.substr(2))
	return -swapped if v < 0 else swapped
