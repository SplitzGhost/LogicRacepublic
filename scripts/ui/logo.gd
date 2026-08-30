class_name Logo
extends Control
## The LogicRace mark: a gradient tile with a stepped track climbing to a finish
## node, optionally followed by the wordmark. Drawn as vectors, so it is the same
## artwork as the app icon.

var tile_size := 168.0
var show_wordmark := true

var _tile: GradRect
var _mark: Mark


class Mark:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x
		var w := s * 0.101
		var col := Color.WHITE
		var pts := PackedVector2Array([
			Vector2(0.225, 0.735), Vector2(0.408, 0.735), Vector2(0.408, 0.545),
			Vector2(0.592, 0.545), Vector2(0.592, 0.36), Vector2(0.762, 0.36),
		])
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(p * s)
		draw_polyline(scaled, col, w, true)
		draw_circle(scaled[0], w * 0.72, col)
		draw_circle(scaled[scaled.size() - 1], w * 1.12, col)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile = GradRect.new()
	_tile.radius = tile_size * 0.265
	_tile.gloss = 0.07
	_tile.grad_dir = Vector2(0.85, 1.0)
	add_child(_tile)

	_mark = Mark.new()
	add_child(_mark)

	Palette.changed.connect(_sync)
	resized.connect(_layout)
	_sync()
	_layout()


func _sync() -> void:
	if _tile != null:
		_tile.set_colors(Palette.c("accent_hi"), Palette.c("accent"))
	queue_redraw()


func _layout() -> void:
	if _tile == null:
		return
	var x := (size.x - tile_size) * 0.5
	_tile.position = Vector2(x, 0.0)
	_tile.size = Vector2(tile_size, tile_size)
	_tile.radius = tile_size * 0.265
	_tile.apply()
	_mark.position = _tile.position
	_mark.size = _tile.size
	_mark.queue_redraw()
	custom_minimum_size.y = tile_size + (108.0 if show_wordmark else 0.0)
	queue_redraw()


func _draw() -> void:
	if not show_wordmark:
		return
	var fs := 60
	var a := "Logic"
	var b := "Race"
	var wa := Palette.font_black.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var wb := Palette.font_black.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (size.x - (wa + wb)) * 0.5
	var y := tile_size + 74.0
	draw_string(Palette.font_black, Vector2(x, y), a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Palette.c("text"))
	draw_string(Palette.font_black, Vector2(x + wa, y), b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Palette.c("accent"))


## Gentle entrance: the tile settles in, the wordmark follows.
func play_intro() -> void:
	if bool(SaveData.get_setting("reduce_motion", false)):
		return
	_tile.pivot_offset = _tile.size * 0.5
	_tile.scale = Vector2(0.82, 0.82)
	_tile.modulate.a = 0.0
	modulate.a = 1.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tile, "scale", Vector2.ONE, 0.55)
	tw.parallel().tween_property(_tile, "modulate:a", 1.0, 0.35)
