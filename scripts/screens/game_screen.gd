extends Screen
## One ranked run: level, two lives, a clock per puzzle.
## Only the level, the lives and a hairline timer are on screen -- the puzzle
## itself owns the middle.

const START_LIVES := 2

const VIEWS := {
	"sudoku": preload("res://scripts/puzzles/sudoku_view.gd"),
	"pattern": preload("res://scripts/puzzles/pattern_view.gd"),
	"target": preload("res://scripts/puzzles/target_view.gd"),
	"mines": preload("res://scripts/puzzles/mines_view.gd"),
	"math": preload("res://scripts/puzzles/math_view.gd"),
}

var level := 1
var lives := START_LIVES
var cleared := 0
var time_left := 0.0
var time_limit := 1.0
var time_ratios: Array[float] = []

var _running := false
var _level_label: Label
var _lives_dots: HudBits.LifeDots
var _timer_line: HudBits.TimerLine
var _slot: Control
var _view: PuzzleView
var _prefetch: Dictionary = {}
var _low_time_warned := false
var _ending := false
var _quit_armed := false
var _quit_btn: IconButton


func _ready() -> void:
	theme = Palette.theme

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padded(40, 26, 40, 34).add_child(col)

	col.add_child(_top_row())

	_timer_line = HudBits.TimerLine.new()
	_timer_line.visible = bool(SaveData.get_setting("timer_bar", true))
	col.add_child(_timer_line)

	_slot = Control.new()
	_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_slot)

	Palette.changed.connect(_sync_colors)
	SaveData.settings_changed.connect(_on_setting)
	_sync_colors()
	_next_puzzle(false)


func _top_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 74
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_quit_btn = IconButton.new()
	_quit_btn.icon = "back"
	_quit_btn.filled = false
	_quit_btn.custom_minimum_size = Vector2(64, 64)
	_quit_btn.tint = "text_dim"
	_quit_btn.pressed.connect(_on_quit)
	row.add_child(_quit_btn)

	_level_label = Label.new()
	_level_label.add_theme_font_override("font", Palette.font_black)
	_level_label.add_theme_font_size_override("font_size", 30)
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_level_label)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	_lives_dots = HudBits.LifeDots.new()
	_lives_dots.total = START_LIVES
	_lives_dots.left = lives
	_lives_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lives_dots.custom_minimum_size = Vector2(130, 64)
	row.add_child(_lives_dots)
	return row


func _sync_colors() -> void:
	if _level_label != null:
		_level_label.add_theme_color_override("font_color", Palette.c("text"))


# ----------------------------------------------------------------- puzzle ---
func _next_puzzle(animate := true) -> void:
	_disarm_quit()
	var difficulty := Ranks.difficulty(level, SaveData.mmr)
	var d: Dictionary = _prefetch
	_prefetch = {}
	if d.is_empty():
		d = PuzzleFactory.make(difficulty)
	if d.is_empty():
		push_error("LogicRace: puzzle generation failed")
		_end_round()
		return

	var script: GDScript = VIEWS[String(d["pool"])]
	var view: PuzzleView = script.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.add_child(view)
	view.setup(d)
	view.solved.connect(_on_solved)
	view.failed.connect(_on_failed)
	_view = view

	_level_label.text = "LEVEL %d" % level
	time_limit = maxf(float(d["time"]), 5.0)
	time_left = time_limit
	_timer_line.ratio = 1.0
	_low_time_warned = false
	_running = true

	if animate and not bool(SaveData.get_setting("reduce_motion", false)):
		view.modulate.a = 0.0
		view.position.x = 44.0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(view, "modulate:a", 1.0, 0.24)
		tw.parallel().tween_property(view, "position:x", 0.0, 0.32)

	_queue_prefetch()


## Builds the next puzzle while the player is reading the current one, so the
## generators never stall a transition.
func _queue_prefetch() -> void:
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(self) or not _running:
		return
	if _prefetch.is_empty():
		_prefetch = PuzzleFactory.make(Ranks.difficulty(level + 1, SaveData.mmr))


func _clear_view(delay: float) -> void:
	var old := _view
	_view = null
	if old == null:
		return
	if bool(SaveData.get_setting("reduce_motion", false)):
		old.queue_free()
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(old, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(old, "position:x", -44.0, 0.22)
	tw.tween_callback(old.queue_free)


func _process(delta: float) -> void:
	if not _running:
		return
	time_left = maxf(0.0, time_left - delta)
	_timer_line.ratio = time_left / time_limit
	if not _low_time_warned and time_left <= time_limit * 0.12:
		_low_time_warned = true
		Sfx.play("tick", 1.0, 0.8)
	if time_left <= 0.0:
		_on_timeout()


# --------------------------------------------------------------- outcomes ---
func _on_solved() -> void:
	if not _running:
		return
	_running = false
	time_ratios.append(clampf(time_left / time_limit, 0.0, 1.0))
	cleared += 1
	level += 1
	Sfx.play("correct")
	Sfx.haptic(14)
	_advance(0.55)


func _on_failed() -> void:
	if not _running:
		return
	_running = false
	_lose_life(0.85)


func _on_timeout() -> void:
	if not _running:
		return
	_running = false
	if _view != null:
		_view.on_timeout()
	_lose_life(1.15)


func _lose_life(delay: float) -> void:
	lives -= 1
	_lives_dots.set_lives(lives)
	Sfx.play("wrong")
	Sfx.haptic(45)
	if lives <= 0:
		_timer_line.ratio = 0.0
		await get_tree().create_timer(delay).timeout
		if is_instance_valid(self):
			_end_round()
		return
	_advance(delay)


func _advance(delay: float) -> void:
	_clear_view(delay)
	await get_tree().create_timer(delay + 0.20).timeout
	if is_instance_valid(self) and not _ending:
		_next_puzzle()


func _end_round() -> void:
	if _ending:
		return
	_ending = true
	_running = false
	Sfx.play("over")

	var avg := 0.0
	for r in time_ratios:
		avg += r
	if not time_ratios.is_empty():
		avg /= float(time_ratios.size())

	var before := SaveData.mmr
	var result := Ranks.score_round(before, cleared, avg)
	SaveData.apply_round(int(result["new_mmr"]), level, cleared)

	result["level"] = level
	result["cleared"] = cleared
	result["avg_time_left"] = avg
	result["mmr_before"] = before
	go_result(result)


## Leaving mid-round is not an escape hatch: the round is scored exactly as if
## the last life had been lost. Two taps, so it never happens by accident.
func _on_quit() -> void:
	if _ending:
		return
	if not _quit_armed:
		_quit_armed = true
		_quit_btn.tint = "bad"
		_quit_btn.queue_redraw()
		_level_label.text = "END ROUND?"
		_level_label.add_theme_color_override("font_color", Palette.c("bad"))
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(self) and _quit_armed:
			_disarm_quit()
		return
	_running = false
	_end_round()


func _disarm_quit() -> void:
	if not _quit_armed:
		return
	_quit_armed = false
	_quit_btn.tint = "text_dim"
	_quit_btn.queue_redraw()
	_level_label.text = "LEVEL %d" % level
	_level_label.add_theme_color_override("font_color", Palette.c("text"))


func _on_setting(key: String) -> void:
	if key == "timer_bar" and _timer_line != null:
		_timer_line.visible = bool(SaveData.get_setting("timer_bar", true))
