class_name TechTree
## 科技路线数据与查询；新增时代时优先改这里，主控只消费接口。

const ROOT := "survival"

const ORDER := [
	"woodcraft",
	"stone_age",
	"farming",
	"fishing",
	"husbandry",
	"food_chain",
	"logistics",
	"iron_age",
	"defense",
	"steam",
	"electric",
	"nuclear",
]

const DATA := {
	"woodcraft": {"age": "木器", "name": "木器时代", "cost": {"wood": 10}, "work": 12.0, "requires": ["survival"], "desc": "解锁木矛/木弓/木箭/木剑与木家具套制造权。"},
	"stone_age": {"age": "石器", "name": "石器时代", "cost": {"wood": 8, "stone": 6}, "work": 16.0, "requires": ["woodcraft"], "desc": "解锁石镐/石剑/精石斧/精木弓/木盾与石家具套制造权。"},
	"farming": {"age": "生存", "name": "驯化种田", "cost": {"wood": 6}, "work": 12.0, "requires": ["stone_age"], "desc": "侧支：农田产量加成，不卡主线。"},
	"fishing": {"age": "生存", "name": "浅滩钓鱼", "cost": {"wood": 8, "stone": 2}, "work": 14.0, "requires": ["farming"], "desc": "侧支：食物加成。"},
	"husbandry": {"age": "生存", "name": "围栏放牧", "cost": {"wood": 12, "crop": 2}, "work": 18.0, "requires": ["farming"], "desc": "侧支：食物上限加成。"},
	"food_chain": {"age": "生存", "name": "食物链整合", "cost": {"wood": 10, "crop": 4}, "work": 22.0, "requires": ["fishing", "husbandry"], "desc": "侧支：全食物加成。"},
	"logistics": {"age": "聚落", "name": "收纳与物流", "cost": {"wood": 10, "stone": 5}, "work": 18.0, "requires": ["food_chain"], "desc": "解锁收纳箱、医疗舱。"},
	"iron_age": {"age": "铁器", "name": "铁器时代", "cost": {"stone": 10, "iron": 6}, "work": 22.0, "requires": ["stone_age"], "desc": "解锁2级台升级权与铁器整段、铁家具套制造权。"},
	"defense": {"age": "铁器", "name": "自动火力", "cost": {"iron": 8, "stone": 8}, "work": 25.0, "requires": ["iron_age"], "desc": "解锁自动炮塔。"},
	"steam": {"age": "蒸汽", "name": "蒸汽时代", "cost": {"iron": 12, "stone": 8, "copper": 4}, "work": 30.0, "requires": ["defense"], "desc": "解锁发电机、水泵、电线杆、电线、高级工作台、手推车、汽车与蒸汽设施套。"},
	"electric": {"age": "电气", "name": "电气时代", "cost": {"iron": 10, "copper": 8}, "work": 32.0, "requires": ["steam"], "desc": "解锁太阳能板、大电池阵、激光炮塔、雷达站、电气工作台与电气设施套。"},
	"nuclear": {"age": "核能", "name": "核能跃迁", "cost": {"iron": 20, "copper": 10}, "work": 45.0, "requires": ["electric"], "desc": "解锁核反应堆、行星发动机（建成即跃迁）。"},
}


static func has(id: String) -> bool:
	return DATA.has(id)


static func get_def(id: String) -> Dictionary:
	return (DATA.get(id, {}) as Dictionary)


static func name_of(id: String) -> String:
	return str(get_def(id).get("name", id))


static func desc_of(id: String) -> String:
	return str(get_def(id).get("desc", ""))


static func work_of(id: String) -> float:
	return float(get_def(id).get("work", 1.0))


static func cost_of(id: String) -> Dictionary:
	return (get_def(id).get("cost", {}) as Dictionary).duplicate()


static func requires_of(id: String) -> Array:
	return (get_def(id).get("requires", []) as Array)


static func age_of(id: String) -> String:
	return str(get_def(id).get("age", "科技"))


static func cost_text(id: String) -> String:
	var parts: PackedStringArray = []
	for resource: String in cost_of(id):
		parts.append("%s %d" % [ActionTable.cn(resource), int(cost_of(id)[resource])])
	return "、".join(parts)
