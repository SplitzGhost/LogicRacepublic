class_name TintLabel
extends Label
## A Label whose colour follows the palette.
##
## Colours live on the node as a theme override instead of inside the shared
## Theme resource. That keeps the light/dark cross-fade from having to rebuild
## (and re-propagate) the Theme every frame, which is both expensive and the kind
## of churn that goes wrong while screens are being freed.

## Set when a screen wants a one-off colour that must survive palette changes.
var frozen := false
var tint_key := "text":
	set(value):
		tint_key = value
		_sync()


func _ready() -> void:
	Palette.changed.connect(_sync)
	_sync()


func _sync() -> void:
	if frozen:
		return
	add_theme_color_override("font_color", Palette.c(tint_key))


static func make(text_value: String, size: int, key := "text", font: Font = null) -> TintLabel:
	var label := TintLabel.new()
	label.text = text_value
	label.tint_key = key
	label.add_theme_font_size_override("font_size", size)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


static func centered(text_value: String, size: int, key := "text", font: Font = null) -> TintLabel:
	var label := make(text_value, size, key, font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
