class_name AgentBubble
extends Object

## Agent reply bubble — markdown body; header copy puts ChatEntry.body on the clipboard.


static func append(
	chat_list: VBoxContainer,
	entry: ChatEntry,
	panel_style: StyleBoxFlat,
	text_color: Color,
	title_color: Color = AgentColors.chat_text_muted
) -> RichTextLabel:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	wrapper.add_child(vbox)

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

	var copy_button := Button.new()
	copy_button.text = "Copy"
	style_copy_button(copy_button, panel_style.bg_color)
	copy_button.pressed.connect(on_copy_pressed.bind(entry))
	header.add_child(copy_button)

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
	wrapper.set_meta(AgentChatView.META_BUBBLE_RICH_TEXT, rich_text)

	chat_list.add_child(wrapper)
	return rich_text


static func on_copy_pressed(entry: ChatEntry) -> void:
	if entry == null or StringUtils.is_blank(entry.body):
		return
	DisplayServer.clipboard_set(entry.body)
	Alert.alert("Copied", Colors.success)
	pass


static func style_copy_button(button: Button, bubble_bg: Color) -> void:
	style_header_button(button, bubble_bg, "Copy message", 40.0)
	pass


static func style_header_button(button: Button, bubble_bg: Color, tooltip: String, min_width: float) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(min_width, 18)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", AgentColors.chat_text_muted)
	button.add_theme_color_override("font_hover_color", AgentColors.chat_text.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", AgentColors.chat_text_muted.darkened(0.08))

	var normal := StyleBoxFlat.new()
	normal.bg_color = bubble_bg.lightened(0.08)
	normal.border_color = AgentColors.chat_text_muted.darkened(0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bubble_bg.lightened(0.16)
	hover.border_color = AgentColors.chat_text_muted

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = bubble_bg.darkened(0.06)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover.duplicate())
	button.add_theme_stylebox_override("disabled", normal.duplicate())
	pass
