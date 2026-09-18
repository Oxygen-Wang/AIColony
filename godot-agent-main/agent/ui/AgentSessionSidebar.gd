class_name AgentSessionSidebar
extends RefCounted

## Left sidebar — pinned + normal session lists with select / delete / drag reorder.

var session_list_root: VBoxContainer
var pinned_header: Label
var pinned_list: VBoxContainer
var pinned_separator: HSeparator
var normal_header: Label
var normal_list: VBoxContainer
var new_session_button: Button
var sidebar_panel: PanelContainer

var session_rows: Dictionary[int, PanelContainer] = {}
var hover_session_id: int = AgentSessionManager.INVALID_SESSION_ID


# ---------------------------------------------------------------------------
# Setup & theme
# ---------------------------------------------------------------------------

func setup(
	p_session_list_root: VBoxContainer,
	p_pinned_header: Label,
	p_pinned_list: VBoxContainer,
	p_pinned_separator: HSeparator,
	p_normal_header: Label,
	p_normal_list: VBoxContainer,
	p_new_session_button: Button,
	p_sidebar_panel: PanelContainer
) -> void:
	session_list_root = p_session_list_root
	pinned_header = p_pinned_header
	pinned_list = p_pinned_list
	pinned_separator = p_pinned_separator
	normal_header = p_normal_header
	normal_list = p_normal_list
	new_session_button = p_new_session_button
	sidebar_panel = p_sidebar_panel
	new_session_button.pressed.connect(on_new_session_pressed)
	AgentEvents.events.session_added.connect(on_session_added)
	AgentEvents.events.session_removed.connect(on_session_removed)
	AgentEvents.events.session_selected.connect(select_item)
	AgentEvents.events.session_title_changed.connect(on_session_refresh)
	AgentEvents.events.agent_start.connect(on_session_refresh)
	AgentEvents.events.session_stop.connect(on_session_refresh)
	AgentEvents.events.theme_changed.connect(on_ui_theme_changed)
	AgentEvents.events.theme_color_changed.connect(on_ui_theme_changed)
	pinned_header.mouse_filter = Control.MOUSE_FILTER_PASS
	normal_header.mouse_filter = Control.MOUSE_FILTER_PASS
	bind_list_drop(pinned_list, true)
	bind_list_drop(pinned_header, true)
	bind_list_drop(normal_list, false)
	bind_list_drop(normal_header, false)
	apply_theme()
	pass


func on_ui_theme_changed() -> void:
	apply_theme()
	pass


func on_session_refresh(session_id: int, _arg: Variant = null) -> void:
	refresh_item(session_id)
	pass


func apply_theme() -> void:
	sidebar_panel.add_theme_stylebox_override("panel", build_sidebar_style())
	pinned_header.add_theme_color_override("font_color", AgentColors.sidebar_muted)
	normal_header.add_theme_color_override("font_color", AgentColors.sidebar_muted)
	apply_new_session_button_theme()
	pinned_separator.add_theme_stylebox_override("separator", build_pinned_separator_style())
	refresh_all_row_styles()
	pass


func apply_new_session_button_theme() -> void:
	var accent := AgentColors.theme_accent_solid()
	new_session_button.flat = false
	new_session_button.focus_mode = Control.FOCUS_NONE
	new_session_button.add_theme_color_override("font_color", accent)
	new_session_button.add_theme_color_override("font_hover_color", accent.lightened(0.08))
	new_session_button.add_theme_color_override("font_pressed_color", accent.darkened(0.06))
	new_session_button.add_theme_color_override("font_disabled_color", AgentColors.sidebar_muted)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.55 if AgentColors.is_dark() else 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = AgentColors.theme_selection_bg()
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.85)

	var pressed := hover.duplicate() as StyleBoxFlat
	if AgentColors.is_dark():
		pressed.bg_color = pressed.bg_color.lightened(0.06)
	else:
		pressed.bg_color = pressed.bg_color.darkened(0.04)
	pressed.border_color = accent

	new_session_button.add_theme_stylebox_override("normal", normal)
	new_session_button.add_theme_stylebox_override("hover", hover)
	new_session_button.add_theme_stylebox_override("pressed", pressed)
	new_session_button.add_theme_stylebox_override("hover_pressed", pressed.duplicate())
	new_session_button.add_theme_stylebox_override("focus", hover.duplicate())
	new_session_button.add_theme_stylebox_override("disabled", normal.duplicate())
	pass


func build_pinned_separator_style() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	var accent := AgentColors.theme_accent_solid()
	var alpha := 0.42 if AgentColors.is_dark() else 0.32
	line.color = Color(accent.r, accent.g, accent.b, alpha)
	line.grow_begin = 2
	line.grow_end = 2
	line.thickness = 1
	return line


func build_sidebar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = AgentColors.sidebar
	style.border_color = AgentColors.sidebar_border
	style.set_border_width(SIDE_RIGHT, 1)
	return style


# ---------------------------------------------------------------------------
# List rebuild & refresh
# ---------------------------------------------------------------------------

func rebuild() -> void:
	clear()
	for session_index: AgentSessionIndexes.SessionIndex in AgentSessionManager.session_indexes.pinned_indexes:
		append_row(session_index.id, session_index.title, true)
	for session_index: AgentSessionIndexes.SessionIndex in AgentSessionManager.session_indexes.indexes:
		append_row(session_index.id, session_index.title, false)
	sync_pinned_section_visibility()
	select_item(AgentSessionManager.active_session_id)
	pass


func refresh_item(session_id: int) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	var select_button: Button = row_panel.get_meta("select_button")
	if select_button != null:
		select_button.text = format_session_label(session_id, AgentSessionManager.get_title(session_id))
	pass


func refresh_all_row_styles() -> void:
	var active_id := AgentSessionManager.active_session_id
	for session_id: int in session_rows:
		style_session_row(session_id, session_id == active_id)
	pass


func select_item(session_id: int) -> void:
	refresh_item(session_id)
	refresh_all_row_styles()
	pass


func sync_pinned_section_visibility() -> void:
	var has_pinned := pinned_list.get_child_count() > 0
	var has_normal := normal_list.get_child_count() > 0
	pinned_separator.visible = has_pinned and has_normal
	pinned_list.custom_minimum_size = Vector2.ZERO
	# Empty Chats list has no row hit target — keep a small drop pad when unpinning is possible.
	normal_list.custom_minimum_size = Vector2(0, 40) if has_pinned and not has_normal else Vector2.ZERO
	pass


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func on_session_added(session_id: int, title: String) -> void:
	append_row(session_id, title, false)
	normal_list.move_child(session_rows[session_id], 0)
	pass


func on_session_removed(session_id: int) -> void:
	remove_row(session_id)
	sync_pinned_section_visibility()
	pass


func on_new_session_pressed() -> void:
	var session := AgentSessionManager.create_session()
	AgentSessionManager.select_session(session.id)
	pass


func on_session_row_pressed(session_id: int) -> void:
	AgentSessionManager.select_session(session_id)
	pass


func on_session_delete_pressed(session_id: int) -> void:
	AgentSessionManager.delete_session(session_id)
	pass


# ---------------------------------------------------------------------------
# Row build & remove
# ---------------------------------------------------------------------------

func clear() -> void:
	for child in pinned_list.get_children():
		child.queue_free()
	for child in normal_list.get_children():
		child.queue_free()
	session_rows.clear()
	pass


func list_for_pinned(pinned: bool) -> VBoxContainer:
	return pinned_list if pinned else normal_list


func append_row(session_id: int, title: String, pinned: bool) -> void:
	var row_panel := PanelContainer.new()
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bind_row_hover(row_panel, session_id)

	var fx := SessionRowSciFiFx.new()
	fx.name = "SciFiFx"
	row_panel.add_child(fx)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row_panel.add_child(row)

	var select_button := Button.new()
	select_button.text = format_session_label(session_id, title)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_button.focus_mode = Control.FOCUS_NONE
	select_button.flat = true
	select_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	select_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	select_button.pressed.connect(on_session_row_pressed.bind(session_id))
	select_button.set_drag_forwarding(get_row_drag_data.bind(session_id), can_drop_on_row.bind(session_id), drop_on_row)
	bind_row_hover(select_button, session_id)

	var delete_button := Button.new()
	delete_button.text = "×"
	delete_button.tooltip_text = "Delete chat"
	delete_button.custom_minimum_size = Vector2(28, 28)
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.flat = true
	delete_button.pressed.connect(on_session_delete_pressed.bind(session_id))
	bind_row_hover(delete_button, session_id)

	row.add_child(select_button)
	row.add_child(delete_button)
	row_panel.set_meta("select_button", select_button)
	row_panel.set_meta("delete_button", delete_button)
	row_panel.set_meta("scifi_fx", fx)
	row_panel.set_meta("pinned", pinned)
	list_for_pinned(pinned).add_child(row_panel)
	session_rows[session_id] = row_panel
	style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func remove_row(session_id: int) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	if hover_session_id == session_id:
		hover_session_id = AgentSessionManager.INVALID_SESSION_ID
	row_panel.queue_free()
	session_rows.erase(session_id)
	pass


# ---------------------------------------------------------------------------
# Row styling
# ---------------------------------------------------------------------------

func bind_row_hover(control: Control, session_id: int) -> void:
	control.mouse_entered.connect(on_session_row_mouse_entered.bind(session_id))
	control.mouse_exited.connect(on_session_row_mouse_exited.bind(session_id))
	pass


func on_session_row_mouse_entered(session_id: int) -> void:
	hover_session_id = session_id
	style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func on_session_row_mouse_exited(session_id: int) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel != null and row_panel.get_global_rect().has_point(row_panel.get_global_mouse_position()):
		return
	if hover_session_id == session_id:
		hover_session_id = AgentSessionManager.INVALID_SESSION_ID
	style_session_row(session_id, session_id == AgentSessionManager.active_session_id)
	pass


func build_session_row_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if selected:
		style.bg_color = AgentColors.theme_selection_bg()
	elif hovered:
		style.bg_color = AgentColors.sidebar_row_hover
	else:
		style.bg_color = Color(0, 0, 0, 0)
	return style


func style_session_row(session_id: int, selected: bool) -> void:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return
	var select_button: Button = row_panel.get_meta("select_button")
	if select_button == null:
		return

	var hovered := hover_session_id == session_id
	row_panel.add_theme_stylebox_override("panel", build_session_row_style(selected, hovered))

	var text_color := AgentColors.sidebar_text if selected or hovered else AgentColors.sidebar_muted
	select_button.add_theme_color_override("font_color", text_color)
	select_button.add_theme_color_override("font_hover_color", text_color)
	select_button.add_theme_color_override("font_pressed_color", text_color)

	var delete_button: Button = row_panel.get_meta("delete_button")
	if delete_button != null:
		delete_button.add_theme_color_override("font_color", AgentColors.sidebar_muted)
		delete_button.add_theme_color_override("font_hover_color", AgentColors.error)
		delete_button.add_theme_color_override("font_pressed_color", AgentColors.error)

	var fx: SessionRowSciFiFx = row_panel.get_meta("scifi_fx")
	if fx != null:
		fx.set_highlight(selected)
	pass


func format_session_label(session_id: int, title: String) -> String:
	if AgentSessionManager.is_running(session_id):
		return title + " ●"
	return title


# ---------------------------------------------------------------------------
# Drag reorder & pin / unpin
# ---------------------------------------------------------------------------

func get_row_drag_data(_at_position: Vector2, session_id: int) -> Variant:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return null
	row_panel.set_drag_preview(Control.new())
	return session_id


func row_is_pinned(session_id: int) -> bool:
	var row_panel: PanelContainer = session_rows.get(session_id)
	if row_panel == null:
		return AgentSessionManager.is_pinned(session_id)
	return row_panel.get_meta("pinned", false)


func clamp_move_index(from_row: PanelContainer, target_list: VBoxContainer, to_index: int) -> int:
	var max_index := maxi(0, target_list.get_child_count() - 1)
	return clampi(to_index, 0, max_index)


func apply_row_move(session_id: int, from_row: PanelContainer, target_list: VBoxContainer, to_index: int, to_pinned: bool) -> void:
	var need_section_change := AgentSessionManager.is_pinned(session_id) != to_pinned
	if from_row.get_parent() != target_list:
		from_row.reparent(target_list)
		from_row.set_meta("pinned", to_pinned)
		sync_pinned_section_visibility()

	to_index = clamp_move_index(from_row, target_list, to_index)
	var from_index := from_row.get_index()
	if not need_section_change and from_index == to_index:
		return

	if from_index != to_index:
		target_list.move_child(from_row, to_index)

	if need_section_change:
		AgentSessionManager.transfer_session_index(session_id, to_pinned, from_row.get_index())
	elif from_index != to_index:
		AgentSessionManager.move_index_in_list(session_id, from_row.get_index(), to_pinned)
	pass


func can_drop_on_row(_at_position: Vector2, data: Variant, target_id: int) -> bool:
	if typeof(data) != TYPE_INT:
		return false
	var session_id: int = data
	var from_row: PanelContainer = session_rows.get(session_id)
	var target_row: PanelContainer = session_rows.get(target_id)
	if from_row == null or target_row == null:
		return from_row != null
	if from_row == target_row:
		return true
	var to_pinned := row_is_pinned(target_id)
	var target_list := list_for_pinned(to_pinned)
	apply_row_move(session_id, from_row, target_list, target_row.get_index(), to_pinned)
	return true


func drop_on_row(_at_position: Vector2, _data: Variant) -> void:
	pass


func bind_list_drop(host: Control, pinned: bool) -> void:
	host.set_drag_forwarding(
		func(_at: Vector2) -> Variant: return null,
		can_drop_on_list.bind(pinned),
		drop_on_list
	)
	pass


func can_drop_on_list(_at_position: Vector2, data: Variant, pinned: bool) -> bool:
	if typeof(data) != TYPE_INT:
		return false
	var session_id: int = data
	var from_row: PanelContainer = session_rows.get(session_id)
	if from_row == null:
		return false
	var target_list := list_for_pinned(pinned)
	var to_index := target_list.get_child_count()
	if from_row.get_parent() == target_list and to_index > 0:
		to_index -= 1
	apply_row_move(session_id, from_row, target_list, to_index, pinned)
	return true


func drop_on_list(_at_position: Vector2, _data: Variant) -> void:
	pass


# ---------------------------------------------------------------------------
# Selected row overlay (shader: sidebar_session_row.gdshader)
# ---------------------------------------------------------------------------

class SessionRowSciFiFx extends ColorRect:
	const SHADER := preload("res://agent/ui/shaders/sidebar_session_row.gdshader")
	const CORNER_RADIUS := 6.0

	var fx_material: ShaderMaterial


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		color = Color(1.0, 1.0, 1.0, 0.0)
		set_anchors_preset(PRESET_FULL_RECT)
		fx_material = ShaderMaterial.new()
		fx_material.shader = SHADER
		material = fx_material
		visible = false
		pass


	func _ready() -> void:
		var parent_row := get_parent() as Control
		if parent_row != null:
			parent_row.resized.connect(sync_uniforms)
		resized.connect(sync_uniforms)
		sync_uniforms()
		pass


	func set_highlight(active: bool) -> void:
		visible = active
		color.a = 1.0 if active else 0.0
		if fx_material == null:
			return
		fx_material.set_shader_parameter("strength", 1.0 if active else 0.0)
		sync_uniforms()
		queue_redraw()
		pass


	func sync_uniforms() -> void:
		if fx_material == null:
			return
		var sz := size
		if sz.x < 1.0 or sz.y < 1.0:
			var parent_row := get_parent() as Control
			if parent_row != null:
				sz = parent_row.size
		fx_material.set_shader_parameter("rect_size", sz)
		fx_material.set_shader_parameter("corner_radius", CORNER_RADIUS)
		fx_material.set_shader_parameter("accent_color", AgentColors.theme_accent_solid())
		fx_material.set_shader_parameter("is_dark", 1.0 if AgentColors.is_dark() else 0.0)
		pass
