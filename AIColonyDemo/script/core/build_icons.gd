class_name BuildIcons
extends RefCounted
## 建造栏图标：把建筑图集里的图案裁下来缩成小图标，规划项目只显示图案、不写文字，
## 具体说明交给按钮的悬停提示。升级项目复用被强化建筑的图，另叠一个金色向上箭头。

const ICON_PX := 40
const GOLD := Color("f2c14e")
const GOLD_EDGE := Color(0.13, 0.09, 0.03)

static var _cache := {}
static var _atlas_images := {}


## 取某规划项目的图标（带缓存）
static func icon(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var base := ActionTable.upgrade_base(kind)
	var img := _base_image(base, ActionTable.is_upgrade(kind))
	img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
	if ActionTable.is_upgrade(kind):
		_stamp_upgrade_arrow(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


## 底图：地板在建成的画面里是矢量画的，图标也照着画，保证所见即所得
static func _base_image(kind: String, upgraded: bool = false) -> Image:
	var tower_dir := GameWorld.tower_directional_texture(kind)
	if tower_dir != null:
		var dir_image := tower_dir.get_image()
		if dir_image.is_compressed():
			dir_image.decompress()
		dir_image.convert(Image.FORMAT_RGBA8)
		# 8 向图集 4x2，取第 3 帧（南向正面）做图标
		var frame := Rect2i(int(dir_image.get_width() / 4) * 2, 0, int(dir_image.get_width() / 4), int(dir_image.get_height() / 2))
		return dir_image.get_region(frame)
	var special := GameWorld.special_building_texture(kind)
	if special != null:
		var special_image := special.get_image()
		if special_image.is_compressed():
			special_image.decompress()
		special_image.convert(Image.FORMAT_RGBA8)
		return special_image
	if kind == "wall":
		var wall_source := GameWorld.wall_autotile_texture(upgraded)
		var wall_image := wall_source.get_image()
		if wall_image.is_compressed():
			wall_image.decompress()
		wall_image.convert(Image.FORMAT_RGBA8)
		return wall_image.get_region(Rect2i(0, 0, wall_image.get_width() / 4, wall_image.get_height() / 4))
	var door_source := GameWorld.door_autotile_texture(kind)
	if door_source != null:
		var door_image := door_source.get_image()
		if door_image.is_compressed():
			door_image.decompress()
		door_image.convert(Image.FORMAT_RGBA8)
		return door_image.get_region(Rect2i(0, 0, door_image.get_width() / 4, door_image.get_height() / 4))
	var directional := GameWorld.directional_texture(kind, upgraded and kind == "wall")
	if directional != null:
		var source := directional.get_image()
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		return source.get_region(Rect2i(0, 0, source.get_width() / 2, source.get_height() / 2))
	var region := GameWorld.asset_region(kind)
	if region.size == Vector2.ZERO:
		return _floor_image()
	return _atlas(GameWorld.asset_texture(kind)).get_region(Rect2i(region))


static func _atlas(texture: Texture2D) -> Image:
	var key := texture.resource_path
	if not _atlas_images.has(key):
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_atlas_images[key] = image
	return _atlas_images[key] as Image


## 地板的矢量画在 world.draw_vector_tile 里，这里照着同一套尺寸重画一遍，
## 否则建造栏上只是一块空米色，看不出是什么。
static func _floor_image() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var board := Color("a89a86")
	var seam := board.darkened(0.18)
	_fill_rect(img, Rect2i(3, 3, 26, 26), board)
	_rect_outline(img, Rect2i(3, 3, 26, 26), Color("6f6557"))
	for i in 3:
		var sy := 3 + 6 * (i + 1)
		_line(img, Vector2i(3, sy), Vector2i(29, sy), seam)
		var sx := 3 + (10 if i % 2 == 0 else 18)
		_line(img, Vector2i(sx, sy - 6), Vector2i(sx, sy), seam)
	return img


static func _fill_rect(img: Image, r: Rect2i, color: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _inside(img, Vector2i(x, y)):
				img.set_pixel(x, y, color)
	pass


static func _rect_outline(img: Image, r: Rect2i, color: Color) -> void:
	_line(img, r.position, Vector2i(r.end.x - 1, r.position.y), color)
	_line(img, Vector2i(r.position.x, r.end.y - 1), Vector2i(r.end.x - 1, r.end.y - 1), color)
	_line(img, r.position, Vector2i(r.position.x, r.end.y - 1), color)
	_line(img, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.end.x - 1, r.end.y - 1), color)
	pass


## 只画水平或垂直的 1px 线，够用且不用担心斜率采样
static func _line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			if _inside(img, Vector2i(x, y)):
				img.set_pixel(x, y, color)
	pass


## 升级标识：金色向上箭头，替代「升级」两个字
static func _stamp_upgrade_arrow(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var head := int(w * 0.36)
	var top := int(h * 0.14)
	var stem := maxi(2, int(w * 0.09))
	var bottom := int(h * 0.72)

	var body: Array = []
	for row in head:
		var span := int(round(float(row) / float(head - 1) * float(head * 0.5)))
		for x in range(cx - span, cx + span + 1):
			body.append(Vector2i(x, top + row))
	for y in range(top + head - 1, bottom):
		for x in range(cx - stem, cx + stem + 1):
			body.append(Vector2i(x, y))

	# 先描一圈深色边，压在建筑图案上也能看清
	for p: Vector2i in body:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(p.x + dx, p.y + dy)
				if _inside(img, n) and not body.has(n):
					img.set_pixel(n.x, n.y, GOLD_EDGE)
	for p: Vector2i in body:
		if _inside(img, p):
			img.set_pixel(p.x, p.y, GOLD)
	pass


static func _inside(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height()
