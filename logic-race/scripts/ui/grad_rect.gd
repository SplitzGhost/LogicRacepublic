class_name GradRect
extends ColorRect
## Anti-aliased rounded rectangle with a linear gradient, used for every accent
## surface (play button, rank badge, selected tiles).

const SHADER := preload("res://assets/shaders/grad_rect.gdshader")

var col_a := Color("#69c6ff")
var col_b := Color("#0f84ea")
var radius := 28.0
var grad_dir := Vector2(0.4, 1.0)
var gloss := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


func _ready() -> void:
	resized.connect(apply)
	apply()


func set_colors(a: Color, b: Color) -> void:
	col_a = a
	col_b = b
	apply()


func apply() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("col_a", col_a)
	mat.set_shader_parameter("col_b", col_b)
	mat.set_shader_parameter("grad_dir", grad_dir)
	mat.set_shader_parameter("gloss", gloss)
