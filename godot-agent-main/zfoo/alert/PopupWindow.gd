## Read-only text popup. Dismiss with Esc, the close button, or a click outside (window loses focus).
class_name PopupWindow
extends Window

var text_edit: TextEdit


func _init() -> void:
	# Child of the main window: follows it, and usually has no taskbar entry.
	transient = true
	# Hide until popup_centered(), otherwise add_child flashes a default-sized window.
	visible = false
	close_requested.connect(on_close_requested)
	window_input.connect(on_window_input)

	text_edit = TextEdit.new()
	text_edit.editable = false
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	text_edit.add_theme_font_override("font", Fonts.regular())
	add_child(text_edit)
	pass


## Open a centered read-only window. Width/height are percent of the screen (1–100).
## Example: `PopupWindow.show_window("Full view", body, 76, 78)`
static func show_window(title: String, text: String, width_percent: int, height_percent: int) -> void:
	var window := PopupWindow.new()
	window.title = title
	gdf.gdf_node.add_child(window)
	# Size against the root viewport; this Window is itself a Viewport.
	var viewport := gdf.gdf_node.get_tree().root.get_visible_rect().size
	window.size = Vector2i(
		int(viewport.x * clampf(width_percent, 1.0, 100.0) / 100.0),
		int(viewport.y * clampf(height_percent, 1.0, 100.0) / 100.0),
	)
	window.set_body(text)
	window.popup_centered()
	pass


func set_body(text: String) -> void:
	text_edit.text = text
	text_edit.scroll_vertical = text_edit.get_line_count()
	pass


func _notification(what: int) -> void:
	# Clicking outside moves focus back to the main window.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and visible:
		queue_free()
	pass


func on_close_requested() -> void:
	queue_free()
	pass


func on_window_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		queue_free()
		set_input_as_handled()
	pass
