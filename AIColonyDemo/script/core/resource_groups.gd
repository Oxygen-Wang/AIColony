class_name GameResourceGroups
extends RefCounted

## Central access to godot-resource-groups resources.
## Rebuild groups in Godot with Project > Tools > Rebuild project resource groups.

const ALL_AUDIO: ResourceGroup = preload("res://config/resource_groups/all_audio.tres")
const ALL_IMAGES: ResourceGroup = preload("res://config/resource_groups/all_images.tres")
const COLONIST_SHEETS: ResourceGroup = preload("res://config/resource_groups/colonist_sheets.tres")
const MONSTER_SHEETS: ResourceGroup = preload("res://config/resource_groups/monster_sheets.tres")
const TILE_ATLASES: ResourceGroup = preload("res://config/resource_groups/tile_atlases.tres")


static func paths(group: ResourceGroup) -> Array[String]:
	return group.paths.duplicate()


static func textures(group: ResourceGroup) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	group.load_all_into(result)
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
