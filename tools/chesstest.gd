extends SceneTree
## Engine checks for the miniature chess pool, on positions worked out by hand
## so the generator is not just agreeing with itself.

const ChessGen := preload("res://scripts/gen/chess_gen.gd")

var failures := 0


func _initialize() -> void:
	var gen: RefCounted = ChessGen.new()

	# 4x4. Black Kc4(0,0), White Kb2(2,1), White Rd1(3,3). Rook to (0,3) mates:
	# the king's three flight squares are covered by the rook's rank and the king.
	var mate_board := _board(4, {0: -1, 9: 1, 15: 3})
	var wins: PackedInt32Array = gen.call("winning_moves", mate_board, 4, 4, 1)
	_check(wins.size() == 1, "expected exactly one mate in 1, got %d" % wins.size())
	if wins.size() >= 1:
		_check(ChessGen.move_from(wins[0]) == 15 and ChessGen.move_to(wins[0]) == 3,
				"wrong mating move: %d -> %d" % [ChessGen.move_from(wins[0]), ChessGen.move_to(wins[0])])

	# The same board, but Black to move is neither mated nor stalemated.
	_check(not gen.call("mated", mate_board, 4, 4, -1), "black is mated before White moves")

	# 4x4 stalemate: Black K(0,0), White Q(2,1), White K(3,3). Black has no move
	# and is not in check, so this must not count as a mate.
	var stale := _board(4, {0: -1, 9: 2, 15: 1})
	var black_moves: PackedInt32Array = gen.call("moves_for", stale, 4, 4, -1)
	_check(black_moves.is_empty(), "expected stalemate, black had %d moves" % black_moves.size())
	_check(not gen.call("in_check", stale, 4, 4, -1), "stalemated king should not be in check")
	_check(not gen.call("mated", stale, 4, 4, -1), "stalemate must not be reported as mate")
	_check(gen.call("stalemated", stale, 4, 4, -1), "stalemate not detected")

	# Pawn promotion: white pawn on the second rank promotes and can mate.
	# 4x4: Black K(0,0)=0, White P(1,1)=5, White K(2,0)=8, White R(3,3)=15.
	var promo := _board(4, {0: -1, 5: 6, 8: 1, 15: 3})
	var promo_moves: PackedInt32Array = gen.call("moves_for", promo, 4, 4, 1)
	var found_promo := false
	for m in promo_moves:
		if ChessGen.move_from(m) == 5 and ChessGen.move_promo(m) != 0:
			found_promo = true
	_check(found_promo, "pawn on the last-but-one rank produced no promotion move")

	_generation_probe(gen)

	print("")
	if failures == 0:
		print("PASS  chess engine")
	else:
		print("FAIL  chess engine, %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _board(w: int, pieces: Dictionary) -> PackedInt32Array:
	var b := PackedInt32Array()
	b.resize(w * w)
	b.fill(0)
	for idx: int in pieces:
		b[idx] = int(pieces[idx])
	return b


func _check(condition: bool, what: String) -> void:
	if not condition:
		failures += 1
		print("   !! ", what)


func _generation_probe(gen: RefCounted) -> void:
	print("── generation ──")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for diff: float in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
		var t0 := Time.get_ticks_usec()
		var made := 0
		var depths := {}
		var seen := {}
		var dupes := 0
		for i in 12:
			var d: Dictionary = gen.call("generate", rng, diff)
			if d.is_empty():
				continue
			made += 1
			depths[int(d["depth"])] = true
			if seen.has(int(d["hash"])):
				dupes += 1
			seen[int(d["hash"])] = true

			# Re-verify independently: the stored solution must mate in `depth`,
			# and it must be the only move that does.
			var board: PackedInt32Array = d["board"]
			var again: PackedInt32Array = gen.call("winning_moves", board, int(d["w"]),
					int(d["h"]), int(d["depth"]))
			if again.size() != 1 or again[0] != int(d["solution"]):
				_check(false, "diff %.2f: solution not unique on re-check" % diff)
			if int(d["depth"]) > 1:
				var faster: PackedInt32Array = gen.call("winning_moves", board, int(d["w"]),
						int(d["h"]), int(d["depth"]) - 1)
				if not faster.is_empty():
					_check(false, "diff %.2f: puzzle is really mate in %d" % [diff, int(d["depth"]) - 1])
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		print("   diff %.2f  %6.1f ms/puzzle  made=%d/12  depths=%s  repeats=%d"
				% [diff, ms / 12.0, made, str(depths.keys()), dupes])
		if made < 8:
			_check(false, "diff %.2f produced only %d of 12 puzzles" % [diff, made])
