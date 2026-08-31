extends Node
## Single source of truth for colour, type and rounding.
##
## Light and dark are two full palettes; `blend` cross-fades between them so the
## dark-mode toggle is an animated dissolve instead of a hard cut.

signal changed

## Arcade violet. Deep indigo ground, saturated violet-to-fuchsia gradients on
## anything you can press, mint green for success, gold for rewards -- the
## vocabulary of a casual mobile game rather than a system settings panel.
const DARK := {
	"bg": Color("#150e35"),
	"bg2": Color("#241553"),
	"card": Color("#2d1f63"),
	"card_alt": Color("#3a2a7c"),
	"sunken": Color("#1c1246"),
	"text": Color("#ffffff"),
	"text_dim": Color("#a99ada"),
	"accent": Color("#8b2ce0"),
	"accent_hi": Color("#e05cf5"),
	"accent_soft": Color("#3d2a80"),
	"accent_deep": Color("#5a1a9c"),
	"on_accent": Color("#ffffff"),
	"line": Color("#4a3691"),
	"good": Color("#2bd97b"),
	"good_hi": Color("#7ef2ae"),
	"good_deep": Color("#12924b"),
	"bad": Color("#ff4d6d"),
	"warn": Color("#ffc233"),
	"gold": Color("#ffcf3d"),
	"gold_deep": Color("#e08c17"),
	"glass": Color(1.0, 1.0, 1.0, 0.14),
	"shadow": Color(0.03, 0.0, 0.12, 0.65),
}

const LIGHT := {
	"bg": Color("#f0ebff"),
	"bg2": Color("#ded4fb"),
	"card": Color("#ffffff"),
	"card_alt": Color("#f4efff"),
	"sunken": Color("#e7dffa"),
	"text": Color("#2a1466"),
	"text_dim": Color("#7d6cb5"),
	"accent": Color("#8b2ce0"),
	"accent_hi": Color("#e05cf5"),
	"accent_soft": Color("#ede2ff"),
	"accent_deep": Color("#5a1a9c"),
	"on_accent": Color("#ffffff"),
	"line": Color("#ddd2f5"),
	"good": Color("#1fbf6a"),
	"good_hi": Color("#5fe39c"),
	"good_deep": Color("#0f8a4b"),
	"bad": Color("#f0355c"),
	"warn": Color("#f0a81f"),
	"gold": Color("#f5b615"),
	"gold_deep": Color("#c97a0c"),
	"glass": Color(0.16, 0.06, 0.34, 0.10),
	"shadow": Color(0.30, 0.18, 0.55, 0.20),
}

## The vivid board/tube palette used by the puzzles that need many distinct
## colours. Same hues in both themes so a puzzle never changes meaning.
const CHIPS: Array[Color] = [
	Color("#ff4d6d"), Color("#ff9f1c"), Color("#ffd60a"), Color("#2bd97b"),
	Color("#21c7d4"), Color("#3d8bff"), Color("#a05cff"), Color("#ff5cc8"),
	Color("#8bd345"), Color("#ff7a45"),
]

const R_CARD := 34.0
const R_TILE := 22.0
const R_PILL := 999.0
## How far a pressable surface sits above its own shadow plate.
const BEVEL := 9.0

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
	_build_theme()
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
		changed.emit()
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_blend, blend, target, 0.42)


## Only the `changed` signal fires while blending. Everything that paints reads
## `c()` at draw time, so the Theme resource itself never has to be touched --
## rebuilding it per frame would re-propagate a theme change through the whole
## tree sixty times a second.
func _set_blend(v: float) -> void:
	blend = v
	changed.emit()


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


## Panel with the faint light edge that separates a card from the deep
## background in the arcade look.
func panel_box(radius := R_CARD, fill_key := "card") -> StyleBoxFlat:
	var sb := flat_box(radius, c(fill_key))
	sb.set_border_width_all(2)
	sb.border_color = c("glass")
	sb.shadow_color = c("shadow")
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 10)
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
## Built once. It carries type only -- no colours, so it never has to change.
## Colour comes from `c()` for painted controls and from TintLabel for text.
func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_medium
	theme.default_font_size = 30

	theme.set_font("font", "Label", font_medium)
	theme.set_font_size("font_size", "Label", 30)

	# ScrollContainer chrome should stay invisible; the app is touch-first.
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
