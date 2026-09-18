class_name ThemeColorSelect
extends RefCounted

## Toolbar control — flat paintbrush icon (accent bristles) + ColorPicker popup.

const BUTTON_SIZE := 28
const ICON_DRAW_SIZE := 24
const ICON_SIZE := 14

var button: Button
var popup: PopupPanel
var color_picker: ColorPicker


func setup(p_button: Button) -> void:
	button = p_button
	AgentColors.load_theme_color_from_settings()
	build_popup()
	button.text = ""
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	AgentEvents.events.theme_changed.connect(on_ui_theme_changed)
	AgentEvents.events.theme_color_changed.connect(on_ui_theme_changed)
	on_ui_theme_changed()
	pass


func on_ui_theme_changed() -> void:
	color_picker.set_block_signals(true)
	color_picker.color = AgentColors.theme_color
	color_picker.set_block_signals(false)
	apply_theme()
	pass


func build_popup() -> void:
	popup = PopupPanel.new()
	color_picker = ColorPicker.new()
	color_picker.edit_alpha = true
	color_picker.color = AgentColors.theme_color
	color_picker.custom_minimum_size = Vector2(300, 320)
	color_picker.color_changed.connect(on_picker_color_changed)
	popup.add_child(color_picker)
	button.add_child(popup)
	pass


func apply_theme() -> void:
	button.tooltip_text = "Theme color"
	AgentToolbarButton.style(button, "Theme color", BUTTON_SIZE / 2)
	apply_equal_icon_margins(2)
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_constant_override("icon_max_height", ICON_SIZE)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	update_icon(button.is_hovered())
	pass


func apply_equal_icon_margins(margin: int) -> void:
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var box := button.get_theme_stylebox(state_name) as StyleBoxFlat
		if box == null:
			continue
		box.content_margin_left = margin
		box.content_margin_right = margin
		box.content_margin_top = margin
		box.content_margin_bottom = margin
	pass


func update_icon(hovered: bool) -> void:
	var accent := AgentColors.theme_accent_solid()
	if hovered:
		accent = accent.lightened(0.10)
	var handle := AgentColors.toolbar_muted
	if hovered:
		handle = AgentColors.toolbar_title
	button.icon = make_brush_icon(accent, handle)
	pass


## Side-view flat brush on one spine: grip upper-right → ferrule → bristle tip lower-left.
func make_brush_icon(accent: Color, handle: Color) -> ImageTexture:
	var s := ICON_DRAW_SIZE
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fs := float(s)
	var grip := Vector2(fs * 0.78, fs * 0.17)
	var tip := Vector2(fs * 0.24, fs * 0.76)
	var spine := tip - grip
	var spine_len := spine.length()
	var u := spine / spine_len
	var axis_angle := atan2(u.y, u.x)
	var handle_a := grip
	var handle_b := grip + u * (spine_len * 0.58)
	var ferrule_a := handle_b
	var ferrule_b := grip + u * (spine_len * 0.74)
	var bristle_center := grip + u * (spine_len * 0.88)
	var handle_r := fs * 0.075
	var ferrule_r := fs * 0.062
	var bristle_rx := fs * 0.17
	var bristle_ry := fs * 0.115
	var bristle_angle := axis_angle
	var ferrule_col := handle.lightened(0.10)
	for y in range(s):
		for x in range(s):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var layers: Array[Color] = []
			var handle_a_alpha := capsule_alpha(p, handle_a, handle_b, handle_r)
			if handle_a_alpha > 0.0:
				layers.append(Color(handle.r, handle.g, handle.b, handle_a_alpha))
			var ferrule_alpha := capsule_alpha(p, ferrule_a, ferrule_b, ferrule_r)
			if ferrule_alpha > 0.0:
				layers.append(Color(ferrule_col.r, ferrule_col.g, ferrule_col.b, ferrule_alpha))
			var bristle_alpha := ellipse_alpha(p, bristle_center, bristle_rx, bristle_ry, bristle_angle)
			if bristle_alpha > 0.0:
				layers.append(Color(accent.r, accent.g, accent.b, bristle_alpha))
			img.set_pixel(x, y, composite_layers(layers))
	img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func capsule_alpha(p: Vector2, a: Vector2, b: Vector2, radius: float) -> float:
	var ba := b - a
	var denom := ba.dot(ba)
	if denom < 0.0001:
		return fill_alpha(p.distance_to(a), radius)
	var h := clampf((p - a).dot(ba) / denom, 0.0, 1.0)
	var dist := (p - a - ba * h).length()
	return fill_alpha(dist, radius)


static func ellipse_alpha(p: Vector2, center: Vector2, rx: float, ry: float, angle: float) -> float:
	if rx <= 0.0 or ry <= 0.0:
		return 0.0
	var d := p - center
	var cos_a := cos(-angle)
	var sin_a := sin(-angle)
	var lx := d.x * cos_a - d.y * sin_a
	var ly := d.x * sin_a + d.y * cos_a
	var norm := sqrt((lx / rx) * (lx / rx) + (ly / ry) * (ly / ry))
	return clampf((1.08 - norm) / 0.14, 0.0, 1.0)


static func fill_alpha(dist: float, radius: float) -> float:
	return clampf((radius + 0.85 - dist) / 1.2, 0.0, 1.0)


static func composite_layers(layers: Array[Color]) -> Color:
	var out := Color(0.0, 0.0, 0.0, 0.0)
	for layer: Color in layers:
		out = out.blend(layer)
	return out


func on_pressed() -> void:
	color_picker.color = AgentColors.theme_color
	var anchor := button.global_position + Vector2(0.0, button.size.y + 6.0)
	popup.position = Vector2i(int(anchor.x - 140.0), int(anchor.y))
	popup.popup()
	pass


func on_picker_color_changed(new_color: Color) -> void:
	AgentColors.set_theme_color(new_color)
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass
