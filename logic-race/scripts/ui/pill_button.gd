class_name PillButton
extends TapButton
## Labelled button. PRIMARY carries the accent gradient and a soft drop shadow;
## the rest are flat surfaces that follow the palette.
##
## The gradient lives in a child node, so the label and icon are painted by a
## second child on top of it -- a parent's own `_draw` would end up underneath.

enum Variant { PRIMARY, SECONDARY, GHOST, DANGER }

var text := "":
	set(value):
		text = value
		_redraw_face()
var variant: Variant = Variant.PRIMARY:
	set(value):
		variant = value
		_sync()
var radius := 34.0:
	set(value):
		radius = value
		_sync()
var font_size := 34:
	set(value):
		font_size = value
		_redraw_face()
var icon := "":
	set(value):
		icon = value
		_redraw_face()

var _grad: GradRect
var _face: Face


class Face:
	extends Control
	## Draws the label and icon above the button background.

	var owner_button: PillButton

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if owner_button == null:
			return
		var rect := Rect2(Vector2.ZERO, size)
		var col: Color = owner_button.text_color()
		var label: String = owner_button.text
		var icon_name: String = owner_button.icon

		if icon_name != "" and label == "":
			Icons.draw(self, icon_name, rect.size * 0.5, minf(rect.size.y * 0.3, 26.0), col, 5.0)
			return

		var text_rect := rect
		if icon_name != "":
			var half := Palette.font_bold.get_string_size(
					label, HORIZONTAL_ALIGNMENT_LEFT, -1, owner_button.font_size).x * 0.5
			Icons.draw(self, icon_name, Vector2(rect.size.x * 0.5 - half - 34.0,
					rect.size.y * 0.5), 20.0, col, 5.0)
			text_rect.position.x += 24.0
		if label != "":
			var fs := UiDraw.fit_size(Palette.font_bold, label, text_rect.size.x - 48.0,
					owner_button.font_size, 18)
			UiDraw.text_center(self, Palette.font_bold, fs, text_rect, label, col)


func _ready() -> void:
	super()
	custom_minimum_size.y = maxf(custom_minimum_size.y, 96.0)

	_grad = GradRect.new()
	_grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grad.gloss = 0.06
	add_child(_grad)

	_face = Face.new()
	_face.owner_button = self
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_face)

	Palette.changed.connect(_sync)
	_sync()


func _sync() -> void:
	if _grad != null:
		_grad.radius = radius
		_grad.visible = variant == Variant.PRIMARY
		if variant == Variant.PRIMARY:
			_grad.set_colors(Palette.c("accent_hi"), Palette.c("accent"))
	_redraw_face()
	queue_redraw()


func _redraw_face() -> void:
	if _face != null:
		_face.queue_redraw()


func fill_color() -> Color:
	match variant:
		Variant.PRIMARY:
			return Palette.c("accent")
		Variant.SECONDARY:
			return Palette.c("card")
		Variant.DANGER:
			return Palette.c("bad")
		_:
			return Color(0, 0, 0, 0)


func text_color() -> Color:
	match variant:
		Variant.PRIMARY, Variant.DANGER:
			return Palette.c("on_accent")
		Variant.GHOST:
			return Palette.c("text_dim")
		_:
			return Palette.c("text")


func _draw() -> void:
	if variant == Variant.GHOST:
		return
	var sb := Palette.flat_box(radius, fill_color())
	if variant == Variant.PRIMARY or variant == Variant.DANGER:
		sb.shadow_color = fill_color() * Color(1, 1, 1, 0.34)
		sb.shadow_size = 24
		sb.shadow_offset = Vector2(0, 12)
	else:
		sb.shadow_color = Palette.c("shadow")
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(0, 5)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
