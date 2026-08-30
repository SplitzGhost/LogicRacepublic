extends SceneTree
## Screenshot harness -- drives the real screens and writes PNGs so the layout
## can be reviewed outside the editor.
##
##   godot --path . --script res://tools/shots.gd
##
## Output goes to user://shots/ (printed on start). Nothing here is part of the
## shipped game.

const OUT := "user://shots"
const SIZE := Vector2i(620, 1343)

var _main: Node
var _pal: Node
var _save: Node
var _fac: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_pal = root.get_node("/root/Palette")
	_save = root.get_node("/root/SaveData")
	_fac = root.get_node("/root/PuzzleFactory")
	print("shots -> ", ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(SIZE)
	root.content_scale_size = Vector2i(720, 1560)

	await _boot()
	await _settle(24)
	await _shot("01_menu_light")

	_pal.call("set_dark", true, false)
	await _settle(12)
	await _shot("02_menu_dark")
	_pal.call("set_dark", false, false)
	await _settle(10)

	_main.call("open_settings")
	await _settle(30)
	await _shot("03_settings")
	_main.call("close_settings")
	await _settle(24)

	var pools: Array[String] = ["math", "pattern", "target", "sudoku", "mines"]
	var idx := 4
	for pool in pools:
		_fac.set("forced_pool", pool)
		_save.set("mmr", 900)
		await _fresh()
		_main.call("go_game")
		await _settle(40)
		await _shot("%02d_game_%s" % [idx, pool])
		idx += 1
	_fac.set("forced_pool", "")

	# A hard sudoku and a hard minesweeper, to check the dense layouts.
	_save.set("mmr", 4200)
	for pool in ["sudoku", "mines", "target", "pattern"]:
		_fac.set("forced_pool", pool)
		await _fresh()
		_main.call("go_game")
		await _settle(20)
		# Replace the level-1 puzzle with a late-game one: drop the live view
		# first, otherwise both stay stacked in the slot.
		var game: Node = _main.get("_current")
		var view: Node = game.get("_view")
		if view != null:
			view.queue_free()
		game.set("_view", null)
		game.set("level", 26)
		game.set("_prefetch", {})
		await _settle(3)
		game.call("_next_puzzle", false)
		await _settle(36)
		await _shot("%02d_hard_%s" % [idx, pool])
		idx += 1
	_fac.set("forced_pool", "")

	await _fresh()
	_main.call("go_result", {
		"level": 14, "cleared": 13, "delta": 168, "level_delta": 149,
		"speed_delta": 19, "new_mmr": 1068, "mmr_before": 900,
		"rank_before": "Silver", "rank_after": "Silver", "promoted": false,
		"demoted": false, "avg_time_left": 0.52, "expected": 9.95,
	})
	await _settle(70)
	await _shot("%02d_result" % idx)

	_cleanup()
	print("done")
	quit()


func _boot() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame


func _fresh() -> void:
	if _main != null:
		_main.queue_free()
		await process_frame
	await _boot()
	await _settle(6)


## Frame counts are unreliable here (the harness renders as fast as it can), so
## wait in real time -- animations are driven by wall-clock delta.
func _settle(frames: int) -> void:
	await create_timer(maxf(0.3, float(frames) / 40.0)).timeout
	await process_frame


func _shot(name: String) -> void:
	_force_redraw(root)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(path)
	print("  ", name, "  ", img.get_size())


## Keeps the harness from leaving test values in the real save file.
func _cleanup() -> void:
	_save.set("mmr", 0)
	_save.set("best_level", 1)
	_save.call("save_game")


func _force_redraw(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child in node.get_children():
		_force_redraw(child)
