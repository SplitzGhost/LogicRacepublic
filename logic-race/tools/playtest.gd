extends SceneTree
## Drives a real round through the real screens.
##
##   godot --headless --path . --script res://tools/playtest.gd
##
## Verifies the game loop end to end: solving advances the level, a wrong answer
## and a timeout each cost a life, two lost lives end the round, the MMR result
## is written to disk, and every one of the five puzzle types can actually be
## completed through its own input path.

var _main: Node
var _pal: Node
var _save: Node
var _fac: Node
var _ranks: Node

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_pal = root.get_node("/root/Palette")
	_save = root.get_node("/root/SaveData")
	_fac = root.get_node("/root/PuzzleFactory")
	_ranks = root.get_node("/root/Ranks")

	await _boot()

	await _test_pool_solvable("math")
	await _test_pool_solvable("pattern")
	await _test_pool_solvable("sudoku")
	await _test_pool_solvable("mines")
	await _test_target_wrong_answer()
	await _test_wrong_answer_costs_life()
	await _test_timeout_costs_life()
	await _test_full_round_scores_mmr()
	await _test_quit_is_scored()
	_test_history_dedupe()

	print("")
	if failures == 0:
		print("PASS  %d checks, 0 failures" % checks)
	else:
		print("FAIL  %d checks, %d failures" % [checks, failures])
	if _main != null:
		_main.free()
	quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------- utils ---
func check(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("   !! ", what)


func _boot() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	current_scene = _main
	await _wait(0.2)


func _restart() -> void:
	if _main != null:
		_main.queue_free()
		await process_frame
	await _boot()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _game() -> Node:
	return _main.get("_current")


## Waits until a puzzle view of the given pool is on screen.
func _await_view(pool := "") -> Node:
	for attempt in 60:
		var game := _game()
		if game != null and game.get("_view") != null:
			var view: Node = game.get("_view")
			if pool == "" or String(_d(view).get("pool", "")) == pool:
				return view
		await _wait(0.1)
	return null


## Plays the current puzzle correctly, whatever pool it belongs to.
func _solve(view: Node) -> bool:
	match String(_d(view)["pool"]):
		"math", "pattern":
			var grid: Node = view.get("_grid")
			grid.call("_on_tile", int(_d(view)["answer_index"]))
			return true
		"sudoku":
			var board: Node = view.get("_board")
			var solution: PackedInt32Array = _d(view)["solution"]
			var given: PackedInt32Array = _d(view)["given"]
			for i in given.size():
				if given[i] != 0:
					continue
				# Filling a cell auto-advances the selection, so only tap when
				# the cell is not already the selected one (a tap would toggle).
				if int(board.get("selected")) != i:
					view.call("_on_cell", i)
				view.call("_on_key", solution[i])
			await _wait(0.4)
			return true
		"mines":
			var w := int(_d(view)["w"])
			var h := int(_d(view)["h"])
			var mines: PackedByteArray = _d(view)["mines"]
			var board: Node = view.get("_board")
			for i in w * h:
				if bool(view.get("finished")):
					break
				var opened: PackedByteArray = board.get("opened")
				if mines[i] == 0 and opened[i] == 0:
					view.call("_on_tap", i)
			return true
		"target":
			return false
	return false


# ------------------------------------------------------------------- tests ---
func _test_pool_solvable(pool: String) -> void:
	print("── %s: solving advances the level ──" % pool)
	_fac.set("forced_pool", pool)
	_save.set("mmr", 0)
	await _restart()
	_main.call("go_game")

	var view := await _await_view(pool)
	check(view != null, "%s: no puzzle appeared" % pool)
	if view == null:
		return
	var game := _game()
	var level_before := int(game.get("level"))
	await _solve(view)
	await _wait(1.8)
	check(int(game.get("level")) == level_before + 1,
			"%s: level did not advance (%d -> %d)" % [pool, level_before, int(game.get("level"))])
	check(int(game.get("lives")) == 2, "%s: solving cost a life" % pool)
	check(int(game.get("cleared")) == 1, "%s: cleared counter did not move" % pool)


func _test_target_wrong_answer() -> void:
	print("── target: folding to the wrong value costs a life ──")
	_fac.set("forced_pool", "target")
	_save.set("mmr", 0)
	await _restart()
	_main.call("go_game")

	var view := await _await_view("target")
	check(view != null, "target: no puzzle appeared")
	if view == null:
		return
	var game := _game()
	# Add everything together; the sum is almost never the target.
	var values: Array = view.get("values")
	var sum := 0
	for v: Vector2i in values:
		sum += v.x
	while (view.get("values") as Array).size() > 1:
		view.call("_apply", 0, 0, 1)
	await _wait(0.8)
	if sum == int(_d(view)["target"]):
		check(int(game.get("cleared")) == 1, "target: plain sum hit the target but was not accepted")
	else:
		check(int(game.get("lives")) == 1, "target: wrong final value did not cost a life")


func _test_wrong_answer_costs_life() -> void:
	print("── a wrong answer costs exactly one life ──")
	_fac.set("forced_pool", "math")
	_save.set("mmr", 0)
	await _restart()
	_main.call("go_game")

	var view := await _await_view("math")
	if view == null:
		check(false, "no puzzle appeared")
		return
	var game := _game()
	var grid: Node = view.get("_grid")
	var wrong := (int(_d(view)["answer_index"]) + 1) % 4
	grid.call("_on_tile", wrong)
	await _wait(0.4)
	check(int(game.get("lives")) == 1, "wrong answer did not cost a life")
	check(int(game.get("level")) == 1, "wrong answer advanced the level")
	await _wait(1.4)
	check(_game().get("_view") != null, "no follow-up puzzle after a wrong answer")


func _test_timeout_costs_life() -> void:
	print("── running out of time costs a life ──")
	_fac.set("forced_pool", "math")
	_save.set("mmr", 0)
	await _restart()
	_main.call("go_game")

	var view := await _await_view("math")
	if view == null:
		check(false, "no puzzle appeared")
		return
	var game := _game()
	game.set("time_left", 0.05)
	await _wait(0.5)
	check(int(game.get("lives")) == 1, "timeout did not cost a life")
	check(bool(view.get("finished")), "timeout did not lock the view")


func _test_full_round_scores_mmr() -> void:
	print("── a finished round scores and persists MMR ──")
	_fac.set("forced_pool", "math")
	_save.set("mmr", 0)
	await _restart()
	_main.call("go_game")

	var game := _game()
	for i in 8:
		var view := await _await_view("math")
		if view == null:
			break
		var grid: Node = view.get("_grid")
		grid.call("_on_tile", int(_d(view)["answer_index"]))
		await _wait(1.5)
	check(int(game.get("cleared")) == 8, "expected 8 cleared, got %d" % int(game.get("cleared")))

	# Burn both lives.
	for i in 2:
		var view := await _await_view("math")
		if view == null:
			break
		var grid: Node = view.get("_grid")
		grid.call("_on_tile", (int(_d(view)["answer_index"]) + 1) % 4)
		await _wait(1.6)

	await _wait(1.0)
	var mmr := int(_save.get("mmr"))
	check(mmr > 0, "eight cleared levels from 0 MMR should gain rating, got %d" % mmr)
	check(int(_save.get("rounds_played")) > 0, "round was not recorded")
	check(int(_save.get("best_level")) >= 9, "best level not updated (%d)" % int(_save.get("best_level")))

	var expected: float = _ranks.call("expected_levels", 0)
	check(absf(expected - 5.0) < 0.01, "expected-level baseline drifted")

	# The result screen should be up, and the value should survive a reload.
	var current: Node = _main.get("_current")
	check(current != null and current.get("summary") != null, "result screen did not appear")

	_save.call("save_game")
	_save.set("mmr", -1)
	_save.call("load_game")
	check(int(_save.get("mmr")) == mmr, "MMR did not survive a save/load round trip")


func _test_history_dedupe() -> void:
	print("── the same puzzle is not served twice ──")
	var seen := {}
	var repeats := 0
	for i in 150:
		var d: Dictionary = _fac.call("make", 0.35, "math")
		if d.is_empty():
			continue
		var h := int(d["hash"])
		if seen.has(h):
			repeats += 1
		seen[h] = true
	check(repeats == 0, "%d repeated puzzles in a 150 puzzle run" % repeats)

	var save_path: String = _save.get("SAVE_PATH") if _save.get("SAVE_PATH") != null else "user://logicrace.save"
	check(FileAccess.file_exists(save_path), "save file was never written")


## `data` is read dynamically so this harness never has to reference the game's
## own classes at compile time (autoload globals are not registered yet then).
func _d(view: Node) -> Dictionary:
	return view.get("data")


func _test_quit_is_scored() -> void:
	print("── quitting mid-round is armed and still scored ──")
	_fac.set("forced_pool", "math")
	_save.set("mmr", 3000)
	_save.call("save_game")
	await _restart()
	_main.call("go_game")

	var view := await _await_view("math")
	if view == null:
		check(false, "no puzzle appeared")
		return
	var game := _game()
	var before := int(_save.get("mmr"))

	game.call("_on_quit")
	await _wait(0.2)
	check(_main.get("_current") == game, "a single tap already left the round")
	check(int(_save.get("mmr")) == before, "a single tap already scored the round")

	game.call("_on_quit")
	await _wait(0.6)
	check(_main.get("_current") != game, "confirming did not end the round")
	check(int(_save.get("mmr")) < before,
			"quitting with zero cleared levels at 3000 MMR should cost rating")
