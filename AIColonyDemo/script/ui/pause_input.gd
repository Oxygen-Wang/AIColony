extends CanvasLayer
## 暂停期间主场景停止处理，由常驻 UI 接收空格以恢复。

func _input(event: InputEvent) -> void:
	if not get_tree().paused or not event is InputEventKey or not event.pressed or event.echo:
		return
	var game := get_parent()
	if event.keycode == KEY_SPACE and not game.start_panel.visible and not game.end_panel.visible and not get_viewport().gui_get_focus_owner() is LineEdit:
		game.set_speed(1.0)
		get_viewport().set_input_as_handled()
	pass


