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

## Grouping Rule

Split groups by gameplay purpose first, folder second. Avoid broad catch-all groups such as `all_images.tres` unless a tool truly needs to scan every image.

```text
Resource Groups
├─ Characters
│  ├─ Base player sheets
│  ├─ Generated colonist sheets
│  ├─ Reference VX/RPG sheets
│  ├─ Creature sheets
│  └─ Monster and boss sheets
├─ UI
│  ├─ Faces and portraits
│  └─ System windows/icons
├─ Tiles
│  ├─ Terrain
│  ├─ Legacy and RPGMaker source atlases
│  ├─ Colony objects
│  ├─ Colony directional doors/walls
│  ├─ Colony autotile walls/doors
│  ├─ Colony towers
│  └─ Generated draft atlases
└─ Audio
   ├─ BGM
   ├─ SFX
   ├─ Ambience
   └─ Jingles
```

## Current Groups

- `all_audio.tres`: all project audio assets.
- `audio_ambience.tres`: ambient loops.
- `audio_bgm.tres`: background music.
- `audio_jingles.tres`: win/lose stingers.
- `audio_sfx.tres`: one-shot sound effects.
- `characters_base.tres`: base character sheets.
- `characters_reference.tres`: reference VX/RPG sheets.
- `colonist_sheets.tres`: colonist sprites.
- `creature_sheets.tres`: simple creature sprites.
- `monster_sheets.tres`: monster sprites.
- `tile_atlases.tres`: tile and object atlases.
- `tiles_autotiles.tres`: overworld autotiles.
- `tiles_colony_autotile.tres`: colony autotile walls/doors.
- `tiles_colony_directional.tres`: directional colony walls/doors.
- `tiles_colony_objects.tres`: colony object atlases.
- `tiles_colony_towers.tres`: tower atlases.
- `tiles_generated_drafts.tres`: generated draft atlases.
- `tiles_legacy.tres`: legacy tile atlases.
- `tiles_rpgmaker.tres`: RPGMaker source atlases.
- `tiles_terrain.tres`: terrain atlases.
- `ui_faces.tres`: portraits and face graphics.
- `ui_system.tres`: windows, panels, icons, and system UI.
