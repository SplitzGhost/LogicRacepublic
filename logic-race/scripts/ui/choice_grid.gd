class_name ChoiceGrid
extends GridContainer
## The 2x2 answer grid used by Pattern Snap and Mental Math.

signal chosen(index: int)

var tiles: Array[ChoiceTile] = []
var locked := false


func _init() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 22)
	add_theme_constant_override("v_separation", 22)


func build(options: Array, as_glyphs: bool) -> void:
	for t in tiles:
		t.queue_free()
	tiles.clear()
	locked = false

	for i in options.size():
		var tile := ChoiceTile.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if as_glyphs:
			tile.set_glyph(options[i])
		else:
			tile.set_text(str(options[i]))
		tile.pressed.connect(_on_tile.bind(i))
		add_child(tile)
		tiles.append(tile)


func _on_tile(index: int) -> void:
	if locked:
		return
	locked = true
	chosen.emit(index)


## Reveals the outcome: the picked tile turns green or red, the correct one is
## always highlighted, the rest fade back.
func reveal(picked: int, correct: int) -> void:
	for i in tiles.size():
		if i == correct:
			tiles[i].state = ChoiceTile.State.CORRECT
		elif i == picked:
			tiles[i].state = ChoiceTile.State.WRONG
			tiles[i].shake()
		else:
			tiles[i].state = ChoiceTile.State.FADED
		tiles[i].enabled = false
