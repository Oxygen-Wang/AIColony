class_name AccentBorderBeamLayer
extends ColorRect

## Theme-accent beam traveling along a rounded-rect outline (not chat-specific).
## Caller aligns this overlay to the target control — see AgentChatInput, UserBubble.

const BEAM_SHADER := preload("res://agent/ui/shaders/accent_border_beam.gdshader")
## Outward margin so glow can draw outside the panel (>= half GLOW_W in shader).
const BEAM_OUTSET := 4.0

var expanded_shape: bool = false
var fixed_corner_radius: float = -1.0
var highlight_strength: float = 0.55
var beam_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	color = Color(1.0, 1.0, 1.0, 0.0)
	ensure_material()
	AgentEvents.events.theme_color_changed.connect(on_ui_theme_changed)
	AgentEvents.events.theme_changed.connect(on_ui_theme_changed)
	if not resized.is_connected(sync_shader_uniforms):
		resized.connect(sync_shader_uniforms)
	sync_shader_uniforms()
	pass


func on_ui_theme_changed() -> void:
	sync_shader_uniforms()
	pass


func set_shape(is_expanded: bool) -> void:
	expanded_shape = is_expanded
	sync_shader_uniforms()
	pass


func set_fixed_corner_radius(radius: float) -> void:
	fixed_corner_radius = radius
	sync_shader_uniforms()
	pass


func set_highlight_strength(strength: float) -> void:
	highlight_strength = clampf(strength, 0.0, 1.0)
	sync_shader_uniforms()
	pass


func wrap_size_from_layout() -> Vector2:
	var beam_size := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if beam_size.x < 1.0 or beam_size.y < 1.0:
		beam_size = size
	return beam_size - Vector2(BEAM_OUTSET * 2.0, BEAM_OUTSET * 2.0)


func corner_radius_for_size() -> float:
	if fixed_corner_radius >= 0.0:
		return fixed_corner_radius
	var wrap_size := wrap_size_from_layout()
	if expanded_shape:
		return 16.0
	return maxf(wrap_size.y * 0.5, 1.0)


func ensure_material() -> void:
	if beam_material != null:
		return
	beam_material = ShaderMaterial.new()
	beam_material.shader = BEAM_SHADER
	material = beam_material
	pass


func sync_shader_uniforms() -> void:
	ensure_material()
	var beam_size := size
	if beam_size.x < 1.0 or beam_size.y < 1.0:
		beam_size = Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if beam_size.x < 1.0 or beam_size.y < 1.0:
		return
	beam_material.set_shader_parameter("accent_color", AgentColors.theme_color)
	beam_material.set_shader_parameter("strength", highlight_strength)
	beam_material.set_shader_parameter("corner_radius", corner_radius_for_size())
	beam_material.set_shader_parameter("rect_size", beam_size)
	beam_material.set_shader_parameter("edge_pad", BEAM_OUTSET)
	pass
