class_name Screen
extends Control
## Base for the full-screen views. `root()` is the Main controller, reached
## through the tree so that screens never have to import it (which would create
## a preload cycle).


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func root() -> Node:
	return get_tree().current_scene


func go_menu() -> void:
	root().call("go_menu")


func go_game() -> void:
	root().call("go_game")


func go_result(summary: Dictionary) -> void:
	root().call("go_result", summary)


func open_settings() -> void:
	root().call("open_settings")


func inset_bottom() -> float:
	return float(root().get("inset_bottom"))


func spacer(ratio := 1.0) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func padded(left := 44, top := 30, right := 44, bottom := 42) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	return m
