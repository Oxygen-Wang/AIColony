class_name Colonist
extends Node2D
## 小人：需求数值、任务状态机、自动行为、绘制

enum Move { ARRIVED, MOVING, BLOCKED }

const SPRITE_SIZE := Vector2(32, 32)

var game: Node            # main.gd
var world: GameWorld

var cname := "小人"
var color := Color.WHITE
var cell := Vector2i.ZERO

var hp := 100.0
var max_hp := 100.0
var hunger := 15.0        # 0~100，越高越饿
var fatigue := 10.0       # 0~100，越高越累
var mood := 70.0          # 0~100
var alive := true

var has_sword := false
var has_axe := false
## 工具背包：pick 级别（0无/1木/2石/3铁）、axe 级别、sword 级别、shield/bow 级别
var pick_lv := 0
var axe_lv := 0
var sword_lv := 0
var shield_lv := 0
var bow_lv := 0
var arrows := 0

# 性格/属性
var speed_mult := 1.0
var work_mult := 1.0
var hunger_rate := 1.0
var mood_bias := 0.0
var sprite_slot := 0
var people_sheet: Texture2D = GameResourceGroups.texture_from_known_group("res://image/characters/characters/People1.png")
var generated_sheet := false
var facing_dir := ColonySprites.DIR_DOWN
var anim_time := 0.0
var is_moving := false
var skills := {"gather": 1.0, "build": 1.0, "research": 1.0, "combat": 1.0, "logistics": 1.0}
var hidden_traits: Array = [] # 只通过行为表现，不在 HUD 展示数值

var queue: Array = []
var task: Dictionary = {}
var path: Array = []
var path_i := 0
var attack_cd := 0.0
var action_note := ""      # 给 AI 看的当前动作描述
var _font: Font


func setup(g: Node, w: GameWorld, data: Dictionary) -> void:
	game = g
	world = w
	cname = data["name"]
	color = data["color"]
	max_hp = data["hp"]
	hp = max_hp
	speed_mult = data["speed"]
	work_mult = data["work"]
	hunger_rate = data["hunger"]
	mood_bias = data["mood"]
	sprite_slot = int(data.get("sprite_slot", 0))
	generated_sheet = bool(data.get("generated_sheet", false))
	var sheet_path := str(data.get("sheet", ""))
	if sheet_path != "":
		var loaded := load_people_sheet(sheet_path)
		if loaded != null:
			people_sheet = loaded
	skills = (data.get("skills", skills) as Dictionary).duplicate()
	hidden_traits = (data.get("traits", []) as Array).duplicate()
	cell = data["cell"]
	position = world.cell_center(cell)
	_font = Ui.font
	add_to_group("colonists")
	pass


func load_people_sheet(sheet_path: String) -> Texture2D:
	if generated_sheet:
		return GameResourceGroups.texture_by_source_path(GameResourceGroups.COLONIST_SHEETS, sheet_path)
	return GameResourceGroups.texture_by_source_path(GameResourceGroups.CHARACTERS_BASE, sheet_path)


func _process(delta: float) -> void:
	if not alive:
		return
	anim_time += delta
	is_moving = false

	tick_needs(delta)
	if attack_cd > 0.0:
		attack_cd -= delta

	# 睡梦中被逼近的野兽吵醒
	if not task.is_empty() and str(task.get("action", "")) == "sleep" \
			and game.beast_near(position, 5.0 * GameWorld.TILE):
		wake_up()

	if not task.is_empty():
		run_task(delta)
	elif not queue.is_empty():
		task = queue.pop_front()
		action_note = action_cn(str(task.get("action", "")))
	else:
		auto_behavior(delta)
		action_note = "空闲"

	queue_redraw()


# ---------------------------------------------------------------- 需求

func tick_needs(delta: float) -> void:
	var day := float(game.DAY_LEN)
	hunger = minf(100.0, hunger + delta * hunger_rate * 100.0 / day)
	var sleeping := not task.is_empty() and str(task.get("action", "")) == "sleep"
	if sleeping:
		fatigue = maxf(0.0, fatigue - delta * 480.0 / day)
	else:
		fatigue = minf(100.0, fatigue + delta * 85.0 / day)

	# 心情向目标值平滑靠拢
	var target := 70.0 + mood_bias
	if hunger > 85.0:
		target -= 30.0
	elif hunger > 60.0:
		target -= 15.0
	if fatigue > 85.0:
		target -= 20.0
	elif fatigue > 70.0:
		target -= 8.0
	if game.is_night() and near_torch():
		target += 8.0
	if game.beast_near(position, 8.0 * GameWorld.TILE):
		target -= 22.0
	if hp < max_hp and world.find_nearest_tile(cell, [GameWorld.T.MED_BAY], 4) != Vector2i(-1, -1):
		hp = minf(max_hp, hp + delta * 3.0)
		target += 5.0
	mood = lerpf(mood, clampf(target, 0.0, 100.0), clampf(delta * 0.25, 0.0, 1.0))
	pass


func near_torch() -> bool:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if world.tile_at(cell + Vector2i(dx, dy)) == GameWorld.T.TORCH:
				return true
			if world.tile_at(cell + Vector2i(dx, dy)) == GameWorld.T.CAMPFIRE:
				return true
	return false


func work_speed() -> float:
	var s := work_mult
	var action := str(task.get("action", ""))
	if action == "mine" or action == "plant" or action == "harvest":
		s *= float(skills.get("gather", 1.0))
	elif action == "build" or action == "repair":
		s *= float(skills.get("build", 1.0))
	elif action == "craft" or action == "cook":
		s *= float(skills.get("logistics", 1.0))
		if action == "craft" and world.has_tile(GameWorld.T.WORKBENCH):
			s *= 1.25
	elif action == "research":
		s *= float(skills.get("research", 1.0))
	if mood < 30.0:
		s *= 0.5
	if fatigue > 80.0:
		s *= 0.6
	return s


func move_speed() -> float:
	var s := speed_mult
	if fatigue > 85.0:
		s *= 0.75
	return s * 108.0


# ---------------------------------------------------------------- 自动行为

func auto_behavior(delta: float) -> void:
	# 饿了自己吃
	var eat_threshold := 72.0 if game.policy == "节约配给" else 60.0
	if hunger > eat_threshold and int(game.resources.get("food", 0)) > 0:
		queue.push_back({"action": "eat", "who": cname})
		return
	if hunger > 75.0 and int(game.resources.get("crop", 0)) > 0:
		queue.push_back({"action": "eat", "who": cname})
		return
	# 深夜自己睡
	if game.is_night() and fatigue > 60.0:
		queue.push_back({"action": "sleep", "who": cname})
		return
	# 被野兽近身自己反击
	if hp < max_hp * 0.3:
		queue.push_back({"action": "flee"})
		return
	if fatigue > 85.0:
		queue.push_back({"action": "sleep"})
		return
	if not game.beasts.is_empty() and game.beast_near(position, (6.0 if bow_lv > 0 and arrows > 0 else 2.5) * GameWorld.TILE):
		queue.push_back({"action": "attack", "who": cname})
		return
	if hp < max_hp * 0.55 and not game.beast_near(position, 7.0 * GameWorld.TILE):
		var med := world.find_nearest_tile(cell, [GameWorld.T.MED_BAY], 64)
		if med != Vector2i(-1, -1):
			var stand := world.adjacent_walkable(med, cell)
			if stand != Vector2i(-1, -1):
				queue.push_back({"action": "move", "x": stand.x, "y": stand.y, "who": cname})
				return
	if game.policy == "科研优先" and game.research_active():
		queue.push_back({"action": "research", "who": cname})
		return
	if game.policy == "紧急维修" and world.find_damaged_struct(cell) != Vector2i(-1, -1) and int(game.resources.get("wood", 0)) > 0:
		queue.push_back({"action": "repair", "who": cname})
		return
	if game.policy == "战备优先" and game.is_night():
		queue.push_back({"action": "patrol", "who": cname})
		return
	# 残血撤回基地
	if hp < 25.0:
		queue.push_back({"action": "flee", "who": cname})
		return
	# 食物链只维护玩家已规划的农田，不自主扩张种植区域。
	if game.can_assign_food_work(self) and world.find_mature_crop(cell) != Vector2i(-1, -1):
		queue.push_back({"action": "harvest"})
		return
	if game.can_assign_food_work(self) and int(game.resources.get("food", 0)) < 12 and ActionTable.can_afford(game.resources, {"crop": 2, "wood": 1}):
		queue.push_back({"action": "cook"})
		return
	if game.can_assign_food_work(self) and world.find_nearest_tile(cell, [GameWorld.T.FARM_PLOT], 64) != Vector2i(-1, -1):
		queue.push_back({"action": "plant"})
		return
	# 玩家规划了蓝图后，殖民者会自行施工；从不自行决定建筑位置。
	var supply: Dictionary = game.supply_job(self)
	if not supply.is_empty():
		queue.push_back(supply)
		return
	var plan := world.find_blueprint(cell)
	if plan != Vector2i(-1, -1) and game.can_assign_auto_build(self):
		queue.push_back({"action": "build", "who": cname})
		return
	# 玩家标记了拆除后，空闲殖民者自行认领拆除单。
	if game.claim_demolish(self) != Vector2i(-1, -1):
		queue.push_back({"action": "demolish", "who": cname})
		return
	# 默认维护：防线受损时自动修理。
	if world.find_damaged_struct(cell) != Vector2i(-1, -1) and int(game.resources.get("wood", 0)) > 0:
		queue.push_back({"action": "repair", "who": cname})
		return
	stand(delta)


func stand(delta: float) -> void:
	# 空闲时在基地附近小幅走动，避免像木头人
	if path.is_empty() or path_i >= path.size():
		if randf() < delta * 0.25:
			var target := world.base_cell + Vector2i(randi_range(-4, 4), randi_range(-4, 4))
			if world.walkable(target):
				move_to(target)
	step_path(delta)
	pass


# ---------------------------------------------------------------- 任务分发

func run_task(delta: float) -> void:
	match str(task["action"]):
		"supply": game.run_supply(self, delta)
		"move": task_move(delta)
		"mine": task_mine(delta)
		"build": task_build(delta)
		"craft": task_craft(delta)
		"attack": task_attack(delta)
		"eat": task_eat(delta)
		"sleep": task_sleep(delta)
		"plant": task_plant(delta)
		"harvest": task_harvest(delta)
		"cook": task_cook(delta)
		"patrol": task_patrol(delta)
		"repair": task_repair(delta)
		"demolish": task_demolish(delta)
		"research": task_research(delta)
		"clear_base": task_clear(delta)
		"flee": task_flee(delta)
		"idle": finish("")
		_: finish("")
	pass


func task_move(delta: float) -> void:
	var t := Vector2i(int(task["x"]), int(task["y"]))
	match move_to(t):
		Move.ARRIVED: finish("")
		Move.BLOCKED: fail("那边过不去")
		Move.MOVING: step_path(delta)
	pass


func task_mine(delta: float) -> void:
	var kind := str(task.get("target", "tree"))
	var want := tile_of(kind)
	# 镐子锁矿：没对应镐直接拒绝，不浪费寻路
	if pick_lv < mine_need(kind):
		prepare_item(["", "wooden_pickaxe", "stone_pickaxe", "iron_pickaxe"][pick_lv + 1])
		return
	if not task.has("goal"):
		var g := world.find_reachable_tile(cell, [want], 48)
		if g == Vector2i(-1, -1):
			fail("附近没有可采集的" + ActionTable.cn(kind))
			return
		task["goal"] = g

	var goal: Vector2i = task["goal"]
	if world.tile_at(goal) != want:
		task.erase("goal")   # 被别人挖掉了，重新找
		return

	match move_adjacent(goal):
		Move.BLOCKED:
			fail("走不到目标")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass

	var need := 1.8
	if kind == "stone":
		need = 2.2
	elif kind == "iron":
		need = 2.8
	elif kind == "copper":
		need = 2.8
	elif kind == "uranium":
		need = 3.6
	# 高级镐挖得更快：每高出门槛 1 级省 25%
	var over := pick_lv - mine_need(kind)
	if over > 0:
		need *= pow(0.75, over)
	if has_axe and kind != "tree":
		need *= 0.5
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= need:
		task["work"] = 0.0
		var got := world.harvest(goal)
		for k in got:
			game.add_resource(k, int(got[k]))
		task.erase("goal")
		var left := int(task.get("count", 1)) - 1
		task["count"] = left
		if left <= 0:
			finish("")


func task_build(delta: float) -> void:
	var kind := str(task.get("type", ""))
	if not task.has("goal"):
		var g: Vector2i = game.available_plan(self, kind)
		if g == Vector2i(-1, -1):
			finish("")
			return
		task["goal"] = g
		if kind == "":
			kind = world.blueprint_at(g)
			task["type"] = kind
	if not game.can_build(kind):
		fail("尚未完成%s所需科技" % ActionTable.cn(kind))
		return

	var goal: Vector2i = task["goal"]
	if world.blueprint_at(goal) != kind:
		finish("")
		return
	# 用规划规则反查而不是 is_buildable：加固计划盖在墙上、方形计划铺在地板上，
	# 这两种目标格子本身不是「空地」，但依然是合法工地。
	if not world.can_place_blueprint(goal, kind):
		task.erase("goal")
		return

	var cost := ActionTable.cost_of(kind)
	if not ActionTable.can_afford(game.resources, cost):
		for resource in cost:
			if int(game.resources.get(resource, 0)) < int(cost[resource]):
				queue.push_front({"action": "mine", "target": "tree" if resource == "wood" else resource, "count": 1})
				break
		finish("")
		return

	match move_adjacent(goal):
		Move.BLOCKED:
			fail("走不到位")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass

	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 1.5:
		task["work"] = 0.0
		if not ActionTable.can_afford(game.resources, cost):
			finish("")
			return
		ActionTable.pay(game.resources, cost)
		world.finish_blueprint(goal, tile_of_build(kind))
		task.erase("goal")
		var left := int(task.get("count", 1)) - 1
		task["count"] = left
		if left <= 0:
			finish("")


func task_craft(delta: float) -> void:
	var item := str(task.get("item", "wood_sword"))
	if not game.can_craft(item):
		fail("需要先研究对应科技才能造" + ActionTable.cn(item))
		return
	var cost := ActionTable.cost_of(item)
	if not ActionTable.can_afford(game.resources, cost):
		fail("材料不够，造不了" + ActionTable.cn(item))
		return
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 2.5:
		ActionTable.pay(game.resources, cost)
		give_item(item)
		finish("造好了" + ActionTable.cn(item))

func give_item(item: String) -> void:
	var n := int(ActionTable.CRAFT_YIELD.get(item, 1))
	if game.auto_equip_weapon(item, n):
		return
	match item:
		"wooden_pickaxe": pick_lv = maxi(pick_lv, 1)
		"stone_pickaxe": pick_lv = maxi(pick_lv, 2)
		"iron_pickaxe": pick_lv = maxi(pick_lv, 3)
		"wooden_axe": axe_lv = maxi(axe_lv, 1)
		"stone_axe": axe_lv = maxi(axe_lv, 2)
		"iron_axe": axe_lv = maxi(axe_lv, 3)
		"wood_sword": sword_lv = maxi(sword_lv, 1)
		"stone_sword": sword_lv = maxi(sword_lv, 2)
		"iron_sword": sword_lv = maxi(sword_lv, 3)
		"wood_shield": shield_lv = maxi(shield_lv, 1)
		"iron_shield": shield_lv = maxi(shield_lv, 2)
		"wood_bow", "fine_bow": bow_lv = maxi(bow_lv, 1 if item == "wood_bow" else 2)
		"iron_bow": bow_lv = maxi(bow_lv, 3)
		"wood_arrow", "iron_arrow": arrows += n
		_: pass
	has_sword = sword_lv > 0
	has_axe = axe_lv > 0 or pick_lv > 0
	pass


func task_research(delta: float) -> void:
	if not game.research_active():
		finish("")
		return
	# 木器/石器免研究台：原地读书推进，其余时代才需到研究台旁
	if not game.tech_needs_bench(game.current_tech):
		game.contribute_research(delta * work_speed(), cname)
		return
	var bench := world.find_nearest_tile(cell, [GameWorld.T.RESEARCH], 64)
	if bench == Vector2i(-1, -1):
		fail("需要先建造研究台")
		return
	match move_adjacent(bench):
		Move.BLOCKED:
			fail("到不了研究台")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			game.contribute_research(delta * work_speed(), cname)


func task_attack(delta: float) -> void:
	if hp < max_hp * 0.4:
		finish("")
		queue.push_front({"action": "flee"})
		return
	var tried: Array = task.get("tried", [])
	var b = pick_beast(tried)
	if b == null:
		fail("附近没有能打的野兽了")
		return
	var d := position.distance_to(b.position)
	if bow_lv > 0 and arrows > 0 and d <= GameWorld.TILE * (5.0 + bow_lv):
		path.clear()
		if attack_cd <= 0.0:
			arrows -= 1
			attack_cd = 1.0
			game.fire_projectile(position, b, 9.0 + bow_lv * 4.0, "arrow")
		return
	if d <= GameWorld.TILE * 1.6:
		path.clear()
		path_i = 0
		cell_sync()
		if attack_cd <= 0.0:
			attack_cd = 0.9
			var dmg := 8.0 + float(bow_lv) * 1.0
			if sword_lv == 1:
				dmg = 12.0
			elif sword_lv == 2:
				dmg = 15.0
			elif sword_lv >= 3:
				dmg = 20.0
			elif axe_lv > 0 and sword_lv == 0:
				dmg = 10.0 + float(axe_lv) * 1.5
			b.take_damage(dmg, self)
		return
	# 追
	if path_i >= path.size() or randf() < delta * 1.5:
		var p := world.find_path(cell, b.cell)
		if p.is_empty():
			# 这只过不去（可能被自己的墙挡住了），换下一只
			tried.append(b.bid)
			task["tried"] = tried
			path.clear()
			path_i = 0
			if tried.size() >= game.live_beasts():
				fail("过不去，路被挡住了")
			return
		path = p
		path_i = 0
	step_path(delta)


func task_eat(_delta: float) -> void:
	if int(game.resources.get("food", 0)) > 0:
		game.add_resource("food", -1)
		hunger = maxf(0.0, hunger - 45.0)
		mood = minf(100.0, mood + 6.0)
		finish("%s吃了顿饭" % cname)
	elif int(game.resources.get("crop", 0)) > 0:
		game.add_resource("crop", -1)
		hunger = maxf(0.0, hunger - 25.0)
		mood = maxf(0.0, mood - 3.0)
		finish("%s生啃了口作物" % cname)
	else:
		fail("没有食物了")
	pass


func task_sleep(delta: float) -> void:
	# 找到床就躺下不动；一张床只睡一人（认领制），没床才就地和衣而卧
	if not task.has("at_post"):
		if not task.has("bed_goal"):
			var spot := find_bed()
			if spot == Vector2i(-1, -1):
				task["at_post"] = true
			else:
				task["bed_goal"] = spot
				path.clear()
				path_i = 0
		if not task.has("at_post") and task.has("bed_goal"):
			var goal: Vector2i = task["bed_goal"]
			# 床没了（被拆）就重新找
			if world.tile_at(goal) != GameWorld.T.BED:
				task.erase("bed_goal")
				return
			if cell == goal:
				task["at_post"] = true
			else:
				match move_to(goal):
					Move.BLOCKED:
						task.erase("bed_goal")
						return
					Move.MOVING:
						step_path(delta)
						return
					_: task["at_post"] = true
	if fatigue <= 3.0 or (not game.is_night() and fatigue < 45.0):
		finish("")


func task_plant(delta: float) -> void:
	if not task.has("goal"):
		var g := world.find_nearest_tile(cell, [GameWorld.T.FARM_PLOT], 64)
		if g == Vector2i(-1, -1):
			g = pick_grass_near_base()
		if g == Vector2i(-1, -1):
			fail("基地附近没有空地了")
			return
		task["goal"] = g
	var goal: Vector2i = task["goal"]
	if world.tile_at(goal) != GameWorld.T.FARM_PLOT and not world.is_buildable(goal):
		task.erase("goal")
		return
	match move_adjacent(goal):
		Move.BLOCKED:
			fail("走不过去")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 1.5:
		world.place(goal, GameWorld.T.CROP)
		finish("")


func task_harvest(delta: float) -> void:
	if not task.has("goal"):
		var g := world.find_mature_crop(cell)
		if g == Vector2i(-1, -1):
			fail("没有成熟的作物")
			return
		task["goal"] = g
	var goal: Vector2i = task["goal"]
	if not world.mature_crop_at(goal):
		task.erase("goal")
		return
	match move_adjacent(goal):
		Move.BLOCKED:
			fail("走不过去")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 1.5:
		world.remove_crop(goal)
		game.add_resource("crop", 2)
		task.erase("goal")
		var left := int(task.get("count", 1)) - 1
		task["count"] = left
		if left <= 0:
			finish("")


func task_cook(delta: float) -> void:
	var need := {"crop": 2, "wood": 1}
	if not ActionTable.can_afford(game.resources, need):
		fail("作物或木材不够，做不了饭")
		return
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 3.0:
		ActionTable.pay(game.resources, need)
		game.add_resource("food", 5)
		task["work"] = 0.0
		var left := int(task.get("count", 1)) - 1
		task["count"] = left
		if left <= 0:
			finish("")


func task_patrol(delta: float) -> void:
	if not task.has("goal"):
		var g := Vector2i(int(task.get("x", world.base_cell.x + 8)), int(task.get("y", world.base_cell.y)))
		task["goal"] = g
	match move_to(task["goal"]):
		Move.BLOCKED:
			finish("")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass
	task["wait"] = float(task.get("wait", 0.0)) + delta
	if float(task["wait"]) >= 4.0:
		finish("")


func task_repair(delta: float) -> void:
	if not task.has("goal"):
		var g := world.find_damaged_struct(cell)
		if g == Vector2i(-1, -1):
			fail("没有需要修理的建筑")
			return
		task["goal"] = g
	var goal: Vector2i = task["goal"]
	if not world.struct_tile(goal):
		task.erase("goal")
		return
	var cost := {"wood": 1}
	if not ActionTable.can_afford(game.resources, cost):
		fail("没有木材可以修")
		return
	match move_adjacent(goal):
		Move.BLOCKED:
			fail("走不过去")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 1.5:
		ActionTable.pay(game.resources, cost)
		world.repair_struct(goal, 40.0)
		task.erase("goal")
		var left := int(task.get("count", 1)) - 1
		task["count"] = left
		if left <= 0:
			finish("")


## 拆除：走到相邻格读条 2 秒，无材料消耗；拆完恢复草地/下层地板
func task_demolish(delta: float) -> void:
	if not task.has("goal"):
		var g: Vector2i = game.claim_demolish(self)
		if g == Vector2i(-1, -1):
			finish("")
			return
		task["goal"] = g
	var goal: Vector2i = task["goal"]
	var key := goal.y * GameWorld.W + goal.x
	if not game.demolish_marks.has(key):
		task.erase("goal")
		return
	if not world.demolishable(goal):
		game.demolish_marks.erase(key)
		game.sync_demolish_draw()
		task.erase("goal")
		return
	match move_adjacent(goal):
		Move.BLOCKED:
			task.erase("goal")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 2.0:
		task["work"] = 0.0
		if not game.demolish_marks.has(key) or not world.demolishable(goal):
			game.demolish_marks.erase(key)
			game.sync_demolish_draw()
			task.erase("goal")
			return
		var old_cn := ActionTable.cn(world.tile_asset_key(world.tile_at(goal)))
		game.demolish_marks.erase(key)
		game.sync_demolish_draw()
		world.destroy_struct(goal)
		task.erase("goal")
		finish("拆除了" + old_cn + "旧址")


func task_clear(delta: float) -> void:
	if not task.has("goal"):
		var g := world.find_nearest_tile(cell, [GameWorld.T.TREE, GameWorld.T.STONE], 14)
		if g == Vector2i(-1, -1):
			fail("基地周围已经清干净了")
			return
		task["goal"] = g
	var goal: Vector2i = task["goal"]
	var t := world.tile_at(goal)
	if t != GameWorld.T.TREE and t != GameWorld.T.STONE:
		task.erase("goal")
		return
	match move_adjacent(goal):
		Move.BLOCKED:
			task.erase("goal")
			return
		Move.MOVING:
			step_path(delta)
			return
		Move.ARRIVED:
			pass
	task["work"] = float(task.get("work", 0.0)) + delta * work_speed()
	if float(task["work"]) >= 2.0:
		task["work"] = 0.0
		var got := world.harvest(goal)
		for k in got:
			game.add_resource(k, int(got[k]))
		task.erase("goal")
		var left := int(task.get("count", 1)) - 1
		task["count"] = left
		if left <= 0:
			finish("")


func task_flee(delta: float) -> void:
	match move_to(world.base_cell):
		Move.MOVING: step_path(delta)
		_: finish("")
	pass


# ---------------------------------------------------------------- 移动

func move_to(target: Vector2i) -> int:
	cell_sync()
	if cell == target:
		path.clear()
		path_i = 0
		return Move.ARRIVED
	if path_i >= path.size():
		var p := world.find_path(cell, target)
		if p.is_empty():
			return Move.BLOCKED
		path = p
		path_i = 0
	return Move.MOVING


func move_adjacent(target: Vector2i) -> int:
	cell_sync()
	if is_adjacent(target):
		return Move.ARRIVED
	var stand := world.adjacent_walkable(target, cell)
	if stand == Vector2i(-1, -1):
		return Move.BLOCKED
	return move_to(stand)


func is_adjacent(c: Vector2i) -> bool:
	return absi(c.x - cell.x) <= 1 and absi(c.y - cell.y) <= 1


func step_path(delta: float) -> void:
	if path_i >= path.size():
		return
	var target := world.cell_center(path[path_i])
	var diff := target - position
	if diff.length_squared() > 0.01:
		facing_dir = ColonySprites.facing_from(diff)
		is_moving = true
	var step := move_speed() * delta
	if diff.length() <= step:
		position = target
		path_i += 1
	else:
		position += diff.normalized() * step
	cell_sync()


func cell_sync() -> void:
	cell = world.world_to_cell(position)
	pass


# ---------------------------------------------------------------- 辅助

func pick_beast(tried: Array = []):
	var best = null
	var best_d := INF
	if task.has("target_id"):
		var wanted := int(task["target_id"])
		for b in game.beasts:
			if is_instance_valid(b) and not b.dead and b.bid == wanted:
				return b
	for b in game.beasts:
		if not is_instance_valid(b) or b.dead:
			continue
		if tried.has(b.bid):
			continue
		if world.find_path(cell, b.cell).is_empty():
			continue
		var d := position.distance_to(b.position)
		if d < best_d:
			best_d = d
			best = b
	return best


func pick_build_spot(kind: String) -> Vector2i:
	if task.has("x") and task.has("y"):
		var c := Vector2i(int(task["x"]), int(task["y"]))
		if world.is_buildable(c):
			return c
	# 没给坐标：在基地外圈找一块空地
	var r := 7
	if kind == "torch":
		r = 5
	elif kind == "bed":
		r = 6
	var cands: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := maxi(absi(dx), absi(dy))
			if d < r - 2:
				continue
			var c := world.base_cell + Vector2i(dx, dy)
			if world.is_buildable(c):
				cands.append(c)
	if cands.is_empty():
		return Vector2i(-1, -1)
	return cands[randi() % cands.size()]


func pick_grass_near_base() -> Vector2i:
	var cands: Array = []
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var c := world.base_cell + Vector2i(dx, dy)
			if world.is_buildable(c) and world.tile_at(c) == GameWorld.T.GRASS:
				cands.append(c)
	if cands.is_empty():
		return Vector2i(-1, -1)
	return cands[randi() % cands.size()]


## 找一张没人认领的床：已被别人当目标/已躺上的跳过；实在没空床返回(-1,-1)就地睡
func find_bed() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(maxi(0, cell.y - 40), mini(GameWorld.H, cell.y + 41)):
		for x in range(maxi(0, cell.x - 40), mini(GameWorld.W, cell.x + 41)):
			var c := Vector2i(x, y)
			if world.tile_at(c) != GameWorld.T.BED:
				continue
			if not world.walkable(c):
				continue
			var taken := false
			for other: Colonist in game.colonists:
				if other == self or not other.alive:
					continue
				var ot: Dictionary = other.task
				if str(ot.get("action", "")) != "sleep":
					continue
				if ot.has("bed_goal") and ot["bed_goal"] == c:
					taken = true
					break
				if ot.has("at_post") and other.cell == c:
					taken = true
					break
			if taken:
				continue
			var d := float(cell.distance_squared_to(c))
			if d < best_d and not world.find_path(cell, c).is_empty():
				best_d = d
				best = c
	return best


func tile_of(kind: String) -> int:
	match kind:
		"tree": return GameWorld.T.TREE
		"stone": return GameWorld.T.STONE
		"iron": return GameWorld.T.IRON
		"copper": return GameWorld.T.COPPER
		"uranium": return GameWorld.T.URANIUM
	return GameWorld.T.TREE

## 采集门槛：目标资源需要的最低镐级别（tree 徒手 0，stone 木镐 1，iron/copper 石镐 2，uranium 铁镐 3）
func mine_need(kind: String) -> int:
	match kind:
		"stone": return 1
		"iron", "copper": return 2
		"uranium": return 3
	return 0

func mine_need_name(kind: String) -> String:
	match kind:
		"stone": return "木镐"
		"iron", "copper": return "石镐"
		"uranium": return "铁镐"
	return ""


func prepare_item(item: String) -> void:
	if not game.can_craft(item):
		finish("")
		return
	var resume := task.duplicate()
	var cost := ActionTable.cost_of(item)
	queue.push_front(resume)
	queue.push_front({"action": "craft", "item": item})
	for resource in cost:
		var shortage := int(cost[resource]) - int(game.resources.get(resource, 0))
		if shortage > 0:
			queue.push_front({"action": "mine", "target": "tree" if resource == "wood" else resource, "count": shortage})
	finish("")
	pass


func tile_of_build(kind: String) -> int:
	match kind:
		"wall": return GameWorld.T.WALL
		"door": return GameWorld.T.DOOR
		"torch": return GameWorld.T.TORCH
		"campfire": return GameWorld.T.CAMPFIRE
		"bed": return GameWorld.T.BED
		"floor": return GameWorld.T.FLOOR
		"farm_plot": return GameWorld.T.FARM_PLOT
		"storage": return GameWorld.T.STORAGE
		"workbench": return GameWorld.T.WORKBENCH
		"workbench2": return GameWorld.T.WORKBENCH2
		"adv_workbench": return GameWorld.T.ADV_WORKBENCH
		"elec_workbench": return GameWorld.T.ELEC_WORKBENCH
		"nuke_workbench": return GameWorld.T.NUKE_WORKBENCH
		"med_bay": return GameWorld.T.MED_BAY
		"arrow_bench": return GameWorld.T.ARROW_BENCH
		"ammo_factory": return GameWorld.T.AMMO_FACTORY
		"ammo_depot": return GameWorld.T.AMMO_DEPOT
		"wood_tower": return GameWorld.T.WOOD_TOWER
		"stone_tower": return GameWorld.T.STONE_TOWER
		"turret": return GameWorld.T.TURRET
		"laser_turret": return GameWorld.T.LASER_TURRET
		"nuke_tower": return GameWorld.T.NUKE_TOWER
		"research": return GameWorld.T.RESEARCH
		"generator": return GameWorld.T.GENERATOR
		"battery": return GameWorld.T.BATTERY
		"solar": return GameWorld.T.SOLAR
		"reactor": return GameWorld.T.REACTOR
		"radar": return GameWorld.T.RADAR
		"ark_core": return GameWorld.T.SHIP_CORE
		"engine": return GameWorld.T.ENGINE
		"engine_floor": return GameWorld.T.ENGINE_FLOOR
		"steam_lamp": return GameWorld.T.STEAM_LAMP
		"iron_rivet_table": return GameWorld.T.IRON_RIVET_TABLE
		"monitor_window": return GameWorld.T.MONITOR_WINDOW
		"wire": return GameWorld.T.WIRE
		"pipe": return GameWorld.T.PIPE
		"pump": return GameWorld.T.PUMP
		"pole": return GameWorld.T.POLE
		"grid_pole": return GameWorld.T.GRID_POLE
		"cart": return GameWorld.T.CART
		"garage": return GameWorld.T.GARAGE
		"shelf": return GameWorld.T.SHELF
		"water_tank": return GameWorld.T.WATER_TANK
		"elec_box": return GameWorld.T.ELEC_BOX
		"elec_lamp": return GameWorld.T.ELEC_LAMP
		"elec_door": return GameWorld.T.ELEC_DOOR
		"metal_table": return GameWorld.T.METAL_TABLE
		"rad_door": return GameWorld.T.RAD_DOOR
		"nuke_lamp": return GameWorld.T.NUKE_LAMP
		"command_table": return GameWorld.T.COMMAND_TABLE
		"lead_chest": return GameWorld.T.LEAD_CHEST
		"wood_chest": return GameWorld.T.WOOD_CHEST
		"wood_table": return GameWorld.T.WOOD_TABLE
		"wood_chair": return GameWorld.T.WOOD_CHAIR
		"wood_window": return GameWorld.T.WOOD_WINDOW
		"wood_fence": return GameWorld.T.WOOD_FENCE
		"wood_ladder": return GameWorld.T.WOOD_LADDER
		"wood_lamp": return GameWorld.T.WOOD_LAMP
		"stone_chest": return GameWorld.T.STONE_CHEST
		"stone_table": return GameWorld.T.STONE_TABLE
		"stone_chair": return GameWorld.T.STONE_CHAIR
		"stone_door": return GameWorld.T.STONE_DOOR
		"stone_window": return GameWorld.T.STONE_WINDOW
		"stone_fence": return GameWorld.T.STONE_FENCE
		"stone_ladder": return GameWorld.T.STONE_LADDER
		"stone_lamp": return GameWorld.T.STONE_LAMP
		"iron_chest": return GameWorld.T.IRON_CHEST
		"iron_table": return GameWorld.T.IRON_TABLE
		"iron_chair": return GameWorld.T.IRON_CHAIR
		"iron_door": return GameWorld.T.IRON_DOOR
		"iron_window": return GameWorld.T.IRON_WINDOW
		"iron_fence": return GameWorld.T.IRON_FENCE
		"iron_ladder": return GameWorld.T.IRON_LADDER
		"iron_lamp": return GameWorld.T.IRON_LAMP
		"copper_chest": return GameWorld.T.COPPER_CHEST
	return GameWorld.T.WALL


func action_cn(a: String) -> String:
	match a:
		"move": return "赶路"
		"mine": return "采集"
		"build": return "建造"
		"craft": return "制作"
		"attack": return "战斗"
		"eat": return "吃饭"
		"sleep": return "睡觉"
		"plant": return "种植"
		"harvest": return "收获"
		"cook": return "做饭"
		"patrol": return "巡逻"
		"repair": return "修理"
		"research": return "科研"
		"clear_base": return "清理"
		"flee": return "撤退"
		"idle": return "待命"
	return "干活"


func finish(msg: String) -> void:
	if msg != "":
		game.log_line(msg, Color(0.75, 0.85, 1.0))
	task = {}
	path.clear()
	path_i = 0
	pass


func fail(msg: String) -> void:
	game.log_line("%s：%s" % [cname, msg], Color(1.0, 0.6, 0.55))
	task = {}
	path.clear()
	path_i = 0
	pass


# ---------------------------------------------------------------- 受伤 / 死亡

func take_damage(dmg: float) -> void:
	if not alive:
		return
	# 盾减伤：木盾 -2，铁盾 -4
	hp -= maxf(1.0, dmg - float(shield_lv) * 2.0)
	mood = maxf(0.0, mood - 3.0)
	wake_up()   # 挨打就醒，并且还手
	if hp <= 0.0:
		hp = 0.0
		die()


## 被新指令打断睡眠（main 分发指令时调用）
func interrupt_sleep() -> void:
	if not task.is_empty() and str(task.get("action", "")) == "sleep":
		task = {}
		path.clear()
		path_i = 0
	pass


## 醒来：中断睡眠并去还手
func wake_up() -> void:
	interrupt_sleep()
	if not attack_pending():
		queue.push_front({"action": "attack", "who": cname})
	pass


func attack_pending() -> bool:
	if not task.is_empty() and str(task.get("action", "")) == "attack":
		return true
	for t in queue:
		if str(t.get("action", "")) == "attack":
			return true
	return false


func die() -> void:
	alive = false
	visible = false
	game.log_line("%s 倒下了……" % cname, Color(1.0, 0.4, 0.4))
	game.on_colonist_death()
	pass


func task_desc() -> String:
	if not alive:
		return "已阵亡"
	if task.is_empty():
		return "空闲"
	return action_note


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	if not alive:
		return
	# 32×32 像素角色，并用颜色描边保留殖民者辨识度。
	draw_circle(Vector2(0, 11), 9.0, Color(0, 0, 0, 0.25))
	if generated_sheet:
		var source_size := people_sheet.get_size() / 4.0
		var frame := 2 + int(anim_time * 7.0) % 2 if is_moving else int(anim_time * 1.8) % 2
		var region := Rect2(Vector2(frame, facing_dir) * source_size, source_size)
		draw_texture_rect_region(people_sheet, Rect2(-16, -24, 32, 40), region)
	else:
		var sheet_col := sprite_slot % 4
		var sheet_row := sprite_slot / 4
		var region := Rect2(Vector2(sheet_col * 96 + 32, sheet_row * 128), SPRITE_SIZE)
		draw_texture_rect_region(people_sheet, Rect2(-16, -18, 32, 32), region)
	draw_arc(Vector2(0, -2), 13.0, 0, TAU, 24, color.lightened(0.18), 1.4)
	if _font:
		draw_string(_font, Vector2(-36, -16), cname, HORIZONTAL_ALIGNMENT_CENTER, 72, 15, Color.WHITE)
		if not task.is_empty():
			draw_string(_font, Vector2(-36, 30), action_note, HORIZONTAL_ALIGNMENT_CENTER, 72, 12,
				Color(0.85, 0.9, 1.0, 0.85))
	# 血条
	if hp < max_hp:
		var w := 24.0
		draw_rect(Rect2(-w * 0.5, -20, w, 3.5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, -20, w * (hp / max_hp), 3.5), Color(0.35, 0.85, 0.4))
	# 选中高亮
	if game.selected == self:
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, Color(1, 0.95, 0.4), 2.5)
	# 自动装备后的武器直接显示在角色身侧。
	if bow_lv > 0:
		draw_arc(Vector2(11, 6), 6.0, -PI * 0.5, PI * 0.5, 10, Color("b9824a"), 1.8)
		draw_line(Vector2(11, 0), Vector2(11, 12), Color("e8dfc5"), 1.0)
	elif has_sword:
		draw_line(Vector2(9, 12), Vector2(14, 1), Color("dce5ea"), 2.2)
		draw_line(Vector2(8, 9), Vector2(13, 11), Color("b9824a"), 1.8)
	elif has_axe:
		draw_circle(Vector2(10, 10), 3.5, Color(0.9, 0.75, 0.4))
