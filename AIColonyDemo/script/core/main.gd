extends Node2D
## 游戏主控：时间、资源、昼夜、兽袭、胜负、UI、指令分发

const DAY_LEN := 600.0            # 一游戏天的现实秒数：10 分钟
const CFG_PATH := "user://settings.cfg"
const PROJECTILE := preload("res://script/entities/projectile.gd")
var tower_ammo := {}
var depot_stock := {}
var proposed_layout: Array = []
var layout_dialog: ConfirmationDialog
var build_search: LineEdit
var build_era: OptionButton


func fire_projectile(origin: Vector2, target: Beast, damage: float, ammo: String) -> void:
	var shot := PROJECTILE.new()
	shot.position = origin
	shot.target = target
	shot.damage = damage
	shot.tint = Color("70e6fc") if ammo == "energy" else Color("f3cf83")
	world.add_child(shot)
	pass


func ammo_type(tile: int) -> String:
	if tile in [GameWorld.T.WOOD_TOWER, GameWorld.T.STONE_TOWER]:
		return "arrow"
	return "energy" if tile in [GameWorld.T.LASER_TURRET, GameWorld.T.NUKE_TOWER] else "shell"


func available_plan(worker: Colonist, kind: String = "") -> Vector2i:
	var best := Vector2i(-1, -1)
	var distance := INF
	for key in world.blueprints:
		var cell := Vector2i(int(key) % GameWorld.W, int(key) / GameWorld.W)
		var planned := world.blueprint_at(cell)
		if (kind != "" and kind != planned) or not can_build(planned):
			continue
		var claimed := false
		for other: Colonist in colonists:
			if other == worker or not other.alive:
				continue
			if other.task.get("goal", Vector2i(-1, -1)) == cell and other.task.get("action", "") == "build":
				claimed = true
		var d := worker.cell.distance_squared_to(cell)
		if not claimed and d < distance and not world.find_path(worker.cell, cell).is_empty():
			best = cell
			distance = d
	return best


func supply_job(worker: Colonist) -> Dictionary:
	if worker.hunger > 65.0 or worker.fatigue > 70.0:
		return {}
	for other: Colonist in colonists:
		if other != worker and other.alive and (other.task.get("action", "") == "supply" or other.queue.any(func(q): return q.get("action", "") == "supply")):
			return {}
	var depot := world.find_nearest_tile(worker.cell, [GameWorld.T.AMMO_DEPOT], 64)
	if depot == Vector2i(-1, -1):
		return {}
	var depot_key := depot.y * GameWorld.W + depot.x
	if not depot_stock.has(depot_key):
		depot_stock[depot_key] = {"arrow": 0, "shell": 0, "energy": 0}
	var stock: Dictionary = depot_stock[depot_key]
	for i in world.tiles.size():
		if tower_combat_stats(world.tiles[i]).is_empty() or int(tower_ammo.get(i, 0)) >= 8:
			continue
		var ammo := ammo_type(world.tiles[i])
		if int(stock.get(ammo, 0)) > 0:
			return {"action": "supply", "goal": depot, "depot": depot, "destination": Vector2i(i % GameWorld.W, i / GameWorld.W), "ammo": ammo}
	for archer: Colonist in colonists:
		if archer.alive and archer.bow_lv > 0 and archer.arrows < 3 and int(stock.arrow) > 0:
			return {"action": "supply", "goal": depot, "depot": depot, "archer": archer, "ammo": "arrow"}
	for ammo: String in ["arrow", "shell", "energy"]:
		if int(stock.get(ammo, 0)) >= 24 or (ammo == "energy" and not unlocked_tech.has("electric")):
			continue
		var material := "wood" if ammo == "arrow" else ("iron" if ammo == "shell" else "copper")
		if int(resources.get(material, 0)) < 1:
			continue
		var station := world.find_nearest_tile(worker.cell, [GameWorld.T.ARROW_BENCH if ammo == "arrow" else GameWorld.T.AMMO_FACTORY], 64)
		if station != Vector2i(-1, -1):
			return {"action": "supply", "goal": station, "depot": depot, "ammo": ammo, "material": material}
	return {}


func run_supply(worker: Colonist, delta: float) -> void:
	var job := worker.task
	var depot: Vector2i = job.depot
	if world.tile_at(depot) != GameWorld.T.AMMO_DEPOT:
		worker.finish("")
		return
	var stock: Dictionary = depot_stock.get(depot.y * GameWorld.W + depot.x, {})
	var goal: Vector2i = job.goal
	if job.has("cargo"):
		if job.has("archer") and is_instance_valid(job.archer) and job.archer.alive:
			goal = job.archer.cell
		else:
			goal = job.get("destination", depot)
	match worker.move_adjacent(goal):
		Colonist.Move.MOVING:
			worker.step_path(delta)
			return
		Colonist.Move.BLOCKED:
			if job.has("cargo"):
				stock[job.ammo] = int(stock.get(job.ammo, 0)) + int(job.cargo)
			worker.finish("")
			return
	if not job.has("cargo"):
		if job.has("material"):
			var required := GameWorld.T.ARROW_BENCH if job.ammo == "arrow" else GameWorld.T.AMMO_FACTORY
			if world.tile_at(goal) != required:
				worker.finish("")
				return
			job["work"] = float(job.get("work", 0.0)) + delta * worker.work_speed()
			if float(job.work) < 3.0:
				return
			if int(resources.get(job.material, 0)) < 1:
				worker.finish("")
				return
			resources[job.material] -= 1
			job["cargo"] = 6
		else:
			var amount := mini(8, int(stock.get(job.ammo, 0)))
			stock[job.ammo] = int(stock.get(job.ammo, 0)) - amount
			job["cargo"] = amount
		return
	var cargo := int(job.cargo)
	if job.has("archer") and is_instance_valid(job.archer) and job.archer.alive:
		job.archer.arrows += cargo
	elif job.has("destination") and not tower_combat_stats(world.tile_at(goal)).is_empty() and ammo_type(world.tile_at(goal)) == job.ammo:
		var key := goal.y * GameWorld.W + goal.x
		tower_ammo[key] = int(tower_ammo.get(key, 0)) + cargo
	else:
		stock[job.ammo] = int(stock.get(job.ammo, 0)) + cargo
	worker.finish("")
	pass


func propose_defense() -> void:
	proposed_layout.clear()
	for offset in range(-5, 6):
		for delta in [Vector2i(offset, -5), Vector2i(offset, 5), Vector2i(-5, offset), Vector2i(5, offset)]:
			var cell: Vector2i = world.base_cell + delta
			var kind := "door" if delta.x == 0 else "wall"
			if world.can_place_blueprint(cell, kind) and not proposed_layout.any(func(p): return p.cell == cell):
				proposed_layout.append({"cell": cell, "kind": kind})
	if can_build("wood_tower"):
		for delta in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
			var cell: Vector2i = world.base_cell + delta
			if world.can_place_blueprint(cell, "wood_tower"):
				proposed_layout.append({"cell": cell, "kind": "wood_tower"})
	world.layout_preview = proposed_layout.duplicate()
	if layout_dialog == null:
		layout_dialog = ConfirmationDialog.new()
		layout_dialog.title = "防线规划"
		layout_dialog.ok_button_text = "确认建造"
		layout_dialog.cancel_button_text = "取消"
		layout_dialog.confirmed.connect(confirm_defense)
		layout_dialog.canceled.connect(cancel_defense)
		ui_layer.add_child(layout_dialog)
	layout_dialog.dialog_text = "基地围墙、南北出入口与内侧箭塔，共 %d 项。确认后加入施工蓝图。" % proposed_layout.size()
	layout_dialog.popup_centered()
	pass


func confirm_defense() -> void:
	for plan in proposed_layout:
		if can_build(plan.kind):
			world.add_blueprint(plan.cell, plan.kind)
	cancel_defense()
	pass


func cancel_defense() -> void:
	proposed_layout.clear()
	world.layout_preview.clear()
	pass

const PAWN_DEFS := [
	{"name": "抽抽", "sheet": "res://image/characters/colonists/generated/npc_04_security_4x4.png", "generated_sheet": true, "color": Color("e05a5a"), "hp": 110.0, "speed": 1.12, "work": 1.05, "hunger": 1.10, "mood": 0.0, "skills": {"gather": 0.9, "build": 1.0, "research": 0.8, "combat": 1.3, "logistics": 0.9}, "traits": ["莽撞", "护短", "好胜"]},
	{"name": "班花", "sheet": "res://image/characters/colonists/generated/npc_02_medic_botanist_4x4.png", "generated_sheet": true, "color": Color("7fc7ff"), "hp": 85.0, "speed": 1.08, "work": 1.15, "hunger": 0.90, "mood": 8.0, "skills": {"gather": 1.0, "build": 1.1, "research": 1.3, "combat": 0.8, "logistics": 1.1}, "traits": ["细心", "共情", "完美主义"]},
	{"name": "龟龟", "sheet": "res://image/characters/colonists/generated/npc_03_miner_4x4.png", "generated_sheet": true, "color": Color("b8b8b8"), "hp": 135.0, "speed": 0.82, "work": 1.0, "hunger": 0.95, "mood": 5.0, "skills": {"gather": 1.2, "build": 1.25, "research": 0.8, "combat": 1.15, "logistics": 0.9}, "traits": ["沉稳", "固执", "守序"]},
	{"name": "魔法师", "sheet": "res://image/characters/colonists/generated/npc_05_scientist_4x4.png", "generated_sheet": true, "color": Color("c99aff"), "hp": 90.0, "speed": 1.0, "work": 0.92, "hunger": 0.9, "mood": 10.0, "skills": {"gather": 0.8, "build": 0.9, "research": 1.45, "combat": 0.85, "logistics": 1.0}, "traits": ["好奇", "散漫", "灵感"]},
	{"name": "七海", "sheet": "res://image/characters/colonists/generated/npc_01_engineer_4x4.png", "generated_sheet": true, "color": Color("66d5a6"), "hp": 105.0, "speed": 1.18, "work": 1.18, "hunger": 1.0, "mood": 6.0, "skills": {"gather": 1.3, "build": 1.05, "research": 1.0, "combat": 0.95, "logistics": 1.25}, "traits": ["勤快", "节俭", "焦虑"]},
	{"name": "鱼和糖", "sheet": "res://image/characters/colonists/generated/npc_06_farmer_quartermaster_4x4.png", "generated_sheet": true, "color": Color("ffd27f"), "hp": 95.0, "speed": 1.05, "work": 1.08, "hunger": 0.95, "mood": 12.0, "skills": {"gather": 1.0, "build": 0.95, "research": 1.05, "combat": 0.75, "logistics": 1.35}, "traits": ["胆小", "温柔", "警觉"]},
]

const WAVE_COUNT := [3, 4, 5, 6, 15]
const WAVE_HP := [40.0, 50.0, 60.0, 70.0, 90.0]
const WAVE_DMG := [6.0, 8.0, 10.0, 12.0, 15.0]
const TECHS := {
	"woodcraft": {"name": "木器时代", "cost": {"wood": 10}, "work": 12.0, "requires": ["survival"], "desc": "解锁木矛/木弓/木箭/木剑与木家具套制造权。"},
	"stone_age": {"name": "石器时代", "cost": {"wood": 8, "stone": 6}, "work": 16.0, "requires": ["woodcraft"], "desc": "解锁石镐/石剑/精石斧/精木弓/木盾与石家具套制造权。"},
	"farming": {"name": "驯化种田", "cost": {"wood": 6}, "work": 12.0, "requires": ["stone_age"], "desc": "侧支：农田产量加成，不卡主线。"},
	"fishing": {"name": "浅滩钓鱼", "cost": {"wood": 8, "stone": 2}, "work": 14.0, "requires": ["farming"], "desc": "侧支：食物加成。"},
	"husbandry": {"name": "围栏放牧", "cost": {"wood": 12, "crop": 2}, "work": 18.0, "requires": ["farming"], "desc": "侧支：食物上限加成。"},
	"food_chain": {"name": "食物链整合", "cost": {"wood": 10, "crop": 4}, "work": 22.0, "requires": ["fishing", "husbandry"], "desc": "侧支：全食物加成。"},
	"logistics": {"name": "收纳与物流", "cost": {"wood": 10, "stone": 5}, "work": 18.0, "requires": ["food_chain"], "desc": "解锁收纳箱、医疗舱。"},
	"iron_age": {"name": "铁器时代", "cost": {"stone": 10, "iron": 6}, "work": 22.0, "requires": ["stone_age"], "desc": "解锁2级台升级权与铁器整段、铁家具套制造权。"},
	"defense": {"name": "自动火力", "cost": {"iron": 8, "stone": 8}, "work": 25.0, "requires": ["iron_age"], "desc": "解锁自动炮塔（建筑体石20铁12另付）。"},
	"steam": {"name": "蒸汽时代", "cost": {"iron": 12, "stone": 8, "copper": 4}, "work": 30.0, "requires": ["defense"], "desc": "解锁发电机、水泵、电线杆、电线、高级工作台、手推车、汽车与蒸汽设施套。"},
	"electric": {"name": "电气时代", "cost": {"iron": 10, "copper": 8}, "work": 32.0, "requires": ["steam"], "desc": "解锁太阳能板、大电池阵、激光炮塔、雷达站、电气工作台与电气设施套。"},
	"nuclear": {"name": "核能跃迁", "cost": {"iron": 20, "copper": 10}, "work": 45.0, "requires": ["electric"], "desc": "解锁核反应堆、行星发动机（建成即跃迁）。"},
}
const TECH_ORDER := ["woodcraft", "stone_age", "farming", "fishing", "husbandry", "food_chain", "logistics", "iron_age", "defense", "steam", "electric", "nuclear"]
## 木器/石器免研究台，其余一律要先建成研究台
const NO_BENCH_TECH := {"woodcraft": true, "stone_age": true}
const QUICK_LIMIT := 6

var world: GameWorld
var colonists: Array = []
var beasts: Array = []
var resources := {"wood": 0, "stone": 0, "iron": 0, "copper": 0, "uranium": 0, "crop": 0, "food": 6}
var stats := {"wood": 0, "stone": 0, "iron": 0, "copper": 0, "uranium": 0, "crop": 0}

var planet := 1
var day := 1
var continue_button: Button
var objective_label: Label
var day_time := 0.0
var speed := 1.0
var difficulty := 1.0
var difficulty_name := "标准"
var game_over := false
var won := false
var selected: Colonist = null
var ai: AIManager
var ai_log
var camera: Camera2D
var tint: CanvasModulate
var night_spawned := false
var beast_id := 0
var _hud_cd := 0.0
var _turret_cd := 0.0
var unlocked_tech := {"survival": true}
var current_tech := ""
var research_progress := 0.0

# UI
var ui_layer: CanvasLayer
var time_label: Label
var res_label: Label
var pawn_box: HBoxContainer
var pawn_buttons: Array = []
var chat_log: RichTextLabel
var chat_input: LineEdit
var start_panel: Control
var end_panel: Control
var end_label: Label
var key_edit: LineEdit
var model_edit: LineEdit
var diff_option: OptionButton
var status_label: Label
var policy_label: Label
var policy := "平衡"
var blueprint_kind := "wall"
var blueprint_rotation := 0
var command_history: Array[String] = []
var history_index := 0
var blueprint_buttons := {}
## 规划拖拽模式：矩形（Ctrl）框选铺/删，进框选模式（Shift）做蓝图多选，拆除（X）标记拆除
enum Drag { NONE, RECT_PLACE, RECT_ERASE, SELECT, DEMOLISH }
var drag_mode := Drag.NONE
var drag_start_cell := Vector2i(-1, -1)
var select_rect := [Vector2i(-1, -1), Vector2i(-1, -1)]
var clipboard: Array = []
var paste_preview := false
var demolish_mode := false
var demolish_marks := {}       # 格子索引 -> true；已标拆除、待施工
var demolish_undo: Array = []  # 栈：每次 mark_demolish_rect 的格子数组，Ctrl+Z 弹出撤销
var _idle_time := 0.0
const IDLE_AUTO_SECONDS := 10.0
var auto_steward := true
var tech_label: Label
var tech_buttons := {}
var ai_quick_box: HBoxContainer
var ai_quick_commands: Array[String] = []
var last_player_command := ""


func _ready() -> void:
	randomize()
	if get_window():
		get_window().theme = Ui.theme

	setup_world()
	setup_ai()
	setup_camera()
	build_ui()
	load_settings()

	if auto_start():
		start_game()
		if _selftest:
			_test_start_ms = Time.get_ticks_msec()
			Engine.time_scale = 8.0
			probe()
	else:
		start_panel.visible = true
		get_tree().paused = true
	pass


func probe() -> void:
	var cnt := {}
	for t in world.tiles:
		cnt[t] = int(cnt.get(t, 0)) + 1
	print("[PROBE] 地形统计(0草 1树 2石 3铁 23铜 24铀 10岩壁 11洞地面): ", cnt)
	print("[PROBE] 基地 %s 最近的树: %s  最近的石: %s" % [
		str(world.base_cell),
		str(world.find_nearest_tile(world.base_cell, [GameWorld.T.TREE], 48)),
		str(world.find_nearest_tile(world.base_cell, [GameWorld.T.STONE], 48)),
	])
	pass


func auto_start() -> bool:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_shot = args.has("--shot")
	_shot_ms = Time.get_ticks_msec()
	_selftest = args.has("--selftest")
	return args.has("--autostart") or _selftest or DisplayServer.get_name() == "headless"


# ---------------------------------------------------------------- 初始化

func setup_world() -> void:
	world = GameWorld.new()
	world.name = "World"
	add_child(world)
	world.generate(randi())

	tint = CanvasModulate.new()
	add_child(tint)

	# 出生点围着基地站一圈
	var ring: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := world.base_cell + Vector2i(dx, dy)
			if world.walkable(c):
				ring.append(c)
	ring.shuffle()

	for i in PAWN_DEFS.size():
		var d: Dictionary = (PAWN_DEFS[i] as Dictionary).duplicate()
		d["sprite_slot"] = ColonySprites.PAWN_SPRITES[d["name"]]["block"]
		d["cell"] = ring[i % ring.size()] if not ring.is_empty() else world.base_cell
		var col := Colonist.new()
		world.add_child(col)
		col.setup(self, world, d)
		colonists.append(col)
	pass


func setup_ai() -> void:
	ai = AIManager.new()
	ai.name = "AIManager"
	add_child(ai)
	ai.result_ready.connect(on_ai_result)
	ai.busy_changed.connect(on_ai_busy)
	ai_log = load("res://script/data/ai_log.gd").new()
	ai_log.load_saved()
	for record in ai_log.entries:
		var text := str((record as Dictionary).get("player", ""))
		if text != "" and not ai_quick_commands.has(text):
			ai_quick_commands.append(text)
	while ai_quick_commands.size() > QUICK_LIMIT:
		ai_quick_commands.pop_back()
	pass


func setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = world.cell_center(world.base_cell)
	camera.zoom = Vector2(1.0, 1.0)
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	pass


# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	handle_camera(delta)
	if not game_over:
		tick_time(delta)
		tick_turrets(delta)

	world.night_factor = night_factor()
	update_tint()
	update_hover()
	tick_idle_auto(delta)

	_hud_cd -= delta
	if _hud_cd <= 0.0:
		_hud_cd = 0.4
		update_hud()

	if _selftest:
		run_selftest()
	if _shot and (Time.get_ticks_msec() - _shot_ms) / 1000.0 > 2.5:
		capture()
	pass


## 开发自检用：截图后退出（--shot）
func capture() -> void:
	_shot = false
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shot.png")
	print("[SHOT] 已保存 shot.png  尺寸=", img.get_size())
	get_tree().quit()
	pass


# ---------------------------------------------------------------- 自检（仅 --selftest）

var _selftest := false
var _test_start_ms := 0
var _test_stage := 0
var _shot := false
var _shot_ms := 0


func run_selftest() -> void:
	var t := (Time.get_ticks_msec() - _test_start_ms) / 1000.0

	if _test_stage == 0 and t > 1.0:
		_test_stage = 1
		print("[SELFTEST] 阶段1：采集 / 种植 / 做饭")
		send_command("抽抽去砍5棵树")
		send_command("七海去采3块石头")
		send_command("班花去种地")
		send_command("鱼和糖做饭")

	elif _test_stage == 1 and t > 9.0:
		_test_stage = 2
		report("阶段1 结果")
		print("[SELFTEST] 阶段2：建造 / 制作")
		send_command("所有人建围墙")
		send_command("龟龟造石斧")
		send_command("七海去打铁矿石2块")

	elif _test_stage == 2 and t > 18.0:
		_test_stage = 3
		report("阶段2 结果")
		print("[SELFTEST] 阶段3：兽袭 / 战斗")
		spawn_wave(3)
		send_command("所有人去打野兽")

	elif _test_stage == 3 and t > 27.0:
		_test_stage = 4
		report("阶段3 结果")
		print("[SELFTEST] 阶段4：撤退 / 睡觉 / 吃饭")
		send_command("所有人撤回基地")
		send_command("大家去睡觉")

	elif _test_stage == 4 and t > 34.0:
		_test_stage = 5
		report("阶段4 结果")
		print("[SELFTEST] 完成")
		get_tree().quit()
	pass


func report(title: String) -> void:
	print("──────── %s ────────" % title)
	print("  第%d天 %s  资源：木%d 石%d 铁%d 铜%d 铀%d 作物%d 食物%d  野兽:%d  科技:%s" % [
		day, clock_text(), int(resources["wood"]), int(resources["stone"]),
		int(resources["iron"]), int(resources["copper"]), int(resources["uranium"]), int(resources["crop"]), int(resources["food"]), live_beasts(),
		",".join(unlocked_tech.keys()),
	])
	for c in colonists:
		if not c.alive:
			print("  %s：已阵亡" % c.cname)
			continue
		print("  %s：血%d 饥%d 疲%d 心%d  位置(%d,%d)  当前:%s  队列:%d" % [
			c.cname, int(c.hp), int(c.hunger), int(c.fatigue), int(c.mood),
			c.cell.x, c.cell.y, c.task_desc(), c.queue.size(),
		])
	pass


func tick_time(delta: float) -> void:
	day_time += delta
	if day_time >= DAY_LEN:
		day_time -= DAY_LEN
		day += 1
		night_spawned = false
		for b in beasts:
			if is_instance_valid(b):
				b.retreating = true

	# 18:00 入夜刷兽
	if not night_spawned and day_time >= DAY_LEN * 0.5:
		night_spawned = true
		spawn_wave(day)

	world.tick_crops(delta)

	# 定期清理已死亡的野兽引用
	if fmod(day_time, 3.0) < delta:
		beasts = beasts.filter(func(b): return is_instance_valid(b) and not b.dead)


func handle_camera(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * 700.0 * delta / camera.zoom.x
		clamp_camera()


func tick_turrets(delta: float) -> void:
	_turret_cd -= delta
	if _turret_cd > 0.0:
		return
	_turret_cd = 0.8
	for y in GameWorld.H:
		for x in GameWorld.W:
			var c := Vector2i(x, y)
			var tt := world.tile_at(c)
			var tower_stats := tower_combat_stats(tt)
			if tower_stats.is_empty():
				continue
			var origin := world.cell_center(c)
			var target: Beast = null
			var d_best := float(tower_stats["range"]) * GameWorld.TILE
			for b in beasts:
				if is_instance_valid(b) and not b.dead:
					var d := origin.distance_to(b.position)
					if d < d_best:
						d_best = d
						target = b
			if target:
				var key := c.y * GameWorld.W + c.x
				if int(tower_ammo.get(key, 0)) <= 0:
					continue
				tower_ammo[key] = int(tower_ammo[key]) - 1
				world.set_tower_facing_to(c, target.position)
				fire_projectile(origin, target, float(tower_stats["damage"]), ammo_type(tt))


func tower_combat_stats(tile: int) -> Dictionary:
	match tile:
		GameWorld.T.WOOD_TOWER: return {"range": 5.0, "damage": 6.0}
		GameWorld.T.STONE_TOWER: return {"range": 7.0, "damage": 10.0}
		GameWorld.T.TURRET: return {"range": 8.0, "damage": 16.0}
		GameWorld.T.LASER_TURRET: return {"range": 10.0, "damage": 24.0}
		GameWorld.T.NUKE_TOWER: return {"range": 12.0, "damage": 36.0}
	return {}


func clamp_camera() -> void:
	var half := get_viewport_rect().size * 0.5 / camera.zoom
	var map := Vector2(GameWorld.W, GameWorld.H) * GameWorld.TILE
	if map.x > half.x * 2:
		camera.position.x = clampf(camera.position.x, half.x, map.x - half.x)
	else:
		camera.position.x = map.x * 0.5
	if map.y > half.y * 2:
		camera.position.y = clampf(camera.position.y, half.y, map.y - half.y)
	else:
		camera.position.y = map.y * 0.5
	pass


func _unhandled_input(event: InputEvent) -> void:
	if game_over or start_panel.visible:
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				finish_drag(false)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				finish_drag(true)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.12).clamp(Vector2(0.35, 0.35), Vector2(3.0, 3.0))
			clamp_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.12).clamp(Vector2(0.35, 0.35), Vector2(3.0, 3.0))
			clamp_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if paste_preview:
				paste_clipboard(world.world_to_cell(get_global_mouse_position()))
				return
			var mp := get_global_mouse_position()
			var cell := world.world_to_cell(mp)
			if demolish_mode:
				begin_drag(Drag.DEMOLISH, cell)
				return
			if event.shift_pressed:
				begin_drag(Drag.SELECT, cell)
				return
			if event.ctrl_pressed:
				begin_drag(Drag.RECT_PLACE, cell)
				return
			# 优先选中人物；若没有点到人物，才由玩家亲手规划建筑。
			var best: Colonist = null
			var best_d := 26.0
			for c in colonists:
				if not c.alive:
					continue
				var d := mp.distance_to(c.position)
				if d < best_d:
					best_d = d
					best = c
			if best:
				selected = best
				update_hud()
			else:
				place_blueprint(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if paste_preview:
				cancel_paste()
				return
			if demolish_mode:
				set_demolish_mode(false)
				return
			if event.ctrl_pressed:
				begin_drag(Drag.RECT_ERASE, world.world_to_cell(get_global_mouse_position()))
				return
			cancel_drag()
			var cell := world.world_to_cell(get_global_mouse_position())
			if world.blueprint_at(cell) == "":
				return
			var kind := world.blueprint_at(cell)
			world.remove_blueprint(cell)
			log_line("已撤销该格%s规划" % ActionTable.cn(kind), Color(0.7, 0.85, 1.0))
	elif event is InputEventMouseMotion and drag_mode != Drag.NONE:
		update_drag(world.world_to_cell(get_global_mouse_position()))


# ---------------------------------------------------------------- 规划

## 开始拖拽：Ctrl+左键按着拖出矩形，松左键才铺；Ctrl+右键按着拖出矩形，松右键才删；
## X 拆除模式下左键点/拖框标记拆除；Shift+左键框出蓝图选区做复制粘贴
func begin_drag(mode: Drag, cell: Vector2i) -> void:
	drag_mode = mode
	drag_start_cell = cell
	if mode == Drag.RECT_PLACE or mode == Drag.RECT_ERASE:
		world.preview_kind = blueprint_kind
		world.preview_rotation = blueprint_rotation
	else:
		world.preview_kind = ""
	update_drag(cell)
	pass


func update_drag(cell: Vector2i) -> void:
	match drag_mode:
		Drag.RECT_PLACE, Drag.RECT_ERASE, Drag.SELECT:
			world.preview_cells = world.rect_cells(drag_start_cell, cell)
		Drag.DEMOLISH:
			world.demolish_cells = world.rect_cells(drag_start_cell, cell)
	world.queue_redraw()
	pass


func finish_drag(from_right: bool) -> void:
	if drag_mode == Drag.NONE:
		return
	var mode := drag_mode
	drag_mode = Drag.NONE
	var cells: Array = []
	if mode == Drag.DEMOLISH:
		cells = world.demolish_cells.duplicate()
		world.demolish_cells = []
	else:
		cells = world.preview_cells.duplicate()
		world.preview_cells = []
	if cells.is_empty():
		world.queue_redraw()
		return
	match mode:
		Drag.RECT_PLACE:
			if from_right:
				log_line("矩形铺设请用左键松手确认。", Color(1.0, 0.8, 0.5))
				world.queue_redraw()
				return
			place_rect(cells)
		Drag.RECT_ERASE:
			if not from_right:
				log_line("矩形删除请用右键松手确认。", Color(1.0, 0.8, 0.5))
				world.queue_redraw()
				return
			erase_rect(cells)
		Drag.SELECT:
			confirm_select(cells)
		Drag.DEMOLISH:
			if from_right:
				set_demolish_mode(false)
				world.queue_redraw()
				return
			mark_demolish_rect(cells)
	world.queue_redraw()
	pass


func place_rect(cells: Array) -> void:
	var kind := blueprint_kind
	var placed := 0
	for c: Vector2i in cells:
		if not can_build(kind):
			break
		if world.add_blueprint(c, kind, blueprint_rotation):
			placed += 1
	if placed > 0:
		log_line("已规划 %d 格%s；施工队会按顺序完成。" % [placed, ActionTable.cn(kind)], Color(0.7, 0.9, 1.0))
	else:
		log_line(plan_fail_hint(kind), Color(1.0, 0.7, 0.45))
	pass


func erase_rect(cells: Array) -> void:
	var removed := 0
	for c: Vector2i in cells:
		if world.blueprint_at(c) != "":
			world.remove_blueprint(c)
			removed += 1
	if removed > 0:
		log_line("已撤销 %d 格蓝图规划。" % removed, Color(0.7, 0.85, 1.0))
	pass


func confirm_select(cells: Array) -> void:
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	select_rect = [lo, hi]
	var n := count_blueprints_in(lo, hi)
	log_line("已框选 (%d,%d)-(%d,%d)，含 %d 格蓝图；Ctrl+C 复制，Ctrl+V 粘贴。" % [lo.x, lo.y, hi.x, hi.y, n], Color(0.7, 0.9, 1.0))
	pass


func count_blueprints_in(lo: Vector2i, hi: Vector2i) -> int:
	var n := 0
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if world.blueprint_at(Vector2i(x, y)) != "":
				n += 1
	return n


func copy_selection() -> void:
	if select_rect[0] == Vector2i(-1, -1):
		log_line("先按住 Shift+左键框选蓝图，再复制。", Color(1.0, 0.8, 0.5))
		return
	clipboard = snapshot_blueprints(select_rect[0], select_rect[1])
	if clipboard.is_empty():
		log_line("框选区内没有蓝图可复制。", Color(1.0, 0.8, 0.5))
		return
	paste_preview = true
	world.preview_kind = blueprint_kind
	log_line("已复制 %d 格蓝图；移动鼠标预览，左键放下，右键/Esc 取消。" % clipboard.size(), Color(0.7, 0.9, 1.0))
	pass


func snapshot_blueprints(lo: Vector2i, hi: Vector2i) -> Array:
	var out: Array = []
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var kind := world.blueprint_at(Vector2i(x, y))
			if kind == "":
				continue
			out.append({"dx": x - lo.x, "dy": y - lo.y, "kind": kind, "rot": world.blueprint_rotation_at(Vector2i(x, y))})
	return out


func paste_clipboard(origin: Vector2i) -> void:
	var placed := 0
	var first_kind := ""
	for item in clipboard:
		var d: Dictionary = item
		var kind := str(d.get("kind", ""))
		if first_kind == "":
			first_kind = kind
		if not can_build(kind):
			continue
		if world.add_blueprint(origin + Vector2i(int(d["dx"]), int(d["dy"])), kind, int(d.get("rot", 0))):
			placed += 1
	if placed > 0:
		log_line("已粘贴 %d 格%s。" % [placed, ActionTable.cn(first_kind)], Color(0.7, 0.9, 1.0))
	else:
		log_line("此处不能粘贴：目标格被占用或科技未解锁。", Color(1.0, 0.7, 0.45))
	paste_preview = false
	world.preview_cells = []
	world.preview_kind = blueprint_kind
	world.queue_redraw()
	pass


func cancel_paste() -> void:
	paste_preview = false
	clipboard.clear()
	world.preview_cells = []
	world.preview_kind = blueprint_kind
	log_line("已取消粘贴。", Color(0.7, 0.85, 1.0))
	world.queue_redraw()
	pass


func cancel_drag() -> void:
	drag_mode = Drag.NONE
	world.preview_cells = []
	world.demolish_cells = []
	world.queue_redraw()
	pass


## 拆除模式开关：X 键进/出；标记已有建筑派人拆除（无材料消耗，读条 2 秒）。
func set_demolish_mode(on: bool) -> void:
	demolish_mode = on
	cancel_drag()
	cancel_paste()
	if on:
		log_line("拆除模式：左键点/拖框标记拆除，右键或 Esc 退出，Ctrl+Z 撤销上次标记。", Color(1.0, 0.6, 0.5))
	else:
		log_line("已退出拆除模式。", Color(0.7, 0.85, 1.0))
	world.queue_redraw()
	pass


## 单格/矩形标记拆除：只收已有建筑（墙/门/塔/机器/家具都行），空地与蓝图直接跳过。
func mark_demolish_rect(cells: Array) -> void:
	var marked: Array = []
	for c: Vector2i in cells:
		if not world.in_bounds(c):
			continue
		var key := c.y * GameWorld.W + c.x
		if demolish_marks.has(key):
			continue
		if world.blueprint_at(c) != "":
			continue
		if not world.demolishable(c):
			continue
		demolish_marks[key] = true
		marked.append(c)
	if marked.is_empty():
		log_line("这里没有可拆除的建筑。", Color(1.0, 0.8, 0.5))
	else:
		demolish_undo.append(marked)
		log_line("已标记 %d 格拆除；施工队会前来拆除。" % marked.size(), Color(1.0, 0.6, 0.5))
	sync_demolish_draw()
	pass


func undo_demolish() -> void:
	if demolish_undo.is_empty():
		log_line("没有可撤销的拆除标记。", Color(1.0, 0.8, 0.5))
		return
	var cells: Array = demolish_undo.pop_back()
	var n := 0
	for c: Vector2i in cells:
		var key := c.y * GameWorld.W + c.x
		if demolish_marks.has(key):
			demolish_marks.erase(key)
			n += 1
	log_line("已撤销 %d 格拆除标记。" % n, Color(0.7, 0.85, 1.0))
	sync_demolish_draw()
	pass


## 拆除标记 -> 世界层红 X：集中同步，claim/施工完成也要调这个。
func sync_demolish_draw() -> void:
	if world == null:
		return
	world.demolish_mark_cells.clear()
	for key in demolish_marks:
		world.demolish_mark_cells.append(Vector2i(int(key) % GameWorld.W, int(key) / GameWorld.W))
	world.queue_redraw()
	pass


## 鼠标所在格记录给世界层，用来画跟随鼠标的半透明虚影；
## 鼠标停在面板上时不画，免得工具栏底下浮着一个虚影。
func update_hover() -> void:
	if world == null or get_viewport() == null:
		return
	var cell := Vector2i(-1, -1)
	if get_viewport().gui_get_hovered_control() == null:
		cell = world.world_to_cell(get_global_mouse_position())
	if cell == world.hover_cell and not paste_preview:
		return
	world.hover_cell = cell
	if paste_preview and not clipboard.is_empty() and world.in_bounds(cell):
		var cells: Array = []
		for item in clipboard:
			var d: Dictionary = item
			cells.append(cell + Vector2i(int(d["dx"]), int(d["dy"])))
		world.preview_cells = cells
		world.preview_kind = str((clipboard[0] as Dictionary).get("kind", blueprint_kind))
	elif paste_preview:
		world.preview_cells = []
	world.queue_redraw()
	pass


## R：旋转当前规划朝向；鼠标停在一格待施工的建筑上时，直接转那一格
func rotate_blueprint() -> void:
	blueprint_rotation = (blueprint_rotation + 1) % 4
	world.preview_rotation = blueprint_rotation
	var cell := world.world_to_cell(get_global_mouse_position())
	if world.blueprint_at(cell) != "":
		world.set_blueprint_rotation(cell, blueprint_rotation)
		log_line("%s 已旋转 %d°" % [ActionTable.cn(blueprint_kind), blueprint_rotation * 90], Color(0.7, 0.9, 1.0))
	world.queue_redraw()
	pass


func plan_fail_hint(kind: String) -> String:
	if not can_build(kind):
		return "尚未完成对应科技，无法规划%s。" % ActionTable.cn(kind)
	if ActionTable.is_upgrade(kind):
		return "这里不能规划%s：需要先建成%s。" % [
			ActionTable.cn(kind),
			ActionTable.cn(ActionTable.upgrade_base(kind)),
		]
	return "这里不能规划：需选择空地、地板或洞穴地面。"


func place_blueprint(c: Vector2i, verbose: bool = true) -> bool:
	if not can_build(blueprint_kind):
		if verbose:
			log_line(plan_fail_hint(blueprint_kind), Color(1.0, 0.72, 0.45))
		return false
	if world.add_blueprint(c, blueprint_kind, blueprint_rotation):
		if verbose:
			log_line("已规划%s；施工队会按顺序完成。" % ActionTable.cn(blueprint_kind), Color(0.7, 0.9, 1.0))
		return true
	if verbose:
		log_line(plan_fail_hint(blueprint_kind), Color(1.0, 0.7, 0.45))
	return false


# ---------------------------------------------------------------- 昼夜

func is_night() -> bool:
	return day_time >= DAY_LEN * 0.5


func night_factor() -> float:
	if not is_night():
		return 0.0
	var p := (day_time - DAY_LEN * 0.5) / (DAY_LEN * 0.5)
	return clampf(minf(p * 4.0, (1.0 - p) * 4.0), 0.0, 1.0)


func update_tint() -> void:
	if tint == null:
		return
	if is_night():
		tint.color = Color(1, 1, 1).lerp(Color(0.38, 0.42, 0.66), night_factor())
	else:
		var p := day_time / (DAY_LEN * 0.5)
		var warm := clampf((p - 0.72) / 0.28, 0.0, 1.0)
		tint.color = Color(1, 1, 1).lerp(Color(1.0, 0.86, 0.72), warm * 0.35)


func clock_text() -> String:
	var hours := 6.0 + day_time / DAY_LEN * 24.0
	hours = fmod(hours, 24.0)
	var h := int(hours)
	var m := int((hours - h) * 60.0)
	return "%02d:%02d" % [h, m]


# ---------------------------------------------------------------- 兽袭

func spawn_wave(n: int) -> void:
	var idx := clampi(n - 1, 0, WAVE_COUNT.size() - 1)
	var count := maxi(1, int(round(float(WAVE_COUNT[idx]) * difficulty)))
	var hp: float = float(WAVE_HP[idx]) * (0.75 + 0.25 * difficulty)
	var dmg: float = float(WAVE_DMG[idx]) * difficulty
	if world.has_tile(GameWorld.T.RADAR):
		log_line("雷达站提前捕捉到热源，炮塔与巡逻人员获得预警。", Color(0.55, 0.86, 1.0))
	for i in count:
		spawn_beast(hp, dmg)
	log_line("🌙 夜幕降临，%d 只野兽正在逼近基地！" % count, Color(1.0, 0.55, 0.5))
	pass


func spawn_beast(hp: float, dmg: float, enemy_kind: int = -1) -> void:
	for attempt in 60:
		var side := randi() % 4
		var c: Vector2i
		match side:
			0:
				c = Vector2i(randi_range(1, GameWorld.W - 2), 1)
			1:
				c = Vector2i(randi_range(1, GameWorld.W - 2), GameWorld.H - 2)
			2:
				c = Vector2i(1, randi_range(1, GameWorld.H - 2))
			_:
				c = Vector2i(GameWorld.W - 2, randi_range(1, GameWorld.H - 2))
		if not world.walkable(c, true):
			continue
		beast_id += 1
		var b := Beast.new()
		world.add_child(b)
		var kind := enemy_kind if enemy_kind >= 0 else pick_enemy_kind()
		b.setup(self, world, beast_id, hp * enemy_hp_mult(kind), dmg * enemy_dmg_mult(kind), c, kind, enemy_scale(kind))
		beasts.append(b)
		return


func pick_enemy_kind() -> int:
	var max_kind := clampi(day + randi_range(0, 4), 0, 19)
	return randi_range(0, max_kind)


func enemy_hp_mult(kind: int) -> float:
	return 1.0 + float(kind / 4) * 0.22


func enemy_dmg_mult(kind: int) -> float:
	return 1.0 + float(kind / 4) * 0.15


func enemy_scale(kind: int) -> float:
	if kind >= 16:
		return 1.28
	if kind >= 8:
		return 1.16
	return 1.0


func live_beasts() -> int:
	var n := 0
	for b in beasts:
		if is_instance_valid(b) and not b.dead:
			n += 1
	return n


func beast_near(pos: Vector2, dist: float) -> bool:
	for b in beasts:
		if is_instance_valid(b) and not b.dead and pos.distance_to(b.position) < dist:
			return true
	return false


# ---------------------------------------------------------------- 资源 / 日志

func add_resource(kind: String, amount: int) -> void:
	resources[kind] = int(resources.get(kind, 0)) + amount
	if amount > 0 and stats.has(kind):
		stats[kind] = int(stats[kind]) + amount
	pass


func log_line(text: String, color := Color.WHITE) -> void:
	if _selftest:
		print("      · " + text)
	if chat_log == null:
		return
	chat_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func on_colonist_death() -> void:
	var alive := 0
	for c in colonists:
		if c.alive:
			alive += 1
	if alive == 0:
		defeat()
	pass


# ---------------------------------------------------------------- 指令

func on_ai_busy(busy: bool) -> void:
	if status_label == null:
		return
	status_label.text = "总管思考中…" if busy else ""


func on_ai_result(reply: String, commands: Array, source: String) -> void:
	_idle_time = 0.0
	log_line("总管：" + reply, Color(0.62, 0.85, 1.0))
	if source.begins_with("rule") and source != "rule":
		var why := "接口异常" if source != "rule" else ""
		log_line("（%s，已改用本地规则解析）" % why, Color(0.75, 0.75, 0.6))
	var n := 0
	for cmd in commands:
		n += dispatch(cmd)
	if n > 0:
		log_line("→ 已下达 %d 条指令" % n, Color(0.7, 0.95, 0.7))
		remember_ai_quick(last_player_command)
	if ai_log != null:
		ai_log.append(last_player_command, reply, commands, source, day, clock_text())
	pass


func dispatch(cmd: Dictionary) -> int:
	cmd = ActionTable.validate(cmd)
	if cmd.is_empty():
		return 0
	var action := str(cmd.get("action", ""))
	var who := str(cmd.get("who", "all"))
	var targets: Array = []
	if who == "all" or who == "所有人" or who == "":
		for c in colonists:
			if c.alive:
				targets.append(c)
	else:
		for c in colonists:
			if c.alive and (c.cname == who or c.cname.begins_with(who) or who.begins_with(c.cname)):
				targets.append(c)
	if targets.is_empty():
		log_line("没有找到叫「%s」的殖民者" % who, Color(1.0, 0.7, 0.4))
		return 0
	if action == "build" and world.find_blueprint(world.base_cell, str(cmd.get("type", ""))) == Vector2i(-1, -1):
		log_line("请先在地图上规划%s，再安排施工。" % ActionTable.cn(str(cmd.get("type", ""))))
		return 0
	if action == "build" and not can_build(str(cmd.get("type", ""))):
		log_line("尚未完成对应科技，无法安排%s。" % ActionTable.cn(str(cmd.get("type", ""))), Color(1.0, 0.72, 0.45))
		return 0
	if action == "craft" and not can_craft(str(cmd.get("item", ""))):
		log_line("尚未完成对应科技，无法制作%s。" % ActionTable.cn(str(cmd.get("item", ""))), Color(1.0, 0.72, 0.45))
		return 0
	if action == "demolish" and demolish_marks.is_empty():
		log_line("还没有拆除标记：按 X 进入拆除模式，左键点/拖框标记建筑再派人。", Color(1.0, 0.8, 0.5))
		return 0
	if who in ["all", "所有人", ""] and action in ["mine", "build", "craft", "research", "cook", "harvest", "demolish"]:
		targets = targets.filter(func(c: Colonist) -> bool: return c.hunger < 75.0 and c.fatigue < 80.0 and c.hp > c.max_hp * 0.35)
		var skill := "gather" if action in ["mine", "harvest"] else ("build" if action in ["build", "demolish"] else ("research" if action == "research" else "logistics"))
		targets.sort_custom(func(a: Colonist, b: Colonist) -> bool: return worker_score(a, skill) > worker_score(b, skill))
		if action != "build" and targets.size() > 1:
			targets.resize(1)
	for c in targets:
		if action in ["flee", "idle", "attack"]:
			c.queue.clear()
			c.finish("")
		var t := cmd.duplicate()
		t.erase("who")
		# 新命令会把睡着的人叫起来（除非命令就是让他继续睡）
		if action != "sleep":
			c.interrupt_sleep()
		c.queue.append(t.duplicate())
	return targets.size()


func worker_score(worker: Colonist, skill: String) -> float:
	return float(worker.skills.get(skill, 1.0)) * 10.0 - worker.queue.size() * 4.0 - (0.0 if worker.task.is_empty() else 6.0) - worker.fatigue * 0.05 - worker.hunger * 0.05 - worker.cell.distance_to(world.base_cell) * 0.1


## 聊天框 10 秒没输入且总管空闲时，从历史对话里挑一条中等策略自动发展
func tick_idle_auto(delta: float) -> void:
	if not auto_steward or game_over or start_panel.visible or _selftest:
		return
	if ai != null and ai.is_busy():
		_idle_time = 0.0
		return
	_idle_time += delta
	if _idle_time < IDLE_AUTO_SECONDS:
		return
	_idle_time = 0.0
	var pick := pick_idle_strategy()
	if pick == "":
		return
	log_line("（总管自动接管：%s）" % pick, Color(0.6, 0.8, 0.9))
	send_command(pick)


func pick_idle_strategy() -> String:
	if ai_log == null or ai_log.entries.is_empty():
		return ""
	var scored: Array = []
	for record in ai_log.entries:
		var r: Dictionary = record
		var cmds: Array = r.get("commands", [])
		if cmds.is_empty():
			continue
		var text := str(r.get("player", "")).strip_edges()
		if text == "" or text == last_player_command:
			continue
		var score := 0.0
		for cmd in cmds:
			var action := str((cmd as Dictionary).get("action", ""))
			if action in ["mine", "build", "research", "plant", "harvest", "cook", "craft"]:
				score += 1.0
			elif action in ["attack", "flee"]:
				score -= 2.0
			elif action in ["idle", "sleep"]:
				score -= 1.0
		scored.append({"text": text, "score": score, "n": cmds.size()})
	scored.sort_custom(func(a, b): return float(a["score"]) / maxf(1.0, float(a["n"])) > float(b["score"]) / maxf(1.0, float(b["n"])))
	for item in scored:
		var d: Dictionary = item
		var avg := float(d["score"]) / maxf(1.0, float(d["n"]))
		if avg >= 0.5 and float(d["n"]) >= 1 and float(d["n"]) <= 4:
			return str(d["text"])
	return ""


func send_command(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	if t.contains("建防线"):
		propose_defense()
		return
	_idle_time = 0.0
	last_player_command = t
	command_history.append(t)
	if command_history.size() > 50:
		command_history.pop_front()
	history_index = command_history.size()
	log_line("你：" + t, Color(1.0, 0.95, 0.8))
	if chat_input:
		chat_input.text = ""
	var snap := snapshot()
	snap["_last_text"] = t
	ai.ask(t, snap)


func remember_ai_quick(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	if ai_quick_commands.has(t):
		ai_quick_commands.erase(t)
	ai_quick_commands.push_front(t)
	while ai_quick_commands.size() > QUICK_LIMIT:
		ai_quick_commands.pop_back()
	refresh_ai_quick_buttons()
	pass


func refresh_ai_quick_buttons() -> void:
	if ai_quick_box == null:
		return
	for child in ai_quick_box.get_children():
		child.queue_free()
	if ai_quick_commands.is_empty():
		var empty := Label.new()
		empty.text = "暂无"
		empty.add_theme_color_override("font_color", Color(0.62, 0.68, 0.68))
		ai_quick_box.add_child(empty)
		return
	for text in ai_quick_commands:
		var b := Button.new()
		b.text = short_command(text)
		b.tooltip_text = text
		b.pressed.connect(send_command.bind(text))
		ai_quick_box.add_child(b)
	pass


func short_command(text: String) -> String:
	var t := text.strip_edges()
	if t.length() <= 8:
		return t
	return t.substr(0, 8) + "…"


func snapshot() -> Dictionary:
	var cs: Array = []
	for c in colonists:
		cs.append({
			"name": c.cname, "x": c.cell.x, "y": c.cell.y,
			"hp": int(c.hp), "hunger": int(c.hunger), "fatigue": int(c.fatigue),
			"mood": int(c.mood), "task": c.task_desc(), "alive": c.alive,
			"pick": c.pick_lv, "axe": c.axe_lv, "sword": c.sword_lv,
			"shield": c.shield_lv, "bow": c.bow_lv, "arrows": c.arrows,
		})
	var techs: Array = []
	for id in TECH_ORDER:
		if unlocked_tech.has(id):
			techs.append(id)
	return {
		"day": day,
		"clock": clock_text(),
		"resources": resources.duplicate(),
		"base": [world.base_cell.x, world.base_cell.y],
		"beast_count": live_beasts(),
		"colonists": cs,
		"techs": techs,
		"research": current_tech,
	}


# ---------------------------------------------------------------- 胜负

func victory() -> void:
	if game_over:
		return
	game_over = true
	won = true
	show_end("🚀 首次迁移成功！\n\n方舟地基已携带建筑、库存与幸存者脱离地表，抵达第二颗星球。\n\n主线通关后可继续无尽殖民。\n已生存：第 %d 天\n采集总计：木材 %d / 石料 %d / 铁矿 %d / 铜矿 %d / 铀矿 %d / 作物 %d\n幸存者：%d 人" % [
		day, int(stats["wood"]), int(stats["stone"]), int(stats["iron"]), int(stats["copper"]), int(stats["uranium"]), int(stats["crop"]),
		alive_count(),
	])


func defeat() -> void:
	if game_over:
		return
	game_over = true
	won = false
	show_end("💀 殖民地全灭\n\n你们坚持到了第 %d 天 %s。\n\n采集总计：木材 %d / 石料 %d / 铁矿 %d / 铜矿 %d / 铀矿 %d / 作物 %d" % [
		day, clock_text(), int(stats["wood"]), int(stats["stone"]), int(stats["iron"]), int(stats["copper"]), int(stats["uranium"]), int(stats["crop"]),
	])


func alive_count() -> int:
	var n := 0
	for c in colonists:
		if c.alive:
			n += 1
	return n


func show_end(text: String) -> void:
	continue_button.visible = won
	end_label.text = text
	end_panel.visible = true
	get_tree().paused = true
	pass


# ---------------------------------------------------------------- UI

func build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.set_script(load("res://script/ui/pause_input.gd"))
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Ui.theme
	ui_layer.add_child(root)

	build_top(root)
	build_blueprint_bar(root)
	build_pawn_strip(root)
	build_tech_bar(root)
	build_chat(root)
	objective_label = Label.new()
	objective_label.position = Vector2(16, 184)
	objective_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	objective_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.72))
	root.add_child(objective_label)
	build_start(root)
	build_end(root)
	pass


func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.055, 0.07, 0.96)
	sb.border_color = Color(0.3, 0.35, 0.42, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func build_top(root: Control) -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", panel_style())
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	top.add_child(hb)

	time_label = Label.new()
	hb.add_child(time_label)

	res_label = Label.new()
	hb.add_child(res_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	hb.add_child(status_label)

	policy_label = Label.new()
	policy_label.text = "政策：平衡"
	policy_label.add_theme_color_override("font_color", Color(0.72, 0.9, 0.82))
	hb.add_child(policy_label)
	for p in ["平衡", "战备优先", "科研优先", "节约配给", "紧急维修"]:
		var policy_button := Button.new()
		policy_button.text = p
		policy_button.pressed.connect(set_policy.bind(p))
		hb.add_child(policy_button)

	for item in [["⏸", 0.0], ["×1", 1.0], ["×2", 2.0], ["×4", 4.0]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(46, 0)
		b.pressed.connect(set_speed.bind(float(item[1])))
		hb.add_child(b)

	var help := Button.new()
	help.text = "？"
	help.pressed.connect(func() -> void: log_line("先采集木石、规划床和农田，再造研究台。顶部选图案后：左键放一格，Ctrl+左键按住拉框、松左键铺满（先松Ctrl取消），Ctrl+右键按住拉框、松右键删除，Shift+左键框选蓝图再Ctrl+C/V复制粘贴，R 旋转朝向，右键撤销单格。10 秒不打字总管自动挑历史中等策略接管，可点输入框旁自动开关。"))
	help.tooltip_text = "输入框打字下指令；WASD 平移视角；滚轮缩放；点小人可查看"
	hb.add_child(help)
	pass


func build_pawn_strip(root: Control) -> void:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", panel_style())
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 106
	strip.offset_bottom = 158
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(strip)

	pawn_box = HBoxContainer.new()
	pawn_box.add_theme_constant_override("separation", 8)
	strip.add_child(pawn_box)

	for c in colonists:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(200, 0)
		b.pressed.connect(focus_colonist.bind(c))
		pawn_box.add_child(b)
		pawn_buttons.append(b)
	pass


## 建造栏只放图案，不写文字；具体说明与材料消耗都在悬停提示里。
func build_blueprint_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", panel_style())
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 46
	bar.offset_bottom = 106
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	bar.add_child(hb)
	build_era = OptionButton.new()
	for era in ["全部", "基础", "木器", "石器", "铁器", "火力", "蒸汽", "电气", "核能"]:
		build_era.add_item(era)
	build_era.item_selected.connect(func(_index): filter_buildings())
	hb.add_child(build_era)
	build_search = LineEdit.new()
	build_search.placeholder_text = "搜索建筑"
	build_search.custom_minimum_size.x = 130
	build_search.text_changed.connect(func(_text): filter_buildings())
	hb.add_child(build_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(scroll)
	var icons := HBoxContainer.new()
	scroll.add_child(icons)
	var group := ButtonGroup.new()
	for kind in ActionTable.BUILD_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.icon = BuildIcons.icon(kind)
		b.custom_minimum_size = Vector2(44, 38)
		b.tooltip_text = blueprint_tooltip(kind)
		b.pressed.connect(select_blueprint.bind(kind))
		blueprint_buttons[kind] = b
		icons.add_child(b)
	select_blueprint(blueprint_kind)
	pass


func blueprint_tooltip(kind: String) -> String:
	var lines: PackedStringArray = [str(ActionTable.cn(kind))]
	lines.append("消耗：" + (ActionTable.cost_text(kind) if ActionTable.cost_of(kind).size() > 0 else "免费"))
	lines.append(str(ActionTable.DESC.get(kind, "")))
	if not can_build(kind):
		lines.append("※ 需要先完成对应科技")
	return "\n".join(lines)


func building_era(kind: String) -> String:
	if kind in ["ammo_factory", "turret"]:
		return "火力"
	if kind in ["arrow_bench", "ammo_depot"] or kind.begins_with("wood_"):
		return "木器"
	if kind.begins_with("stone_"):
		return "石器"
	if kind.begins_with("iron_") or kind == "workbench2":
		return "铁器"
	if kind.begins_with("nuke_") or kind in ["reactor", "engine", "engine_floor", "ark_core", "rad_door", "lead_chest", "command_table"]:
		return "核能"
	if kind.begins_with("elec_") or kind in ["solar", "laser_turret", "radar", "grid_pole", "monitor_window", "metal_table"]:
		return "电气"
	if kind in ["generator", "battery", "adv_workbench", "pump", "pole", "wire", "pipe", "cart", "garage", "shelf", "water_tank", "copper_chest", "steam_lamp"]:
		return "蒸汽"
	return "基础"


func filter_buildings() -> void:
	var era := build_era.get_item_text(build_era.selected)
	var query := build_search.text.strip_edges()
	for kind in blueprint_buttons:
		blueprint_buttons[kind].visible = (era == "全部" or building_era(kind) == era) and (query == "" or ActionTable.cn(kind).contains(query) or str(kind).contains(query))
	pass


## 科技解锁后按钮才可用：这几项要等研究完成
func refresh_blueprint_bar() -> void:
	for kind in blueprint_buttons:
		var b: Button = blueprint_buttons[kind]
		b.disabled = not can_build(kind)
		b.button_pressed = kind == blueprint_kind
	pass


func select_blueprint(kind: String) -> void:
	if not can_build(kind):
		log_line("尚未完成对应科技，无法规划%s。" % ActionTable.cn(kind), Color(1.0, 0.72, 0.45))
		refresh_blueprint_bar()
		return
	blueprint_kind = kind
	blueprint_rotation = 0
	world.preview_kind = kind
	world.preview_rotation = 0
	refresh_blueprint_bar()
	pass


func build_tech_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", panel_style())
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_left = -360
	bar.offset_right = -14
	bar.offset_top = 168
	bar.offset_bottom = 440
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	bar.add_child(vb)
	tech_label = Label.new()
	tech_label.text = "科技树：先生存，再攀升"
	vb.add_child(tech_label)
	for id in TECH_ORDER:
		var b := Button.new()
		b.text = str(TECHS[id]["name"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 28)
		b.tooltip_text = "%s\n消耗：%s" % [str(TECHS[id]["desc"]), tech_cost_text(id)]
		b.pressed.connect(begin_research.bind(id))
		tech_buttons[id] = b
		vb.add_child(b)
	var jump := Button.new()
	jump.text = "星海跃迁"
	jump.tooltip_text = "完成核能跃迁科技并建成行星发动机后，将整个基地迁移至第二颗星球。"
	jump.pressed.connect(try_jump)
	vb.add_child(jump)
	pass


func tech_needs_bench(id: String) -> bool:
	return not NO_BENCH_TECH.has(id)

func can_build(kind: String) -> bool:
	match kind:
		"arrow_bench", "ammo_depot": return unlocked_tech.has("woodcraft")
		"ammo_factory": return unlocked_tech.has("defense")
		"storage", "med_bay": return unlocked_tech.has("logistics")
		"wood_tower": return unlocked_tech.has("woodcraft")
		"stone_tower": return unlocked_tech.has("stone_age")
		"turret": return unlocked_tech.has("defense")
		"generator", "battery": return unlocked_tech.has("steam")
		"radar": return unlocked_tech.has("electric")
		"ark_core", "reactor", "engine": return unlocked_tech.has("nuclear")
		"workbench2": return unlocked_tech.has("iron_age")
		"adv_workbench", "pump", "pole", "wire", "pipe", "cart", "garage", "shelf", "water_tank", "copper_chest", "steam_lamp", "iron_rivet_table": return unlocked_tech.has("steam")
		"solar", "laser_turret", "elec_workbench", "elec_box", "elec_lamp", "elec_door", "metal_table", "grid_pole", "monitor_window": return unlocked_tech.has("electric")
		"engine_floor", "nuke_tower": return unlocked_tech.has("nuclear")
		"nuke_workbench", "rad_door", "nuke_lamp", "command_table", "lead_chest": return unlocked_tech.has("nuclear")
		"wood_chest", "wood_table", "wood_chair", "wood_window", "wood_fence", "wood_ladder", "wood_lamp": return unlocked_tech.has("woodcraft")
		"stone_chest", "stone_table", "stone_chair", "stone_door", "stone_window", "stone_fence", "stone_ladder", "stone_lamp": return unlocked_tech.has("stone_age")
		"iron_chest", "iron_table", "iron_chair", "iron_door", "iron_window", "iron_fence", "iron_ladder", "iron_lamp": return unlocked_tech.has("iron_age")
	return true

func can_craft(item: String) -> bool:
	var need := str(ActionTable.CRAFT_TECH.get(item, ""))
	if need == "":
		return true
	return unlocked_tech.has(need)


## 武器完成后自动发给最缺装备的存活殖民者，避免制造者把所有武器都留在自己身上。
func auto_equip_weapon(item: String, count: int = 1) -> bool:
	var level := 0
	var field := ""
	match item:
		"wood_spear", "wood_sword": level = 1; field = "sword_lv"
		"stone_sword": level = 2; field = "sword_lv"
		"iron_sword": level = 3; field = "sword_lv"
		"wood_bow": level = 1; field = "bow_lv"
		"fine_bow": level = 2; field = "bow_lv"
		"iron_bow": level = 3; field = "bow_lv"
		"wood_shield": level = 1; field = "shield_lv"
		"iron_shield": level = 2; field = "shield_lv"
		"wood_arrow", "iron_arrow":
			var archers := colonists.filter(func(c: Colonist) -> bool: return c.alive and c.bow_lv > 0)
			if archers.is_empty():
				return false
			archers.sort_custom(func(a: Colonist, b: Colonist) -> bool: return a.arrows < b.arrows)
			(archers[0] as Colonist).arrows += count
			return true
		_: return false
	var candidates := colonists.filter(func(c: Colonist) -> bool: return c.alive and int(c.get(field)) < level)
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a: Colonist, b: Colonist) -> bool: return int(a.get(field)) < int(b.get(field)))
	var receiver := candidates[0] as Colonist
	receiver.set(field, level)
	receiver.has_sword = receiver.sword_lv > 0
	log_line("%s 自动装备了%s。" % [receiver.cname, ActionTable.cn(item)], Color(0.72, 0.9, 1.0))
	return true


func can_assign_auto_build(worker: Colonist) -> bool:
	return worker.hunger < 75.0 and worker.fatigue < 80.0 and available_plan(worker) != Vector2i(-1, -1)


## 认领一块待拆除的建筑：已被别人盯上的跳过，避免扎堆
func claim_demolish(worker: Colonist) -> Vector2i:
	if worker.hunger >= 75.0 or worker.fatigue >= 80.0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for key in demolish_marks:
		var c := Vector2i(int(key) % GameWorld.W, int(key) / GameWorld.W)
		if not world.demolishable(c):
			continue
		var claimed := false
		for other: Colonist in colonists:
			if other == worker or not other.alive:
				continue
			if str(other.task.get("action", "")) == "demolish" and other.task.get("goal", Vector2i(-1, -1)) == c:
				claimed = true
				break
		if claimed:
			continue
		var d := worker.cell.distance_squared_to(c)
		if d < best_d and not world.find_path(worker.cell, c).is_empty():
			best_d = d
			best = c
	return best


func research_active() -> bool:
	return current_tech != ""


func can_assign_food_work(worker: Colonist) -> bool:
	for c: Colonist in colonists:
		if c == worker or not c.alive:
			continue
		if str(c.task.get("action", "")) in ["plant", "harvest", "cook"]:
			return false
		for pending: Dictionary in c.queue:
			if str(pending.get("action", "")) in ["plant", "harvest", "cook"]:
				return false
	return true


func tech_cost_text(id: String) -> String:
	var parts: PackedStringArray = []
	var cost: Dictionary = TECHS[id].get("cost", {})
	for resource: String in cost:
		parts.append("%s %d" % [ActionTable.cn(resource), int(cost[resource])])
	return "、".join(parts)


func tech_ready(id: String) -> bool:
	if unlocked_tech.has(id) or research_active():
		return false
	for prereq in TECHS[id].get("requires", []):
		if not unlocked_tech.has(prereq):
			return false
	if tech_needs_bench(id) and not has_research_bench():
		return false
	return ActionTable.can_afford(resources, TECHS[id].get("cost", {}))


func has_research_bench() -> bool:
	for t in world.tiles:
		if t == GameWorld.T.RESEARCH:
			return true
	return false


func begin_research(id: String) -> void:
	if unlocked_tech.has(id):
		log_line("「%s」已经完成。" % TECHS[id]["name"], Color(0.75, 0.9, 0.75))
		return
	if research_active():
		log_line("当前正在研究「%s」。" % TECHS[current_tech]["name"], Color(1.0, 0.82, 0.5))
		return
	for prereq in TECHS[id].get("requires", []):
		if not unlocked_tech.has(prereq):
			log_line("研究「%s」前需先完成「%s」。" % [TECHS[id]["name"], TECHS[prereq]["name"]], Color(1.0, 0.72, 0.45))
			return
	if tech_needs_bench(id) and not has_research_bench():
		log_line("需要先手工规划并建成研究台。", Color(1.0, 0.72, 0.45))
		return
	var cost: Dictionary = TECHS[id]["cost"]
	if not ActionTable.can_afford(resources, cost):
		log_line("研究「%s」的材料不足。" % TECHS[id]["name"], Color(1.0, 0.72, 0.45))
		return
	ActionTable.pay(resources, cost)
	current_tech = id
	research_progress = 0.0
	var researcher: Colonist = null
	var skill_best := -1.0
	for c in colonists:
		if c.alive and float(c.skills.get("research", 1.0)) > skill_best:
			skill_best = float(c.skills.get("research", 1.0))
			researcher = c
	if researcher:
		researcher.queue.push_front({"action": "research"})
		log_line("开始研究「%s」，%s 已前往研究台。" % [TECHS[id]["name"], researcher.cname], Color(0.65, 0.88, 1.0))
	else:
		log_line("开始研究「%s」，但当前无人可执行。" % TECHS[id]["name"], Color(1.0, 0.72, 0.45))
	pass


func contribute_research(amount: float, who: String) -> void:
	if not research_active():
		return
	research_progress += amount
	var need := float(TECHS[current_tech]["work"])
	if research_progress < need:
		return
	var done := current_tech
	unlocked_tech[done] = true
	current_tech = ""
	research_progress = 0.0
	log_line("★ %s 完成了「%s」：%s" % [who, TECHS[done]["name"], TECHS[done]["desc"]], Color(0.75, 1.0, 0.7))


func has_ship_core() -> bool:
	for t in world.tiles:
		if t == GameWorld.T.SHIP_CORE:
			return true
	return false


func try_jump() -> void:
	if not unlocked_tech.has("nuclear"):
		log_line("尚未完成「核能跃迁」科技。", Color(1.0, 0.72, 0.45))
		return
	if not has_ship_core():
		log_line("请先由玩家规划并建成行星发动机。", Color(1.0, 0.72, 0.45))
		return
	if live_beasts() > 0:
		log_line("方舟正在锁定地基，必须先清除当前威胁。", Color(1.0, 0.72, 0.45))
		return
	migrate_colony()
	victory()


func focus_colonist(c: Colonist) -> void:
	selected = c
	camera.position = c.position
	update_hud()
	pass


func build_chat(root: Control) -> void:
	var wrap := HBoxContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -300
	wrap.offset_left = 12
	wrap.offset_right = -12
	wrap.offset_bottom = -12
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_theme_constant_override("separation", 10)
	root.add_child(wrap)

	var strategy_panel := PanelContainer.new()
	strategy_panel.add_theme_stylebox_override("panel", panel_style())
	strategy_panel.custom_minimum_size = Vector2(420, 0)
	wrap.add_child(strategy_panel)

	var strategy := VBoxContainer.new()
	strategy.add_theme_constant_override("separation", 6)
	strategy_panel.add_child(strategy)
	var strategy_title := Label.new()
	strategy_title.text = "策略按钮"
	strategy_title.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	strategy.add_child(strategy_title)
	for item in [
		["采集开局", "抽抽砍5棵树，七海采3块石头，龟龟挖2块铁矿"],
		["食物循环", "班花种地，鱼和糖收庄稼，然后做饭"],
		["安全战备", "所有人迎击野兽"],
		["撤回休整", "大家撤回基地，然后去睡觉"],
		["施工队开工", "所有人建当前蓝图"],
		["科研推进", "魔法师研究，班花研究"],
	]:
		var b := Button.new()
		b.text = str(item[0])
		b.custom_minimum_size = Vector2(0, 26)
		b.tooltip_text = str(item[1])
		b.pressed.connect(send_command.bind(str(item[1])))
		strategy.add_child(b)

	var recent_title := Label.new()
	recent_title.text = "AI 已用指令"
	recent_title.add_theme_color_override("font_color", Color(0.78, 0.9, 0.78))
	strategy.add_child(recent_title)
	ai_quick_box = HBoxContainer.new()
	ai_quick_box.add_theme_constant_override("separation", 4)
	strategy.add_child(ai_quick_box)
	refresh_ai_quick_buttons()

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(right)

	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", panel_style())
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)

	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.selection_enabled = true
	chat_log.custom_minimum_size = Vector2(0, 95)
	log_panel.add_child(chat_log)

	var input_panel := PanelContainer.new()
	input_panel.add_theme_stylebox_override("panel", panel_style())
	right.add_child(input_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	input_panel.add_child(hb)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = "下达工作指令，例如：抽抽砍5棵树 / 七海采石 / 所有人迎击野兽"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.gui_input.connect(on_chat_key)
	chat_input.text_submitted.connect(func(t): send_command(t))
	chat_input.text_changed.connect(func(_t): _idle_time = 0.0)
	hb.add_child(chat_input)
	var auto_btn := Button.new()
	auto_btn.text = "自动"
	auto_btn.toggle_mode = true
	auto_btn.button_pressed = auto_steward
	auto_btn.tooltip_text = "10 秒没输入时总管自动从历史里挑中等策略发展"
	auto_btn.toggled.connect(func(on): auto_steward = on)
	hb.add_child(auto_btn)

	var quick := HBoxContainer.new()
	right.add_child(quick)
	for example in ["现在情况怎么样", "抽抽砍5棵树，七海采3块石头", "所有人迎击野兽", "大家撤回基地"]:
		var button := Button.new()
		button.text = example
		button.pressed.connect(send_command.bind(example))
		quick.add_child(button)
	var send := Button.new()
	send.text = "发送"
	send.pressed.connect(func(): send_command(chat_input.text))
	hb.add_child(send)
	pass


func build_start(root: Control) -> void:
	start_panel = Control.new()
	start_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(start_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_panel.add_child(center)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel_style())
	box.custom_minimum_size = Vector2(720, 0)
	center.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)

	var title := Label.new()
	title.text = "AI Life: 星神远征"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.custom_minimum_size = Vector2(0, 210)
	desc.text = """[b]玩法[/b]：你不亲自干活。在底部输入框打字，[color=#8fd4ff]AI 总管[/color]会把你的话翻译成指令，派给 6 个殖民者执行。
	pass


[b]目标[/b]：让方舟地基穿越星海，把生命带到下一颗星球。

[b]指令示例[/b]
· 抽抽去砍 5 棵树
· 所有人建围墙
· 龟龟造石斧，然后去打野兽
· 大家撤回来
· 班花去种地，鱼和糖做饭

[b]视角[/b]：WASD 平移，滚轮缩放，点小人看状态。

[b]关于 API[/b]：填了 DeepSeek Key 就用大模型理解你的自然语言；[color=#ffd27f]留空则用内置规则解析[/color]（也能玩，但只认关键词）。"""
	vb.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	vb.add_child(grid)

	grid.add_child(mk_label("难度"))
	diff_option = OptionButton.new()
	diff_option.add_item("轻松")
	diff_option.add_item("标准")
	diff_option.add_item("困难")
	diff_option.selected = 1
	grid.add_child(diff_option)

	grid.add_child(mk_label("DeepSeek Key"))
	key_edit = LineEdit.new()
	key_edit.placeholder_text = "sk-...（留空 = 本地规则模式）"
	key_edit.secret = true
	key_edit.custom_minimum_size = Vector2(460, 0)
	grid.add_child(key_edit)

	grid.add_child(mk_label("模型"))
	model_edit = LineEdit.new()
	model_edit.text = "deepseek-flash"
	grid.add_child(model_edit)

	var start_btn := Button.new()
	start_btn.text = "开始游戏"
	start_btn.custom_minimum_size = Vector2(0, 44)
	start_btn.pressed.connect(start_game)
	vb.add_child(start_btn)


func mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size = Vector2(120, 0)
	return l


func build_end(root: Control) -> void:
	end_panel = Control.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.visible = false
	root.add_child(end_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(center)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel_style())
	center.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)

	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_label)

	continue_button = Button.new()
	continue_button.text = "继续殖民新星球"
	continue_button.pressed.connect(continue_colony)
	vb.add_child(continue_button)

	var again := Button.new()
	again.text = "再来一局"
	again.custom_minimum_size = Vector2(0, 44)
	again.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	vb.add_child(again)
	pass


# ---------------------------------------------------------------- HUD 刷新

func update_hud() -> void:
	if time_label == null:
		return
	var phase := "夜晚" if is_night() else "白天"
	time_label.text = "星球 %d · 第 %d 天  %s  %s" % [planet, day, clock_text(), phase]
	objective_label.text = objective_text()
	refresh_blueprint_bar()
	res_label.text = "木材 %d  石料 %d  铁矿 %d  铜矿 %d  铀矿 %d  作物 %d  食物 %d  野兽 %d  [%s]" % [
		int(resources["wood"]), int(resources["stone"]), int(resources["iron"]),
		int(resources["copper"]), int(resources["uranium"]),
		int(resources["crop"]), int(resources["food"]), live_beasts(), difficulty_name,
	]
	if tech_label:
		if research_active():
			tech_label.text = "科技：%s  %d%%" % [TECHS[current_tech]["name"], int(research_progress / float(TECHS[current_tech]["work"]) * 100.0)]
		else:
			tech_label.text = "科技树：木器 → 石器 → 铁器 → 火力 → 蒸汽 → 电气 → 核能跃迁"
	for id in tech_buttons:
		var b: Button = tech_buttons[id]
		var prefix := "○ "
		if unlocked_tech.has(id):
			prefix = "✓ "
			b.disabled = true
		elif current_tech == id:
			prefix = "… "
			b.disabled = true
		else:
			b.disabled = not tech_ready(id)
			prefix = "◇ " if not b.disabled else "× "
		b.text = "%s%s  %s" % [prefix, str(TECHS[id]["name"]), tech_cost_text(id)]

	for i in pawn_buttons.size():
		var c: Colonist = colonists[i]
		var b: Button = pawn_buttons[i]
		if not c.alive:
			b.text = "%s（阵亡）" % c.cname
			b.disabled = true
			continue
		var mark := "★ " if selected == c else ""
		b.tooltip_text = "饥饿、疲劳越低越好；心情越高越好。\n采集 %.2f · 建造 %.2f · 科研 %.2f · 战斗 %.2f · 后勤 %.2f\n待办 %d 项" % [c.skills.gather, c.skills.build, c.skills.research, c.skills.combat, c.skills.logistics, c.queue.size()]
		b.text = "%s%s  血%d 饥%d 疲%d 心%d\n%s" % [
			mark, c.cname, int(c.hp), int(c.hunger), int(c.fatigue), int(c.mood), c.task_desc(),
		]


func set_speed(s: float) -> void:
	speed = s
	if s <= 0.0:
		get_tree().paused = true
		Engine.time_scale = 1.0
	else:
		get_tree().paused = false
		Engine.time_scale = s
	log_line("速度调整为 %s" % ("暂停" if s <= 0.0 else "×%d" % int(s)), Color(0.8, 0.8, 0.8))
	pass


func set_policy(next_policy: String) -> void:
	policy = next_policy
	if policy_label:
		policy_label.text = "政策：%s" % policy
	log_line("星神政策已切换为「%s」。" % policy, Color(0.72, 0.9, 0.82))
	pass


# ---------------------------------------------------------------- 设置存取

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	key_edit.text = str(cfg.get_value("api", "key", ""))
	model_edit.text = str(cfg.get_value("api", "model", "deepseek-flash"))
	var d := int(cfg.get_value("game", "difficulty", 1))
	diff_option.selected = clampi(d, 0, 2)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("api", "key", key_edit.text.strip_edges())
	cfg.set_value("api", "model", model_edit.text.strip_edges())
	cfg.set_value("game", "difficulty", diff_option.selected)
	cfg.save(CFG_PATH)
	pass


# ---------------------------------------------------------------- 开局

func start_game() -> void:
	var key := key_edit.text.strip_edges()
	if OS.get_cmdline_user_args().has("--offline") or _selftest:
		key = ""
	var mdl := model_edit.text.strip_edges()
	ai.api_key = key
	ai.model = mdl if mdl != "" else "deepseek-flash"
	ai.online = key != ""

	match diff_option.selected:
		0:
			difficulty = 0.6
			difficulty_name = "轻松"
		2:
			difficulty = 1.5
			difficulty_name = "困难"
		_:
			difficulty = 1.0
			difficulty_name = "标准"

	if not (OS.get_cmdline_user_args().has("--offline") or _selftest or DisplayServer.get_name() == "headless"):
		save_settings()

	start_panel.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0

	log_line("—— 殖民地建立 ——", Color(0.9, 0.9, 0.6))
	if key == "":
		log_line("未配置 API Key：总管使用本地规则解析（只认关键词）。可在开始界面填写 Key 后重开。", Color(1.0, 0.82, 0.5))
	else:
		log_line("已配置 DeepSeek（模型 %s）。直接打字下指令即可。" % ai.model, Color(0.6, 0.9, 1.0))
	log_line("星神已上线：顶部选图案规划建筑，殖民者会自主施工。试试「抽抽去砍5棵树」。", Color(0.85, 0.85, 0.85))
	pass


## 迁移保留人工建筑、蓝图与农作物状态；自然资源重新生成，旧路径作废。
func migrate_colony() -> void:
	var structures := {}
	for i in world.tiles.size():
		if world.tiles[i] not in [GameWorld.T.GRASS, GameWorld.T.TREE, GameWorld.T.STONE, GameWorld.T.IRON, GameWorld.T.COPPER, GameWorld.T.URANIUM, GameWorld.T.CAVE_WALL, GameWorld.T.CAVE_FLOOR]:
			structures[i] = world.tiles[i]
	world.generate(randi())
	for i in structures:
		world.tiles[i] = structures[i]
	for i in world.blueprints:
		if not structures.has(i):
			world.tiles[i] = GameWorld.T.GRASS
	# 只保留仍然压在建筑底下的地板记录，避免迁移后留下指向空地的旧记录
	for i in world.base_floor.keys():
		if not structures.has(i):
			world.base_floor.erase(i)
	for i in world.struct_rotations.keys():
		if not structures.has(i):
			world.struct_rotations.erase(i)
	world.refresh_all_solid()
	for beast: Beast in beasts:
		if is_instance_valid(beast):
			beast.queue_free()
	beasts.clear()
	var occupied := {}
	for c in colonists:
		c.queue.clear()
		c.finish("")
		if c.alive:
			var landing := world.base_cell
			for radius in range(0, GameWorld.W):
				var found := false
				for y in range(-radius, radius + 1):
					for x in range(-radius, radius + 1):
						var candidate := world.base_cell + Vector2i(x, y)
						if world.walkable(candidate) and not occupied.has(candidate):
							landing = candidate
							found = true
							break
					if found:
						break
				if found:
					break
			occupied[landing] = true
			c.cell = landing
			c.position = world.cell_center(landing)
	cancel_drag()
	planet += 1
	day_time = 0.0
	night_spawned = false
	camera.position = world.cell_center(world.base_cell)
	world.queue_redraw()
	pass


func continue_colony() -> void:
	game_over = false
	end_panel.visible = false
	set_speed(1.0)
	log_line("已降落星球 %d：建筑、库存、科技与幸存者已保留。" % planet)
	pass


func objective_text() -> String:
	if not world.has_tile(GameWorld.T.RESEARCH):
		return "当前目标：采集木材与铁矿 → 手工规划研究台 → 殖民者自动施工。"
	if not unlocked_tech.has("nuclear"):
		return "当前目标：木器 → 石器 → 铁器 → 火力 → 蒸汽 → 电气 → 核能跃迁。待施工计划 %d" % world.blueprints.size()
	if not has_ship_core():
		return "当前目标：规划并建成行星发动机，再清除野兽即可迁移。"
	return "方舟就绪：清除剩余 %d 只野兽，然后点击星海跃迁。" % live_beasts()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	_idle_time = 0.0
	if event.keycode == KEY_ESCAPE:
		chat_input.release_focus()
		cancel_drag()
		if paste_preview:
			cancel_paste()
		if demolish_mode:
			set_demolish_mode(false)
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		undo_demolish()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and event.keycode == KEY_C:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		copy_selection()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and event.keycode == KEY_V:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		if clipboard.is_empty():
			log_line("剪贴板是空的：先 Shift+左键框选再 Ctrl+C。", Color(1.0, 0.8, 0.5))
		else:
			paste_preview = true
			world.preview_kind = blueprint_kind
			log_line("粘贴预览中：移动鼠标，左键放下，右键/Esc 取消。", Color(0.7, 0.9, 1.0))
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit or game_over or start_panel.visible:
		return
	if event.keycode == KEY_HOME:
		camera.position = world.cell_center(world.base_cell)
	elif event.keycode == KEY_ENTER:
		chat_input.grab_focus()
	elif event.keycode == KEY_SPACE:
		set_speed(1.0 if get_tree().paused else 0.0)
	elif event.keycode == KEY_R:
		rotate_blueprint()
	elif event.keycode == KEY_X:
		set_demolish_mode(not demolish_mode)
	pass


func on_chat_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN]:
		history_index = clampi(history_index + (-1 if event.keycode == KEY_UP else 1), 0, command_history.size())
		chat_input.text = command_history[history_index] if history_index < command_history.size() else ""
		chat_input.caret_column = chat_input.text.length()
		chat_input.accept_event()
	pass
