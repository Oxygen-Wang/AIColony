# Godot Resource Groups

The `godot-resource-groups` plugin is installed under:

```text
res://addons/godot_resource_groups/
```

The project resource groups live under:

```text
res://config/resource_groups/
```

## Rebuild Groups

In Godot, use:

```text
Project > Tools > Rebuild project resource groups
```

This scans the project and fills each `.tres` group's `paths` array from its `base_folder`, `includes`, and `excludes`.

## Runtime Usage

```gdscript
var colonist_paths := GameResourceGroups.paths(GameResourceGroups.COLONIST_SHEETS)
var all_tiles := GameResourceGroups.textures(GameResourceGroups.TILE_ATLASES)
var engineer := GameResourceGroups.texture_by_name(
	GameResourceGroups.COLONIST_SHEETS,
	"npc_01_engineer_4x4"
)
```

Use this when a system needs to discover a family of assets. Keep direct `preload()` for critical always-used assets where startup validation matters.

## Current Groups

- `all_images.tres`: all project image assets.
- `all_audio.tres`: all project audio assets.
- `colonist_sheets.tres`: colonist sprites.
- `monster_sheets.tres`: monster sprites.
- `tile_atlases.tres`: tile and object atlases.
