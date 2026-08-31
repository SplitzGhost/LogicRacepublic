extends Screen
## Round summary: how far you got, what it did to your IQ, and the rank bar
## moving to its new position.

var summary: Dictionary = {}

var _rank: RankBar
var _delta_label: TintLabel
var _breakdown: TintLabel


func _ready() -> void:
	theme = Palette.theme

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padded(44, 60, 44, 48).add_child(col)

	col.add_child(spacer(0.7))
	col.add_child(TintLabel.centered("ROUND OVER", 24, "text_dim", Palette.font_bold))
	col.add_child(TintLabel.centered("Level %d" % int(summary.get("level", 1)), 92,
			"text", Palette.font_black))

	col.add_child(spacer(0.5))
	col.add_child(_iq_card())
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


func _iq_card() -> Control:
	var card := Card.new()
	card.custom_minimum_size.y = 388
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.content(40).add_child(col)

	var delta := int(summary.get("delta", 0))
	_delta_label = TintLabel.centered(
			("+%d IQ" % delta) if delta >= 0 else ("%d IQ" % delta),
			60, "good" if delta >= 0 else "bad", Palette.font_black)
	col.add_child(_delta_label)

	_breakdown = TintLabel.centered(_breakdown_text(), 23, "text_dim")
	_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_breakdown)

	_rank = RankBar.new()
	_rank.compact = true
	_rank.custom_minimum_size.y = 162
	_rank.iq = int(summary.get("iq_before", 0))
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
		_rank.set_iq(int(summary.get("new_iq", 0)), false)
		return
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self):
		return
	_rank.set_iq(int(summary.get("new_iq", 0)), true)
	if bool(summary.get("promoted", false)):
		await get_tree().create_timer(0.7).timeout
		if not is_instance_valid(self):
			return
		Sfx.play("rank_up")
		Sfx.haptic(30)
		_delta_label.text = "%s!" % String(summary.get("rank_after", ""))
		_delta_label.frozen = true
		_delta_label.add_theme_color_override("font_color",
				Ranks.rank_color(int(summary.get("new_iq", 0))))
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_delta_label.pivot_offset = _delta_label.size * 0.5
		tw.tween_property(_delta_label, "scale", Vector2(1.12, 1.12), 0.2)
		tw.tween_property(_delta_label, "scale", Vector2.ONE, 0.3)
