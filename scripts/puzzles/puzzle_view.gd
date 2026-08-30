class_name PuzzleView
extends Control
## Base for the five puzzle types. A view reports exactly one outcome:
## `solved` or `failed` (a wrong answer). Running out of time is handled by the
## game screen, which then calls `on_timeout()` so the view can show the answer.

signal solved
signal failed

var data: Dictionary = {}
var finished := false

var _col: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(d: Dictionary) -> void:
	data = d
	theme = Palette.theme
	_col = VBoxContainer.new()
	_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_col.add_theme_constant_override("separation", 26)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	_col.add_child(_header())
	build(_col)


func _header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.text = String(data.get("title", "")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Palette.font_bold)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Palette.c("accent"))
	box.add_child(title)

	var hint := Label.new()
	hint.text = String(data.get("hint", ""))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Palette.c("text_dim"))
	box.add_child(hint)
	return box


## Subclasses fill the column below the header.
func build(_column: VBoxContainer) -> void:
	pass


func succeed() -> void:
	if finished:
		return
	finished = true
	solved.emit()


func fail() -> void:
	if finished:
		return
	finished = true
	failed.emit()


## The clock ran out. Views override this to reveal the answer.
func on_timeout() -> void:
	finished = true


func spacer(ratio := 1.0) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
