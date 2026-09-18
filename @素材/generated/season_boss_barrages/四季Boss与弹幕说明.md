# 四季 Boss 与弹幕素材说明

更新时间：2026-09-18

目录：

`D:\1\123\@素材\generated\season_boss_barrages`

## Boss 图集

Boss 图集为 `4 列 x 4 行`。

行顺序：

1. 下
2. 左
3. 右
4. 上

列顺序：

1. 待机
2. 移动 1
3. 移动 2
4. 攻击

| 文件 | Boss | 说明 |
|---|---|---|
| `boss_spring_directional_4x4.png` | 春季 Boss：花角母兽 | 鹿形植物巨兽，藤蔓、花瓣、花粉攻击 |
| `boss_summer_directional_4x4.png` | 夏季 Boss：熔背巨兽 | 熔岩火蜥巨兽，吐息、陨火、熔岩爆炸 |
| `boss_autumn_directional_4x4.png` | 秋季 Boss：丰收空壳王 | 南瓜稻草树王，镰刀、叶刃、恐惧灯 |
| `boss_winter_directional_4x4.png` | 冬季 Boss：霜冠巨兽 | 冰熊狼巨兽，冰刺、暴风雪、霜冻冲击 |

## 弹幕图集

弹幕图集为 `4 行 x 4 列`。

每行 1 个技能。

列顺序：

1. 预警范围
2. 飞行弹体 / 主体运动
3. 命中爆发
4. 溅射 / 残留 / 持续范围

### 春季 Boss 弹幕

文件：`boss_spring_barrage_vfx_4skills_4x4.png`

1. 根刺连环：直线/链式地刺，溅射伤害。
2. 花粉环爆：圆形花粉扩散，可做治疗敌方或减速玩家。
3. 藤蔓缠绕弹：追踪藤球，命中后束缚小范围目标。
4. 召唤春芽：落点预警，召唤小怪或生成持续生长区域。

### 夏季 Boss 弹幕

文件：`boss_summer_barrage_vfx_4skills_4x4.png`

1. 熔火吐息：扇形喷火，持续灼烧。
2. 陨火雨：多落点预警，落地溅射。
3. 火环冲锋：环形火轨迹，经过路径持续伤害。
4. 熔岩炸弹：慢速大火球，命中后分裂小火星。

### 秋季 Boss 弹幕

文件：`boss_autumn_barrage_vfx_4skills_4x4.png`

1. 叶刃旋风：旋转叶刃，穿透或持续伤害。
2. 南瓜恐惧灯：圆形恐惧范围，可做混乱/减速。
3. 稻草人分身：召唤分身，死亡时爆叶溅射。
4. 收割镰波：半月形弹幕，多段溅射。

### 冬季 Boss 弹幕

文件：`boss_winter_barrage_vfx_4skills_4x4.png`

1. 冰刺牢笼：圆形冰刺围困，爆发后有残留减速。
2. 暴风雪锥波：锥形寒风，持续减速和伤害。
3. 冰晶散射：多方向冰晶弹，命中小范围溅射。
4. 霜冻践踏：圆形冲击波，击退并留下寒冷区域。

## 生成提示词核心模板

Boss 图集：

```text
Use case: stylized-concept
Asset type: Godot 2D seasonal boss directional animation atlas
Primary request: create a transparent pixel-art boss atlas for <season> boss, with down/left/right/up views and attack frames
Composition/framing: exact grid concept 4 columns x 4 rows. Rows from top to bottom are down, left, right, up. Columns are idle, walk1, walk2, attack. Center one full-body boss per cell. No labels.
Constraints: transparent background, no text, no watermark, no terrain, no UI, boss visibly large, attack frame must face same row direction
```

弹幕图集：

```text
Use case: stylized-concept
Asset type: Godot 2D boss bullet-hell skill VFX atlas
Primary request: create a transparent pixel-art VFX atlas for <season> boss, 4 different dynamic barrage skills
Composition/framing: 4 rows x 4 columns. One skill per row. Columns are warning telegraph, projectile/core motion, impact, splash/aftereffect. No text labels.
Constraints: transparent background, no text, no watermark, no terrain, no UI frame, strong motion trails, clear damage radius, visually distinct skills, include splash damage rings
```

## 后续处理备注

- 当前为 AI 原始草案，透明边缘和个别高亮残留需要正式接入前检查。
- 建议正式切图时统一 Boss 单格尺寸、脚底基准和碰撞半径。
- 弹幕图建议先作为 VFX 源图集保存，接入时按技能拆成预警、飞行、命中、残留四段。

