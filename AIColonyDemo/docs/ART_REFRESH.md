# Art Refresh Notes

本轮更新把地图实体统一到新的殖民地贴图图集：

- 项目资源：`res://image/tiles/colony/colony_assets_v1.png`
- 用途：树、石头、铁矿、墙、门、火把、篝火、农田、床、收纳箱、工作台、医疗舱、研究台、炮塔、电力设备、方舟核心。
- 接入位置：`res://script/core/world.gd`
- 蓝图预览：地图上的蓝图会绘制对应建筑的半透明预览，不再只显示文字框。

最终使用的生成提示词：

```text
Use case: stylized-concept
Asset type: transparent 2D game sprite atlas for a Godot colony simulation
Primary request: create a cohesive 4 by 4 grid sprite atlas on a fully transparent background. Each sprite must be isolated with transparent padding; no dark square tile backgrounds, no labels, no text, no watermark.
Subject: 16 readable top-down three-quarter game sprites in reading order: forest tree cluster, stone boulder, iron ore boulder with orange veins, wooden wall segment, wooden door, torch lamp, campfire, farm plot with seedlings, bed, storage crate, wooden workbench, medical bay pod, research bench with blue glow, turret, generator/battery power unit, ark jump core crystal.
Style/medium: hand-painted 2D game sprites, crisp silhouette, readable at 32x32, consistent scale, subtle painted shadows included under each object with soft alpha.
Composition/framing: exactly 4 columns by 4 rows, objects centered in their cells with even transparent margin, orthographic top-down three-quarter angle.
Color palette: natural greens, slate gray, warm wood, restrained sci-fi cyan and violet highlights.
Constraints: fully transparent background between and around sprites, no grid lines, no dark panels, no text, no numbers, no UI, no characters, no watermark.
```

UI 同步改动：

- 底部左侧新增“策略按钮”，直接发送具体策略命令。
- AI 成功解析并下发过的玩家指令会沉淀到“AI 已用指令”快捷按钮。
- 科技树改为右侧节点式路径：种田 -> 钓鱼/放牧 -> 食物链 -> 物流 -> 防御 -> 电力 -> 跃迁。
