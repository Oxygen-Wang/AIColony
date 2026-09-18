extends Node
## 全局字体 / 主题（自动加载单例 Ui）
## 作用：让所有 UI 和画布文字都能正确显示中文（Godot 默认字体不含中文字形）

var font: Font
var theme: Theme

func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"SimHei",
		"Noto Sans CJK SC",
		"PingFang SC",
		"sans-serif",
	])
	sf.allow_system_fallback = true
	font = sf

	theme = Theme.new()
	theme.default_font = sf
	theme.default_font_size = 16

	# 让所有 Control 默认用上中文字体
	if get_window():
		get_window().theme = theme
	pass


