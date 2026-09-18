class_name TerrainSurface
extends Sprite2D
## 连续地表材质独立于格子逻辑；只在生成地图时更新生境权重。

var atlas: Texture2D = GameResourceGroups.texture_from_known_group("res://image/tiles/terrain/terrain_atlas_v1.png")
const TERRAIN_SHADER: Shader = preload("res://shader/terrain.gdshader")

func rebuild(tiles: PackedInt32Array, width: int, height: int, tile_size: int) -> void:
	var mask := Image.create(width, height, false, Image.FORMAT_RGB8)
	for y in height:
		for x in width:
			var kind := tiles[y * width + x]
			var rock := 1.0 if kind in [GameWorld.T.CAVE_WALL, GameWorld.T.CAVE_FLOOR] else 0.0
			var forest := 1.0 if kind == GameWorld.T.TREE else 0.0
			var soil := 0.5 if kind in [GameWorld.T.STONE, GameWorld.T.IRON] else 0.0
			mask.set_pixel(x, y, Color(rock, forest, soil))
	texture = ImageTexture.create_from_image(mask)
	centered = false
	scale = Vector2(tile_size, tile_size)
	z_index = -10
	var surface_material := ShaderMaterial.new()
	surface_material.shader = TERRAIN_SHADER
	surface_material.set_shader_parameter("terrain_atlas", atlas)
	surface_material.set_shader_parameter("biome_map", texture)
	surface_material.set_shader_parameter("world_size", float(width * tile_size))
	material = surface_material
	pass
