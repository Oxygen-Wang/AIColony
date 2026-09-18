class_name StrategyLibrary
## 保存 AI 已验证可执行的玩家策略；重开后仍可作为快捷按钮使用。

const PATH := "user://strategy_library.json"
const LIMIT := 12

var entries: Array[String] = []


func load_saved() -> void:
	entries.clear()
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for item in parsed:
			var text := str(item).strip_edges()
			if text != "" and not entries.has(text):
				entries.append(text)
	pass


func remember(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	if entries.has(clean):
		entries.erase(clean)
	entries.push_front(clean)
	while entries.size() > LIMIT:
		entries.pop_back()
	save()
	pass


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(entries, "\t"))
	pass


func recent(limit: int) -> Array[String]:
	var out: Array[String] = []
	for text in entries.slice(0, limit):
		out.append(str(text))
	return out
