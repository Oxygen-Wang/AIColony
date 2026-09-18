extends Node
## 离线回归：验证玩家意图、取消施工和迁移状态，而不是只检查场景能启动。

var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)
	pass

func _ready() -> void:
	var game: Node2D = load("res://scene/main/Main.tscn").instantiate()
	add_child(game)
	game.ai.online = false
	game.ai.api_key = ""
	game.set_process(false)
	for colonist: Colonist in game.colonists:
		colonist.set_process(false)
	var snap: Dictionary = game.snapshot()
	var result := RuleParser.parse("抽抽砍5棵树，七海采3块石头", snap)
	check(result.commands.size() == 2, "复合命令拆为两条")
	check(result.commands[0].who == "抽抽" and result.commands[0].count == 5, "首句人物和数量")
	check(result.commands[1].who == "七海" and result.commands[1].count == 3 and result.commands[1].target == "stone", "次句人物、资源和数量独立")
	result = RuleParser.parse("龟龟造石斧，然后去打野兽", snap)
	check(result.commands.size() == 2 and result.commands[1].who == "龟龟" and result.commands[1].action == "attack", "顺序指令继承人物")
	result = RuleParser.parse("现在食物多少，抽抽砍树", snap)
	check(result.commands.size() == 1 and result.commands[0].action == "mine", "询问不会阻止后续工作")
	check(RuleParser.parse("现在情况怎么样", snap).commands.is_empty(), "纯询问无副作用")
	result = RuleParser.parse("抽抽到70,72", snap)
	check(result.commands.size() == 1 and result.commands[0].x == 70 and result.commands[0].y == 72, "坐标逗号不分句")
	check(RuleParser.parse("鱼和糖做饭", snap).commands.size() == 1, "烹饪不误触发进食")
	check(RuleParser.parse("建收纳箱", snap).commands.size() == 1, "收纳箱不误触发收割")
	check(ActionTable.validate({"action": "mine", "target": "invalid"}).is_empty(), "拒绝不存在的资源")
	check(ActionTable.validate({"action": "mine", "target": "tree", "count": 999999}).count == 99, "数量有上限")
	var json_result := AIManager.extract_json('解释 {bad} 然后 {"reply":"含有 } 和 { 的字符串", "commands":[]} 尾巴 {}')
	check(json_result.get("reply", "") == "含有 } 和 { 的字符串", "JSON 抢救正确处理字符串括号和多个对象")
	check(AIManager.extract_json("not json").is_empty(), "无效响应安静失败")
	for name: String in ColonySprites.PAWN_SPRITES:
		var def: Dictionary = ColonySprites.PAWN_SPRITES[name]
		var frame := ColonySprites.walk_frame(def.sheet, def.block, 3, 2)
		check(not frame.is_empty() and Rect2(Vector2.ZERO, frame.tex.get_size()).encloses(frame.rect), "角色帧在图集内：" + name)
	var world: GameWorld = game.world
	var cell := world.base_cell + Vector2i(3, 3)
	world.place(cell, GameWorld.T.GRASS)
	check(game.dispatch({"action": "build", "type": "bed", "who": "抽抽"}) == 0, "无蓝图时提示而不自动选址")
	world.add_blueprint(cell, "bed")
	var worker: Colonist = game.colonists[0]
	worker.task = {"action": "build", "type": "bed", "goal": cell, "work": 1.4}
	game.resources.wood = 50
	world.remove_blueprint(cell)
	worker.task_build(1.0)
	check(world.tile_at(cell) == GameWorld.T.GRASS and game.resources.wood == 50, "取消的蓝图不会建成或扣材料")
	worker.queue.append({"action": "mine", "target": "tree", "count": 99})
	worker.task = {"action": "mine", "target": "tree"}
	game.dispatch({"action": "flee", "who": worker.cname})
	check(worker.task.is_empty() and worker.queue.size() == 1 and worker.queue[0].action == "flee", "紧急撤退中断采集与旧队列")
	world.place(cell, GameWorld.T.WALL)
	world.struct_hp[cell.y * GameWorld.W + cell.x] = 37.0
	var plan := cell + Vector2i(1, 0)
	world.place(plan, GameWorld.T.GRASS)
	world.add_blueprint(plan, "bed")
	var hp_before := worker.hp
	var before := world.tiles.duplicate()
	game.unlocked_tech.launch = true
	game.migrate_colony()
	check(game.planet == 2 and world.tiles != before, "迁移生成不同星球")
	check(world.tile_at(cell) == GameWorld.T.WALL and world.struct_hp[cell.y * GameWorld.W + cell.x] == 37.0, "建筑及损伤保留")
	check(world.blueprint_at(plan) == "bed" and world.is_buildable(plan), "未完成蓝图及其可施工地面保留")
	check(game.resources.wood == 50 and worker.hp == hp_before and game.unlocked_tech.launch, "库存、人员状态和科技保留")
	check(worker.queue.is_empty() and worker.path.is_empty() and world.walkable(worker.cell), "旧任务路径清理并安全降落")
	game.victory()
	check(game.end_panel.visible and game.continue_button.visible, "迁移结算允许继续")
	game.continue_colony()
	check(not game.game_over and not get_tree().paused and not game.end_panel.visible, "继续殖民恢复游戏")
	var landings := {}
	for colonist: Colonist in game.colonists:
		landings[colonist.cell] = true
	check(landings.size() == 6, "六人分别降落到不同格子")
	worker.cell = world.base_cell
	worker.position = world.cell_center(worker.cell)
	var work_cell := worker.cell + Vector2i(1, 0)
	world.place(work_cell, GameWorld.T.TREE)
	worker.task = {"action": "mine", "target": "tree", "goal": work_cell, "count": 1}
	var wood_before: int = game.resources.wood
	for i in 20:
		if not worker.task.is_empty():
			worker.task_mine(1.0)
	check(game.resources.wood == wood_before + 3 and world.tile_at(work_cell) == GameWorld.T.GRASS, "实际采集销毁资源格并入库")
	world.add_blueprint(work_cell, "farm_plot")
	worker.task = {"action": "build", "type": "farm_plot", "goal": work_cell}
	for i in 20:
		if not worker.task.is_empty():
			worker.task_build(1.0)
	check(world.tile_at(work_cell) == GameWorld.T.FARM_PLOT and world.blueprint_at(work_cell) == "", "实际施工消耗蓝图并建成农田")
	worker.task = {"action": "plant", "goal": work_cell}
	for i in 20:
		if not worker.task.is_empty():
			worker.task_plant(1.0)
	world.tick_crops(61.0)
	check(world.mature_crop_at(work_cell), "农田种植及生长")
	worker.task = {"action": "harvest", "goal": work_cell}
	var crop_before: int = game.resources.crop
	for i in 20:
		if not worker.task.is_empty():
			worker.task_harvest(1.0)
	check(game.resources.crop == crop_before + 2 and world.tile_at(work_cell) == GameWorld.T.FARM_PLOT, "收割入库并恢复农田供补种")
	worker.task = {"action": "cook", "count": 1}
	var food_before: int = game.resources.food
	for i in 20:
		if not worker.task.is_empty():
			worker.task_cook(1.0)
	check(game.resources.food == food_before + 5, "作物烹饪产出食物")

	# —— 拖拽补格：快速拖动时中间跳过的格子必须补满，城墙才连得起来 ——
	var line := world.line_cells(Vector2i(64, 60), Vector2i(70, 63))
	check(line.size() == 10 and line[0] == Vector2i(64, 60) and line[line.size() - 1] == Vector2i(70, 63), "补格覆盖首尾之间全部格子")
	var four_way := true
	for i in range(1, line.size()):
		var step: Vector2i = line[i] - line[i - 1]
		if absi(step.x) + absi(step.y) != 1:
			four_way = false
	check(four_way, "补格只走四向，城墙不会在对角留下缺口")
	check(world.line_cells(Vector2i(64, 60), Vector2i(64, 60)).size() == 1, "原地按下只落一格")
	check(world.rect_cells(Vector2i(70, 70), Vector2i(72, 71)).size() == 6, "Ctrl 矩形覆盖 3×2 全部格子")

	# —— 地板分层：地板之上能继续盖，建筑被打掉后地板还在 ——
	game.resources.wood = 50
	game.resources.stone = 50
	worker.queue.clear()
	worker.cell = world.base_cell
	worker.position = world.cell_center(worker.cell)
	for dy in range(0, 4):
		for dx in range(-1, 2):
			world.place(world.base_cell + Vector2i(dx, dy), GameWorld.T.GRASS)
	var fcell := worker.cell + Vector2i(0, 1)
	world.place(fcell, GameWorld.T.FLOOR)
	check(world.can_place_blueprint(fcell, "wall"), "地板铺好后仍可规划上层建筑")
	check(world.add_blueprint(fcell, "wall"), "地板格接受墙的规划")
	worker.task = {"action": "build", "type": "wall", "goal": fcell}
	for i in 12:
		if not worker.task.is_empty():
			worker.task_build(1.0)
	check(world.tile_at(fcell) == GameWorld.T.WALL, "地板上盖起了墙")
	world.damage_struct(fcell, 999.0)
	check(world.tile_at(fcell) == GameWorld.T.FLOOR, "墙被摧毁后露出压在下方的地板")

	# —— 加固：只能盖在对应建筑上，完成后耐久与等级提升 ——
	var wcell := worker.cell + Vector2i(0, 2)
	world.place(wcell, GameWorld.T.GRASS)
	check(not world.can_place_blueprint(wcell, "wall_upgrade"), "空地上不能规划城墙加固")
	check(not world.can_place_blueprint(wcell, "floor_upgrade"), "空地上不能规划地板加固")
	world.place(wcell, GameWorld.T.WALL)
	world.struct_hp[wcell.y * GameWorld.W + wcell.x] = 90.0
	check(world.can_place_blueprint(wcell, "wall_upgrade"), "已建成的墙上可以规划加固")
	check(world.add_blueprint(wcell, "wall_upgrade"), "加固计划入队")
	worker.task = {"action": "build", "type": "wall_upgrade", "goal": wcell}
	for i in 12:
		if not worker.task.is_empty():
			worker.task_build(1.0)
	check(world.blueprint_at(wcell) == "" and world.tile_at(wcell) == GameWorld.T.WALL, "加固消耗计划且墙仍在")
	check(world.struct_max_hp(wcell) == GameWorld.WALL_HP_UPGRADED, "加固后城墙耐久上限提升")
	check(world.repair_struct(wcell, 500.0) and world.struct_hp[wcell.y * GameWorld.W + wcell.x] == GameWorld.WALL_HP_UPGRADED, "加固后的墙能修到更高上限")
	var ucell := worker.cell + Vector2i(0, 3)
	world.place(ucell, GameWorld.T.FLOOR)
	check(world.add_blueprint(ucell, "floor_upgrade"), "地板上可以规划加固")
	worker.task = {"action": "build", "type": "floor_upgrade", "goal": ucell}
	for i in 12:
		if not worker.task.is_empty():
			worker.task_build(1.0)
	check(world.floor_upgrade_at(ucell) == 1 and world.tile_at(ucell) == GameWorld.T.FLOOR, "地板加固只提升等级、不换物块")

	# —— R 旋转：朝向要一直保留到建成之后 ——
	var rcell := worker.cell + Vector2i(-1, 1)
	world.place(rcell, GameWorld.T.GRASS)
	check(world.add_blueprint(rcell, "door", 3), "带朝向的规划入队")
	check(world.blueprint_rotation_at(rcell) == 3, "规划记录了旋转朝向")
	world.set_blueprint_rotation(rcell, 1)
	check(world.blueprint_rotation_at(rcell) == 1, "R 可以直接改已放下的计划朝向")
	worker.task = {"action": "build", "type": "door", "goal": rcell}
	for i in 12:
		if not worker.task.is_empty():
			worker.task_build(1.0)
	check(world.struct_rotation_at(rcell) == 1, "建成后的门保持规划朝向")

	# —— 建造栏：图案齐全，每个项目都有悬停说明 ——
	var no_icon: Array = []
	for kind in ActionTable.BUILD_ORDER:
		if BuildIcons.icon(kind) == null:
			no_icon.append(kind)
	check(no_icon.is_empty(), "每个规划项目都有图标：" + str(no_icon))
	var no_desc: Array = []
	for kind in ActionTable.BUILD_ORDER:
		if not ActionTable.DESC.has(kind):
			no_desc.append(kind)
	check(no_desc.is_empty(), "每个规划项目都有悬停说明：" + str(no_desc))
	check(ActionTable.BUILD_ORDER.has("wall_upgrade") and ActionTable.BUILD_ORDER.has("floor_upgrade"), "加固项目出现在建造栏")
	check(ActionTable.upgrade_base("wall_upgrade") == "wall" and not ActionTable.is_upgrade("wall"), "加固项目复用被强化建筑的图")

	print("REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
	pass
