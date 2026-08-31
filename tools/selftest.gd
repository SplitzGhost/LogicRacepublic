extends SceneTree
## Headless validation of every procedural generator.
##
##   godot --headless --script res://tools/selftest.gd
##
## Checks correctness (unique sudoku solutions, guess-free minesweeper boards,
## reachable targets, proven chess mates, independently re-evaluated arithmetic),
## option sanity, solvable water-sort deals and generation cost across the whole
## difficulty range.

const SudokuGen := preload("res://scripts/gen/sudoku_gen.gd")
const PatternGen := preload("res://scripts/gen/pattern_gen.gd")
const TargetGen := preload("res://scripts/gen/target_gen.gd")
const MinesGen := preload("res://scripts/gen/mines_gen.gd")
const MathGen := preload("res://scripts/gen/math_gen.gd")
const ChessGen := preload("res://scripts/gen/chess_gen.gd")
const WaterGen := preload("res://scripts/gen/water_gen.gd")

const SAMPLES := 24
const CHESS_SAMPLES := 6
const DIFFS := [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]

var failures := 0
var checked := 0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260830




	_run("sudoku", SudokuGen.new(), rng, _check_sudoku, SAMPLES)
	_run("pattern", PatternGen.new(), rng, _check_pattern, SAMPLES)
	_run("target", TargetGen.new(), rng, _check_target, SAMPLES)
	_run("mines", MinesGen.new(), rng, _check_mines, SAMPLES)
	_run("math", MathGen.new(), rng, _check_math, SAMPLES)
	_run("water", WaterGen.new(), rng, _check_water, SAMPLES)
	_run("chess", ChessGen.new(), rng, _check_chess, CHESS_SAMPLES)

	_uniqueness_probe(rng)

	print("")
	if failures == 0:
		print("PASS  %d puzzles checked, 0 failures" % checked)
	else:
		print("FAIL  %d puzzles checked, %d failures" % [checked, failures])
	quit(1 if failures > 0 else 0)


func _fail(what: String) -> void:
	failures += 1
	print("   !! ", what)


func _run(name: String, gen: RefCounted, rng: RandomNumberGenerator, checker: Callable,
		samples: int) -> void:
	print("── %s ─────────────────────────────" % name)
	for diff: float in DIFFS:
		var t0 := Time.get_ticks_usec()
		var empties := 0
		var times: Array[float] = []
		for i in samples:
			var d: Dictionary = gen.call("generate", rng, diff)
			if d.is_empty():
				empties += 1
				continue
			checked += 1
			times.append(float(d["time"]))
			var err: String = checker.call(d, gen)
			if err != "":
				_fail("diff=%.2f  %s" % [diff, err])
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var tmin := 999.0
		var tmax := 0.0
		for t in times:
			tmin = minf(tmin, t)
			tmax = maxf(tmax, t)
		print("   diff %.2f  %6.1f ms/puzzle  time %.0f-%.0fs  empty=%d"
				% [diff, ms / float(samples), tmin, tmax, empties])
		if empties > samples / 3:
			_fail("diff=%.2f produced too many empty results" % diff)


# ------------------------------------------------------------------ checks ---
func _check_common(d: Dictionary) -> String:
	if not d.has("hash") or not d.has("time"):
		return "missing hash/time"
	if float(d["time"]) <= 3.0:
		return "implausible time limit %s" % d["time"]
	return ""


func _check_choices(d: Dictionary) -> String:
	var opts: Array = d["options"]
	if opts.size() != 4:
		return "expected 4 options, got %d" % opts.size()
	var idx := int(d["answer_index"])
	if idx < 0 or idx >= 4:
		return "answer_index out of range (%d)" % idx
	if str(opts[idx]) != str(d["answer"]):
		return "answer_index points at the wrong option"
	for i in 4:
		for j in range(i + 1, 4):
			if str(opts[i]) == str(opts[j]):
				return "duplicate options: %s" % str(opts[i])
	return ""


func _check_sudoku(d: Dictionary, gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	var size := int(d["size"])
	var given: PackedInt32Array = d["given"]
	var solution: PackedInt32Array = d["solution"]
	if given.size() != size * size or solution.size() != size * size:
		return "grid size mismatch"
	for i in given.size():
		if given[i] != 0 and given[i] != solution[i]:
			return "given cell contradicts the solution"
	var n: int = gen.call("_count_solutions", given, size, int(d["box_w"]), int(d["box_h"]), 3)
	if n != 1:
		return "puzzle has %d solutions (expected exactly 1)" % n
	if int(d["blanks"]) < 4:
		return "too few blanks (%d)" % int(d["blanks"])
	return ""


func _check_pattern(d: Dictionary, _gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	if (d["shown"] as Array).size() != 5:
		return "expected 5 shown elements"
	var kind := String(d["kind"])
	if not ["number", "letter", "shape"].has(kind):
		return "unknown element kind '%s'" % kind
	if kind == "shape":
		for e2: Dictionary in (d["shown"] as Array):
			if int(e2.get("count", 0)) < 1 or int(e2.get("count", 0)) > 3:
				return "shape repeat count out of range"
	return _check_choices(d)


func _check_target(d: Dictionary, gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	var nums: Array = d["numbers"]
	if nums.size() != 4:
		return "expected 4 numbers"
	var vals: Array = []
	for v in nums:
		vals.append(Vector2i(int(v), 1))
	if not gen.call("reachable", vals, Vector2i(int(d["target"]), 1)):
		return "target %d unreachable from %s" % [int(d["target"]), str(nums)]
	if int(d["solutions"]) <= 0:
		return "solution count is zero"
	return ""


func _check_mines(d: Dictionary, gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	var w := int(d["w"])
	var h := int(d["h"])
	var mines: PackedByteArray = d["mines"]
	var opened: PackedByteArray = d["opened"]
	var count := 0
	for i in w * h:
		if mines[i] == 1:
			count += 1
			if opened[i] == 1:
				return "a mine is pre-opened"
	if count != int(d["mine_count"]):
		return "mine count mismatch (%d vs %d)" % [count, int(d["mine_count"])]
	if opened[int(d["start"])] != 1:
		return "start cell is not opened"
	var open_n := 0
	for i in w * h:
		if opened[i] == 1:
			open_n += 1
	if open_n < 3:
		return "opening region too small (%d cells)" % open_n
	if int(d["remaining"]) <= 0:
		return "nothing left to solve"
	# The promise the pool makes: never a guess.
	if not gen.call("_solvable", w, h, mines, opened, int(d["mine_count"])):
		return "board is not solvable by logic alone"
	return ""


func _check_math(d: Dictionary, _gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	var e2 := _check_choices(d)
	if e2 != "":
		return e2
	var value: Variant = _eval(String(d["text"]))
	if value == null:
		return "could not re-evaluate '%s'" % d["text"]
	if absf(float(value) - float(d["answer"])) > 0.0001:
		return "'%s' evaluates to %s, generator said %d" % [d["text"], str(value), int(d["answer"])]
	return ""




func _check_water(d: Dictionary, gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	var tubes: Array = d["tubes"]
	var cap := int(d["capacity"])
	var colors := int(d["colors"])
	if tubes.size() != colors + int(d["empties"]):
		return "tube count does not match colours plus empties"

	var counts := {}
	for t: Array in tubes:
		if t.size() > cap:
			return "a tube holds more than its capacity"
		for v in t:
			counts[int(v)] = int(counts.get(int(v), 0)) + 1
	if counts.size() != colors:
		return "expected %d colours, found %d" % [colors, counts.size()]
	for c: int in counts:
		if int(counts[c]) != cap:
			return "colour %d appears %d times, expected %d" % [c, int(counts[c]), cap]

	if WaterGen.is_solved(tubes, cap):
		return "deal is already solved"
	# The promise the pool makes: every deal can actually be sorted.
	if not gen.call("_solvable", tubes):
		return "deal is not solvable"
	return ""


func _check_chess(d: Dictionary, gen: RefCounted) -> String:
	var e := _check_common(d)
	if e != "":
		return e
	var w := int(d["w"])
	var h := int(d["h"])
	var board: PackedInt32Array = d["board"]
	if board.size() != w * h:
		return "board size mismatch"

	var kings := {1: 0, -1: 0}
	for v in board:
		if absi(v) == ChessGen.KING:
			kings[signi(v)] = int(kings[signi(v)]) + 1
	if int(kings[1]) != 1 or int(kings[-1]) != 1:
		return "expected exactly one king per side"
	if gen.call("in_check", board, w, h, ChessGen.BLACK):
		return "Black is already in check with White to move"

	var depth := int(d["depth"])
	var wins: PackedInt32Array = gen.call("winning_moves", board, w, h, depth)
	if wins.size() != 1:
		return "expected exactly one mating move, found %d" % wins.size()
	if wins[0] != int(d["solution"]):
		return "stored solution is not the winning move"
	if depth > 1:
		var faster: PackedInt32Array = gen.call("winning_moves", board, w, h, depth - 1)
		if not faster.is_empty():
			return "claimed mate in %d but there is a mate in %d" % [depth, depth - 1]
	return ""


## Independently re-evaluates the displayed expression with Godot's Expression
## parser, so a typo in the generator's own arithmetic cannot slip through.
func _eval(text: String) -> Variant:
	var s := text
	var re := RegEx.new()
	re.compile("(\\d+)%\\s+of\\s+(\\d+)")
	s = re.sub(s, "($1 * $2 / 100.0)", true)
	var sq := RegEx.new()
	sq.compile("(\\d+)²")
	s = sq.sub(s, "($1 * $1)", true)
	s = s.replace("×", "*").replace("÷", "/").replace("−", "-")
	var expr := Expression.new()
	if expr.parse(s) != OK:
		return null
	var out: Variant = expr.execute()
	if expr.has_execute_failed():
		return null
	return out




# -------------------------------------------------------------- uniqueness ---
## The dedupe promise only holds if generators actually produce a wide space of
## distinct fingerprints. Measure the collision rate over a big sample.
func _uniqueness_probe(rng: RandomNumberGenerator) -> void:
	print("── fingerprint spread ─────────────")
	var gens := {
		"sudoku": SudokuGen.new(), "pattern": PatternGen.new(),
		"target": TargetGen.new(), "mines": MinesGen.new(), "math": MathGen.new(),
		"water": WaterGen.new(),
	}
	for name: String in gens:
		var seen := {}
		var dupes := 0
		var n := 260
		for i in n:
			var diff := float(i) / float(n)
			var d: Dictionary = gens[name].call("generate", rng, diff)
			if d.is_empty():
				continue
			var hsh := int(d["hash"])
			if seen.has(hsh):
				dupes += 1
			seen[hsh] = true
		var pct := 100.0 * float(dupes) / float(n)
		print("   %-8s %3d/%d repeats (%.1f%%)" % [name, dupes, n, pct])
		if pct > 25.0:
			_fail("%s repeats far too often" % name)
