class_name PillButton
extends TapButton
## Arcade-style button: a coloured face sitting on a darker plate, so it reads as
## a physical key. Pressing pushes the face down onto the plate.
##
## The face is a gradient child node and the label a second child on top of it --
## a parent's own `_draw` would end up underneath both.

enum Variant { PRIMARY, SECONDARY, GHOST, DANGER, SUCCESS, GOLD }

var text := "":
	set(value):
		text = value
		_redraw_face()
var variant: Variant = Variant.PRIMARY:
	set(value):
		variant = value
		_sync()
var radius := 30.0:
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
var _depth := 0.0
var _tw3: Tween


class Face:
	extends Control
	## Draws the label and icon above the button face.

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
			var half := Palette.font_black.get_string_size(
					label, HORIZONTAL_ALIGNMENT_LEFT, -1, owner_button.font_size).x * 0.5
			Icons.draw(self, icon_name, Vector2(rect.size.x * 0.5 - half - 34.0,
					rect.size.y * 0.5), 20.0, col, 5.0)
			text_rect.position.x += 24.0
		if label != "":
			var fs := UiDraw.fit_size(Palette.font_black, label, text_rect.size.x - 44.0,
					owner_button.font_size, 18)
			UiDraw.text_center(self, Palette.font_black, fs, text_rect, label, col)


func _init() -> void:
	super()
	# The face travels instead of the whole control.
	press_scale = 1.0


func _ready() -> void:
	super()
	custom_minimum_size.y = maxf(custom_minimum_size.y, 96.0)

	_grad = GradRect.new()
	_grad.gloss = 0.10
	add_child(_grad)

	_face = Face.new()
	_face.owner_button = self
	add_child(_face)

	resized.connect(_layout)
	Palette.changed.connect(_sync)
	_sync()


## Face colours per variant: [top, bottom, plate].
func _ramp() -> Array:
	match variant:
		Variant.PRIMARY:
			return [Palette.c("accent_hi"), Palette.c("accent"), Palette.c("accent_deep")]
		Variant.SUCCESS:
			return [Palette.c("good_hi"), Palette.c("good"), Palette.c("good_deep")]
		Variant.GOLD:
			return [Palette.c("gold"), Palette.c("gold").lerp(Palette.c("gold_deep"), 0.5),
					Palette.c("gold_deep")]
		Variant.DANGER:
			return [Palette.c("bad").lerp(Color.WHITE, 0.25), Palette.c("bad"),
					Palette.c("bad").darkened(0.35)]
		Variant.SECONDARY:
			return [Palette.c("card_alt"), Palette.c("card"), Palette.c("sunken")]
		_:
			return [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]


func text_color() -> Color:
	match variant:
		Variant.SECONDARY:
			return Palette.c("text")
		Variant.GHOST:
			return Palette.c("text_dim")
		Variant.GOLD:
			return Palette.c("gold_deep").darkened(0.45)
		_:
			return Palette.c("on_accent")


func _sync() -> void:
	if _grad == null:
		return
	var ramp := _ramp()
	_grad.visible = variant != Variant.GHOST
	_grad.radius = radius
	_grad.set_colors(ramp[0], ramp[1])
	_layout()
	_redraw_face()
	queue_redraw()


func _layout() -> void:
	if _grad == null:
		return
	var bevel := 0.0 if variant == Variant.GHOST else Palette.BEVEL
	var travel := bevel * 0.72 * _depth
	var face_h: float = maxf(10.0, size.y - bevel)
	_grad.position = Vector2(0.0, travel)
	_grad.size = Vector2(size.x, face_h)
	_grad.apply()
	_face.position = _grad.position
	_face.size = _grad.size
	_face.queue_redraw()
	queue_redraw()


func _redraw_face() -> void:
	if _face != null:
		_face.queue_redraw()


## Pressing pushes the face down onto the plate instead of scaling the control.
func press_feedback(down: bool) -> void:
	var target := 1.0 if down else 0.0
	if bool(SaveData.get_setting("reduce_motion", false)):
		_set_depth(target)
		return
	if _tw3 != null and _tw3.is_valid():
		_tw3.kill()
	_tw3 = create_tween()
	_tw3.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw3.tween_method(_set_depth, _depth, target, 0.08 if down else 0.16)


func _set_depth(v: float) -> void:
	_depth = v
	_layout()


func _draw() -> void:
	if variant == Variant.GHOST:
		return
	# The plate: same silhouette, darker, one bevel taller than the face.
	var plate := Palette.flat_box(radius, _ramp()[2])
	plate.shadow_color = Palette.c("shadow")
	plate.shadow_size = 20
	plate.shadow_offset = Vector2(0, 10)
	draw_style_box(plate, Rect2(Vector2.ZERO, size))
