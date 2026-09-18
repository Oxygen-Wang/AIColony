class_name RuleParser
## 规则解析兜底：不依赖任何 API，用关键词把玩家的话拆成动作表指令
## 触发的两种场景：1) 没填 API Key  2) DeepSeek 请求失败/超时/返回不是 JSON

const CN_NUM := {
	"零": 0, "一": 1, "两": 2, "二": 2, "三": 3, "四": 4,
	"五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
}


static func parse_clause(text: String, snap: Dictionary) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {"reply": "你说啥？", "commands": []}

	var who := find_who(t, snap)
	var count := find_count(t)
	var cmds: Array = []

	# --- 制作（要先判，否则"石斧"里的"石"会被当成采石）
	var craft_item := ""
	for key in ["wooden_pickaxe", "wooden_axe", "iron_pickaxe", "stone_pickaxe", "iron_sword", "stone_sword", "iron_axe", "iron_bow", "iron_shield", "fine_bow", "wood_shield", "wood_spear", "wood_bow", "wood_arrow", "iron_arrow", "wood_sword", "stone_axe"]:
		if t.contains(ActionTable.cn(key)):
			craft_item = key
			break
	if craft_item == "":
		if t.contains("镐"):
			craft_item = "wooden_pickaxe" if not t.contains("石") and not t.contains("铁") else ("stone_pickaxe" if t.contains("石") else "iron_pickaxe")
		elif t.contains("矛"):
			craft_item = "wood_spear"
		elif t.contains("弓"):
			craft_item = "wood_bow"
		elif t.contains("箭"):
			craft_item = "iron_arrow" if t.contains("铁") else "wood_arrow"
		elif t.contains("盾"):
			craft_item = "iron_shield" if t.contains("铁") else "wood_shield"
		elif t.contains("剑"):
			craft_item = "iron_sword" if t.contains("铁") else ("stone_sword" if t.contains("石") else "wood_sword")
		elif t.contains("斧"):
			craft_item = "iron_axe" if t.contains("铁") else ("stone_axe" if (t.contains("石") or t.contains("精")) else "wooden_axe")
	if craft_item != "":
		cmds.append(cmd("craft", who, {"item": craft_item, "count": count}))

	# --- 采集
	var mining_intent := has(t, ["砍", "伐", "挖", "采", "开采", "敲", "拾取木材"]) or (t.contains("打") and (t.contains("铁") or t.contains("铜") or t.contains("铀") or t.contains("矿") or t.contains("石")))
	if mining_intent:
		var target := "tree"
		if t.contains("铀"):
			target = "uranium"
		elif t.contains("铜"):
			target = "copper"
		elif t.contains("铁") or t.contains("矿"):
			target = "iron"
		elif t.contains("石"):
			target = "stone"
		cmds.append(cmd("mine", who, {"target": target, "count": count}))

	# --- 建造
	var build_type := ""
	if t.contains("门") and not t.contains("门口"):
		build_type = "door"
	elif t.contains("火把") or t.contains("灯"):
		build_type = "torch"
	elif t.contains("床"):
		build_type = "bed"
	elif t.contains("地板") or t.contains("铺地"):
		build_type = "floor"
	elif t.contains("墙") or t.contains("围墙"):
		build_type = "wall"
	for kind in ActionTable.VALID_BUILDS:
		if t.contains(ActionTable.cn(kind)):
			build_type = kind
	if build_type != "" and has(t, ["建", "盖", "造", "搭", "放", "围"]):
		# "修墙" 走修理分支，不在这里建
		if not (build_type == "wall" and t.contains("修")):
			cmds.append(cmd("build", who, {"type": build_type, "count": count}))

	if has(t, ["科研", "研究"] ) and build_type == "" and not has(t, ["建", "造"]):
		cmds.append(cmd("research", who, {}))

	# --- 修理
	if has(t, ["修", "补"]) and (t.contains("墙") or t.contains("门") or t.contains("建筑")):
		cmds.append(cmd("repair", who, {"count": count}))

	# --- 拆除（需先用 X 拆除模式在地图上标记；无标记则提示）
	if has(t, ["拆", "推倒", "铲除"]):
		cmds.append(cmd("demolish", who, {}))

	# --- 战斗
	# “打铁矿/打石头”是采集，不是攻击；战斗需明确提到目标，或使用攻击性动词。
	var gathering := mining_intent and (t.contains("树") or t.contains("木") or t.contains("石") or t.contains("矿"))
	if not gathering and has(t, ["打", "攻击", "杀", "揍", "迎击", "反击", "清理野兽", "消灭"]):
		if t.contains("兽") or t.contains("怪") or t.contains("它") or t.contains("敌人") or t.contains("清理兽") or has(t, ["打", "杀", "揍"]):
			var c := cmd("attack", who, {})
			var id := find_beast_id(t)
			if id >= 0:
				c["target_id"] = id
			cmds.append(c)

	# --- 生产链
	if has(t, ["种", "播种"]):
		cmds.append(cmd("plant", who, {"count": count}))
	if has(t, ["收割", "收获", "采摘"]):
		cmds.append(cmd("harvest", who, {"count": count}))
	if has(t, ["煮", "做饭", "烹饪", "弄点吃的", "做吃的"]):
		cmds.append(cmd("cook", who, {"count": count}))

	# --- 其他
	if has(t, ["巡逻", "警戒", "站岗", "防守", "守卫"]):
		cmds.append(cmd("patrol", who, {"count": count}))
	if has(t, ["清理", "清掉", "铲平", "腾地方"]):
		cmds.append(cmd("clear_base", who, {"count": count}))
	if has(t, ["撤", "退", "逃", "回基地", "回来", "躲"]):
		if not cmds.any(func(c): return c["action"] == "attack"):
			cmds.append(cmd("flee", who, {}))
	if has(t, ["吃", "进食"]) and not has(t, ["好吃", "做吃的", "弄点吃的"]):
		cmds.append(cmd("eat", who, {}))
	if has(t, ["睡", "休息", "歇"]):
		cmds.append(cmd("sleep", who, {}))
	if has(t, ["待命", "原地", "别动", "停下", "停工"]):
		cmds.append(cmd("idle", who, {}))

	# --- 移动（放最后，避免抢掉具体动作）
	if cmds.is_empty():
		var pos := find_coords(t)
		if pos != Vector2i(-1, -1):
			cmds.append(cmd("move", who, {"x": pos.x, "y": pos.y}))
		elif has(t, ["去", "到", "走", "前往", "移动", "过来", "集合"]):
			var dir := find_direction(t, snap)
			cmds.append(cmd("move", who, {"x": dir.x, "y": dir.y}))

	if cmds.is_empty():
		return {
			"reply": "没太听懂。可以这样说：「抽抽去砍5棵树」「所有人建围墙」「龟龟去打野兽」「班花造石斧」「大家撤回来」",
			"commands": [],
		}

	return {"reply": make_reply(cmds, snap), "commands": cmds}


# ---------------------------------------------------------------- 解析工具

static func cmd(action: String, who: String, extra: Dictionary) -> Dictionary:
	var d := {"action": action, "who": who}
	for k in extra:
		d[k] = extra[k]
	return d


static func has(t: String, words: Array) -> bool:
	for w in words:
		if t.contains(w):
			return true
	return false


static func find_who(t: String, snap: Dictionary) -> String:
	if has(t, ["所有人", "大家", "全部", "所有", "全员", "都去"]):
		return "all"
	for c in snap.get("colonists", []):
		if t.contains(str(c["name"])):
			return str(c["name"])
	return "all"


static func find_count(t: String) -> int:
	# 阿拉伯数字 + 量词
	var re := RegEx.new()
	re.compile("(\\d+)\\s*[个棵块座件张把只头份碗盘]?")
	var m := re.search(t)
	if m:
		var v := int(m.get_string(1))
		if v > 0 and v <= 99:
			return v
	# 中文数字
	for ch in CN_NUM:
		if t.contains(ch + "个") or t.contains(ch + "棵") or t.contains(ch + "块") or \
		   t.contains(ch + "座") or t.contains(ch + "只") or t.contains(ch + "张"):
			return CN_NUM[ch]
	return 1


static func find_beast_id(t: String) -> int:
	var re := RegEx.new()
	re.compile("#\\s*(\\d+)")
	var m := re.search(t)
	if m:
		return int(m.get_string(1))
	return -1


static func find_coords(t: String) -> Vector2i:
	var re := RegEx.new()
	re.compile("(\\d{1,3})\\s*[,，]\\s*(\\d{1,3})")
	var m := re.search(t)
	if m:
		return Vector2i(int(m.get_string(1)), int(m.get_string(2)))
	return Vector2i(-1, -1)


static func find_direction(t: String, snap: Dictionary) -> Vector2i:
	var base := Vector2i(snap.get("base", [64, 64])[0], snap.get("base", [64, 64])[1])
	var step := 10
	if t.contains("东") or t.contains("右"):
		return base + Vector2i(step, 0)
	if t.contains("西") or t.contains("左"):
		return base + Vector2i(-step, 0)
	if t.contains("南") or t.contains("下"):
		return base + Vector2i(0, step)
	if t.contains("北") or t.contains("上"):
		return base + Vector2i(0, -step)
	return base


static func make_reply(cmds: Array, snap: Dictionary) -> String:
	var names: Dictionary = {}
	for c in snap.get("colonists", []):
		names[str(c["name"])] = true

	var parts: PackedStringArray = []
	for c in cmds:
		var who := str(c["who"])
		var who_cn := "所有人" if who == "all" else who
		var n := int(c.get("count", 1))
		var tail := "" if n <= 1 else "%d个" % n
		match str(c["action"]):
			"mine":
				var kind := str(c.get("target", "tree"))
				var verb: String = {"tree": "砍", "stone": "采", "iron": "挖", "copper": "挖", "uranium": "挖"}.get(kind, "采")
				parts.append("让%s去%s%s%s" % [who_cn, verb, tail, ActionTable.cn(kind)])
			"build": parts.append("让%s去建%s" % [who_cn, ActionTable.cn(str(c.get("type", "wall")))])
			"craft": parts.append("让%s去造%s" % [who_cn, ActionTable.cn(str(c.get("item", "")))])
			"attack": parts.append("让%s去迎击野兽" % who_cn)
			"eat": parts.append("让%s吃饭" % who_cn)
			"sleep": parts.append("让%s去休息" % who_cn)
			"plant": parts.append("让%s去种地" % who_cn)
			"harvest": parts.append("让%s去收庄稼" % who_cn)
			"cook": parts.append("让%s去做饭" % who_cn)
			"patrol": parts.append("让%s去巡逻" % who_cn)
			"repair": parts.append("让%s去修理" % who_cn)
			"demolish": parts.append("让%s去拆除标记的建筑" % who_cn)
			"clear_base": parts.append("让%s去清理周边" % who_cn)
			"flee": parts.append("让%s撤回基地" % who_cn)
			"idle": parts.append("让%s原地待命" % who_cn)
			"move": parts.append("让%s赶过去" % who_cn)
			_: parts.append("安排%s行动" % who_cn)
	return "收到，" + "，".join(parts) + "。"


## 分句独立解析人物、数量；“然后”继承上一句的执行者，坐标逗号保留。
static func parse(text: String, snap: Dictionary) -> Dictionary:
	var splitter := RegEx.new()
	splitter.compile("(?<![0-9])[,，]|[,，](?![0-9])|[。；;\\n]|然后|接着|再让")
	var normalized := splitter.sub(text, "|", true)
	var commands: Array = []
	var replies: PackedStringArray = []
	var inherited := "all"
	for clause in normalized.split("|", false):
		if has(clause, ["情况", "状态", "多少", "汇报", "怎么样"]):
			replies.append("第%d天，存活%d人，野兽%d只；库存：%s。" % [int(snap.get("day", 1)), snap.get("colonists", []).filter(func(c: Dictionary) -> bool: return c.get("alive", true)).size(), int(snap.get("beast_count", 0)), str(snap.get("resources", {}))])
			continue
		var who := find_who(clause, snap)
		if who == "all" and not has(clause, ["所有", "大家", "全员", "全部"]):
			who = inherited
		inherited = who
		var result := parse_clause(clause, snap)
		for command in result["commands"]:
			command["who"] = who
			var validated := ActionTable.validate(command)
			if not validated.is_empty() and commands.size() < 8:
				commands.append(validated)
	if not commands.is_empty():
		replies.append(make_reply(commands, snap))
	if replies.is_empty():
		replies.append("试试：抽抽砍5棵树，七海采3块石头。建筑请先放蓝图，再指派施工。")
	return {"reply": "\n".join(replies), "commands": commands}


