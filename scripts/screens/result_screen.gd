extends Screen
## Round summary: how far you got, what it did to your MMR, and the rank bar
## moving to its new position.

var summary: Dictionary = {}

var _rank: RankBar
var _delta_label: Label
var _breakdown: Label


func _ready() -> void:
	theme = Palette.theme

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padded(44, 60, 44, 48).add_child(col)

	col.add_child(spacer(0.7))

	var caps := Label.new()
	caps.text = "ROUND OVER"
	caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caps.add_theme_font_override("font", Palette.font_bold)
	caps.add_theme_font_size_override("font_size", 24)
	caps.add_theme_color_override("font_color", Palette.c("text_dim"))
	col.add_child(caps)

	var level := Label.new()
	level.text = "Level %d" % int(summary.get("level", 1))
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.add_theme_font_override("font", Palette.font_black)
	level.add_theme_font_size_override("font_size", 92)
	level.add_theme_color_override("font_color", Palette.c("text"))
	col.add_child(level)

	col.add_child(spacer(0.5))
	col.add_child(_mmr_card())
	col.add_child(spacer(0.6))

	var again := PillButton.new()
	again.text = "Play again"
	again.font_size = 36
	again.custom_minimum_size.y = 118
	again.radius = 40.0
	again.pressed.connect(go_game)
	col.add_child(again)

	var menu := PillButton.new()
	menu.text = "Main menu"
	menu.variant = PillButton.Variant.GHOST
	menu.font_size = 30
	menu.custom_minimum_size.y = 88
	menu.pressed.connect(go_menu)
	col.add_child(menu)

	_animate()


func _mmr_card() -> Control:
	var card := Card.new()
	card.custom_minimum_size.y = 388
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.content(40).add_child(col)

	var delta := int(summary.get("delta", 0))
	_delta_label = Label.new()
	_delta_label.text = ("+%d MMR" % delta) if delta >= 0 else ("%d MMR" % delta)
	_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delta_label.add_theme_font_override("font", Palette.font_black)
	_delta_label.add_theme_font_size_override("font_size", 60)
	_delta_label.add_theme_color_override("font_color",
			Palette.c("good") if delta >= 0 else Palette.c("bad"))
	col.add_child(_delta_label)

	_breakdown = Label.new()
	_breakdown.text = _breakdown_text()
	_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_breakdown.add_theme_font_size_override("font_size", 23)
	_breakdown.add_theme_color_override("font_color", Palette.c("text_dim"))
	col.add_child(_breakdown)

	_rank = RankBar.new()
	_rank.compact = true
	_rank.custom_minimum_size.y = 152
	_rank.mmr = int(summary.get("mmr_before", 0))
	col.add_child(_rank)
	return card


func _breakdown_text() -> String:
	var cleared := int(summary.get("cleared", 0))
	var speed := int(summary.get("speed_delta", 0))
	var expected := float(summary.get("expected", 0.0))
	var parts := PackedStringArray()
	parts.append("%d cleared" % cleared)
	parts.append("%.1f expected" % expected)
	if speed > 0:
		parts.append("speed +%d" % speed)
	else:
		var left := int(round(float(summary.get("avg_time_left", 0.0)) * 100.0))
		parts.append("%d%% time left" % left)
	return "  ·  ".join(parts)


func _animate() -> void:
	if bool(SaveData.get_setting("reduce_motion", false)):
		_rank.set_mmr(int(summary.get("new_mmr", 0)), false)
		return
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self):
		return
	_rank.set_mmr(int(summary.get("new_mmr", 0)), true)
	if bool(summary.get("promoted", false)):
		await get_tree().create_timer(0.7).timeout
		if not is_instance_valid(self):
			return
		Sfx.play("rank_up")
		Sfx.haptic(30)
		_delta_label.text = "%s!" % String(summary.get("rank_after", ""))
		_delta_label.add_theme_color_override("font_color", Ranks.rank_color(
				int(summary.get("new_mmr", 0))))
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_delta_label.pivot_offset = _delta_label.size * 0.5
		tw.tween_property(_delta_label, "scale", Vector2(1.12, 1.12), 0.2)
		tw.tween_property(_delta_label, "scale", Vector2.ONE, 0.3)
