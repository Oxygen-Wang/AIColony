extends Node

@onready var showLogButton: Button = $ShowLog


func _ready() -> void:
	showLogButton.pressed.connect(on_show_log_pressed)
	pass


func on_show_log_pressed() -> void:
	Log.info("LogWindow manual test")
	LogWindow.show_log_window(128, 70, 80)
	pass
