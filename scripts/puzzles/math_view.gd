extends PuzzleView
## Mental Math: one expression, four options.

var _grid: ChoiceGrid


func build(column: VBoxContainer) -> void:
	column.add_child(spacer(0.55))

	var card := Card.new()
	card.custom_minimum_size.y = 236
	var text := String(data["text"])
	var label := TintLabel.centered(text, _size_for(text.length()), "text", Palette.font_black)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.content(28).add_child(label)
	column.add_child(card)

	column.add_child(spacer(0.4))

	_grid = ChoiceGrid.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_stretch_ratio = 1.7
	_grid.build(data["options"], false)
	_grid.chosen.connect(_on_chosen)
	column.add_child(_grid)
	column.add_child(spacer(0.12))


func _size_for(length: int) -> int:
	if length <= 9:
		return 82
	if length <= 14:
		return 66
	if length <= 20:
		return 54
	return 44


func _on_chosen(index: int) -> void:
	var correct := int(data["answer_index"])
	_grid.reveal(index, correct)
	if index == correct:
		succeed()
	else:
		fail()


func on_timeout() -> void:
	super()
	_grid.locked = true
	_grid.reveal(-1, int(data["answer_index"]))
