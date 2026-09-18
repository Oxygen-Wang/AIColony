class_name Beast
extends Node2D
## 野兽：夜里从地图边缘刷新，扑向最近的小人；被墙挡住就拆墙

const MONSTER_SHEET: Texture2D = preload("res://image/characters/creatures/Monster1.png")
const GENERATED_ENEMY_SHEETS := [
	preload("res://image/characters/monsters/generated/enemy_directional_01_basic_16x4.png"),
	preload("res://image/characters/monsters/generated/enemy_directional_02_mid_16x4.png"),
	preload("res://image/characters/monsters/generated/enemy_directional_03_heavy_16x4.png"),
	preload("res://image/characters/monsters/generated/enemy_directional_04_seasonal_16x4.png"),
	preload("res://image/characters/monsters/generated/enemy_directional_05_endgame_16x4.png"),
]
const SPRITE_SIZE := Vector2(32, 32)

static var generated_enemy_sheets: Array[Texture2D] = []

var game: Node
var world: GameWorld

var bid := 0
var hp := 40.0
var max_hp := 40.0
var dmg := 8.0
var speed := 74.0
var enemy_kind := 0
var sprite_scale := 1.0

var cell := Vector2i.ZERO
var path: Array = []
var path_i := 0
var repath_cd := 0.0
var attack_cd := 0.0
var attack_flash := 0.0
var dead := false
var retreating := false
var facing_dir := 0
var moving := false

var _font: Font
var _wobble := 0.0


func setup(g: Node, w: GameWorld, id: int, health: float, damage: float, spawn: Vector2i, kind: int = 0, scale: float = 1.0) -> void:
	game = g
	world = w
	bid = id
	hp = health
	max_hp = health
	dmg = damage
	enemy_kind = kind
	sprite_scale = scale
	cell = spawn
	position = world.cell_center(spawn)
	_font = Ui.font
	_wobble = randf() * TAU
	add_to_group("beasts")
	pass


func _process(delta: float) -> void:
	if dead:
		return
	_wobble += delta * 6.0
	queue_redraw()

	if attack_cd > 0.0:
		attack_cd -= delta
	if attack_flash > 0.0:
		attack_flash -= delta
	if repath_cd > 0.0:
		repath_cd -= delta
	moving = false

	if retreating:
		retreat(delta)
		return

	var target := nearest_colonist()
	if target == null:
		# 没目标了就在原地游荡
		return

	var dist := position.distance_to(target.position)
	if dist <= GameWorld.TILE * 1.4:
		update_facing(target.position - position)
		if attack_cd <= 0.0:
			attack_cd = 1.5
			attack_flash = 0.32
			target.take_damage(dmg)
		return

	if repath_cd <= 0.0:
		repath_cd = 0.6
		var p := world.find_path(cell, target.cell, true)
		if p.is_empty():
			# 被挡路：拆最近的墙/门
			var wall := blocking_struct()
			if wall != Vector2i(-1, -1):
				var p2 := world.find_path(cell, wall, true)
				if not p2.is_empty():
					path = p2
					path_i = 0
				else:
					path.clear()
			else:
				path.clear()
		else:
			path = p
			path_i = 0

	step(delta)

	# 走到墙边就打墙
	var adj := adjacent_struct()
	if adj != Vector2i(-1, -1) and attack_cd <= 0.0:
		attack_cd = 1.2
		attack_flash = 0.32
		update_facing(world.cell_center(adj) - position)
		if world.damage_struct(adj, 12.0):
			game.log_line("一段建筑被野兽拆掉了！", Color(1.0, 0.5, 0.4))


func nearest_colonist() -> Colonist:
	var best: Colonist = null
	var best_d := INF
	for c in game.colonists:
		if not is_instance_valid(c) or not c.alive:
			continue
		var d := position.distance_to(c.position)
		if d < best_d:
			best_d = d
			best = c
	return best


func blocking_struct() -> Vector2i:
	# 找附近 10 格内最近的墙/门
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var c := cell + Vector2i(dx, dy)
			if world.struct_tile(c):
				var d := Vector2(dx, dy).length()
				if d < best_d:
					best_d = d
					best = c
	return best


func adjacent_struct() -> Vector2i:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var c := cell + Vector2i(dx, dy)
			if world.struct_tile(c):
				return c
	return Vector2i(-1, -1)


func step(delta: float) -> void:
	if path_i >= path.size():
		return
	var target := world.cell_center(path[path_i])
	var diff := target - position
	var step := speed * delta
	if diff.length() <= step:
		position = target
		path_i += 1
	else:
		update_facing(diff)
		position += diff.normalized() * step
		moving = true
	cell = world.world_to_cell(position)
	pass


func update_facing(delta_pos: Vector2) -> void:
	if delta_pos.length_squared() <= 0.01:
		return
	if absf(delta_pos.x) > absf(delta_pos.y):
		facing_dir = 2 if delta_pos.x > 0.0 else 1
	else:
		facing_dir = 0 if delta_pos.y > 0.0 else 3
	pass


func retreat(delta: float) -> void:
	# 天亮撤退：朝最近的地图边缘跑
	if cell.x <= 0 or cell.y <= 0 or cell.x >= GameWorld.W - 1 or cell.y >= GameWorld.H - 1:
		queue_free()
		return
	if path_i >= path.size():
		var edge := nearest_edge_cell()
		var p := world.find_path(cell, edge, true)
		if p.is_empty():
			queue_free()
			return
		path = p
		path_i = 0
	step(delta)


func nearest_edge_cell() -> Vector2i:
	var dl := cell.x
	var dr := GameWorld.W - 1 - cell.x
	var du := cell.y
	var dd := GameWorld.H - 1 - cell.y
	var m := mini(mini(dl, dr), mini(du, dd))
	if m == dl:
		return Vector2i(0, cell.y)
	if m == dr:
		return Vector2i(GameWorld.W - 1, cell.y)
	if m == du:
		return Vector2i(cell.x, 0)
	return Vector2i(cell.x, GameWorld.H - 1)


func take_damage(amount: float, _from = null) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		die()


func die() -> void:
	dead = true
	game.add_resource("food", 2)
	game.log_line("一头野兽被击杀（+2 食物）", Color(0.7, 1.0, 0.7))
	queue_free()
	pass


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	var bob := sin(_wobble) * 1.5
	if enemy_kind >= 0:
		draw_generated_enemy(bob)
	else:
		var frame := 1 if int(_wobble * 2.0) % 2 == 0 else 0
		var region := Rect2(Vector2(frame * 32, 0), SPRITE_SIZE)
		draw_texture_rect_region(MONSTER_SHEET, Rect2(-16, -17 + bob, 32, 32), region)
	draw_arc(Vector2(0, bob - 1), 13.0 * sprite_scale, 0, TAU, 20, Color("7e2020"), 1.5)
	# 血条
	if hp < max_hp:
		draw_rect(Rect2(-14, -22, 28, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -22, 28 * (hp / max_hp), 4), Color(0.9, 0.3, 0.3))
	if _font:
		draw_string(_font, Vector2(-20, -26), "#%d" % bid, HORIZONTAL_ALIGNMENT_CENTER, 40, 11,
			Color(1, 0.8, 0.8, 0.8))
	pass


func draw_generated_enemy(bob: float) -> void:
	var sheets := get_generated_enemy_sheets()
	var sheet_index := clampi(enemy_kind / 4, 0, sheets.size() - 1)
	var local_index := posmod(enemy_kind, 4)
	var texture: Texture2D = sheets[sheet_index]
	var cell_size := Vector2(texture.get_width() / 16.0, texture.get_height() / 4.0)
	var action_col := 0
	if attack_flash > 0.0:
		action_col = 3
	elif moving:
		action_col = 1 + posmod(int(_wobble * 4.0), 2)
	var source_col := local_index * 4 + action_col
	var source := Rect2(Vector2(source_col, facing_dir) * cell_size, cell_size)
	var draw_size := Vector2(36, 36) * sprite_scale
	draw_texture_rect_region(texture, Rect2(-draw_size.x * 0.5, -draw_size.y * 0.62 + bob, draw_size.x, draw_size.y), source)
	pass


static func get_generated_enemy_sheets() -> Array[Texture2D]:
	if not generated_enemy_sheets.is_empty():
		return generated_enemy_sheets
	generated_enemy_sheets = GameResourceGroups.textures_matching(
		GameResourceGroups.MONSTER_SHEETS,
		["generated/enemy_directional_*.png"]
	)
	if generated_enemy_sheets.is_empty():
		for texture: Texture2D in GENERATED_ENEMY_SHEETS:
			generated_enemy_sheets.append(texture)
	return generated_enemy_sheets
