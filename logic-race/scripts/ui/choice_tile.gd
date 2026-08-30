class_name ChoiceTile
extends TapButton
## One answer option. Shows either a number or a Pattern Snap glyph, and can be
## flashed green/red once the answer is in.

enum State { IDLE, CORRECT, WRONG, FADED }

var mode := "text"          ## "text" or "glyph"
var text := ""
var glyph := {"shape": 0, "rot": 0, "fill": true}
var state: State = State.IDLE:
	set(value):
		state = value
		queue_redraw()


func _init() -> void:
	super()
	custom_minimum_size = Vector2(0, 148)
	press_scale = 0.965
	sfx_name = "select"


func _ready() -> void:
	super()
	Palette.changed.connect(queue_redraw)


func set_glyph(g: Dictionary) -> void:
	mode = "glyph"
	glyph = g
	queue_redraw()


func set_text(t: String) -> void:
	mode = "text"
	text = t
	queue_redraw()


func _bg() -> Color:
	match state:
		State.CORRECT:
			return Palette.c("good")
		State.WRONG:
			return Palette.c("bad")
		State.FADED:
			return Palette.c("card").lerp(Palette.c("bg"), 0.55)
		_:
			return Palette.c("card")


func _fg() -> Color:
	match state:
		State.CORRECT, State.WRONG:
			return Color.WHITE
		State.FADED:
			return Palette.c("text_dim")
		_:
			return Palette.c("text")


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var sb := Palette.flat_box(Palette.R_TILE + 4.0, _bg())
	if state == State.IDLE:
		sb.shadow_color = Palette.c("shadow")
		sb.shadow_size = 16
		sb.shadow_offset = Vector2(0, 6)
	else:
		sb.shadow_color = _bg() * Color(1, 1, 1, 0.35)
		sb.shadow_size = 20
		sb.shadow_offset = Vector2(0, 8)
	draw_style_box(sb, rect)

	if mode == "glyph":
		var r: float = minf(rect.size.x, rect.size.y) * 0.27
		UiDraw.draw_glyph(self, int(glyph["shape"]), int(glyph["rot"]),
				rect.size * 0.5, r, _fg(), bool(glyph["fill"]), 8.0)
	else:
		var fs := UiDraw.fit_size(Palette.font_bold, text, rect.size.x - 40.0, 52, 22)
		UiDraw.text_center(self, Palette.font_bold, fs, rect, text, _fg())
