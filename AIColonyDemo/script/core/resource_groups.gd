class_name GameResourceGroups
extends RefCounted

## Central access to godot-resource-groups resources.
## Rebuild groups in Godot with Project > Tools > Rebuild project resource groups.

const ALL_AUDIO: ResourceGroup = preload("res://config/resource_groups/all_audio.tres")
const AUDIO_AMBIENCE: ResourceGroup = preload("res://config/resource_groups/audio_ambience.tres")
const AUDIO_BGM: ResourceGroup = preload("res://config/resource_groups/audio_bgm.tres")
const AUDIO_JINGLES: ResourceGroup = preload("res://config/resource_groups/audio_jingles.tres")
const AUDIO_SFX: ResourceGroup = preload("res://config/resource_groups/audio_sfx.tres")
const CHARACTERS_BASE: ResourceGroup = preload("res://config/resource_groups/characters_base.tres")
const CHARACTERS_REFERENCE: ResourceGroup = preload("res://config/resource_groups/characters_reference.tres")
const COLONIST_SHEETS: ResourceGroup = preload("res://config/resource_groups/colonist_sheets.tres")
const CREATURE_SHEETS: ResourceGroup = preload("res://config/resource_groups/creature_sheets.tres")
const MONSTER_SHEETS: ResourceGroup = preload("res://config/resource_groups/monster_sheets.tres")
const TILE_ATLASES: ResourceGroup = preload("res://config/resource_groups/tile_atlases.tres")
const TILES_AUTOTILES: ResourceGroup = preload("res://config/resource_groups/tiles_autotiles.tres")
const TILES_COLONY_AUTOTILE: ResourceGroup = preload("res://config/resource_groups/tiles_colony_autotile.tres")
const TILES_COLONY_DIRECTIONAL: ResourceGroup = preload("res://config/resource_groups/tiles_colony_directional.tres")
const TILES_COLONY_OBJECTS: ResourceGroup = preload("res://config/resource_groups/tiles_colony_objects.tres")
const TILES_COLONY_TOWERS: ResourceGroup = preload("res://config/resource_groups/tiles_colony_towers.tres")
const TILES_GENERATED_DRAFTS: ResourceGroup = preload("res://config/resource_groups/tiles_generated_drafts.tres")
const TILES_LEGACY: ResourceGroup = preload("res://config/resource_groups/tiles_legacy.tres")
const TILES_RPGMAKER: ResourceGroup = preload("res://config/resource_groups/tiles_rpgmaker.tres")
const TILES_TERRAIN: ResourceGroup = preload("res://config/resource_groups/tiles_terrain.tres")
const UI_FACES: ResourceGroup = preload("res://config/resource_groups/ui_faces.tres")
const UI_SYSTEM: ResourceGroup = preload("res://config/resource_groups/ui_system.tres")


static func paths(group: ResourceGroup) -> Array[String]:
	return group.paths.duplicate()


static func textures(group: ResourceGroup) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	group.load_all_into(result)
	return result


static func textures_matching(group: ResourceGroup, includes: Array[String], excludes: Array[String] = []) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	group.load_matching_into(result, includes, excludes)
	return result


static func first_path_containing(group: ResourceGroup, text: String) -> String:
	for path: String in group.paths:
		if path.contains(text):
			return path
	return ""


static func texture_by_name(group: ResourceGroup, file_stem: String) -> Texture2D:
	var path := first_path_containing(group, file_stem + ".")
	if path == "":
		return null
	return load(path) as Texture2D


static func texture_by_source_path(group: ResourceGroup, source_path: String) -> Texture2D:
	var file_name := source_path.get_file()
	var file_stem := file_name.get_basename()
	var texture := texture_by_name(group, file_stem)
	if texture != null:
		return texture
	if ResourceLoader.exists(source_path):
		return load(source_path) as Texture2D
	return null
