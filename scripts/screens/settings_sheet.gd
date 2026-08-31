extends Control
## Bottom sheet with the usual switches plus the developer tools. Slides up over
## a dimmed backdrop and dismisses on tap-outside, the close button or the system
## back gesture.

signal closed

const SHEET_RATIO := 0.84
## Extra height below the bottom edge so the lower rounded corners stay hidden.
const BOTTOM_BLEED := 60.0
const POOL_CHOICES: Array[String] = [
	"", "sudoku", "pattern", "target", "mines", "math", "chess", "water",
]

var _dim: ColorRect
var _sheet: Card
var _reset_btn: PillButton
var _reset_armed := false
var _dev_box: VBoxContainer
var _dev_rank: TintLabel
var _dev_level: TintLabel
var _dev_pool: PillButton


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
	# The card deliberately overshoots the screen edge, so the content has to be
	# lifted back above it.
	var bottom_pad := 30.0 + BOTTOM_BLEED + float(get_parent().get("inset_bottom"))
	var pad := _sheet.content(44)
	pad.add_theme_constant_override("margin_bottom", int(bottom_pad))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	pad.add_child(outer)

	var head := HBoxContainer.new()
	var title := TintLabel.make("Settings", 46, "text", Palette.font_black)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var close := IconButton.new()
	close.icon = "close"
	close.filled = false
	close.custom_minimum_size = Vector2(72, 72)
	close.tint = "text_dim"
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	outer.add_child(head)

	# The developer rows make the sheet taller than the screen, so it scrolls.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := MarginContainer.new()
	# Keep the content clear of the scrollbar track.
	inner.add_theme_constant_override("margin_right", 26)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	inner.add_child(col)
	var bar := scroll.get_v_scroll_bar()
	bar.modulate = Color(1, 1, 1, 0.35)

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
	col.add_child(_divider())
	col.add_child(_dev_switch_row())
	col.add_child(_dev_section())

	col.add_child(_gap(18))
	_reset_btn = PillButton.new()
	_reset_btn.text = "Reset progress"
	_reset_btn.variant = PillButton.Variant.GHOST
	_reset_btn.font_size = 27
	_reset_btn.custom_minimum_size.y = 84
	_reset_btn.pressed.connect(_on_reset)
	col.add_child(_reset_btn)

	var stats := TintLabel.centered("", 21, "text_dim")
	stats.text = "%d rounds  ·  %d puzzles remembered" % [
			SaveData.rounds_played, SaveData.history_size()]
	col.add_child(stats)
	col.add_child(_gap(12))


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _divider() -> Control:
	var line := Card.new()
	line.radius = 1.0
	line.shadow = false
	line.border_key = ""
	line.fill_key = "line"
	line.custom_minimum_size.y = 2
	return line


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 92
	var label := TintLabel.make(label_text, 30, "text")
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _switch_row(label_text: String, key: String) -> Control:
	var row := _row(label_text)
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


# ------------------------------------------------------------ developer ---
func _dev_switch_row() -> Control:
	var row := _row("Developer mode")
	var sw := SwitchControl.new()
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.set_on_silent(SaveData.dev_enabled())
	sw.toggled.connect(_on_dev_toggle)
	row.add_child(sw)
	return row


func _on_dev_toggle(on: bool) -> void:
	SaveData.set_dev_mode(on)
	_dev_box.visible = on
	_sync_dev()


## Testing tools. Everything here is undone the moment developer mode is
## switched back off.
func _dev_section() -> Control:
	_dev_box = VBoxContainer.new()
	_dev_box.add_theme_constant_override("separation", 8)
	_dev_box.visible = SaveData.dev_enabled()

	var note := TintLabel.make("Progress is restored when you turn this off.", 21, "text_dim")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dev_box.add_child(note)

	var iq_row := _row("IQ points")
	_dev_rank = TintLabel.make("", 23, "accent_hi", Palette.font_bold)
	_dev_rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	iq_row.add_child(_dev_rank)
	iq_row.add_child(_step_button("−", func() -> void: _bump_iq(-400)))
	iq_row.add_child(_step_button("+", func() -> void: _bump_iq(400)))
	_dev_box.add_child(iq_row)

	var rank_row := _row("Rank step")
	rank_row.add_child(_step_button("−", func() -> void: _step_rank(-1)))
	rank_row.add_child(_step_button("+", func() -> void: _step_rank(1)))
	_dev_box.add_child(rank_row)

	var level_row := _row("Start level")
	_dev_level = TintLabel.make("", 23, "accent_hi", Palette.font_bold)
	_dev_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_row.add_child(_dev_level)
	level_row.add_child(_step_button("−", func() -> void: _bump_level(-5)))
	level_row.add_child(_step_button("+", func() -> void: _bump_level(5)))
	_dev_box.add_child(level_row)

	var pool_row := _row("Force pool")
	_dev_pool = PillButton.new()
	_dev_pool.variant = PillButton.Variant.SECONDARY
	_dev_pool.font_size = 24
	_dev_pool.radius = 22.0
	_dev_pool.custom_minimum_size = Vector2(196, 74)
	_dev_pool.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dev_pool.pressed.connect(_cycle_pool)
	pool_row.add_child(_dev_pool)
	_dev_box.add_child(pool_row)

	_dev_box.add_child(_dev_switch("Infinite lives", "infinite_lives"))
	_dev_box.add_child(_dev_switch("Freeze timer", "freeze_timer"))

	_sync_dev()
	return _dev_box


func _dev_switch(label_text: String, key: String) -> Control:
	var row := _row(label_text)
	var sw := SwitchControl.new()
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.set_on_silent(bool(SaveData.dev_get(key, false)))
	sw.toggled.connect(func(on: bool) -> void: SaveData.dev_set(key, on))
	row.add_child(sw)
	return row


func _step_button(label_text: String, action: Callable) -> PillButton:
	var b := PillButton.new()
	b.text = label_text
	b.variant = PillButton.Variant.SECONDARY
	b.font_size = 34
	b.radius = 22.0
	b.custom_minimum_size = Vector2(76, 74)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	return b


func _bump_iq(delta: int) -> void:
	SaveData.iq = maxi(0, SaveData.iq + delta)
	SaveData.progress_changed.emit()
	SaveData.save_game()
	_sync_dev()


## Jumps to the floor of the next or previous division.
func _step_rank(direction: int) -> void:
	var tier := Ranks.tier_of(SaveData.iq)
	var division := Ranks.division_of(SaveData.iq)
	var step := tier * Ranks.DIVISIONS + division + direction
	step = clampi(step, 0, Ranks.RANKS.size() * Ranks.DIVISIONS - 1)
	SaveData.iq = Ranks.division_floor(step / Ranks.DIVISIONS, step % Ranks.DIVISIONS)
	SaveData.progress_changed.emit()
	SaveData.save_game()
	_sync_dev()


func _bump_level(delta: int) -> void:
	SaveData.dev_set("start_level", maxi(1, int(SaveData.dev_get("start_level", 1)) + delta))
	_sync_dev()


func _cycle_pool() -> void:
	var current := String(SaveData.dev_get("pool", ""))
	var idx := POOL_CHOICES.find(current)
	SaveData.dev_set("pool", POOL_CHOICES[(idx + 1) % POOL_CHOICES.size()])
	_sync_dev()


func _sync_dev() -> void:
	if _dev_rank == null:
		return
	_dev_rank.text = "%d · %s" % [SaveData.iq, Ranks.rank_name(SaveData.iq)]
	_dev_level.text = str(int(SaveData.dev_get("start_level", 1)))
	var pool := String(SaveData.dev_get("pool", ""))
	_dev_pool.text = "Random" if pool == "" else pool.capitalize()


# ----------------------------------------------------------------- reset ---
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
	_sync_dev()


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
