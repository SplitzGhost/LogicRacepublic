class_name IconButton
extends TapButton
## Round icon button (theme toggle, settings, back, undo, flag).

var icon := "sliders":
	set(value):
		icon = value
		queue_redraw()
var filled := true
var tint := ""     ## palette key; empty = default text colour
var icon_scale := 0.42
var stroke := 5.0


func _ready() -> void:
	super()
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(84, 84)
	Palette.changed.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if filled:
		var sb := Palette.flat_box(size.y * 0.5, Palette.c("card"))
		sb.shadow_color = Palette.c("shadow")
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, rect)
	var col := Palette.c("text") if tint == "" else Palette.c(tint)
	Icons.draw(self, icon, rect.size * 0.5, size.y * icon_scale, col, stroke)
