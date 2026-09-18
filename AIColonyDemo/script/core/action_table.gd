class_name ActionTable
## 动作表：定义 AI 总管可以下达的全部指令，以及指令的校验/规范化规则

const RES_NAMES := {"wood": "木材", "stone": "石料", "iron": "铁矿", "copper": "铜矿", "uranium": "铀矿", "crop": "作物", "food": "食物", "tree": "树"}
const VALID_TARGETS := ["tree", "stone", "iron", "copper", "uranium"]
const VALID_BUILDS := ["arrow_bench", "ammo_factory", "ammo_depot", "wall", "door", "torch", "campfire", "bed", "floor", "farm_plot", "storage", "workbench", "med_bay", "wood_tower", "stone_tower", "turret", "nuke_tower", "research", "generator", "battery", "radar", "ark_core", "wall_upgrade", "floor_upgrade", "workbench2", "adv_workbench", "pump", "pole", "wire", "pipe", "cart", "garage", "solar", "laser_turret", "reactor", "engine", "engine_floor", "steam_lamp", "iron_rivet_table", "monitor_window", "wood_chest", "wood_table", "wood_chair", "wood_window", "wood_fence", "wood_ladder", "wood_lamp", "stone_chest", "stone_table", "stone_chair", "stone_door", "stone_window", "stone_fence", "stone_ladder", "stone_lamp", "iron_chest", "iron_table", "iron_chair", "iron_door", "iron_window", "iron_fence", "iron_ladder", "iron_lamp", "copper_chest", "shelf", "water_tank", "elec_workbench", "elec_box", "elec_lamp", "elec_door", "metal_table", "grid_pole", "nuke_workbench", "rad_door", "nuke_lamp", "command_table", "lead_chest"]
const VALID_ITEMS := ["wooden_pickaxe", "wooden_axe", "wood_spear", "wood_bow", "wood_arrow", "wood_sword", "stone_pickaxe", "stone_sword", "wood_shield", "fine_bow", "stone_axe", "iron_pickaxe", "iron_axe", "iron_sword", "iron_shield", "iron_bow", "iron_arrow"]

## 玩家可规划的建筑，顺序即建造栏从左到右的顺序
const BUILD_ORDER := ["arrow_bench", "ammo_factory", "ammo_depot", "wall", "wall_upgrade", "door", "floor", "floor_upgrade", "torch", "campfire", "farm_plot", "bed", "wood_tower", "wood_chest", "wood_table", "wood_chair", "wood_window", "wood_fence", "wood_ladder", "wood_lamp", "stone_tower", "stone_chest", "stone_table", "stone_chair", "stone_door", "stone_window", "stone_fence", "stone_ladder", "stone_lamp", "storage", "workbench", "workbench2", "med_bay", "turret", "research", "iron_chest", "iron_table", "iron_chair", "iron_door", "iron_window", "iron_fence", "iron_ladder", "iron_lamp", "generator", "battery", "pump", "pole", "wire", "pipe", "cart", "garage", "shelf", "water_tank", "copper_chest", "adv_workbench", "steam_lamp", "iron_rivet_table", "radar", "monitor_window", "solar", "laser_turret", "elec_workbench", "elec_box", "elec_lamp", "elec_door", "metal_table", "grid_pole", "reactor", "nuke_tower", "ark_core", "engine", "engine_floor", "nuke_workbench", "rad_door", "nuke_lamp", "command_table", "lead_chest"]

## 规划项目与对应建筑贴图的关系：强化项目复用被强化建筑的图，虚影放大一圈叠加在原建筑上
const UPGRADE_SUFFIX := "_upgrade"


## 是否为强化项目（需要已有建筑才能规划）
static func is_upgrade(kind: String) -> bool:
	return kind.ends_with(UPGRADE_SUFFIX)


## 强化项目对应的基础建筑（墙 / 地板），非强化项目返回自身
static func upgrade_base(kind: String) -> String:
	if is_upgrade(kind):
		return kind.trim_suffix(UPGRADE_SUFFIX)
	return kind

## 动作定义：req = 必填参数，opt = 可选参数
const DEFS := {
	"move": {"desc": "走到指定格子坐标", "req": ["x", "y"], "opt": []},
	"mine": {"desc": "采集资源，target 可为 tree(砍树)/stone(采石，需木镐)/iron(挖铁，需石镐)/copper(挖铜，需石镐)/uranium(挖铀，需铁镐)，count 是数量", "req": ["target"], "opt": ["count"]},
	"build": {"desc": "施工玩家已放置的蓝图，AI 不会自行决定建筑位置；type 可为 wall(墙)/door(门)/torch(火把)/campfire(篝火)/bed(床)/floor(地板)/farm_plot(农田)/storage(收纳箱)/workbench(工作台)/med_bay(医疗舱)/turret(炮塔)/research(研究台)/generator(发电机)/battery(电池)/radar(雷达站)/ark_core(行星发动机)/wall_upgrade(城墙加固，需已有墙)/floor_upgrade(地板加固，需已有地板)/workbench2(2级台)/adv_workbench(高级工作台)/pump(水泵)/pole(电线杆)/cart(手推车)/garage(车库)/solar(太阳能板)/laser_turret(激光炮塔)/reactor(核反应堆)/engine(发动机舱)/木石铁家具套", "req": ["type"], "opt": ["count"]},
	"craft": {"desc": "制作装备，item 可为 wooden_pickaxe(木镐)/wooden_axe(木斧)/wood_spear(木矛)/wood_bow(木弓)/wood_arrow(木箭)/wood_sword(木剑)/stone_pickaxe(石镐)/stone_sword(石剑)/wood_shield(木盾)/fine_bow(精木弓)/stone_axe(精石斧)/iron_pickaxe(铁镐)/iron_axe(铁斧)/iron_sword(铁剑)/iron_shield(铁盾)/iron_bow(铁弓)/iron_arrow(铁箭)", "req": ["item"], "opt": ["count"]},
	"attack": {"desc": "攻击野兽，target_id 缺省则打最近的", "req": [], "opt": ["target_id"]},
	"eat": {"desc": "进食（消耗食物）", "req": [], "opt": []},
	"sleep": {"desc": "睡觉，恢复疲劳", "req": [], "opt": []},
	"plant": {"desc": "种地（在基地附近找草地）", "req": [], "opt": ["x", "y"]},
	"harvest": {"desc": "收获成熟的作物", "req": [], "opt": []},
	"cook": {"desc": "烹饪，消耗作物和木材产出食物", "req": [], "opt": ["count"]},
	"patrol": {"desc": "在基地周边巡逻", "req": [], "opt": ["x", "y"]},
	"repair": {"desc": "修理受损的墙或门", "req": [], "opt": ["x", "y"]},
	"demolish": {"desc": "拆除玩家已用拆除模式(X键)标记的建筑；无人认领则派一人去拆，无需材料、读条约2秒", "req": [], "opt": []},
	"research": {"desc": "在研究台投入科研劳动，推进星神已选择的科技", "req": [], "opt": []},
	"clear_base": {"desc": "清理基地周边的树和石头", "req": [], "opt": ["count"]},
	"flee": {"desc": "撤回基地", "req": [], "opt": []},
	"idle": {"desc": "原地待命", "req": [], "opt": []},
}

## 资源消耗表：项目 -> {资源名: 数量}（与 策划/资源-合成表.md 对齐）
const COSTS := {
	"arrow_bench": {"wood": 8, "stone": 2},
	"ammo_factory": {"iron": 10, "stone": 8},
	"ammo_depot": {"wood": 6, "stone": 4},
	"wall": {"stone": 5},
	"floor": {"stone": 1},
	"door": {"wood": 6},
	"torch": {"wood": 3},
	"campfire": {"wood": 10},
	"bed": {"wood": 8},
	"farm_plot": {"wood": 4},
	"storage": {"wood": 8, "stone": 4},
	"workbench": {"wood": 12, "stone": 4},
	"med_bay": {"wood": 10, "iron": 4},
	"wood_tower": {"wood": 14},
	"stone_tower": {"wood": 8, "stone": 14},
	"turret": {"stone": 20, "iron": 12},
	"nuke_tower": {"iron": 18, "copper": 10, "uranium": 4},
	"research": {"wood": 10, "iron": 4},
	"generator": {"iron": 10, "stone": 6},
	"battery": {"iron": 6, "stone": 4},
	"radar": {"iron": 10, "stone": 8},
	"ark_core": {"iron": 20, "copper": 10},
	"wall_upgrade": {"wood": 2, "stone": 3},
	"floor_upgrade": {"stone": 2},
	# 2级台 / 时代工作台与设施
	"workbench2": {"stone": 6, "iron": 2},
	"adv_workbench": {"iron": 8, "stone": 8},
	"elec_workbench": {"iron": 10, "copper": 6},
	"nuke_workbench": {"iron": 15, "copper": 10},
	"pump": {"wood": 6, "stone": 4},
	"pole": {"wood": 4, "iron": 2},
	"wire": {"copper": 2},
	"pipe": {"copper": 2},
	"cart": {"iron": 4, "wood": 6},
	"garage": {"stone": 8, "iron": 4},
	"solar": {"iron": 6, "copper": 4},
	"laser_turret": {"iron": 8, "copper": 6},
	"reactor": {"iron": 20, "copper": 10},
	"engine": {"iron": 10},
	"engine_floor": {"iron": 10},
	"shelf": {"wood": 6, "iron": 2},
	"water_tank": {"wood": 6, "iron": 2},
	"elec_box": {"iron": 4, "copper": 2},
	"elec_lamp": {"iron": 2, "copper": 2},
	"elec_door": {"iron": 6, "copper": 2},
	"metal_table": {"iron": 6},
	"monitor_window": {"iron": 2, "copper": 1},
	"grid_pole": {"iron": 4, "copper": 2},
	"rad_door": {"iron": 8, "copper": 4},
	"nuke_lamp": {"iron": 4, "copper": 4},
	"command_table": {"iron": 8, "copper": 2},
	"lead_chest": {"iron": 6, "copper": 2},
	"steam_lamp": {"iron": 2, "copper": 2},
	"iron_rivet_table": {"iron": 4, "stone": 2},
	# 木家具套（woodcraft）
	"wood_chest": {"wood": 6},
	"wood_table": {"wood": 4},
	"wood_chair": {"wood": 2},
	"wood_window": {"wood": 2},
	"wood_fence": {"wood": 2},
	"wood_ladder": {"wood": 2},
	"wood_lamp": {"wood": 3},
	# 石家具套（stone_age）
	"stone_chest": {"stone": 6, "wood": 2},
	"stone_table": {"stone": 4},
	"stone_chair": {"stone": 2, "wood": 1},
	"stone_door": {"stone": 6},
	"stone_window": {"stone": 2},
	"stone_fence": {"stone": 2},
	"stone_ladder": {"stone": 2},
	"stone_lamp": {"stone": 3, "wood": 1},
	# 铁家具套（iron_age）
	"iron_chest": {"iron": 4, "wood": 2},
	"iron_table": {"iron": 4},
	"iron_chair": {"iron": 2, "wood": 1},
	"iron_door": {"iron": 6},
	"iron_window": {"iron": 2},
	"iron_fence": {"iron": 2},
	"iron_ladder": {"iron": 2},
	"iron_lamp": {"iron": 2, "copper": 1},
	"copper_chest": {"copper": 4, "wood": 2},
	# craft 工具武器（数量型产出在 CRAFT_YIELD 里）
	"wooden_pickaxe": {"wood": 4},
	"wooden_axe": {"wood": 3},
	"wood_spear": {"wood": 2},
	"wood_bow": {"wood": 4},
	"wood_arrow": {"wood": 1},
	"wood_sword": {"wood": 3},
	"stone_pickaxe": {"stone": 3, "wood": 2},
	"stone_sword": {"stone": 2, "wood": 1},
	"wood_shield": {"wood": 4},
	"fine_bow": {"wood": 3},
	"stone_axe": {"wood": 2, "stone": 2},
	"iron_pickaxe": {"iron": 3, "wood": 1},
	"iron_axe": {"iron": 2, "wood": 1},
	"iron_sword": {"iron": 3, "wood": 1},
	"iron_shield": {"iron": 2, "wood": 2},
	"iron_bow": {"iron": 2, "wood": 2},
	"iron_arrow": {"iron": 1},
}

## 一次制造产出数量（缺省 1；木栅栏/梯、箭等一造多件）
const CRAFT_YIELD := {
	"wood_fence": 2,
	"wood_ladder": 2,
	"stone_fence": 2,
	"stone_ladder": 2,
	"iron_fence": 2,
	"iron_ladder": 2,
	"wood_arrow": 3,
	"iron_arrow": 3,
	"pipe": 2,
}

## craft 制造门：物品 -> 需要的科技（无条目 = 零科技徒手可搓）
const CRAFT_TECH := {
	"wood_spear": "woodcraft",
	"wood_bow": "woodcraft",
	"wood_arrow": "woodcraft",
	"wood_sword": "woodcraft",
	"stone_pickaxe": "stone_age",
	"stone_sword": "stone_age",
	"wood_shield": "stone_age",
	"fine_bow": "stone_age",
	"stone_axe": "stone_age",
	"iron_pickaxe": "iron_age",
	"iron_axe": "iron_age",
	"iron_sword": "iron_age",
	"iron_shield": "iron_age",
	"iron_bow": "iron_age",
	"iron_arrow": "iron_age",
}

## 建造栏悬停说明：项目 -> 具体描述
const DESC := {
	"arrow_bench": "木器时代：工人消耗木材生产箭矢，送入弹药仓。",
	"ammo_factory": "火力时代：工人用铁矿生产炮弹，电气时代用铜矿生产能量弹。",
	"ammo_depot": "木器时代：储存弹药，由空闲工人优先补给空弹塔和弓手。",
	"wall": "围出防线：挡住野兽，保护里面的殖民者与建筑。可以按住 Shift 拖动一次拉出一整条连续城墙。",
	"wall_upgrade": "在已建成的城墙上加固：血量上限从 100 提升到 220。需要先有一面墙，再把加固计划盖上去。",
	"door": "自己人能进出，野兽进不来。适合开在城墙线上当出入口。",
	"floor": "铺一块室内地板，遮住泥土并提升观感。铺好之后还能在地板上继续盖其他建筑。",
	"floor_upgrade": "在已铺好的地板上加固：等级 +1，踩上去更结实、观感更好。",
	"torch": "夜里提供一圈光照，减轻黑暗对士气的拖累。",
	"campfire": "取暖与聚餐点，夜里光源更强，也是殖民者休息的聚集处。",
	"farm_plot": "农田：种下作物后会自动补种与收割，是稳定的食物来源。",
	"bed": "床铺：殖民者夜里在这里睡觉，恢复疲劳。",
	"storage": "收纳箱：整理物资，让殖民者更快地把材料送到工地。",
	"workbench": "工作台：制作木剑与石斧，提升采集与战斗效率。",
	"med_bay": "医疗舱：伤员在这里治疗，降低阵亡风险。",
	"turret": "自动炮塔：夜里自动射击靠近的野兽，守住防线缺口。",
	"wood_tower": "木制箭塔：木器时代的基础远程防御，射速快、伤害较低。",
	"stone_tower": "石制弩塔：射程和威力高于木箭塔。",
	"nuke_tower": "核能等离子塔：终局远程防御，射程与伤害最高。",
	"research": "研究台：投入科研劳动推进星神选定的科技，是攀升科技树的前提。",
	"generator": "发电机：为电力设施提供能量。",
	"battery": "电池：储存电力，供夜间设施使用。",
	"radar": "雷达站：提前发现来袭的野兽，让炮塔与巡逻人员获得预警。",
	"ark_core": "行星发动机：建成后即可启动星海跃迁，带着整个基地前往下一颗星球（需核能跃迁科技）。",
	"engine_floor": "发动机舱板：铺发动机底座的地板。",
	"wire": "电线：连电线杆组网，铜料放量点。",
	"pipe": "水管：接水泵到发电机。",
	"steam_lamp": "蒸汽灯：燃气灯，范围大。",
	"iron_rivet_table": "铆铁桌椅：蒸汽工坊套。",
	"monitor_window": "监控窗：雷达站配套。",
	"workbench2": "2级台：在1级台上升級，解锁铁器整段制造。",
	"adv_workbench": "高级工作台：做得更快，铁器量产，蒸汽时代设施。",
	"elec_workbench": "电气工作台：3级台，做电气件更快。",
	"nuke_workbench": "核能工作台：终极台。",
	"pump": "水井水泵：抽水供锅炉。",
	"pole": "电线杆：送电组网。",
	"cart": "手推车：多拉货，物流提效。",
	"garage": "车库：停放手推车与汽车。",
	"solar": "太阳能板：白天发电免燃料。",
	"laser_turret": "激光炮塔：炮塔上位，强但耗电。",
	"reactor": "核反应堆：巨量电力，终局能源，需铀作燃料。",
	"engine": "行星发动机舱：跃迁用的发动机本体。",
	"wood_chest": "木箱：存物，收纳箱下位。",
	"wood_table": "木桌：配椅回心情。",
	"wood_chair": "木椅：配桌回心情。",
	"wood_window": "木窗：装饰加采光。",
	"wood_fence": "木栅栏：挡兽不挡人。",
	"wood_ladder": "木梯：装饰与上下。",
	"wood_lamp": "木灯：室内灯。",
	"stone_chest": "石箱：更硬的箱。",
	"stone_table": "石桌：耐用版桌。",
	"stone_chair": "石椅：耐用版椅。",
	"stone_door": "石门：硬门，挡兽好。",
	"stone_window": "石窗：石墙配套。",
	"stone_fence": "石栅栏：城墙下位。",
	"stone_ladder": "石梯：矿洞用梯。",
	"stone_lamp": "石灯：室外庭院灯。",
	"iron_chest": "铁箱：大容量箱。",
	"iron_table": "铁桌：工坊桌。",
	"iron_chair": "铁椅：工坊椅。",
	"iron_door": "铁门：加固门。",
	"iron_window": "铁窗：工坊窗。",
	"iron_fence": "铁栅栏：聚落外围栏。",
	"iron_ladder": "铁梯：深矿梯。",
	"iron_lamp": "铁矿灯：亮度最大。",
	"copper_chest": "铜箱：防潮箱。",
	"shelf": "货架：露天堆料架。",
	"water_tank": "水箱：存水配锅炉。",
	"elec_box": "电箱：配电箱。",
	"elec_lamp": "电灯：室内电灯，可开关。",
	"elec_door": "电动门：感应开关。",
	"metal_table": "金属桌椅：实验室套。",
	"grid_pole": "电网杆：电线杆上位。",
	"rad_door": "防辐射门：发动机舱门。",
	"nuke_lamp": "核能灯：全图最亮。",
	"command_table": "指挥桌椅：跃迁指挥套。",
	"lead_chest": "铅箱：存铀矿专用箱。",
}

## 中文名映射（用于日志与提示）
const CN := {
	"arrow_bench": "箭矢台", "ammo_factory": "弹药厂", "ammo_depot": "弹药仓",
	"tree": "树",
	"wall": "墙", "door": "门", "torch": "火把", "campfire": "篝火", "bed": "床", "floor": "地板", "farm_plot": "农田", "storage": "收纳箱", "workbench": "工作台", "med_bay": "医疗舱", "wood_tower": "木制箭塔", "stone_tower": "石制弩塔", "turret": "铁制炮塔", "nuke_tower": "核能塔", "research": "研究台", "generator": "发电机", "battery": "电池", "radar": "雷达站", "ark_core": "行星发动机",
	"wall_upgrade": "城墙加固", "floor_upgrade": "地板加固",
	"workbench2": "2级台", "adv_workbench": "高级工作台", "elec_workbench": "电气工作台", "nuke_workbench": "核能工作台",
	"pump": "水井水泵", "pole": "电线杆", "wire": "电线", "pipe": "水管", "cart": "手推车", "garage": "车库",
	"solar": "太阳能板", "laser_turret": "激光炮塔", "reactor": "核反应堆", "engine": "发动机舱", "engine_floor": "发动机舱板",
	"shelf": "货架", "water_tank": "水箱", "elec_box": "电箱", "elec_lamp": "电灯", "elec_door": "电动门",
	"metal_table": "金属桌椅", "monitor_window": "监控窗", "grid_pole": "电网杆",
	"rad_door": "防辐射门", "nuke_lamp": "核能灯", "command_table": "指挥桌椅", "lead_chest": "铅箱",
	"steam_lamp": "蒸汽灯", "iron_rivet_table": "铆铁桌椅",
	"wood_chest": "木箱", "wood_table": "木桌", "wood_chair": "木椅", "wood_window": "木窗",
	"wood_fence": "木栅栏", "wood_ladder": "木梯", "wood_lamp": "木灯",
	"stone_chest": "石箱", "stone_table": "石桌", "stone_chair": "石椅", "stone_door": "石门",
	"stone_window": "石窗", "stone_fence": "石栅栏", "stone_ladder": "石梯", "stone_lamp": "石灯",
	"iron_chest": "铁箱", "iron_table": "铁桌", "iron_chair": "铁椅", "iron_door": "铁门",
	"iron_window": "铁窗", "iron_fence": "铁栅栏", "iron_ladder": "铁梯", "iron_lamp": "铁灯",
	"copper_chest": "铜箱",
	"wooden_pickaxe": "木镐", "wooden_axe": "木斧", "wood_spear": "木矛", "wood_bow": "木弓",
	"wood_arrow": "木箭", "wood_sword": "木剑", "stone_pickaxe": "石镐", "stone_sword": "石剑",
	"wood_shield": "木盾", "fine_bow": "精木弓", "stone_axe": "精石斧",
	"iron_pickaxe": "铁镐", "iron_axe": "铁斧", "iron_sword": "铁剑", "iron_shield": "铁盾",
	"iron_bow": "铁弓", "iron_arrow": "铁箭",
}

## 中文名查询：CN 查不到的回退到 RES_NAMES（资源名），再没有返回原 key
static func cn(key: String) -> String:
	return str(CN.get(key, RES_NAMES.get(key, key)))


## 校验一条指令，返回规范化后的指令字典；不合法则返回空字典
static func validate(raw: Dictionary) -> Dictionary:
	if not raw.has("action"):
		return {}
	var action := str(raw["action"]).strip_edges()
	if not DEFS.has(action):
		return {}
	var def: Dictionary = DEFS[action]
	var out := {"action": action}

	for key in def["req"]:
		if not raw.has(key):
			return {}
		if raw[key] is Array or raw[key] is Dictionary or raw[key] == null:
			return {}
		outkey(key, raw, out)

	for key in def["opt"]:
		if raw.has(key) and raw[key] != null and str(raw[key]) != "":
			if raw[key] is Array or raw[key] is Dictionary:
				return {}
			outkey(key, raw, out)

	# who：指定小人名字，或 all / 所有人
	var who := str(raw.get("who", "all")).strip_edges()
	if who == "":
		who = "all"
	out["who"] = who

	# 枚举值校验
	if action == "mine" and not VALID_TARGETS.has(str(out.get("target", ""))):
		return {}
	if action == "build" and not VALID_BUILDS.has(str(out.get("type", ""))):
		return {}
	if action == "craft" and not VALID_ITEMS.has(str(out.get("item", ""))):
		return {}

	# 数量归一化
	if out.has("count"):
		out["count"] = clampi(int(out["count"]), 1, 99)
	if out.has("target_id"):
		out["target_id"] = int(out["target_id"])
	if out.has("x"):
		out["x"] = int(out["x"])
	if out.has("y"):
		out["y"] = int(out["y"])

	return out


static func outkey(key: String, raw: Dictionary, out: Dictionary) -> void:
	var v = raw[key]
	if v is String:
		out[key] = v.strip_edges()
	else:
		out[key] = v
	pass


## 生成给 AI 的动作表说明文本（塞进系统提示）
static func describe() -> String:
	var lines: PackedStringArray = []
	for action in DEFS:
		var d: Dictionary = DEFS[action]
		var req: Array = d["req"]
		var opt: Array = d["opt"]
		var parts: PackedStringArray = []
		if not req.is_empty():
			parts.append("必填: " + ", ".join(req))
		if not opt.is_empty():
			parts.append("可选: " + ", ".join(opt))
		var tail := ""
		if not parts.is_empty():
			tail = "（" + "；".join(parts) + "）"
		lines.append("- %s: %s%s" % [action, d["desc"], tail])
	return "\n".join(lines)


## 返回某项目的资源消耗（副本）
static func cost_of(key: String) -> Dictionary:
	return (COSTS.get(key, {}) as Dictionary).duplicate()


## 检查资源是否足够
static func can_afford(res: Dictionary, cost: Dictionary) -> bool:
	for k in cost:
		if int(res.get(k, 0)) < int(cost[k]):
			return false
	return true


## 扣资源
static func pay(res: Dictionary, cost: Dictionary) -> void:
	for k in cost:
		res[k] = int(res.get(k, 0)) - int(cost[k])
	pass


static func cost_text(kind: String) -> String:
	var parts: PackedStringArray = []
	var cost := cost_of(kind)
	for resource: String in cost:
		parts.append("%s %d" % [cn(resource), cost[resource]])
	return "、".join(parts)


