extends Screen
## Logo, rank progress, Play. Theme toggle sits top left, settings top right.

var _logo: Logo
var _rank: RankBar
var _theme_btn: IconButton
var _stats: Label


func _ready() -> void:
	theme = Palette.theme

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padded(44, 30, 44, 56).add_child(col)

	col.add_child(_top_row())
	col.add_child(spacer(1.0))

	_logo = Logo.new()
	col.add_child(_logo)

	col.add_child(spacer(1.1))
	col.add_child(_rank_card())

	var play := PillButton.new()
	play.text = "Play"
	play.font_size = 40
	play.custom_minimum_size.y = 120
	play.radius = 40.0
	play.pressed.connect(go_game)
	col.add_child(play)

	_stats = Label.new()
	_stats.theme_type_variation = "Dim"
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 23)
	col.add_child(_stats)

	Palette.changed.connect(_sync)
	SaveData.progress_changed.connect(_sync)
	_sync()
	_logo.play_intro()


func _top_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 84
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_theme_btn = IconButton.new()
	_theme_btn.icon = "moon"
	_theme_btn.pressed.connect(_on_theme)
	row.add_child(_theme_btn)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	var settings := IconButton.new()
	settings.icon = "sliders"
	settings.pressed.connect(open_settings)
	row.add_child(settings)
	return row


func _rank_card() -> Control:
	var card := Card.new()
	card.custom_minimum_size.y = 236
	_rank = RankBar.new()
	card.content(40).add_child(_rank)
	return card


func _sync() -> void:
	_theme_btn.icon = "sun" if Palette.is_dark() else "moon"
	_rank.set_mmr(SaveData.mmr, false)
	_stats.text = "Best level %d   ·   %d puzzles solved" % [SaveData.best_level, SaveData.puzzles_solved]
	_stats.add_theme_color_override("font_color", Palette.c("text_dim"))


func _on_theme() -> void:
	SaveData.set_setting("dark", not Palette.is_dark())
