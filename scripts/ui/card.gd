class_name Card
extends Control
## Rounded surface with a faint light edge and a deep shadow -- the panel style
## the whole arcade layout is built from. Children are laid out by the owner.

var radius := Palette.R_CARD
var fill_key := "card"
var shadow := true
var shadow_size := 22
var border_key := "glass"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	Palette.changed.connect(queue_redraw)


## Adds and returns a padded container that fills the card.
func content(pad := 36) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	add_child(m)
	return m


func _draw() -> void:
	var sb := Palette.flat_box(radius, Palette.c(fill_key))
	if border_key != "":
		sb.set_border_width_all(2)
		sb.border_color = Palette.c(border_key)
	if shadow:
		sb.shadow_color = Palette.c("shadow")
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0, 10)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
