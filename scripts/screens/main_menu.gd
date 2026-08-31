extends Screen
## Logo, rank progress, best-level record, and the two buttons.

var _logo: Logo
var _rank: RankBar
var _best: BestCard


class BestCard:
	extends Card
	## The personal record, given its own panel next to the rank.

	var level := 1:
		set(value):
			level = value
			queue_redraw()

	func _init() -> void:
		super()
		fill_key = "card_alt"
		custom_minimum_size.y = 116

	func _draw() -> void:
		super()
		var pad := 32.0
		var icon_r := size.y * 0.30
		Icons.draw(self, "trophy", Vector2(pad + icon_r, size.y * 0.5), icon_r,
				Palette.c("gold"), maxf(3.0, icon_r * 0.16))

		var text_x := pad + icon_r * 2.0 + 22.0
		draw_string(Palette.font_bold, Vector2(text_x, size.y * 0.5 - 8.0), "BEST LEVEL",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Palette.c("text_dim"))

		var value := str(level)
		var w := Palette.font_black.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		draw_string(Palette.font_black, Vector2(size.x - pad - w, size.y * 0.5 + 18.0),
				value, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Palette.c("gold"))


func _ready() -> void:
	theme = Palette.theme

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padded(44, 34, 44, 56).add_child(col)

	col.add_child(spacer(0.22))

	_logo = Logo.new()
	col.add_child(_logo)

	col.add_child(spacer(0.40))
	col.add_child(_rank_card())

	_best = BestCard.new()
	col.add_child(_best)

	col.add_child(spacer(0.30))
	col.add_child(_buttons())
	col.add_child(spacer(0.75))

	SaveData.progress_changed.connect(_sync)
	SaveData.settings_changed.connect(_on_setting)
	_sync()
	_logo.play_intro()


func _rank_card() -> Control:
	var card := Card.new()
	card.custom_minimum_size.y = 236
	_rank = RankBar.new()
	card.content(40).add_child(_rank)
	return card


## Play and Settings sit together as one centred block, slightly inset from the
## page margin so they read as a pair rather than as page-wide bars.
func _buttons() -> Control:
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 26)
	inset.add_theme_constant_override("margin_right", 26)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(col)

	var play := PillButton.new()
	play.text = "PLAY"
	play.font_size = 42
	play.custom_minimum_size.y = 124
	play.radius = 36.0
	play.pressed.connect(go_game)
	col.add_child(play)

	var settings := PillButton.new()
	settings.text = "Settings"
	settings.variant = PillButton.Variant.SECONDARY
	settings.font_size = 32
	settings.custom_minimum_size.y = 100
	settings.radius = 32.0
	settings.pressed.connect(open_settings)
	col.add_child(settings)
	return inset


func _on_setting(key: String) -> void:
	if key.begins_with("dev/"):
		_sync()


func _sync() -> void:
	_rank.set_iq(SaveData.iq, false)
	_best.level = SaveData.best_level
