class_name ColonySprites
extends RefCounted

## 素材图集：加载、切分、缓存。所有贴图 1:1 使用，不做缩放。
##
## VX Ace 行走图规格（People*/Actor*/Monster*/Animal）：
##   整图 384x256 = 4列 × 2行 个「角色块」，每块 96x128
##   每块内部 = 3帧 × 4方向，单帧 32x32
##   方向行序：0=朝下 1=朝左 2=朝右 3=朝上
##   行走循环帧序：0 → 1 → 2 → 1（1 是站姿）
##
## 图块集（Outside_B / Inside_B）：512x512 = 16×16 格，每格 32x32

const FRAME := 32
const BLOCK_W := 96
const BLOCK_H := 128
const BLOCK_COLS := 4
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3
const WALK_CYCLE := [0, 1, 2, 1]

const CHARS_DIR := "res://image/characters/reference/"
const MONSTERS_DIR := "res://image/characters/monsters/"
const TILES_DIR := "res://image/tiles/legacy/"

## 新生成的大图集先作为完整源素材入库。后续逐项验收切图时，从这里取对应时代图集，
## 不直接覆盖已经在运行的建筑图集，避免尚未校准的格子影响现有存档。
const EXPANDED_ASSET_DRAFTS := {
	"resources_wood_stone": preload("res://image/tiles/generated/expanded_asset_drafts/01_resources_wood_stone_tools.png"),
	"iron_age": preload("res://image/tiles/generated/expanded_asset_drafts/02_iron_age_workshop.png"),
	"furniture_survival": preload("res://image/tiles/generated/expanded_asset_drafts/03_furniture_survival_buildings.png"),
	"steam_electric": preload("res://image/tiles/generated/expanded_asset_drafts/04_steam_electric_tech.png"),
	"electric_nuclear": preload("res://image/tiles/generated/expanded_asset_drafts/05_electric_nuclear_endgame.png"),
	"actions_status_ui": preload("res://image/tiles/generated/expanded_asset_drafts/06_actions_status_ui.png"),
}

## 6 个固定主角 → 行走图 / 角色块 / 性格
## 性格取自 Pawn.TRAITS，6 人各占一种，保证辨识度
const PAWN_SPRITES := {
	"抽抽":   {"sheet": "Actor3",  "block": 7, "trait": "莽撞"},
	"班花":   {"sheet": "People4", "block": 3, "trait": "心细"},
	"龟龟":   {"sheet": "Actor2",  "block": 1, "trait": "结实"},
	"魔法师": {"sheet": "People2", "block": 6, "trait": "懒散"},
	"七海":   {"sheet": "People6", "block": 7, "trait": "勤快"},
	"鱼和糖": {"sheet": "People8", "block": 1, "trait": "胆小"},
}

## 地形资源物件
const RES_SPRITES := {
	"tree":  {"sheet": "Outside_B", "col": 5, "row": 11},
	"stone": {"sheet": "Outside_B", "col": 7, "row": 11},
	"iron":  {"sheet": "Outside_B", "col": 7, "row": 12},
}

## 建筑贴图。farm 没有合适素材，保留矢量画（见 World._draw）
const BUILDING_SPRITES := {
	"wall":     {"sheet": "Outside_B", "col": 5,  "row": 2},
	"door":     {"sheet": "Outside_B", "col": 2,  "row": 6},
	"campfire": {"sheet": "Outside_B", "col": 3,  "row": 10},
	# (11,10) 是灯头（水晶提灯），(11,11) 只是它下面那截光杆，别用错
	"torch":    {"sheet": "Outside_B", "col": 11, "row": 10},
	# 城垛样式的灰石垛口，比当围墙用的木栅栏更像防御工事
	"turret":   {"sheet": "Outside_B", "col": 12, "row": 10},
	"crop":     {"sheet": "Outside_B", "col": 4,  "row": 13},
	"bed":      {"sheet": "Inside_B",  "col": 1,  "row": 10},
	"table":    {"sheet": "Inside_B",  "col": 3,  "row": 12},
}

## 野兽贴图，按夜数递进（索引 = 波次索引）
const BEAST_SPRITES := [
	{"sheet": "Animal",   "block": 4},   # 灰狼 —— 前期
	{"sheet": "Monster3", "block": 7},   # 披甲野兽 —— 后期
]

static var _cache := {}


## 加载贴图，失败返回 null（调用方需自行兜底成矢量画）
static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[path] = t
	return t


## 行走图取帧 → {"tex": Texture2D, "rect": Rect2}，失败返回 {}
static func walk_frame(sheet: String, block: int, dir: int, frame: int, in_monsters: bool = false) -> Dictionary:
	var base := MONSTERS_DIR if in_monsters else CHARS_DIR
	var tex := texture(base + sheet + ".png")
	if tex == null:
		return {}
	var bx := (block % BLOCK_COLS) * BLOCK_W
	var by := (block / BLOCK_COLS) * BLOCK_H
	var f := clampi(frame, 0, 2)
	var d := clampi(dir, 0, 3)
	return {"tex": tex, "rect": Rect2(bx + f * FRAME, by + d * FRAME, FRAME, FRAME)}


## 图块集取格 → {"tex": Texture2D, "rect": Rect2}，失败返回 {}
static func tile_region(sheet: String, col: int, row: int) -> Dictionary:
	var tex := texture(TILES_DIR + sheet + ".png")
	if tex == null:
		return {}
	return {"tex": tex, "rect": Rect2(col * FRAME, row * FRAME, FRAME, FRAME)}


static func res_region(kind: String) -> Dictionary:
	var d: Dictionary = RES_SPRITES.get(kind, {})
	if d.is_empty():
		return {}
	return tile_region(d["sheet"], d["col"], d["row"])


static func building_region(id: String) -> Dictionary:
	var d: Dictionary = BUILDING_SPRITES.get(id, {})
	if d.is_empty():
		return {}
	return tile_region(d["sheet"], d["col"], d["row"])


## 由移动方向求朝向行号
static func facing_from(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return DIR_RIGHT if dir.x > 0.0 else DIR_LEFT
	return DIR_DOWN if dir.y > 0.0 else DIR_UP


