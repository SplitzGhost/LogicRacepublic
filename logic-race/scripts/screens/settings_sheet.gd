extends Control
## Bottom sheet with the usual switches. Slides up over a dimmed backdrop and
## dismisses on tap-outside, the close button or the system back gesture.

signal closed

const SHEET_RATIO := 0.76
## Extra height below the bottom edge so the lower rounded corners stay hidden.
const BOTTOM_BLEED := 60.0

var _dim: ColorRect
var _sheet: Card
var _reset_btn: PillButton
var _reset_armed := false


func _ready() -> void:
	theme = Palette.theme
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_sheet = Card.new()
	_sheet.radius = 48.0
	_sheet.shadow_size = 40
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0 - SHEET_RATIO
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 0.0
	_sheet.offset_right = 0.0
	_sheet.offset_top = 0.0
	# Overshoot the bottom edge so the lower corners never show a rounded gap.
	_sheet.offset_bottom = BOTTOM_BLEED
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)

	_build_content()
	_appear()


func _build_content() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	# The card deliberately overshoots the screen edge, so the content has to be
	# lifted back above it.
	var bottom_pad := 40.0 + BOTTOM_BLEED + float(get_parent().get("inset_bottom"))
	var pad := _sheet.content(44)
	pad.add_theme_constant_override("margin_bottom", int(bottom_pad))
	pad.add_child(col)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_override("font", Palette.font_black)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Palette.c("text"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var close := IconButton.new()
	close.icon = "close"
	close.filled = false
	close.custom_minimum_size = Vector2(72, 72)
	close.tint = "text_dim"
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	col.add_child(head)

	col.add_child(_gap(16))
	col.add_child(_switch_row("Dark appearance", "dark"))
	col.add_child(_divider())
	col.add_child(_switch_row("Sound effects", "sfx"))
	col.add_child(_volume_row())
	col.add_child(_divider())
	col.add_child(_switch_row("Haptics", "haptics"))
	col.add_child(_divider())
	col.add_child(_switch_row("Timer bar", "timer_bar"))
	col.add_child(_divider())
	col.add_child(_switch_row("Reduce motion", "reduce_motion"))

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)

	var stats := Label.new()
	stats.text = "%d rounds  ·  %d puzzles solved  ·  %d remembered" % [
			SaveData.rounds_played, SaveData.puzzles_solved, SaveData.history_size()]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 21)
	stats.add_theme_color_override("font_color", Palette.c("text_dim"))
	col.add_child(stats)

	_reset_btn = PillButton.new()
	_reset_btn.text = "Reset progress"
	_reset_btn.variant = PillButton.Variant.GHOST
	_reset_btn.font_size = 27
	_reset_btn.custom_minimum_size.y = 84
	_reset_btn.pressed.connect(_on_reset)
	col.add_child(_reset_btn)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _divider() -> Control:
	var line := Card.new()
	line.radius = 1.0
	line.shadow = false
	line.fill_key = "line"
	line.custom_minimum_size.y = 2
	return line


func _switch_row(label_text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 96

	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Palette.c("text"))
	row.add_child(label)

	var sw := SwitchControl.new()
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.set_on_silent(bool(SaveData.get_setting(key, false)))
	sw.toggled.connect(func(on: bool) -> void: SaveData.set_setting(key, on))
	row.add_child(sw)
	return row


func _volume_row() -> Control:
	var slider := SliderRow.new()
	slider.label = "Volume"
	slider.value = float(SaveData.get_setting("volume", 0.85))
	slider.value_changed.connect(func(v: float) -> void: SaveData.set_setting("volume", v))
	return slider


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Tap again to erase everything"
		_reset_btn.variant = PillButton.Variant.DANGER
		await get_tree().create_timer(3.5).timeout
		if is_instance_valid(_reset_btn) and _reset_armed:
			_reset_armed = false
			_reset_btn.text = "Reset progress"
			_reset_btn.variant = PillButton.Variant.GHOST
		return
	SaveData.reset_progress()
	Sfx.play("over", 1.2, 0.7)
	_reset_armed = false
	_reset_btn.text = "Progress erased"
	_reset_btn.variant = PillButton.Variant.GHOST
	_reset_btn.enabled = false


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			closed.emit()


# ------------------------------------------------------------- transition ---
## The slide is driven through the anchor offsets rather than `position`, which
## would detach the sheet from its anchored resting place.
func _slide_to(offset: float, duration: float, ease_type: Tween.EaseType) -> Tween:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	tw.tween_property(_sheet, "offset_top", offset, duration)
	tw.parallel().tween_property(_sheet, "offset_bottom", BOTTOM_BLEED + offset, duration)
	return tw


func _appear() -> void:
	if bool(SaveData.get_setting("reduce_motion", false)):
		_dim.color = Color(0, 0, 0, 0.45)
		return
	var travel := get_viewport_rect().size.y
	_sheet.offset_top = travel
	_sheet.offset_bottom = BOTTOM_BLEED + travel
	var tw := _slide_to(0.0, 0.38, Tween.EASE_OUT)
	tw.parallel().tween_property(_dim, "color", Color(0, 0, 0, 0.45), 0.28)


func dismiss() -> void:
	if bool(SaveData.get_setting("reduce_motion", false)):
		queue_free()
		return
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := _slide_to(get_viewport_rect().size.y, 0.28, Tween.EASE_IN)
	tw.parallel().tween_property(_dim, "color", Color(0, 0, 0, 0.0), 0.24)
	tw.tween_callback(queue_free)
