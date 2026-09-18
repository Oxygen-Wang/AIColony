class_name UserBubble
extends Object

## User message bubble — flowing border beam (same shader as chat input).

const BeamLayer := preload("res://agent/ui/effects/AccentBorderBeamLayer.gd")
const BUBBLE_CORNER_RADIUS := 8.0
const BEAM_STRENGTH := 1.0


static func append(
	chat_list: VBoxContainer,
	session_id: int,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	text_color: Color,
	title_color: Color = AgentColors.chat_text_muted
) -> RichTextLabel:
	var host := Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.clip_contents = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.set_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style)
	host.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label := Label.new()
	title_label.text = entry.title
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", 12)
	header.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var delete_from_here_button := Button.new()
	delete_from_here_button.name = "DeleteFromHereButton"
	delete_from_here_button.text = "Delete"
	AgentBubble.style_header_button(delete_from_here_button, panel_style.bg_color, "Delete from here", 52.0)
	delete_from_here_button.pressed.connect(on_delete_from_here_pressed.bind(session_id, entry))
	header.add_child(delete_from_here_button)

	vbox.add_child(header)

	var rich_text := MarkdownUtils.create_rich_text_label(
		text_color,
		entry.body,
		MarkdownToggle.markdown_enabled_for_entry(entry),
		0.0,
		AgentColors.code_block_bg_html()
	)
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	vbox.add_child(rich_text)

	var beam: AccentBorderBeamLayer = BeamLayer.new()
	beam.name = "BorderBeam"
	beam.z_index = 10
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.set_fixed_corner_radius(BUBBLE_CORNER_RADIUS)
	beam.set_highlight_strength(BEAM_STRENGTH)
	host.add_child(beam)

	panel.minimum_size_changed.connect(sync_layout.bind(host, panel, beam))
	panel.resized.connect(sync_layout.bind(host, panel, beam))
	host.resized.connect(sync_layout.bind(host, panel, beam))

	host.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)
	chat_list.add_child(host)
	sync_layout.call_deferred(host, panel, beam)
	return rich_text


static func on_delete_from_here_pressed(session_id: int, entry: ChatEntry) -> void:
	AgentSessionManager.truncate_chat_from_entry(session_id, entry)
	pass


static func sync_layout(host: Control, panel: PanelContainer, beam: AccentBorderBeamLayer) -> void:
	if not is_instance_valid(host) or not is_instance_valid(panel) or not is_instance_valid(beam):
		return
	host.custom_minimum_size = panel.get_combined_minimum_size()
	var pad := AccentBorderBeamLayer.BEAM_OUTSET
	var panel_size := panel.size
	if panel_size.x < 1.0 or panel_size.y < 1.0:
		panel_size = panel.get_combined_minimum_size()
	beam.layout_mode = 0
	beam.position = panel.position - Vector2(pad, pad)
	beam.size = panel_size + Vector2(pad * 2.0, pad * 2.0)
	beam.sync_shader_uniforms()
	pass
