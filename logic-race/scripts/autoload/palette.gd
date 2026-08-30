extends Node
## Single source of truth for colour, type and rounding.
##
## Light and dark are two full palettes; `blend` cross-fades between them so the
## dark-mode toggle is an animated dissolve instead of a hard cut.

signal changed

const LIGHT := {
	"bg": Color("#eaeef5"),
	"bg2": Color("#dfe5ef"),
	"card": Color("#ffffff"),
	"card_alt": Color("#f2f5fa"),
	"sunken": Color("#e8ecf3"),
	"text": Color("#101722"),
	"text_dim": Color("#7d8798"),
	"accent": Color("#1a95ef"),
	"accent_hi": Color("#69c6ff"),
	"accent_soft": Color("#dcefff"),
	"on_accent": Color("#ffffff"),
	"line": Color("#dde3ec"),
	"good": Color("#22b573"),
	"bad": Color("#f2415a"),
	"warn": Color("#f5a524"),
	"shadow": Color(0.24, 0.33, 0.47, 0.16),
}

const DARK := {
	"bg": Color("#0a0d12"),
	"bg2": Color("#0e131a"),
	"card": Color("#151b24"),
	"card_alt": Color("#1c232e"),
	"sunken": Color("#10151d"),
	"text": Color("#f1f5fa"),
	"text_dim": Color("#79839a"),
	"accent": Color("#2ba6ff"),
	"accent_hi": Color("#68d1ff"),
	"accent_soft": Color("#12304a"),
	"on_accent": Color("#ffffff"),
	"line": Color("#232b37"),
	"good": Color("#2fd08a"),
	"bad": Color("#ff5c6e"),
	"warn": Color("#ffb43d"),
	"shadow": Color(0.0, 0.0, 0.0, 0.55),
}

const R_CARD := 34.0
const R_TILE := 22.0
const R_PILL := 999.0

var blend := 0.0  ## 0 = light, 1 = dark
var theme: Theme
var font_medium: Font
var font_bold: Font
var font_black: Font

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fonts()
	blend = 1.0 if bool(SaveData.get_setting("dark", false)) else 0.0
	_rebuild_theme()
	SaveData.settings_changed.connect(_on_setting)


func _on_setting(key: String) -> void:
	if key == "dark":
		set_dark(bool(SaveData.get_setting("dark", false)))


# ------------------------------------------------------------------ colour ---
func c(key: String) -> Color:
	var a: Color = LIGHT.get(key, Color.MAGENTA)
	var b: Color = DARK.get(key, Color.MAGENTA)
	return a.lerp(b, blend)


func is_dark() -> bool:
	return blend > 0.5


func set_dark(dark: bool, animate := true) -> void:
	var target := 1.0 if dark else 0.0
	if is_equal_approx(blend, target):
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or bool(SaveData.get_setting("reduce_motion", false)):
		blend = target
		_rebuild_theme()
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_blend, blend, target, 0.42)


func _set_blend(v: float) -> void:
	blend = v
	_rebuild_theme()


# -------------------------------------------------------------------- type ---
func _build_fonts() -> void:
	font_medium = _system_font(500)
	font_bold = _system_font(680)
	font_black = _system_font(830)


func _system_font(weight: int) -> Font:
	var f := SystemFont.new()
	# SF Pro on iOS/macOS, Roboto on Android, Segoe UI on Windows.
	f.font_names = PackedStringArray([
		"SF Pro Display", "SF Pro Text", "-apple-system", "Helvetica Neue",
		"Segoe UI", "Roboto", "Inter", "Noto Sans", "DejaVu Sans",
	])
	f.font_weight = weight
	f.allow_system_fallback = true
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


# ------------------------------------------------------------------- boxes ---
func card_box(radius := R_CARD, fill_key := "card", shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c(fill_key)
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 12
	if shadow:
		sb.shadow_color = c("shadow")
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 8)
	return sb


func flat_box(radius: float, fill: Color, border := 0.0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 12
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_col
	return sb


# ------------------------------------------------------------------- theme ---
func _rebuild_theme() -> void:
	if theme == null:
		theme = Theme.new()
	theme.default_font = font_medium
	theme.default_font_size = 30

	theme.set_color("font_color", "Label", c("text"))
	theme.set_font("font", "Label", font_medium)
	theme.set_font_size("font_size", "Label", 30)

	theme.set_type_variation("Dim", "Label")
	theme.set_color("font_color", "Dim", c("text_dim"))
	theme.set_font_size("font_size", "Dim", 25)

	theme.set_type_variation("Caps", "Label")
	theme.set_color("font_color", "Caps", c("text_dim"))
	theme.set_font("font", "Caps", font_bold)
	theme.set_font_size("font_size", "Caps", 21)

	theme.set_type_variation("Title", "Label")
	theme.set_color("font_color", "Title", c("text"))
	theme.set_font("font", "Title", font_black)
	theme.set_font_size("font_size", "Title", 54)

	theme.set_type_variation("Huge", "Label")
	theme.set_color("font_color", "Huge", c("text"))
	theme.set_font("font", "Huge", font_black)
	theme.set_font_size("font_size", "Huge", 86)

	theme.set_type_variation("Strong", "Label")
	theme.set_color("font_color", "Strong", c("text"))
	theme.set_font("font", "Strong", font_bold)
	theme.set_font_size("font_size", "Strong", 34)

	# ScrollContainer chrome should stay invisible; the app is touch-first.
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", empty)

	changed.emit()
