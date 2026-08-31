extends Node
## Picks a pool at random for every single puzzle, generates it procedurally and
## keeps the player from ever seeing a puzzle they have already been served --
## unless every pool has genuinely run out of new material.

const POOLS: Array[String] = [
	"sudoku", "pattern", "target", "mines", "math", "chess", "water",
]

const GENERATORS := {
	"sudoku": preload("res://scripts/gen/sudoku_gen.gd"),
	"pattern": preload("res://scripts/gen/pattern_gen.gd"),
	"target": preload("res://scripts/gen/target_gen.gd"),
	"mines": preload("res://scripts/gen/mines_gen.gd"),
	"math": preload("res://scripts/gen/math_gen.gd"),
	"chess": preload("res://scripts/gen/chess_gen.gd"),
	"water": preload("res://scripts/gen/water_gen.gd"),
}

## Retries inside one pool before the factory gives up on it.
const MAX_TRIES := 64
## Chess is by far the slowest generator; it gets a smaller budget so a
## near-exhausted pool cannot stall a frame.
const SLOW_POOLS: Array[String] = ["chess"]
const SLOW_TRIES := 12

var rng := RandomNumberGenerator.new()
## Test hook: when set, every puzzle comes from this pool instead of a random one.
var forced_pool := ""
var _generators: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	for name: String in GENERATORS:
		_generators[name] = (GENERATORS[name] as GDScript).new()


func random_pool() -> String:
	return POOLS[rng.randi_range(0, POOLS.size() - 1)]


## Build one puzzle at the given difficulty (0..1). `pool` may be forced for
## testing; by default the pool is drawn at random for every puzzle.
func make(difficulty: float, pool := "") -> Dictionary:
	var diff := clampf(difficulty, 0.0, 1.0)
	if pool != "":
		return _from_pool(pool, diff, true)
	if forced_pool != "":
		return _from_pool(forced_pool, diff, true)

	var first := random_pool()
	var made := _from_pool(first, diff, false)
	if not made.is_empty():
		return made

	# That pool has nothing new left at this difficulty. Rather than repeat a
	# puzzle, try the others before falling back to a repeat.
	var others := POOLS.duplicate()
	others.erase(first)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = others[i]
		others[i] = others[j]
		others[j] = t
	for other: String in others:
		made = _from_pool(other, diff, false)
		if not made.is_empty():
			return made

	# Every pool is exhausted at this difficulty; a repeat is now unavoidable.
	return _from_pool(first, diff, true)


## Generates from one pool. With `allow_repeat` off it returns an empty result
## rather than handing back a puzzle the player has already seen.
func _from_pool(pool: String, diff: float, allow_repeat: bool) -> Dictionary:
	var gen: RefCounted = _generators.get(pool)
	if gen == null:
		return {}
	var tries := SLOW_TRIES if SLOW_POOLS.has(pool) else MAX_TRIES
	var last: Dictionary = {}

	for attempt in tries:
		var d: Dictionary = gen.call("generate", rng, diff)
		if d.is_empty():
			continue
		last = d
		if not SaveData.seen(pool, int(d["hash"])):
			SaveData.remember(pool, int(d["hash"]))
			d["difficulty"] = diff
			return d

	if not allow_repeat or last.is_empty():
		return {}
	SaveData.remember(pool, int(last["hash"]))
	last["difficulty"] = diff
	last["repeat"] = true
	return last
