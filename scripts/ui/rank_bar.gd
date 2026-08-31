class_name RankBar
extends Control
## Current rank, IQ points, and how much is still missing until the next division.
## The number and the bar can be animated, which the result screen uses.

var iq := 0
var shown_iq := 0.0
var compact := false

var _fill: GradRect
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 148)


func _ready() -> void:
	_fill = GradRect.new()
	_fill.radius = 10.0
	_fill.grad_dir = Vector2(1.0, 0.25)
	add_child(_fill)
	Palette.changed.connect(_refresh)
	resized.connect(_refresh)
	set_iq(iq, false)


func set_iq(value: int, animate := true) -> void:
	iq = value
	if not animate or bool(SaveData.get_setting("reduce_motion", false)):
		shown_iq = float(value)
		_refresh()
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(_set_shown, shown_iq, float(value), 1.05)


func _set_shown(v: float) -> void:
	shown_iq = v
	_refresh()


## The bar sits above the rank name, so the card reads:
## "how much is left" first, "where you are" underneath.
func _bar_rect() -> Rect2:
	return Rect2(Vector2(0.0, 62.0 if compact else 52.0), Vector2(size.x, 20.0))


func _refresh() -> void:
	queue_redraw()
	if _fill == null:
		return
	var info := Ranks.rank_progress(int(round(shown_iq)))
	var bar := _bar_rect()
	var w: float = maxf(bar.size.x * float(info["ratio"]), 20.0)
	_fill.position = bar.position
	_fill.size = Vector2(w, bar.size.y)
	var rank_col: Color = info["color"]
	_fill.set_colors(rank_col.lerp(Palette.c("accent_hi"), 0.35), rank_col)


func _draw() -> void:
	var info := Ranks.rank_progress(int(round(shown_iq)))
	var bar := _bar_rect()

	# Top line: label on the left, total rating on the right.
	if not compact:
		draw_string(Palette.font_bold, Vector2(2.0, 26.0), "RANK",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Palette.c("text_dim"))
	var iq_text := "%d IQ" % int(round(shown_iq))
	var iq_w := Palette.font_bold.get_string_size(iq_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(Palette.font_bold, Vector2(size.x - iq_w, 38.0 if compact else 28.0), iq_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.c("text"))

	draw_style_box(Palette.flat_box(bar.size.y * 0.5, Palette.c("sunken")), bar)

	# Below the bar: the rank you are in now, and what is still missing.
	var name_size := 44 if not compact else 40
	var baseline := bar.position.y + bar.size.y + float(name_size) + 8.0
	draw_string(Palette.font_black, Vector2(2.0, baseline), String(info["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, info["color"] as Color)

	var note := "Top rank reached" if bool(info["is_max"]) \
			else "%d IQ to %s" % [int(info["to_next"]), String(info["next_name"])]
	var note_w := Palette.font_medium.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(Palette.font_medium, Vector2(size.x - note_w, baseline - 6.0), note,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.c("text_dim"))
