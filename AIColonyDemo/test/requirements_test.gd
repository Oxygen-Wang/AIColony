extends SceneTree
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
	else:
		print("[PASS] ", label)
	pass

func _initialize() -> void:
	call_deferred("run")
	pass

func run() -> void:
	var game = load("res://scene/main/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for c in game.colonists:
		c.set_process(false)
		c.finish("")
		c.queue.clear()
	var world: GameWorld = game.world
	check(GameWorld.SOLID_P.size() == GameWorld.T.size() and GameWorld.SOLID_B.size() == GameWorld.T.size(), "collision arrays match enum")
	for tile in [GameWorld.T.WOOD_TABLE, GameWorld.T.STONE_CHAIR, GameWorld.T.IRON_LADDER, GameWorld.T.BED]:
		check(not GameWorld.SOLID_P[tile], "furniture passable: %d" % tile)
	for tile in [GameWorld.T.DOOR, GameWorld.T.STONE_FENCE, GameWorld.T.IRON_FENCE]:
		check(not GameWorld.SOLID_P[tile] and GameWorld.SOLID_B[tile], "defense blocks enemies: %d" % tile)
	game.unlocked_tech["woodcraft"] = true
	game.resources["wood"] = 100
	game.resources["stone"] = 100
	game.propose_defense()
	check(world.blueprints.is_empty() and not world.layout_preview.is_empty(), "layout preview does not build")
	game.cancel_defense()
	check(world.blueprints.is_empty(), "cancel leaves no blueprints")
	game.propose_defense()
	game.confirm_defense()
	game.layout_dialog.hide()
	check(not world.blueprints.is_empty(), "confirmation creates blueprints")
	var worker: Colonist = game.colonists[0]
	var second: Colonist = game.colonists[1]
	var plan: Vector2i = game.available_plan(worker)
	worker.task = {"action": "build", "goal": plan}
	check(game.available_plan(second) != plan, "workers reserve distinct sites")
	worker.finish("")
	world.blueprints.clear()
	var base := world.base_cell
	var station := base + Vector2i(1, 0)
	var depot := base + Vector2i(0, 1)
	var tower := base + Vector2i(-1, 0)
	world.place(station, GameWorld.T.ARROW_BENCH)
	world.place(depot, GameWorld.T.AMMO_DEPOT)
	world.place(tower, GameWorld.T.WOOD_TOWER)
	worker.position = world.cell_center(base)
	worker.cell = base
	worker.task = game.supply_job(worker)
	game.run_supply(worker, 10.0)
	game.run_supply(worker, 0.1)
	var key := depot.y * GameWorld.W + depot.x
	check(int(game.depot_stock[key].arrow) == 6, "production consumes wood and deposits six arrows")
	worker.task = game.supply_job(worker)
	game.run_supply(worker, 0.1)
	game.run_supply(worker, 0.1)
	var tower_key := tower.y * GameWorld.W + tower.x
	check(int(game.tower_ammo.get(tower_key, 0)) == 6 and int(game.depot_stock[key].arrow) == 0, "worker transfers depot ammo to tower")
	var beast := Beast.new()
	world.add_child(beast)
	beast.setup(game, world, 999, 100, 1, base + Vector2i(2, 0))
	beast.set_process(false)
	game.beasts.append(beast)
	game.tick_turrets(1.0)
	check(beast.hp == 100 and int(game.tower_ammo[tower_key]) == 5, "launch consumes one ammo without instant damage")
	for child in world.get_children():
		if child.get_script() == game.PROJECTILE:
			child._process(1.0)
	check(beast.hp == 94, "projectile applies damage on impact")
	game.tower_ammo[tower_key] = 0
	game.tick_turrets(1.0)
	check(beast.hp == 94, "empty tower stops firing")
	worker.bow_lv = 1
	worker.arrows = 1
	worker.task = {"action": "attack"}
	worker.attack_cd = 0
	worker.task_attack(0.1)
	check(worker.arrows == 0, "archer consumes personal arrow")
	beast.dead = true
	beast.queue_free()
	game.beasts.clear()
	await process_frame
	game.unlocked_tech["nuclear"] = true
	world.place(base + Vector2i(3, 0), GameWorld.T.SHIP_CORE)
	game.try_jump()
	check(game.planet == 2 and game.won, "engine and nuclear technology allow migration")
	paused = false
	print("[REQUIREMENTS] failures=", failures)
	quit(1 if failures else 0)
	pass
