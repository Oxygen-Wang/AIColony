class_name AIManager
extends Node
## AI 总管：把玩家的话翻译成动作表
## 正常走 DeepSeek（OpenAI 兼容接口），失败则自动降级到规则解析

signal result_ready(reply: String, commands: Array, source: String)
signal busy_changed(busy: bool)

const URL := "https://api.deepseek.com/chat/completions"

var api_key := ""
var model := "deepseek-flash"
var online := true          # 是否尝试走 API

var _http: HTTPRequest
var _busy := false
var _pending: Array = []    # 排队中的玩家发言 [{text, snapshot}]
var snapshot: Dictionary = {}
var _current_text := ""
var _last_source := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(on_completed)
	pass


func is_busy() -> bool:
	return _busy


## 玩家发言入口
func ask(text: String, snapshot: Dictionary) -> void:
	if not is_busy() and _pending.is_empty() and (not online or api_key == ""):
		# 离线模式：直接规则解析
		emit_rule(text, snapshot, "rule")
		return

	if is_busy():
		_pending.append({"text": text, "snapshot": snapshot})
		return

	send(text, snapshot)


func send(text: String, snapshot: Dictionary) -> void:
	_busy = true
	busy_changed.emit(true)
	snapshot = snapshot
	_current_text = text

	var body := {
		"model": model,
		"messages": [
			{"role": "system", "content": system_prompt(snapshot)},
			{"role": "user", "content": text},
		],
		"stream": false,
		"temperature": 0.3,
		"max_tokens": 1200,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	])
	var err := _http.request(URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		finish_busy()
		emit_rule(text, snapshot, "rule-offline")
		drain()
	pass


func on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	finish_busy()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_rule(last_player_text(), snapshot, "rule-netfail")
		drain()
		return
	if code != 200:
		emit_rule(last_player_text(), snapshot, "rule-code%d" % code)
		drain()
		return

	var txt := body.get_string_from_utf8()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY or not data.has("choices"):
		emit_rule(last_player_text(), snapshot, "rule-badresp")
		drain()
		return

	var content := ""
	var choices = data["choices"]
	if choices is Array and choices.size() > 0 and choices[0] is Dictionary:
		var msg = choices[0].get("message", {})
		if msg is Dictionary:
			content = str(msg.get("content", ""))

	var parsed := extract_json(content)
	if parsed.is_empty() or not parsed.get("commands") is Array:
		emit_rule(_current_text, snapshot, "rule-badjson")
	else:
		var cmds: Array = []
		var raw_cmds = parsed.get("commands", [])
		if raw_cmds is Array:
			for raw in raw_cmds.slice(0, 8):
				if typeof(raw) != TYPE_DICTIONARY:
					continue
				var v := ActionTable.validate(raw)
				if not v.is_empty():
					cmds.append(v)
		var reply := str(parsed.get("reply", "收到。"))
		result_ready.emit(reply, cmds, "ai")

	drain()


func drain() -> void:
	if _pending.is_empty():
		return
	var next: Dictionary = _pending.pop_front()
	send(str(next["text"]), next["snapshot"])


func finish_busy() -> void:
	_busy = false
	busy_changed.emit(false)
	pass


func last_player_text() -> String:
	return _current_text


# ---------------------------------------------------------------- 降级

func emit_rule(text: String, snapshot: Dictionary, source: String) -> void:
	var r := RuleParser.parse(text, snapshot)
	_last_source = source
	result_ready.emit(str(r["reply"]), r["commands"], source)
	pass


# ---------------------------------------------------------------- 提示词

func system_prompt(snap: Dictionary) -> String:
	var day := int(snap.get("day", 1))
	var clock := str(snap.get("clock", "06:00"))
	var res: Dictionary = snap.get("resources", {})
	var base: Array = snap.get("base", [64, 64])
	var beasts := int(snap.get("beast_count", 0))

	var pawn_lines: PackedStringArray = []
	for c in snap.get("colonists", []):
		pawn_lines.append("  - %s：位置(%d,%d)，生命%d%%，饥饿%d%%，疲劳%d%%，心情%d%%，当前：%s" % [
			str(c["name"]), int(c["x"]), int(c["y"]),
			int(c["hp"]), int(c["hunger"]), int(c["fatigue"]), int(c["mood"]),
			str(c.get("task", "空闲")),
		])

	return """你是舰载总管"星神"，负责把玩家的中文指令翻译成动作表，并调度殖民者执行。


【当前世界】
第%d天 %s
殖民地基地坐标：(%d, %d)
资源：木材%d 石料%d 铁矿%d 铜矿%d 铀矿%d 作物%d 食物%d
场上野兽：%d 只
殖民者：
%s

【可用动作】（只能使用下列动作，不要发明新动作）
%s

【输出要求】
只输出一个 JSON 对象，不要输出任何解释、不要用 markdown 代码块。格式：
{"reply": "对玩家说的一句话（中文，简短，带一点总管口吻）", "commands": [{"action": "...", "who": "小人名字或all", ...其他参数}]}

【规则】
1. who 填殖民者名字，或填 "all" 表示所有人。
2. commands 最多 8 条。玩家的一个要求可以拆成多条指令。
3. build 只能施工玩家已放置的蓝图，绝不自动选址；未放蓝图时提示玩家先规划。
4. mine 的 count 是采集数量；没提数量就填 1。注意采集门槛：石头要木镐、铁/铜要石镐、铀要铁镐，没镐先 craft 镐。
4b. demolish 只能拆玩家已用拆除模式(X键)标记的建筑；玩家说"拆墙/拆掉/推倒"时只下 demolish 指令，绝不替玩家选拆除位置；无标记时在 reply 里提醒先用X键标记。
5. craft 新工具要对应科技（木器/石器/铁器时代）；木镐木斧零科技可搓。
6. 如果玩家的话和游戏无关，或者你无法理解，就返回空 commands 并在 reply 里说明。
7. 注意殖民者的疲劳和饥饿：如果某人已经很累，可以提醒玩家，或换个人派活。
8. 有野兽时优先考虑安全，必要时建议玩家让他们撤退或迎击。""" % [
		day, clock, base[0], base[1],
		int(res.get("wood", 0)), int(res.get("stone", 0)), int(res.get("iron", 0)),
		int(res.get("copper", 0)), int(res.get("uranium", 0)),
		int(res.get("crop", 0)), int(res.get("food", 0)),
		beasts,
		"\n".join(pawn_lines),
		ActionTable.describe(),
	]


static func try_parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


## 从可能夹带 markdown / 废话的文本里抠出第一个完整 JSON 对象
static func extract_json(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	# 直接就是 JSON
	var direct = try_parse(t)
	if direct is Dictionary:
		return direct

	# 抠 ```json ... ``` 代码块
	var fence := t.find("```")
	if fence >= 0:
		var end := t.find("```", fence + 3)
		if end > fence:
			var inner := t.substr(fence + 3, end - fence - 3)
			inner = inner.trim_prefix("json").strip_edges()
			var d = try_parse(inner)
			if d is Dictionary:
				return d

	# 按花括号配平抠第一段
	var start := t.find("{")
	while start >= 0:
		var depth := 0
		var in_str := false
		var esc := false
		for i in range(start, t.length()):
			var c := t[i]
			if esc:
				esc = false
				continue
			if c == "\\":
				esc = true
				continue
			if c == "\"":
				in_str = not in_str
				continue
			if in_str:
				continue
			if c == "{":
				depth += 1
			elif c == "}":
				depth -= 1
				if depth == 0:
					var chunk := t.substr(start, i - start + 1)
					var parsed = try_parse(chunk)
					if parsed is Dictionary:
						return parsed
					break
		start = t.find("{", start + 1)
	return {}


