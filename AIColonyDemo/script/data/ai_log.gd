class_name AiLog
## AI 生成数据的本地 JSON 存读：每次总管返回的玩家话、回复、指令都追加保存。

const DIR := "user://dialogs"
const PATH := "user://dialogs/ai_history.json"
const LIMIT := 100

var entries: Array = []


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
			if item is Dictionary:
				entries.append(item)
	pass


func append(player_text: String, reply: String, commands: Array, source: String, day: int = 0, clock: String = "") -> void:
	var record := {
		"time": Time.get_datetime_string_from_system(),
		"day": day,
		"clock": clock,
		"player": player_text,
		"reply": reply,
		"commands": commands.duplicate(true),
		"source": source,
	}
	entries.push_front(record)
	while entries.size() > LIMIT:
		entries.pop_back()
	save()
	pass


func save() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(entries, "\t"))
	pass


func clear() -> void:
	entries.clear()
	save()
	pass
