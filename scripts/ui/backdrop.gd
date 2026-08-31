class_name Backdrop
extends ColorRect
## Full-screen background: a deep indigo wash with two saturated blooms, so the
## cards and buttons read as lit objects on a dark stage.

const SHADER := preload("res://assets/shaders/backdrop.gdshader")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Palette.changed.connect(_sync)
	resized.connect(_sync)
	_sync()


func _sync() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("base", Palette.c("bg"))
	mat.set_shader_parameter("base2", Palette.c("bg2"))
	mat.set_shader_parameter("bloom", Palette.c("accent_hi"))
	mat.set_shader_parameter("bloom2", Palette.c("accent"))
	mat.set_shader_parameter("bloom_strength", lerpf(0.22, 0.40, Palette.blend))
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
