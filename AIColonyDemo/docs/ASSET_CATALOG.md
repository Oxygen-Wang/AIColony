> 本文为早期设计或素材记录。当前接线、目录和功能范围见 [INTEGRATION_REPORT.md](INTEGRATION_REPORT.md)。

# 素材目录压缩说明

这份文档记录工作区里适合继续用于 `AIColonyDemo` 的素材。素材文件本身保留，不删除；项目运行时优先使用复制到 `AIColonyDemo/assets/` 内的副本。

## 当前已接入

- `AIColonyDemo/assets/sprites/characters/People1.png`
  - 来源：`RPGMaker_VXAce_Sprites/Characters/People1.png`
  - 用途：殖民者行走精灵。
  - 读取方式：每帧 32x32 像素，当前使用角色槽位的朝下站立帧。

- `AIColonyDemo/assets/sprites/creatures/Monster1.png`
  - 来源：`RPGMaker_VXAce_Sprites/Characters/Monster1.png`
  - 用途：夜袭敌人精灵。
  - 读取方式：每帧 32x32 像素，带轻微摆动动画。

## RPGMaker_VXAce_Sprites 可用素材

推荐保留的目录：

- `Characters/`：最适合当前俯视角角色、敌人、门、箱子、火焰、机关。
- `Tilesets/`：适合做基地、地面、水边、森林、矿区、室内区域。
- `System/IconSet.png`：适合做资源、物品、工具和 UI 图标。
- `Audio/SE/`：适合采集、建造、受击、确认、取消等短音效。
- `Audio/BGS/`：适合风、雨、水流、火焰等环境声。
- `Parallaxes/`：适合标题背景或事件背景，不建议直接塞进主地图。
- `Animations/`：适合战斗命中特效、火焰、雷击、治疗等反馈。

当前项目最值得下一步接入：

- `Tilesets/Outside_A*.png`：森林、草地、水、山体等外部地图。
- `Tilesets/World_*.png`：世界地图感更强，适合大地图或小地图。
- `System/IconSet.png`：资源栏和建造菜单图标。
- `Audio/SE/Attack*.ogg`、`Damage*.ogg`、`Decision*.ogg`、`Equip*.ogg`：基础操作音效。

## overworld_autotiles_v1-0 可用素材

这个包是 CC0 授权的 Godot 友好自动图块素材，适合优先接入。

保留文件：

- `overworld_autotiles.png`：主图块表。
- `overworld_autotiles.aseprite`：源文件，方便以后调整颜色和格子。
- `overworld_autotiles_godot4.zip`：Godot 4 示例工程，可参考 TileSet 配置。
- `README.txt`：授权说明。

适合本项目的用途：

- 草地、泥地、水边、道路、悬崖或边缘过渡。
- 比 RPG Maker 自动图块更容易直接配置到 Godot 4。
- 适合把当前程序绘制的地面替换为 TileMapLayer。

## TerrariaClone-main 可用素材

推荐仅保留 `textures/` 中的小型像素素材作为参考，不直接混入当前美术风格，除非统一缩放和调色。

可参考内容：

- `textures/sprites/player/`：横版玩家动作，不适合直接用于俯视角殖民者。
- `textures/sprites/monsters/`：横版敌人动作，可作为敌人类型参考。
- `textures/unused/`：小物件参考。

使用建议：

- 适合做“功能占位图”，不适合作为最终主风格。
- 若使用，需要统一像素尺寸、朝向和阴影规则。

## game 与 Terraria 源码目录的素材态度

- `game` 里可能有运行文件、反编译源码、语言文件和二进制资源，不作为当前项目素材库。
- `Terraria-Source-Code-master` 与 `tModLoader-1.4.5` 主要当机制参考，不把源码或受版权限制的内容复制进项目。

## 接入规范

新增素材建议放置：

```text
AIColonyDemo/assets/
  sprites/
    characters/
    creatures/
    props/
  tilesets/
    overworld/
    rpgmaker/
  audio/
    se/
    bgm/
    bgs/
```

命名建议：

- 使用英文小写与下划线，例如 `colonist_people1.png`、`beast_monster1.png`、`outside_grass_water.png`。
- 源素材不改名，复制进项目资产目录后再按项目用途命名。
- 每次复制素材，都在本文件补一行来源和用途。

导入建议：

- 像素图统一最近邻过滤。
- 精灵表记录单帧尺寸。
- TileSet 记录 tile 尺寸、自动图块规则和碰撞规则。
- 音效记录使用场景，避免后期找不到声音来源。
