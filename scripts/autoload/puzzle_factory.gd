extends Node
## Picks a pool at random for every single puzzle, generates it procedurally and
## keeps the player from ever seeing a puzzle they have already been served --
## unless the generator genuinely cannot produce anything new.

const POOLS: Array[String] = ["sudoku", "pattern", "target", "mines", "math"]

const SudokuGen := preload("res://scripts/gen/sudoku_gen.gd")
const PatternGen := preload("res://scripts/gen/pattern_gen.gd")
const TargetGen := preload("res://scripts/gen/target_gen.gd")
const MinesGen := preload("res://scripts/gen/mines_gen.gd")
const MathGen := preload("res://scripts/gen/math_gen.gd")

## How often we retry before accepting a repeat.
const MAX_TRIES := 48

var rng := RandomNumberGenerator.new()
## Test hook: when set, every puzzle comes from this pool instead of a random one.
var forced_pool := ""
var _generators: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	_generators = {
		"sudoku": SudokuGen.new(),
		"pattern": PatternGen.new(),
		"target": TargetGen.new(),
		"mines": MinesGen.new(),
		"math": MathGen.new(),
	}


func random_pool() -> String:
	return POOLS[rng.randi_range(0, POOLS.size() - 1)]


## Build one puzzle at the given difficulty (0..1). `pool` may be forced for
## testing; by default the pool is drawn at random for every puzzle.
func make(difficulty: float, pool := "") -> Dictionary:
	var chosen := pool
	if chosen == "":
		chosen = forced_pool if forced_pool != "" else random_pool()
	var gen: RefCounted = _generators[chosen]
	var last: Dictionary = {}

	for attempt in MAX_TRIES:
		var d: Dictionary = gen.call("generate", rng, clampf(difficulty, 0.0, 1.0))
		if d.is_empty():
			continue
		last = d
		if not SaveData.seen(chosen, int(d["hash"])):
			SaveData.remember(chosen, int(d["hash"]))
			d["difficulty"] = difficulty
			return d

	# Exhausted: this generator has no unseen variant left at this difficulty.
	if last.is_empty():
		# Extremely defensive -- fall back to the pool that can always deliver.
		last = _generators["math"].call("generate", rng, clampf(difficulty, 0.0, 1.0))
		if last.is_empty():
			return {}
		chosen = "math"
	SaveData.remember(chosen, int(last["hash"]))
	last["difficulty"] = difficulty
	last["repeat"] = true
	return last
