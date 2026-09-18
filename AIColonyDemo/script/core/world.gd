class_name GameWorld
extends Node2D
## 世界地图：算法生成物块、绘制、寻路、物块增删改

static var INSIDE_PROPS: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/rpgmaker/Inside_B.png")
static var COLONY_ASSETS: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/colony/colony_assets_v1.png")
static var COLONY_OBJECTS_LATEST: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/colony/colony_objects_latest.png")
static var WALL_STONE_DIRECTIONS: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/wall_stone_4dir.png")
static var WALL_UPGRADED_DIRECTIONS: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/wall_upgraded_4dir.png")
static var WALL_STONE_AUTOTILE: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/wall_stone_autotile_4x4.png")
static var WALL_UPGRADED_AUTOTILE: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/wall_upgraded_autotile_4x4.png")
static var DIRECTIONAL_ASSETS := {
	"door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/door_wood_4dir.png"),
	"stone_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/door_stone_4dir.png"),
	"iron_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/door_iron_4dir.png"),
	"elec_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/door_electric_4dir.png"),
	"rad_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/directional/door_radiation_4dir.png"),
}
static var DOOR_AUTOTILE_ASSETS := {
	"door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/door_wood_wall_segment_4x4.png"),
	"stone_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/door_stone_wall_segment_4x4.png"),
	"iron_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/door_iron_wall_segment_4x4.png"),
	"elec_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/door_electric_wall_segment_4x4.png"),
	"rad_door": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/autotile/door_radiation_wall_segment_4x4.png"),
}
static var TOWER_ASSETS := {
	"wood_tower": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_wood_arrow.png"),
	"stone_tower": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_stone_ballista.png"),
	"turret": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_iron_cannon.png"),
	"laser_turret": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_electric_laser.png"),
	"nuke_tower": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_nuclear_plasma.png"),
}
static var TOWER_DIRECTIONAL_ASSETS := {
	"wood_tower": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_wood_arrow_8dir.png"),
	"stone_tower": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_stone_ballista_8dir.png"),
	"turret": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_iron_cannon_8dir.png"),
	"laser_turret": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_electric_laser_8dir.png"),
	"nuke_tower": GameResourceGroups.texture_from_known_group("res://image/tiles/colony/towers/tower_nuclear_plasma_8dir.png"),
}
const OBJECT_ATLAS_ORDER := {
	"battery": 0, "radar": 1, "floor": 2, "crop_0": 3, "crop_1": 4, "crop_2": 5, "wall_upgraded": 6, "floor_upgraded": 7,
	"copper": 8, "uranium": 9, "wire": 10, "pipe": 11,
	"bed": 12, "wood_table": 13, "wood_chair": 14, "wood_chest": 15, "shelf": 16, "cart": 17, "solar": 18,
	"stone_table": 19, "stone_chair": 20, "stone_chest": 21, "stone_window": 22, "stone_fence": 23, "stone_ladder": 24,
	"iron_chest": 25, "iron_table": 26, "iron_chair": 27, "iron_window": 28, "iron_fence": 29, "iron_ladder": 30,
	"pump": 31, "pole": 32, "water_tank": 33, "generator": 34, "steam_lamp": 35, "adv_workbench": 36, "garage": 37, "copper_chest": 38, "iron_rivet_table": 39,
	"elec_lamp": 40, "elec_workbench": 41, "grid_pole": 42, "elec_box": 43,
	"monitor_window": 44, "reactor": 45, "engine_floor": 46, "engine": 47, "nuke_workbench": 48, "lead_chest": 49, "nuke_lamp": 50, "command_table": 51, "ark_core": 52, "laser_turret": 53,
}

const TILE := 32
const W := 128
const H := 128
const WALL_MASK_TO_AUTOTILE_INDEX := {
	0: 0,
	1: 1,
	2: 2,
	4: 3,
	8: 4,
	5: 5,
	10: 6,
	3: 7,
	6: 8,
	12: 9,
	9: 10,
	7: 11,
	14: 12,
	13: 13,
	11: 14,
	15: 15,
}

enum T {
	GRASS,       # 0 草地
	TREE,        # 1 树
	STONE,       # 2 石头
	IRON,        # 3 铁矿
	WALL,        # 4 墙
	DOOR,        # 5 门
	TORCH,       # 6 火把
	FLOOR,       # 7 地板
	BED,         # 8 床
	CROP,        # 9 作物
	CAVE_WALL,   # 10 洞穴岩壁
	CAVE_FLOOR,  # 11 洞穴地面
	STORAGE,     # 12 收纳箱
	TURRET,      # 13 自动炮塔
	RESEARCH,    # 14 研究台
	GENERATOR,   # 15 发电机
	BATTERY,     # 16 电池
	SHIP_CORE,   # 17 方舟跃迁核心
	CAMPFIRE,    # 18 篝火
	FARM_PLOT,   # 19 农田
	WORKBENCH,   # 20 工作台
	MED_BAY,     # 21 医疗舱
	RADAR,       # 22 雷达站
	COPPER,      # 23 铜矿（石镐挖）
	URANIUM,     # 24 铀矿（铁镐挖，深层稀有）
	WORKBENCH2,  # 25 2级台
	ADV_WORKBENCH, # 26 高级工作台
	PUMP,        # 27 水井水泵
	POLE,        # 28 电线杆
	CART,        # 29 手推车库（车库建筑，载具另算）
	GARAGE,      # 30 车库
	SOLAR,       # 31 太阳能板
	LASER_TURRET, # 32 激光炮塔
	REACTOR,     # 33 核反应堆
	ENGINE,      # 34 行星发动机舱
	WOOD_CHEST,  # 35 木箱
	WOOD_TABLE,  # 36 木桌
	WOOD_CHAIR,  # 37 木椅
	WOOD_WINDOW, # 38 木窗
	WOOD_FENCE,  # 39 木栅栏
	WOOD_LADDER, # 40 木梯
	WOOD_LAMP,   # 41 木灯
	STONE_CHEST, # 42 石箱
	STONE_TABLE, # 43 石桌
	STONE_CHAIR, # 44 石椅
	STONE_DOOR,  # 45 石门
	STONE_WINDOW, # 46 石窗
	STONE_FENCE, # 47 石栅栏
	STONE_LADDER, # 48 石梯
	STONE_LAMP,  # 49 石灯
	IRON_CHEST,  # 50 铁箱
	IRON_TABLE,  # 51 铁桌
	IRON_CHAIR,  # 52 铁椅
	IRON_DOOR,   # 53 铁门
	IRON_WINDOW, # 54 铁窗
	IRON_FENCE,  # 55 铁栅栏
	IRON_LADDER, # 56 铁梯
	IRON_LAMP,   # 57 铁灯
	COPPER_CHEST, # 58 铜箱
	SHELF,       # 59 货架
	WATER_TANK,  # 60 水箱
	ELEC_WORKBENCH, # 61 电气工作台
	ELEC_BOX,    # 62 电箱
	ELEC_LAMP,   # 63 电灯
	ELEC_DOOR,   # 64 电动门
	METAL_TABLE, # 65 金属桌椅
	GRID_POLE,   # 66 电网杆
	NUKE_WORKBENCH, # 67 核能工作台
	RAD_DOOR,    # 68 防辐射门
	NUKE_LAMP,   # 69 核能灯
	COMMAND_TABLE, # 70 指挥桌椅
	LEAD_CHEST,  # 71 铅箱
	STEAM_LAMP,  # 72 蒸汽灯
	IRON_RIVET_TABLE, # 73 铆铁桌椅
	MONITOR_WINDOW, # 74 监控窗
	ENGINE_FLOOR, # 75 发动机舱板
	WIRE,        # 76 电线
	PIPE,        # 77 水管
	WOOD_TOWER,  # 78 木制箭塔
	STONE_TOWER, # 79 石制弩塔
	NUKE_TOWER,  # 80 核能等离子塔
	ARROW_BENCH, AMMO_FACTORY, AMMO_DEPOT,
	WATER,
}

## 小人视角的阻挡（门可以开，所以不阻挡）。新增物块时同步尾部追加。
## true=矿/树/墙/炮塔/大机器挡路；门/床/家具/箱柜/货架/水箱/灯/线管/栅栏/火把/农田可过
const SOLID_P := [
	false, true, true, true, true, false, false, false, false, false,
	true, false, false, true, true, true, true, true, false, false,
	true, true, true, true, true, true, true, true, false, false,
	true, true, true, true, true, false, false, false, false, false,
	false, false, false, false, false, false, false, false, false, false,
	false, false, false, false, false, false, false, false, false, false,
	false, true, false, false, false, false, false, true, false, false,
	false, false, false, false, false, false, false, false, true, true,
	true, true, true, true,
	true,
]
## 野兽视角的阻挡 = 小人版 + 门/栅栏挡兽（栅栏设计为挡兽不挡人）
const SOLID_B := [
	false, true, true, true, true, true, false, false, false, false,
	true, false, false, true, true, true, true, true, false, false,
	true, true, true, true, true, true, true, true, false, false,
	true, true, true, true, true, false, false, false, false, true,
	false, false, false, false, false, true, false, true, false, false,
	false, false, false, true, false, true, false, false, false, false,
	false, true, false, false, true, false, false, true, true, false,
	false, false, false, false, false, false, false, false, true, true,
	true, true, true, true,
	true,
]
const _SOLID_LEN := 85

## 采集产出：物块 -> {资源: 数量}
const YIELD := {
	T.TREE: {"wood": 3},
	T.STONE: {"stone": 3},
	T.IRON: {"iron": 2},
	T.COPPER: {"copper": 2},
	T.URANIUM: {"uranium": 1},
	T.CAVE_WALL: {"stone": 3},
}

## 物块颜色
const COLORS := [
	Color("3f7d3a"), # 草地
	Color("26571f"), # 树
	Color("8a8f96"), # 石头
	Color("9aa3ad"), # 铁矿
	Color("6b5b4b"), # 墙
	Color("a9773c"), # 门
	Color("d9a441"), # 火把
	Color("9c8f7a"), # 地板
	Color("6a5acd"), # 床
	Color("8fbf4a"), # 作物
	Color("43434c"), # 洞穴岩壁
	Color("5d5347"), # 洞穴地面
	Color("936b3e"), # 收纳箱
	Color("596b7a"), # 炮塔
	Color("6173a7"), # 研究台
	Color("68765a"), # 发电机
	Color("4f8aaa"), # 电池
	Color("8b65b5"), # 方舟核心
	Color("c77a32"), # 篝火
	Color("73502e"), # 农田
	Color("7a5a3a"), # 工作台
	Color("7da7a1"), # 医疗舱
	Color("506f88"), # 雷达站
	Color("b87333"), # 铜矿
	Color("7cff6a"), # 铀矿
	Color("8a6a3a"), # 2级台
	Color("6a6a7a"), # 高级工作台
	Color("4a7aaa"), # 水泵
	Color("7a5a3a"), # 电线杆
	Color("8a7a5a"), # 手推车
	Color("5a5a6a"), # 车库
	Color("3a6aaa"), # 太阳能板
	Color("aa3a3a"), # 激光炮塔
	Color("3aaa3a"), # 核反应堆
	Color("aaaaff"), # 发动机舱
	Color("936b3e"), # 木箱
	Color("a9773c"), # 木桌
	Color("a9773c"), # 木椅
	Color("c7d7e7"), # 木窗
	Color("7a5a3a"), # 木栅栏
	Color("7a5a3a"), # 木梯
	Color("d9a441"), # 木灯
	Color("8a8f96"), # 石箱
	Color("8a8f96"), # 石桌
	Color("8a8f96"), # 石椅
	Color("6b5b4b"), # 石门
	Color("aab7c7"), # 石窗
	Color("6b5b4b"), # 石栅栏
	Color("8a8f96"), # 石梯
	Color("d9a441"), # 石灯
	Color("596b7a"), # 铁箱
	Color("596b7a"), # 铁桌
	Color("596b7a"), # 铁椅
	Color("4a5a6a"), # 铁门
	Color("aab7c7"), # 铁窗
	Color("4a5a6a"), # 铁栅栏
	Color("596b7a"), # 铁梯
	Color("ffe27a"), # 铁灯
	Color("b87333"), # 铜箱
	Color("8a7a5a"), # 货架
	Color("4a7aaa"), # 水箱
	Color("6a6a7a"), # 电气工作台
	Color("4f8aaa"), # 电箱
	Color("ffe27a"), # 电灯
	Color("4a5a6a"), # 电动门
	Color("9aa3ad"), # 金属桌椅
	Color("7a5a3a"), # 电网杆
	Color("6a6a7a"), # 核能工作台
	Color("8a8a3a"), # 防辐射门
	Color("7cff6a"), # 核能灯
	Color("9aa3ad"), # 指挥桌椅
	Color("5a5a5a"), # 铅箱
	Color("ffe27a"), # 蒸汽灯
	Color("9aa3ad"), # 铆铁桌椅
	Color("91c8e0"), # 监控窗
	Color("aaaaff"), # 发动机舱板
	Color("b87333"), # 电线
	Color("4a7aaa"), # 水管
	Color("8b5a2b"), # 木制箭塔
	Color("7b7f86"), # 石制弩塔
	Color("65e84f"), # 核能等离子塔
	Color("ac824a"), Color("778c95"), Color("997747"),
]

var tiles := PackedInt32Array()
var struct_hp := {}          # 格子索引 -> 建筑血量（仅 WALL / DOOR）
var struct_rotations := {}   # 格子索引 -> 建成建筑的朝向 0..3
var floor_upgrades := {}     # 格子索引 -> 地板强化等级
var base_floor := {}         # 格子索引 -> 压在建筑下方、被摧毁后原地恢复的地板
var crop_growth := {}        # 格子索引 -> 生长进度 0~1
var crop_plots := {}         # 格子索引 -> 该作物是否种在农田上；收获后恢复农田
var blueprints := {}         # 格子索引 -> 建筑类型；由玩家手工规划，殖民者只负责施工
var blueprint_rotations := {} # 格子索引 -> 蓝图旋转 0..3
var night_factor := 0.0      # 0 白天 / 1 深夜，用于火把光晕
var tower_facings := {}      # 格子索引 -> 炮台 8 向朝向，0 东起顺时针

# 规划预览：由 main 写入。悬停虚影 + Ctrl 拉矩形时的待铺格子。
var preview_kind := ""
var layout_preview: Array = []
var preview_rotation := 0
var preview_cells: Array = []
var demolish_cells: Array = []
var demolish_mark_cells: Array = []
var hover_cell := Vector2i(-1, -1)

## 未加固 / 已加固建筑的耐久上限
const WALL_HP := 100.0
const WALL_HP_UPGRADED := 220.0
## 强化计划的虚影比实物放大一圈，方便叠在既有建筑上看清楚
const UPGRADE_GHOST_SCALE := 1.22

var astar_p: AStarGrid2D     # 小人寻路
var astar_b: AStarGrid2D     # 野兽寻路

var base_cell := Vector2i(W / 2, H / 2)
var rng := RandomNumberGenerator.new()
var _font: Font
var terrain_surface: TerrainSurface

## 新建筑贴图先复用旧图集格位（后补图再拆）：铜/铀矿复用铁矿格，家具台子复用相近建筑格
const ATLAS_ORDER := {
	"arrow_bench": 10, "ammo_factory": 14, "ammo_depot": 9,
	"tree": 0,
	"stone": 1,
	"iron": 2,
	"copper": 2,
	"uranium": 2,
	"wall": 3,
	"door": 4,
	"torch": 5,
	"campfire": 6,
	"farm_plot": 7,
	"bed": 8,
	"storage": 9,
	"workbench": 10,
	"workbench2": 10,
	"adv_workbench": 10,
	"elec_workbench": 10,
	"nuke_workbench": 10,
	"med_bay": 11,
	"research": 12,
	"radar": 12,
	"monitor_window": 12,
	"turret": 13,
	"laser_turret": 13,
	"generator": 14,
	"battery": 14,
	"solar": 14,
	"reactor": 14,
	"elec_box": 14,
	"ark_core": 15,
	"engine": 15,
	"pump": 6,
	"water_tank": 6,
	"pole": 4,
	"grid_pole": 4,
	"elec_door": 4,
	"rad_door": 4,
	"stone_door": 4,
	"iron_door": 4,
	"cart": 9,
	"garage": 9,
	"shelf": 9,
	"wood_chest": 9,
	"stone_chest": 9,
	"iron_chest": 9,
	"copper_chest": 9,
	"lead_chest": 9,
	"wood_table": 8,
	"stone_table": 8,
	"iron_table": 8,
	"metal_table": 8,
	"command_table": 8,
	"iron_rivet_table": 8,
	"engine_floor": 7,
	"wire": 2,
	"pipe": 6,
	"steam_lamp": 5,
	"wood_chair": 8,
	"stone_chair": 8,
	"iron_chair": 8,
	"wood_window": 4,
	"stone_window": 4,
	"iron_window": 4,
	"wood_fence": 3,
	"stone_fence": 3,
	"iron_fence": 3,
	"wood_ladder": 7,
	"stone_ladder": 7,
	"iron_ladder": 7,
	"wood_lamp": 5,
	"stone_lamp": 5,
	"iron_lamp": 5,
	"elec_lamp": 5,
	"nuke_lamp": 5,
	"wood_tower": 13,
	"stone_tower": 13,
	"nuke_tower": 13,
}


func _ready() -> void:
	assert(SOLID_P.size() == _SOLID_LEN, "SOLID_P 长度必须等于 _SOLID_LEN")
	assert(SOLID_B.size() == _SOLID_LEN, "SOLID_B 长度必须等于 _SOLID_LEN")
	_font = Ui.font
	terrain_surface = TerrainSurface.new()
	add_child(terrain_surface)
	build_astar()
	pass


# ---------------------------------------------------------------- 生成

func generate(seed_value: int) -> void:
	rng.seed = seed_value
	tiles.resize(W * H)

	var n_forest := FastNoiseLite.new()
	n_forest.seed = rng.randi()
	n_forest.frequency = 0.055
	n_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var n_rock := FastNoiseLite.new()
	n_rock.seed = rng.randi()
	n_rock.frequency = 0.075
	n_rock.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var n_iron := FastNoiseLite.new()
	n_iron.seed = rng.randi()
	n_iron.frequency = 0.19
	n_iron.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var n_copper := FastNoiseLite.new()
	n_copper.seed = rng.randi()
	n_copper.frequency = 0.16
	n_copper.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var n_water := FastNoiseLite.new()
	n_water.seed = rng.randi()
	n_water.frequency = 0.035
	n_water.noise_type = FastNoiseLite.TYPE_SIMPLEX

	# 基础层：草地 / 森林 / 岩石（岩石带里按噪声分铁/铜/石头）
	for y in H:
		for x in W:
			var i := y * W + x
			var wa := n_water.get_noise_2d(x, y)
			var f := n_forest.get_noise_2d(x, y)
			var r := n_rock.get_noise_2d(x, y)
			var ir := n_iron.get_noise_2d(x, y)
			var cu := n_copper.get_noise_2d(x, y)
			if wa < -0.46 or (wa < -0.34 and abs(float(x - base_cell.x)) > 10.0 and abs(float(y - base_cell.y)) > 10.0):
				tiles[i] = T.WATER
			elif r > 0.30:
				if ir > 0.34:
					tiles[i] = T.IRON
				elif cu > 0.34:
					tiles[i] = T.COPPER
				else:
					tiles[i] = T.STONE
			elif f > 0.26:
				tiles[i] = T.TREE
			else:
				tiles[i] = T.GRASS
	# 铀矿：深层稀有点，全图撒 6~10 格石头堆里的单格铀
	for u in rng.randi_range(6, 10):
		var ux := rng.randi_range(8, W - 9)
		var uy := rng.randi_range(8, H - 9)
		var ui := uy * W + ux
		if tiles[ui] == T.STONE or tiles[ui] == T.IRON:
			tiles[ui] = T.URANIUM

	# 洞穴：若干个斑点区域，边缘为岩壁、内部为洞穴地面，洞里铁矿富集
	for c in rng.randi_range(3, 5):
		var cx := rng.randi_range(12, W - 13)
		var cy := rng.randi_range(12, H - 13)
		var rad := rng.randi_range(6, 11)
		for y in range(maxi(0, cy - rad - 3), mini(H, cy + rad + 4)):
			for x in range(maxi(0, cx - rad - 3), mini(W, cx + rad + 4)):
				var d := Vector2(x - cx, y - cy).length()
				if d > rad + 2.5:
					continue
				var i := y * W + x
				if d < float(rad) - 2.0 + n_iron.get_noise_2d(x, y) * 3.0:
					# 洞内地面，铁矿按噪声富集；洞底偶见铀
					var iv := n_iron.get_noise_2d(x, y)
					tiles[i] = T.IRON if iv > 0.30 else (T.URANIUM if iv < -0.55 else T.CAVE_FLOOR)
				elif d < rad + 2.5:
					tiles[i] = T.CAVE_WALL

	# 出生地清空：保证开局有立足之地
	for y in range(base_cell.y - 6, base_cell.y + 7):
		for x in range(base_cell.x - 6, base_cell.x + 7):
			tiles[y * W + x] = T.GRASS

	refresh_all_solid()
	terrain_surface.rebuild(tiles, W, H, TILE)
	pass


func build_astar() -> void:
	astar_p = AStarGrid2D.new()
	astar_p.region = Rect2i(0, 0, W, H)
	astar_p.cell_size = Vector2(TILE, TILE)
	astar_p.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_p.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_p.update()

	astar_b = AStarGrid2D.new()
	astar_b.region = Rect2i(0, 0, W, H)
	astar_b.cell_size = Vector2(TILE, TILE)
	astar_b.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_b.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_b.update()
	pass


func refresh_all_solid() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			var t := tiles[i]
			var v := Vector2i(x, y)
			astar_p.set_point_solid(v, SOLID_P[t])
			astar_b.set_point_solid(v, SOLID_B[t])
	pass


func refresh_solid(c: Vector2i) -> void:
	var t := tiles[c.y * W + c.x]
	astar_p.set_point_solid(c, SOLID_P[t])
	astar_b.set_point_solid(c, SOLID_B[t])
	pass


# ---------------------------------------------------------------- 查询

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func tile_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return T.CAVE_WALL
	return tiles[c.y * W + c.x]


func walkable(c: Vector2i, for_beast: bool = false) -> bool:
	if not in_bounds(c):
		return false
	var t := tiles[c.y * W + c.x]
	return not (SOLID_B[t] if for_beast else SOLID_P[t])


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))


func is_buildable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var t := tiles[c.y * W + c.x]
	return t == T.GRASS or t == T.CAVE_FLOOR or t == T.FLOOR


func can_place_blueprint(c: Vector2i, kind: String) -> bool:
	if not in_bounds(c):
		return false
	var t := tile_at(c)
	if kind == "wall_upgrade":
		return t == T.WALL
	if kind == "floor_upgrade":
		return t == T.FLOOR
	# 地板是基底：已经铺好地板的地面仍然可以继续规划上层建筑。
	if t == T.FLOOR:
		return kind != "floor"
	return t == T.GRASS or t == T.CAVE_FLOOR


## 两格之间需要铺满的格子（含首尾）。走 L 形而不是对角斜线，
## 因为城墙只按四向相连，斜着补格会在拐角留下漏得进野兽的缺口。
func line_cells(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = [from]
	var cur := from
	while cur.x != to.x:
		cur = Vector2i(cur.x + signi(to.x - cur.x), cur.y)
		out.append(cur)
	while cur.y != to.y:
		cur = Vector2i(cur.x, cur.y + signi(to.y - cur.y))
		out.append(cur)
	return out


## 矩形范围内的全部格子（含首尾），用于 Ctrl 拉出的正方形规划
func rect_cells(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			out.append(Vector2i(x, y))
	return out


func struct_tile(c: Vector2i) -> bool:
	var t := tile_at(c)
	return is_wall_line_tile(t)


func is_wall_line_tile(t: int) -> bool:
	return t in [T.WALL, T.DOOR, T.STONE_DOOR, T.IRON_DOOR, T.ELEC_DOOR, T.RAD_DOOR]


func wall_connection_mask(c: Vector2i) -> int:
	var mask := 0
	if struct_tile(c + Vector2i.UP):
		mask |= 1
	if struct_tile(c + Vector2i.RIGHT):
		mask |= 2
	if struct_tile(c + Vector2i.DOWN):
		mask |= 4
	if struct_tile(c + Vector2i.LEFT):
		mask |= 8
	return mask


func door_autotile_direction(c: Vector2i, fallback_rotation: int) -> int:
	var mask := wall_connection_mask(c)
	var horizontal := (mask & 2) != 0 or (mask & 8) != 0
	var vertical := (mask & 1) != 0 or (mask & 4) != 0
	if horizontal and not vertical:
		return 0
	if vertical and not horizontal:
		return 1
	return posmod(fallback_rotation, 4)


func add_blueprint(c: Vector2i, kind: String, rotation: int = 0) -> bool:
	var key := c.y * W + c.x
	if blueprints.has(key):
		# 同一格重复规划同一种建筑时只刷新朝向，方便边拖边转
		if str(blueprints[key]) != kind:
			return false
		blueprint_rotations[key] = rotation % 4
		queue_redraw()
		return true
	if not can_place_blueprint(c, kind):
		return false
	blueprints[key] = kind
	blueprint_rotations[key] = rotation % 4
	queue_redraw()
	return true


func remove_blueprint(c: Vector2i) -> void:
	var key := c.y * W + c.x
	blueprints.erase(key)
	blueprint_rotations.erase(key)
	queue_redraw()
	pass


func blueprint_at(c: Vector2i) -> String:
	return str(blueprints.get(c.y * W + c.x, ""))


func blueprint_rotation_at(c: Vector2i) -> int:
	return int(blueprint_rotations.get(c.y * W + c.x, 0))


## 按 R 键微调某一格已规划建筑的朝向
func set_blueprint_rotation(c: Vector2i, rotation: int) -> void:
	var key := c.y * W + c.x
	if not blueprints.has(key):
		return
	blueprint_rotations[key] = rotation % 4
	queue_redraw()
	pass


func find_blueprint(from: Vector2i, kind: String = "") -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for key in blueprints:
		if kind != "" and str(blueprints[key]) != kind:
			continue
		var c := Vector2i(int(key) % W, int(key) / W)
		var d := Vector2(from - c).length()
		if d < best_d:
			best_d = d
			best = c
	return best


func finish_blueprint(c: Vector2i, t: int) -> void:
	var key := c.y * W + c.x
	var kind := str(blueprints.get(key, ""))
	var rotation := int(blueprint_rotations.get(key, 0))
	blueprints.erase(key)
	blueprint_rotations.erase(key)
	if kind == "wall_upgrade":
		struct_hp[key] = maxf(float(struct_hp.get(key, WALL_HP)), WALL_HP_UPGRADED)
		queue_redraw()
		return
	if kind == "floor_upgrade":
		floor_upgrades[key] = int(floor_upgrades.get(key, 0)) + 1
		queue_redraw()
		return
	place(c, t)
	if rotation == 0:
		struct_rotations.erase(key)
	else:
		struct_rotations[key] = rotation
	queue_redraw()
	pass


## 已加固的城墙耐久上限更高；未加固的维持基础上限
func struct_max_hp(c: Vector2i) -> float:
	return WALL_HP_UPGRADED if float(struct_hp.get(c.y * W + c.x, 0.0)) > WALL_HP else WALL_HP


func floor_upgrade_at(c: Vector2i) -> int:
	return int(floor_upgrades.get(c.y * W + c.x, 0))


func struct_rotation_at(c: Vector2i) -> int:
	return int(struct_rotations.get(c.y * W + c.x, 0))


## 找最近的某类物块（螺旋搜索），找不到返回 (-1,-1)
func find_nearest_tile(from: Vector2i, types: Array, max_r := 40) -> Vector2i:
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue  # 只扫这一圈的外环
				var c := from + Vector2i(dx, dy)
				if in_bounds(c) and types.has(tiles[c.y * W + c.x]):
					return c
	return Vector2i(-1, -1)


func has_tile(type: int) -> bool:
	for t in tiles:
		if t == type:
			return true
	return false


## 寻找真正可抵达的资源格，避免挑中被树/岩石完全围住的孤岛。
func find_reachable_tile(from: Vector2i, types: Array, max_r := 40) -> Vector2i:
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var candidate := from + Vector2i(dx, dy)
				if not in_bounds(candidate) or not types.has(tile_at(candidate)):
					continue
				var stand := adjacent_walkable(candidate, from)
				if stand == Vector2i(-1, -1):
					continue
				if stand == from or not find_path(from, stand).is_empty():
					return candidate
	return Vector2i(-1, -1)


## 找最近的野兽（按像素距离），返回索引，找不到 -1
func find_nearest_beast(from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in range(get_tree().get_nodes_in_group("beasts").size()):
		var b = get_tree().get_nodes_in_group("beasts")[i]
		if not is_instance_valid(b) or b.dead:
			continue
		var d := from.distance_to(b.position)
		if d < best_d:
			best_d = d
			best = i
	return best


# ---------------------------------------------------------------- 修改

## 采集：移除物块并返回产出 {资源: 数量}
func harvest(c: Vector2i) -> Dictionary:
	var t := tile_at(c)
	if not YIELD.has(t):
		return {}
	var out: Dictionary = (YIELD[t] as Dictionary).duplicate()
	tiles[c.y * W + c.x] = T.CAVE_FLOOR if (t == T.CAVE_WALL or t == T.IRON and in_cave(c)) else T.GRASS
	refresh_solid(c)
	queue_redraw()
	return out


func in_cave(c: Vector2i) -> bool:
	# 附近有洞穴地面/岩壁就认为在洞里
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n := c + Vector2i(dx, dy)
			if in_bounds(n):
				var t := tiles[n.y * W + n.x]
				if t == T.CAVE_WALL or t == T.CAVE_FLOOR:
					return true
	return false


func place(c: Vector2i, t: int) -> void:
	if not in_bounds(c):
		return
	var i := c.y * W + c.x
	var old := tiles[i]
	# 地板是基底：建筑盖在地板上时把地板记在下面，建筑被摧毁后原地恢复。
	if old == T.FLOOR and t != T.FLOOR:
		base_floor[i] = T.FLOOR
	elif t == T.FLOOR or t == T.GRASS or t == T.CAVE_FLOOR:
		base_floor.erase(i)
	tiles[i] = t
	if t == T.WALL or t == T.DOOR:
		struct_hp[i] = WALL_HP
	if t == T.CROP:
		crop_growth[i] = 0.0
		if old == T.FARM_PLOT:
			crop_plots[i] = true
	refresh_solid(c)
	queue_redraw()


## 对建筑造成伤害，返回是否被摧毁
func damage_struct(c: Vector2i, dmg: float) -> bool:
	var i := c.y * W + c.x
	if not struct_hp.has(i):
		return false
	var hp := float(struct_hp[i]) - dmg
	if hp <= 0.0:
		destroy_struct(c)
		return true
	struct_hp[i] = hp
	return false


## 建筑被摧毁：下方压着地板就恢复地板，否则露出草地
func destroy_struct(c: Vector2i) -> void:
	var i := c.y * W + c.x
	struct_hp.erase(i)
	struct_rotations.erase(i)
	tiles[i] = int(base_floor.get(i, T.GRASS))
	base_floor.erase(i)
	refresh_solid(c)
	queue_redraw()
	pass


## 是否已有可拆除的建筑（自然资源与空地不行）；蓝图不算建筑，由 remove_blueprint 处理
func demolishable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var t := tiles[c.y * W + c.x]
	return t != T.GRASS and t != T.CAVE_FLOOR and t != T.CROP and t != T.TREE and t != T.STONE and t != T.IRON and t != T.COPPER and t != T.URANIUM and t != T.CAVE_WALL


func repair_struct(c: Vector2i, amount: float) -> bool:
	var i := c.y * W + c.x
	if not struct_hp.has(i):
		return false
	struct_hp[i] = minf(struct_max_hp(c), float(struct_hp[i]) + amount)
	return true


## 找最近的受损建筑
func find_damaged_struct(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for key in struct_hp:
		var c := Vector2i(int(key) % W, int(key) / W)
		if float(struct_hp[key]) >= struct_max_hp(c):
			continue
		var d := Vector2(from - c).length()
		if d < best_d:
			best_d = d
			best = c
	return best


func tick_crops(delta: float) -> void:
	if crop_growth.is_empty():
		return
	var changed := false
	for key in crop_growth.keys():
		var g := float(crop_growth[key])
		if g >= 1.0:
			continue
		var grow_time := 60.0 if crop_plots.has(key) else 90.0
		crop_growth[key] = minf(1.0, g + delta / grow_time)
		changed = true
	if changed:
		queue_redraw()


func mature_crop_at(c: Vector2i) -> bool:
	var i := c.y * W + c.x
	return crop_growth.has(i) and float(crop_growth[i]) >= 1.0


func find_mature_crop(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for key in crop_growth:
		if float(crop_growth[key]) < 1.0:
			continue
		var c := Vector2i(int(key) % W, int(key) / W)
		var d := Vector2(from - c).length()
		if d < best_d:
			best_d = d
			best = c
	return best


func remove_crop(c: Vector2i) -> void:
	var i := c.y * W + c.x
	crop_growth.erase(i)
	if crop_plots.has(i):
		crop_plots.erase(i)
		tiles[i] = T.FARM_PLOT
	else:
		tiles[i] = T.GRASS
	refresh_solid(c)
	queue_redraw()
	pass


# ---------------------------------------------------------------- 寻路

## 返回从 from 到 to 的路径（格子坐标数组，不含起点）；无路可走返回空数组
func find_path(from: Vector2i, to: Vector2i, for_beast: bool = false) -> Array:
	var grid := astar_b if for_beast else astar_p
	if not in_bounds(from) or not in_bounds(to):
		return []

	if grid.is_point_solid(to):
		to = nearest_free(to, for_beast)
		if to == Vector2i(-1, -1):
			return []
	if grid.is_point_solid(from):
		from = nearest_free(from, for_beast)
		if from == Vector2i(-1, -1):
			return []

	var ids := grid.get_id_path(from, to)
	var out: Array = []
	for i in range(1, ids.size()):
		out.append(ids[i])
	return out


func nearest_free(c: Vector2i, for_beast: bool) -> Vector2i:
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if walkable(n, for_beast):
					return n
	return Vector2i(-1, -1)


## 找 c 周围一个可站的格子
func adjacent_walkable(c: Vector2i, from: Vector2i, for_beast: bool = false) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n := c + Vector2i(dx, dy)
			if not walkable(n, for_beast):
				continue
			var d := Vector2(from - n).length()
			if d < best_d:
				best_d = d
				best = n
	return best


# ---------------------------------------------------------------- 绘制

func _process(_delta: float) -> void:
	queue_redraw()
	pass


func _draw() -> void:
	if DisplayServer.get_name() == "headless":
		return

	# 只画视野内的格子
	var view := visible_world_rect()
	var x0 := clampi(int(floor(view.position.x / TILE)) - 1, 0, W - 1)
	var x1 := clampi(int(ceil((view.position.x + view.size.x) / TILE)) + 1, 0, W - 1)
	var y0 := clampi(int(floor(view.position.y / TILE)) - 1, 0, H - 1)
	var y1 := clampi(int(ceil((view.position.y + view.size.y) / TILE)) + 1, 0, H - 1)

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var t := tiles[y * W + x]
			var pos := Vector2(x * TILE, y * TILE)
			var cell := Vector2i(x, y)
			# 连续材质由独立地表层绘制，格子层仅保留实体与规划反馈。
			if t == T.CAVE_WALL:
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0.025, 0.03, 0.04, 0.38))
			if t in [T.TREE, T.STONE, T.IRON, T.COPPER, T.URANIUM, T.WALL, T.BED, T.WOOD_TOWER, T.STONE_TOWER, T.TURRET, T.LASER_TURRET, T.NUKE_TOWER]:
				draw_set_transform(pos + Vector2(16, 25), 0.0, Vector2(1.0, 0.38))
				draw_circle(Vector2.ZERO, 13.0, Color(0.02, 0.03, 0.02, 0.32))
				draw_set_transform(Vector2.ZERO)

			var asset_key := tile_asset_key(t)
			if t == T.FLOOR:
				asset_key = "floor_upgraded" if floor_upgrade_at(cell) > 0 else "floor"
			elif t == T.CROP:
				var growth := float(crop_growth.get(cell.y * W + cell.x, 0.0))
				if growth >= 1.0:
					asset_key = "crop_2"
				elif growth >= 0.5:
					asset_key = "crop_1"
				else:
					asset_key = "crop_0"
			var is_upgraded_wall := t == T.WALL and struct_max_hp(cell) > WALL_HP
			var wall_autotile := wall_autotile_texture(is_upgraded_wall) if t == T.WALL else null
			var door_autotile := door_autotile_texture(asset_key)
			var directional := directional_texture(asset_key, is_upgraded_wall)
			var special := special_building_texture(asset_key)
			var tower_directional := tower_directional_texture(asset_key)
			var atlas_texture := asset_texture(asset_key)
			var atlas_rect := asset_region(asset_key)
			if wall_autotile != null:
				draw_wall_autotile_sprite(pos, wall_autotile, wall_connection_mask(cell))
			elif door_autotile != null:
				draw_door_autotile_sprite(pos, door_autotile, door_autotile_direction(cell, struct_rotation_at(cell)))
			elif tower_directional != null:
				draw_tower_directional_sprite(pos, tower_directional, tower_facing_at(cell))
			elif special != null:
				draw_texture_rect(special, Rect2(pos, Vector2(TILE, TILE)), false)
			elif directional != null:
				draw_directional_sprite(pos, directional, struct_rotation_at(cell))
			elif atlas_rect.size != Vector2.ZERO:
				draw_tile_sprite(pos, atlas_texture, atlas_rect, struct_rotation_at(cell))
				draw_upgraded_marker(t, pos, cell)
			else:
				draw_vector_tile(t, pos, cell)

			var planned := blueprint_at(cell)
			if planned != "":
				draw_plan_ghost(planned, pos, blueprint_rotation_at(cell), 0.62)

	draw_plan_preview()

	# 基地标记
	var bc := cell_center(base_cell)
	draw_arc(bc, TILE * 2.5, 0, TAU, 48, Color(0.95, 0.85, 0.35, 0.5), 3.0)
	if _font:
		draw_string(_font, bc + Vector2(-30, -TILE * 2.5 - 8), "基地",
			HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color(0.95, 0.85, 0.35, 0.85))


## 按 R 键记录下来的朝向绘制建筑：绕格子中心旋转，0 就是素材正放
func draw_tile_sprite(pos: Vector2, texture: Texture2D, region: Rect2, rotation: int) -> void:
	var size := Vector2(TILE, TILE)
	if rotation == 0:
		draw_texture_rect_region(texture, Rect2(pos, size), region)
		return
	draw_set_transform(pos + size * 0.5, float(rotation) * PI * 0.5, Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(-size * 0.5, size), region)
	draw_set_transform(Vector2.ZERO)
	pass


## 四方向专用图按左上=上、右上=右、左下=下、右下=左排列。
## 这里直接选图块，不再旋转像素，门轴、墙面受光和结构细节都能保持正确。
func draw_directional_sprite(pos: Vector2, texture: Texture2D, rotation: int, tint: Color = Color.WHITE, draw_size: Vector2 = Vector2(TILE, TILE)) -> void:
	var source_size := texture.get_size() * 0.5
	var direction := posmod(rotation, 4)
	var source_col := direction % 2
	var source_row := direction / 2
	var source := Rect2(Vector2(source_col, source_row) * source_size, source_size)
	var offset := (Vector2(TILE, TILE) - draw_size) * 0.5
	draw_texture_rect_region(texture, Rect2(pos + offset, draw_size), source, tint)
	pass


## 8 向炮台图集：4×2，顺序为东、东南、南、西南、西、西北、北、东北。
func draw_tower_directional_sprite(pos: Vector2, texture: Texture2D, direction: int, tint: Color = Color.WHITE, draw_size: Vector2 = Vector2(TILE, TILE)) -> void:
	var source_size := Vector2(texture.get_width() / 4.0, texture.get_height() / 2.0)
	var frame := posmod(direction, 8)
	var source := Rect2(Vector2(frame % 4, frame / 4) * source_size, source_size)
	var offset := (Vector2(TILE, TILE) - draw_size) * 0.5
	draw_texture_rect_region(texture, Rect2(pos + offset, draw_size), source, tint)
	pass


func tower_facing_at(cell: Vector2i) -> int:
	return int(tower_facings.get(cell.y * W + cell.x, 2))


func set_tower_facing_to(cell: Vector2i, target_pos: Vector2) -> void:
	var origin := cell_center(cell)
	var to_target := target_pos - origin
	if to_target.length_squared() <= 0.01:
		return
	var angle := atan2(to_target.y, to_target.x)
	tower_facings[cell.y * W + cell.x] = posmod(int(round(angle / (PI * 0.25))), 8)
	queue_redraw()
	pass


func draw_wall_autotile_sprite(pos: Vector2, texture: Texture2D, mask: int, tint: Color = Color.WHITE, draw_size: Vector2 = Vector2(TILE, TILE)) -> void:
	var source_size := texture.get_size() * 0.25
	var index := int(WALL_MASK_TO_AUTOTILE_INDEX.get(mask, 0))
	var source := Rect2(Vector2(index % 4, index / 4) * source_size, source_size)
	var offset := (Vector2(TILE, TILE) - draw_size) * 0.5
	draw_texture_rect_region(texture, Rect2(pos + offset, draw_size), source, tint)
	pass


func draw_door_autotile_sprite(pos: Vector2, texture: Texture2D, direction: int, state_row: int = 0, tint: Color = Color.WHITE, draw_size: Vector2 = Vector2(TILE, TILE)) -> void:
	var source_size := texture.get_size() * 0.25
	var source := Rect2(Vector2(posmod(direction, 4), clampi(state_row, 0, 3)) * source_size, source_size)
	var offset := (Vector2(TILE, TILE) - draw_size) * 0.5
	draw_texture_rect_region(texture, Rect2(pos + offset, draw_size), source, tint)
	pass


## 已加固的城墙加一圈金属包边，和没加固的区分开
func draw_upgraded_marker(t: int, pos: Vector2, cell: Vector2i) -> void:
	if t == T.WALL and struct_max_hp(cell) > WALL_HP:
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), Color(0.95, 0.83, 0.42, 0.6), false, 2.0)
	pass


## 规划虚影：直接用目标建筑本身的图做半透明预览，不再画「蓝图」两个字。
## 强化计划的虚影放大一圈叠在既有建筑之上，一眼能看出是在升级而不是新建。
func draw_plan_ghost(kind: String, pos: Vector2, rotation: int, alpha: float) -> void:
	if kind == "":
		return
	var upgraded := ActionTable.is_upgrade(kind)
	var base := ActionTable.upgrade_base(kind)
	var size := Vector2(TILE, TILE) * (UPGRADE_GHOST_SCALE if upgraded else 1.0)
	var tint := Color(1.0, 0.86, 0.42, alpha) if upgraded else Color(0.62, 0.92, 1.0, alpha)
	if base == "floor":
		# 地板没有专用美术，沿用矢量画，保证虚影和建成结果长得一样
		draw_set_transform(pos + Vector2(TILE, TILE) * 0.5, float(rotation) * PI * 0.5, Vector2.ONE)
		draw_rect(Rect2(-size * 0.5 + Vector2(3, 3), size - Vector2(6, 6)), tint)
		draw_set_transform(Vector2.ZERO)
	else:
		var wall_autotile := wall_autotile_texture(upgraded) if base == "wall" else null
		var door_autotile := door_autotile_texture(base)
		var directional := directional_texture(base, upgraded and base == "wall")
		var tower_dir := tower_directional_texture(base)
		var special := special_building_texture(base)
		if wall_autotile != null:
			draw_wall_autotile_sprite(pos, wall_autotile, 0, tint, size)
		elif door_autotile != null:
			draw_door_autotile_sprite(pos, door_autotile, rotation, 0, tint, size)
		elif tower_dir != null:
			draw_tower_directional_sprite(pos, tower_dir, 2, tint, size)
		elif special != null:
			var offset := (Vector2(TILE, TILE) - size) * 0.5
			draw_texture_rect(special, Rect2(pos + offset, size), false, tint)
		elif directional != null:
			draw_directional_sprite(pos, directional, rotation, tint, size)
		else:
			var texture := asset_texture(base)
			var region := asset_region(base)
			if region.size == Vector2.ZERO:
				return
			draw_set_transform(pos + Vector2(TILE, TILE) * 0.5, float(rotation) * PI * 0.5, Vector2.ONE)
			draw_texture_rect_region(texture, Rect2(-size * 0.5, size), region, tint)
			draw_set_transform(Vector2.ZERO)
	pass


## 鼠标位置的悬停虚影，以及 Ctrl/Shift/X 拉矩形时的待铺格子
func draw_plan_preview() -> void:
	for plan in layout_preview:
		draw_plan_ghost(plan.kind, Vector2(plan.cell * TILE), 0, 0.45)
	# 拆除：拖拽中橙框，已标记红 X（常驻显示，和预览开关无关）
	for cell: Vector2i in demolish_cells:
		draw_rect(Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), Color(1.0, 0.6, 0.3, 0.6), false, 2.0)
	for cell: Vector2i in demolish_mark_cells:
		var r := Rect2(Vector2(cell * TILE), Vector2(TILE, TILE))
		draw_rect(r, Color(1.0, 0.2, 0.2, 0.9), false, 2.0)
		draw_line(r.position + Vector2(8, 8), r.position + r.size - Vector2(8, 8), Color(1.0, 0.2, 0.2, 0.9), 3.0)
		draw_line(r.position + Vector2(r.size.x - 8, 8), r.position + Vector2(8, r.size.y - 8), Color(1.0, 0.2, 0.2, 0.9), 3.0)
	if preview_kind == "":
		# Shift 框选（黄框）与 X 拆除框（橙框）只画包围框，不画建筑虚影
		if not preview_cells.is_empty():
			var lo2: Vector2i = preview_cells[0]
			var hi2: Vector2i = preview_cells[0]
			for cell: Vector2i in preview_cells:
				lo2 = Vector2i(mini(lo2.x, cell.x), mini(lo2.y, cell.y))
				hi2 = Vector2i(maxi(hi2.x, cell.x), maxi(hi2.y, cell.y))
			draw_rect(Rect2(Vector2(lo2 * TILE), Vector2(hi2 - lo2 + Vector2i.ONE) * TILE), Color(1.0, 0.85, 0.3, 0.85), false, 2.0)
		if not demolish_cells.is_empty():
			var lo3: Vector2i = demolish_cells[0]
			var hi3: Vector2i = demolish_cells[0]
			for cell: Vector2i in demolish_cells:
				lo3 = Vector2i(mini(lo3.x, cell.x), mini(lo3.y, cell.y))
				hi3 = Vector2i(maxi(hi3.x, cell.x), maxi(hi3.y, cell.y))
			draw_rect(Rect2(Vector2(lo3 * TILE), Vector2(hi3 - lo3 + Vector2i.ONE) * TILE), Color(1.0, 0.6, 0.3, 0.85), false, 2.0)
		return
	if hover_cell != Vector2i(-1, -1) and preview_cells.is_empty() and blueprint_at(hover_cell) == "":
		draw_plan_ghost(preview_kind, Vector2(hover_cell * TILE), preview_rotation, 0.32)
	for cell: Vector2i in preview_cells:
		draw_plan_ghost(preview_kind, Vector2(cell * TILE), preview_rotation, 0.45)
	if preview_cells.is_empty():
		return
	# 包围框：让玩家在松手前看清这次会铺多大一片
	var lo: Vector2i = preview_cells[0]
	var hi: Vector2i = preview_cells[0]
	for cell: Vector2i in preview_cells:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	draw_rect(Rect2(Vector2(lo * TILE), Vector2(hi - lo + Vector2i.ONE) * TILE), Color(0.35, 0.8, 1.0, 0.75), false, 2.0)
	pass


## 没有专用美术的物块用矢量画兜底
func draw_vector_tile(t: int, pos: Vector2, cell: Vector2i) -> void:
	match t:
		T.WATER:
			draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color("2d6fa6"))
			var shimmer := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.004 + float(cell.x + cell.y))
			draw_line(pos + Vector2(5, 11), pos + Vector2(26, 9), Color(0.62, 0.9, 1.0, shimmer), 1.5)
			draw_line(pos + Vector2(2, 22), pos + Vector2(20, 24), Color(0.48, 0.78, 1.0, shimmer * 0.8), 1.2)
		T.TREE:
			draw_circle(pos + Vector2(16, 16), 12.0, Color("1b3d16"))
			draw_circle(pos + Vector2(13, 13), 4.0, Color("2f6b2a"))
		T.STONE:
			draw_rect(Rect2(pos + Vector2(7, 7), Vector2(18, 18)), Color("a8adb4"))
			draw_rect(Rect2(pos + Vector2(11, 10), Vector2(9, 7)), Color("787f88"))
		T.IRON:
			draw_rect(Rect2(pos + Vector2(7, 7), Vector2(18, 18)), Color("8b949e"))
			draw_circle(pos + Vector2(12, 12), 3.0, Color("e08a3c"))
			draw_circle(pos + Vector2(21, 19), 2.5, Color("e08a3c"))
			draw_circle(pos + Vector2(16, 22), 2.0, Color("f0a860"))
		T.WALL:
			draw_rect(Rect2(pos + Vector2(2, 2), Vector2(28, 28)), Color("7d6a57"))
			draw_rect(Rect2(pos + Vector2(2, 14), Vector2(28, 2)), Color("5c4d3f"))
			draw_line(pos + Vector2(16, 2), pos + Vector2(16, 14), Color("5c4d3f"), 2.0)
		T.DOOR:
			draw_rect(Rect2(pos + Vector2(4, 3), Vector2(24, 26)), Color("b8834a"))
			draw_circle(pos + Vector2(23, 16), 2.5, Color("f2d16b"))
		T.TORCH:
			draw_rect(Rect2(pos + Vector2(14, 12), Vector2(4, 18)), Color("6b4b2a"))
			var glow := 0.35 + 0.65 * night_factor
			draw_circle(pos + Vector2(16, 12), 6.0 + 6.0 * night_factor, Color(1.0, 0.75, 0.25, 0.22 * glow))
			draw_circle(pos + Vector2(16, 11), 4.0, Color("ffc447"))
		T.FLOOR:
			# 加固过的地板更亮，并带一圈浅金色包边
			var lv := floor_upgrade_at(cell)
			var board := Color("a89a86").lightened(0.14 * lv)
			var seam := board.darkened(0.18)
			var corner := pos + Vector2(3, 3)
			draw_rect(Rect2(corner, Vector2(26, 26)), board)
			draw_rect(Rect2(corner, Vector2(26, 26)), Color("6f6557"), false, 1.0)
			# 木板接缝：横缝错开竖缝，免得一整块看起来像空按钮
			for i in 3:
				var sy := corner.y + 6.0 * float(i + 1)
				draw_line(Vector2(corner.x, sy), Vector2(corner.x + 26.0, sy), seam, 1.0)
				var sx := corner.x + (10.0 if i % 2 == 0 else 18.0)
				draw_line(Vector2(sx, sy - 6.0), Vector2(sx, sy), seam, 1.0)
			if lv > 0:
				draw_rect(Rect2(pos + Vector2(2, 2), Vector2(28, 28)), Color(0.95, 0.85, 0.5, 0.5), false, 2.0)
		T.BED:
			# 使用整合自 ColonySim 的室内像素图块。
			draw_texture_rect_region(INSIDE_PROPS, Rect2(pos, Vector2(32, 32)), Rect2(0, 320, 32, 32))
		T.CROP:
			var g := float(crop_growth.get(cell.y * W + cell.x, 0.0))
			var c2 := Color("8fbf4a").lerp(Color("d9d94a"), g)
			draw_circle(pos + Vector2(16, 16), 6.0 + 5.0 * g, c2)
			if g >= 1.0:
				draw_circle(pos + Vector2(16, 16), 3.0, Color("f2f26b"))
		T.STORAGE:
			draw_texture_rect_region(INSIDE_PROPS, Rect2(pos, Vector2(32, 32)), Rect2(0, 192, 32, 32))
		T.TURRET:
			draw_circle(pos + Vector2(16, 16), 10, Color("60717c"))
			draw_line(pos + Vector2(16, 16), pos + Vector2(27, 8), Color("b9c8cf"), 4.0)
		T.RESEARCH:
			draw_rect(Rect2(pos + Vector2(6, 8), Vector2(20, 18)), Color("7185bd"))
			draw_circle(pos + Vector2(16, 7), 4, Color("a8e7ff"))
		T.GENERATOR:
			draw_rect(Rect2(pos + Vector2(5, 7), Vector2(22, 20)), Color("7e8c67"))
			draw_circle(pos + Vector2(16, 17), 6, Color("273125"))
		T.BATTERY:
			draw_rect(Rect2(pos + Vector2(8, 5), Vector2(16, 23)), Color("5a9fc0"))
			draw_line(pos + Vector2(16, 3), pos + Vector2(16, 7), Color("e7f8ff"), 2.0)
		T.SHIP_CORE:
			draw_circle(pos + Vector2(16, 16), 13, Color("634987"))
			draw_circle(pos + Vector2(16, 16), 7, Color("bba7ff"))
			draw_line(pos + Vector2(16, 2), pos + Vector2(16, 30), Color("e5ddff"), 2.0)
		T.CAMPFIRE:
			var glow := 0.25 + 0.75 * night_factor
			draw_circle(pos + Vector2(16, 15), 9.0 + 7.0 * night_factor, Color(1.0, 0.48, 0.12, 0.18 * glow))
			draw_line(pos + Vector2(8, 23), pos + Vector2(24, 17), Color("5b341f"), 3.0)
			draw_line(pos + Vector2(8, 17), pos + Vector2(24, 23), Color("5b341f"), 3.0)
			draw_circle(pos + Vector2(16, 14), 6.0, Color("ffb13d"))
			draw_circle(pos + Vector2(16, 11), 3.5, Color("fff08a"))
		T.FARM_PLOT:
			draw_rect(Rect2(pos + Vector2(4, 5), Vector2(24, 22)), Color("66452a"))
			for yy in [10, 16, 22]:
				draw_line(pos + Vector2(6, yy), pos + Vector2(26, yy - 2), Color("9a7547"), 1.5)
			draw_circle(pos + Vector2(11, 13), 2.5, Color("79b84a"))
			draw_circle(pos + Vector2(21, 20), 2.5, Color("79b84a"))
		T.WORKBENCH:
			draw_rect(Rect2(pos + Vector2(5, 10), Vector2(22, 13)), Color("8a6040"))
			draw_line(pos + Vector2(9, 23), pos + Vector2(9, 29), Color("4a3020"), 2.0)
			draw_line(pos + Vector2(23, 23), pos + Vector2(23, 29), Color("4a3020"), 2.0)
			draw_line(pos + Vector2(13, 12), pos + Vector2(22, 18), Color("c9c3b6"), 2.0)
		T.MED_BAY:
			draw_rect(Rect2(pos + Vector2(5, 11), Vector2(22, 13)), Color("d7e7e4"))
			draw_rect(Rect2(pos + Vector2(8, 8), Vector2(9, 5)), Color("7da7a1"))
			draw_rect(Rect2(pos + Vector2(14, 15), Vector2(4, 9)), Color("db5c5c"))
			draw_rect(Rect2(pos + Vector2(11, 18), Vector2(10, 3)), Color("db5c5c"))
		T.RADAR:
			draw_line(pos + Vector2(16, 26), pos + Vector2(16, 14), Color("b4c8d6"), 2.0)
			draw_arc(pos + Vector2(16, 14), 10, PI * 0.95, PI * 1.9, 16, Color("91c8e0"), 3.0)
			draw_line(pos + Vector2(16, 14), pos + Vector2(25, 7), Color("91c8e0"), 2.0)
			draw_circle(pos + Vector2(16, 26), 4, Color("40596b"))
		# 新资源用矢量兜底（图集复用铁矿格前先保证可辨认；有图后走 tile_asset_key）
		T.COPPER:
			draw_rect(Rect2(pos + Vector2(7, 7), Vector2(18, 18)), Color("a06a35"))
			draw_circle(pos + Vector2(12, 12), 3.0, Color("f0a860"))
			draw_circle(pos + Vector2(21, 19), 2.5, Color("f0a860"))
		T.URANIUM:
			draw_rect(Rect2(pos + Vector2(7, 7), Vector2(18, 18)), Color("4a6a3a"))
			draw_circle(pos + Vector2(16, 16), 4.0, Color("7cff6a"))
		# 新建筑矢量兜底：看不见图的格子也能玩（有图后 tile_asset_key 会优先走贴图）
		T.WORKBENCH2, T.ADV_WORKBENCH, T.ELEC_WORKBENCH, T.NUKE_WORKBENCH:
			draw_rect(Rect2(pos + Vector2(5, 10), Vector2(22, 13)), Color("8a6a5a"))
			draw_rect(Rect2(pos + Vector2(5, 10), Vector2(22, 3)), Color("f2c14e"))
		T.LASER_TURRET:
			draw_circle(pos + Vector2(16, 16), 10, Color("7c6060"))
			draw_line(pos + Vector2(16, 16), pos + Vector2(27, 8), Color("ff8a8a"), 4.0)
		T.SOLAR:
			draw_rect(Rect2(pos + Vector2(4, 8), Vector2(24, 16)), Color("3a6aaa"))
			draw_line(pos + Vector2(4, 16), pos + Vector2(28, 16), Color("e7f8ff"), 1.5)
		T.REACTOR:
			draw_circle(pos + Vector2(16, 16), 11, Color("3a7a3a"))
			draw_circle(pos + Vector2(16, 16), 5, Color("7cff6a"))
		T.ENGINE:
			draw_rect(Rect2(pos + Vector2(4, 6), Vector2(24, 20)), Color("aaaaff"))
			draw_circle(pos + Vector2(16, 16), 5, Color("e5ddff"))
		T.PUMP, T.WATER_TANK:
			draw_rect(Rect2(pos + Vector2(8, 6), Vector2(16, 20)), Color("4a7aaa"))
		T.POLE, T.GRID_POLE:
			draw_rect(Rect2(pos + Vector2(14, 4), Vector2(4, 24)), Color("7a5a3a"))
			draw_line(pos + Vector2(6, 8), pos + Vector2(26, 8), Color("7a5a3a"), 2.0)
		T.CART, T.GARAGE, T.SHELF:
			draw_rect(Rect2(pos + Vector2(5, 12), Vector2(22, 12)), Color("8a7a5a"))
		T.ELEC_BOX:
			draw_rect(Rect2(pos + Vector2(8, 6), Vector2(16, 18)), Color("4f8aaa"))
		T.ELEC_LAMP, T.NUKE_LAMP:
			draw_circle(pos + Vector2(16, 12), 5.0, Color("ffe27a"))
		T.ELEC_DOOR, T.RAD_DOOR, T.STONE_DOOR, T.IRON_DOOR:
			draw_rect(Rect2(pos + Vector2(4, 3), Vector2(24, 26)), Color("8a8a9a"))
		T.WOOD_CHEST, T.STONE_CHEST, T.IRON_CHEST, T.COPPER_CHEST, T.LEAD_CHEST:
			draw_rect(Rect2(pos + Vector2(6, 12), Vector2(20, 12)), Color("936b3e"))
		T.WOOD_TABLE, T.STONE_TABLE, T.IRON_TABLE, T.METAL_TABLE, T.COMMAND_TABLE:
			draw_rect(Rect2(pos + Vector2(4, 12), Vector2(24, 6)), Color("a9773c"))
		T.WOOD_CHAIR, T.STONE_CHAIR, T.IRON_CHAIR:
			draw_rect(Rect2(pos + Vector2(10, 10), Vector2(12, 12)), Color("a9773c"))
		T.WOOD_WINDOW, T.STONE_WINDOW, T.IRON_WINDOW:
			draw_rect(Rect2(pos + Vector2(6, 8), Vector2(20, 14)), Color("c7d7e7"))
		T.WOOD_FENCE, T.STONE_FENCE, T.IRON_FENCE:
			draw_line(pos + Vector2(4, 16), pos + Vector2(28, 16), Color("7d6a57"), 3.0)
		T.WOOD_LADDER, T.STONE_LADDER, T.IRON_LADDER:
			draw_line(pos + Vector2(10, 4), pos + Vector2(10, 28), Color("7d6a57"), 2.0)
			draw_line(pos + Vector2(22, 4), pos + Vector2(22, 28), Color("7d6a57"), 2.0)
		T.WOOD_LAMP, T.STONE_LAMP, T.IRON_LAMP:
			draw_circle(pos + Vector2(16, 12), 4.0, Color("ffc447"))
		T.STEAM_LAMP:
			draw_circle(pos + Vector2(16, 12), 6.0, Color("ffb13d"))
		T.IRON_RIVET_TABLE:
			draw_rect(Rect2(pos + Vector2(4, 12), Vector2(24, 6)), Color("596b7a"))
		T.MONITOR_WINDOW:
			draw_rect(Rect2(pos + Vector2(6, 8), Vector2(20, 14)), Color("91c8e0"))
		T.ENGINE_FLOOR:
			draw_rect(Rect2(pos + Vector2(2, 2), Vector2(28, 28)), Color("aaaaff"))
		T.WIRE:
			draw_line(pos + Vector2(4, 16), pos + Vector2(28, 16), Color("b87333"), 2.0)
		T.PIPE:
			draw_line(pos + Vector2(4, 16), pos + Vector2(28, 16), Color("4a7aaa"), 3.0)
	pass


func visible_world_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(0, 0, W * TILE, H * TILE)
	var vt := get_viewport().get_canvas_transform().affine_inverse()
	var vp_size := get_viewport_rect().size
	var a := vt * Vector2.ZERO
	var b := vt * vp_size
	return Rect2(a, b - a).abs()


func tile_asset_key(t: int) -> String:
	match t:
		T.TREE: return "tree"
		T.STONE: return "stone"
		T.IRON: return "iron"
		T.COPPER: return "copper"
		T.URANIUM: return "uranium"
		T.WALL: return "wall"
		T.DOOR: return "door"
		T.TORCH: return "torch"
		T.CAMPFIRE: return "campfire"
		T.FARM_PLOT: return "farm_plot"
		T.BED: return "bed"
		T.STORAGE: return "storage"
		T.WORKBENCH: return "workbench"
		T.WORKBENCH2: return "workbench2"
		T.ADV_WORKBENCH: return "adv_workbench"
		T.ELEC_WORKBENCH: return "elec_workbench"
		T.NUKE_WORKBENCH: return "nuke_workbench"
		T.MED_BAY: return "med_bay"
		T.RESEARCH: return "research"
		T.TURRET: return "turret"
		T.LASER_TURRET: return "laser_turret"
		T.WOOD_TOWER: return "wood_tower"
		T.STONE_TOWER: return "stone_tower"
		T.NUKE_TOWER: return "nuke_tower"
		T.ARROW_BENCH: return "arrow_bench"
		T.AMMO_FACTORY: return "ammo_factory"
		T.AMMO_DEPOT: return "ammo_depot"
		T.GENERATOR: return "generator"
		T.BATTERY: return "battery"
		T.SOLAR: return "solar"
		T.REACTOR: return "reactor"
		T.RADAR: return "radar"
		T.SHIP_CORE: return "ark_core"
		T.ENGINE: return "engine"
		T.PUMP: return "pump"
		T.POLE: return "pole"
		T.GRID_POLE: return "grid_pole"
		T.CART: return "cart"
		T.GARAGE: return "garage"
		T.SHELF: return "shelf"
		T.WATER_TANK: return "water_tank"
		T.ELEC_BOX: return "elec_box"
		T.ELEC_LAMP: return "elec_lamp"
		T.ELEC_DOOR: return "elec_door"
		T.METAL_TABLE: return "metal_table"
		T.RAD_DOOR: return "rad_door"
		T.NUKE_LAMP: return "nuke_lamp"
		T.COMMAND_TABLE: return "command_table"
		T.LEAD_CHEST: return "lead_chest"
		T.WOOD_CHEST: return "wood_chest"
		T.WOOD_TABLE: return "wood_table"
		T.WOOD_CHAIR: return "wood_chair"
		T.WOOD_WINDOW: return "wood_window"
		T.WOOD_FENCE: return "wood_fence"
		T.WOOD_LADDER: return "wood_ladder"
		T.WOOD_LAMP: return "wood_lamp"
		T.STONE_CHEST: return "stone_chest"
		T.STONE_TABLE: return "stone_table"
		T.STONE_CHAIR: return "stone_chair"
		T.STONE_DOOR: return "stone_door"
		T.STONE_WINDOW: return "stone_window"
		T.STONE_FENCE: return "stone_fence"
		T.STONE_LADDER: return "stone_ladder"
		T.STONE_LAMP: return "stone_lamp"
		T.IRON_CHEST: return "iron_chest"
		T.IRON_TABLE: return "iron_table"
		T.IRON_CHAIR: return "iron_chair"
		T.IRON_DOOR: return "iron_door"
		T.IRON_WINDOW: return "iron_window"
		T.IRON_FENCE: return "iron_fence"
		T.IRON_LADDER: return "iron_ladder"
		T.IRON_LAMP: return "iron_lamp"
		T.COPPER_CHEST: return "copper_chest"
		T.STEAM_LAMP: return "steam_lamp"
		T.IRON_RIVET_TABLE: return "iron_rivet_table"
		T.MONITOR_WINDOW: return "monitor_window"
		T.ENGINE_FLOOR: return "engine_floor"
		T.WIRE: return "wire"
		T.PIPE: return "pipe"
	return ""


## 建筑图集里的图案区域；战斗 HUD 与建造栏图标共用，所以做成静态方法
static func asset_region(kind: String) -> Rect2:
	if OBJECT_ATLAS_ORDER.has(kind):
		var object_size := COLONY_OBJECTS_LATEST.get_size()
		var object_cell := Vector2(object_size.x / 8.0, object_size.y / 7.0)
		var object_index := int(OBJECT_ATLAS_ORDER[kind])
		return Rect2(Vector2(object_index % 8, object_index / 8) * object_cell, object_cell)
	if not ATLAS_ORDER.has(kind):
		return Rect2()
	var size := COLONY_ASSETS.get_size()
	var cell := Vector2(size.x / 4.0, size.y / 4.0)
	var index := int(ATLAS_ORDER[kind])
	return Rect2(Vector2(index % 4, index / 4) * cell, cell)


static func asset_texture(kind: String) -> Texture2D:
	if OBJECT_ATLAS_ORDER.has(kind):
		return COLONY_OBJECTS_LATEST
	return COLONY_ASSETS


static func directional_texture(kind: String, upgraded_wall: bool = false) -> Texture2D:
	if kind == "wall":
		return WALL_UPGRADED_DIRECTIONS if upgraded_wall else WALL_STONE_DIRECTIONS
	return DIRECTIONAL_ASSETS.get(kind) as Texture2D


static func wall_autotile_texture(upgraded_wall: bool = false) -> Texture2D:
	return WALL_UPGRADED_AUTOTILE if upgraded_wall else WALL_STONE_AUTOTILE


static func door_autotile_texture(kind: String) -> Texture2D:
	return DOOR_AUTOTILE_ASSETS.get(kind) as Texture2D


static func tower_directional_texture(kind: String) -> Texture2D:
	return TOWER_DIRECTIONAL_ASSETS.get(kind) as Texture2D


static func special_building_texture(kind: String) -> Texture2D:
	return TOWER_ASSETS.get(kind) as Texture2D
