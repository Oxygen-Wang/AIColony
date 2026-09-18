# AIColony 优化需求对接文档（给其他 AI 看）

> 目标：玩法闭环完整（采集→制造→建造→战斗→跃迁全链路可通关），一次改 7 件事，按下面顺序和验收标准做。

## 0. 代码现状（先读这些）
- `AIColonyDemo/script/core/world.gd`：T 枚举 84 项（0~83；78=WOOD_TOWER、79=STONE_TOWER、80=NUKE_TOWER、81~83=ARROW_BENCH/AMMO_FACTORY/AMMO_DEPOT）；`SOLID_P`/`SOLID_B` 必须与枚举等长（`_SOLID_LEN=84`），改枚举必须同步改数组。
- `AIColonyDemo/script/core/action_table.gd`：`VALID_BUILDS`、`BUILD_ORDER`（70+ 种）、`COSTS`、`CRAFT_TECH`、`VALID_ITEMS`（17 项工具武器）、`cn()` 中文名查询（不要直读 `CN`，资源名走 `RES_NAMES`）。
- `AIColonyDemo/script/core/main.gd`：`TECH_ORDER` 12 节点（woodcraft→stone_age→farming→fishing→husbandry→food_chain→logistics→iron_age→defense→steam→electric→nuclear；`NO_BENCH_TECH` 木/石免研究台），`can_build()` 时代门（含 arrow_bench/ammo_depot=woodcraft、ammo_factory=defense、wood_tower/stone_tower/turret/laser_turret/nuke_tower 按时代）、`can_craft()` 制造门、`tick_turrets()` 耗 `tower_ammo` 并经 `fire_projectile()` 发射可见飞行弹丸、`tower_combat_stats()` 五档（木箭塔5格/6伤、石弩塔7/10、铁炮塔8/16、激光塔10/24、等离子塔12/36）、`auto_equip_weapon()` 按等级自动发最低者。
- `AIColonyDemo/script/entities/colonist.gd`：工具背包 `pick_lv/axe_lv/sword_lv/shield_lv/bow_lv/arrows`，镐子锁矿（`mine_need`：石=木镐1、铁/铜=石镐2、铀=铁镐3），`task_research` 木/石免台。
- `AIColonyDemo/script/core/rule_parser.gd`、`ai_manager.gd`：离线规则解析 + DeepSeek；prompt 里已写采集门槛规则。
- 自测：`Godot_v4.7.2-stable_mono_win64_console.exe --headless --path AIColonyDemo -- --offline --selftest`

## 1. 碰撞：只有墙 + 地面资源挡路【已落地】
- 挡路（SOLID_P/B 均为 true）：树/石/铁/铜/铀矿、洞穴岩壁、墙、五种塔、车库/太阳能板、工作台系/发电机/电池/雷达/反应堆/水泵/电气核能台/弹药厂/弹药仓/箭矢台等大机器。
- 不挡路（均为 false）：门、床、箱柜（收纳箱/木石铁铜铅箱）、货架、水箱、家具桌椅梯、灯、线管水管、电箱、电网杆、火把/篝火/农田、手推车。
- 对兽仍挡（P=false、B=true）：各种门（木/石/铁/电动/防辐射）、三种栅栏（挡兽不挡人）。
- 验收：小人穿家具不卡住；野兽仍被门/墙/栅栏挡住；数组长度保持 84（`_SOLID_LEN=84`，`_ready()` 有 assert）。
- 寻路配合：`pick_beast()`（colonist.gd:782）选怪时先过 `find_path`，走不到的怪直接跳过——自测阶段3实测 5 杀 0 死、无“过不去”刷屏。

## 2. 子弹系统（炮塔 + 殖民者远程，两者都要）【已落地】
- [x] 炮塔弹药：turret / laser_turret / wood_tower / stone_tower / nuke_tower 开火经 `tick_turrets()` 消耗 `tower_ammo`，无弹药停火；伤害经 `fire_projectile()` 发射可见飞行弹丸。
- [x] 弹药生产线 + 补给逻辑：`supply_job()` / `run_supply()` 已在（main.gd:52~136）：工人去 ARROW_BENCH / AMMO_FACTORY 花 3 秒 + 1 木材/铁矿/铜矿生产 6 发 → 存 `depot_stock`（arrow/shell/energy 三种，`ammo_type()` 按塔型映射：木石塔吃箭、铁炮塔吃炮弹、激光/等离子塔吃能量弹）→ 搬运装填 `tower_ammo`（满 8 发停补）/ 弓手（arrows<3 补箭）；单补给员防抢活 + 饥饿/疲劳门槛已在。
- [x] 殖民者远程：有弓有箭时远程（射程 5+bow_lv 格，经 `fire_projectile()` 发箭，伤害 9+bow_lv*4），无箭/贴脸回退近战（剑 12/15/20、斧、拳按 `sword_lv/axe_lv` 切伤害；colonist.gd:486~509）。
- [x] 补给优先级已定并落地：塔（缺弹 <8 发）> 弓手（arrows<3）> 生产补库（库存 <24 发；能量弹需 electric 科技）；种类三种 arrow/shell/energy，材料木/铁/铜一一对应。

## 3. 可建造：按时代分批解锁（不求多，求每时代有新东西）【数据层已落地，贴图待做】
- 时代线：木器 → 石器 → 铁器 → 火力 → 蒸汽 → 电气 → 核能跃迁；种田/钓鱼/放牧/食物链/物流为侧支。
- 每时代 3~6 个新建筑即可，旧时代自然淘汰；`can_build()` 门 + `BUILD_ORDER` 顺序 + `DESC` 悬停说明同步加。
- 配合子弹系统优先补：弹药厂/箭矢台/弹药仓【数据层已落地：`can_build` 时代门 + COSTS + DESC + 中文名已在；建筑贴图已落地：`colony_objects_latest.png`（8×7 格，54 物体，顺序与 `OBJECT_ATLAS_ORDER` 一致）+ 5 张炮台 8 向图集（4×2，东/东南/南/西南/西/西北/北/东北），地图/虚影/建造栏图标共用】。

## 4. AI 智能：派活更聪明（第一优先级）【半落地：分活已在，多施工者待做】
- [x] 按技能/距离/状态分活：`dispatch()`（main.gd:1001）按动作选 skill（采集=gather、建造=build、研究=research、其余=logistics），经 `worker_score()`（main.gd:1047：技能分 − 队列长度 − 疲劳/饥饿 − 距基地距离）排序派活；饥饿≥75 / 疲劳≥80 / 血量≤35% 的人不派远活；`supply_job()` 带饥饿/疲劳门槛 + 单补给员防抢活。
- [ ] 不抢活：蓝图认领检查只在 `available_plan()` 里有（main.gd:31），`dispatch()` 的 build 分支仍把全体 targets 逐个塞同一工地队列，可扎堆。
- [ ] `can_assign_auto_build()`（main.gd:1543）仍只派 1 名施工者，可放宽到按工地数量派；缺料先采料再施工未做。
- 验收（selftest 口径）：阶段1 无“需要XX镐”刷屏（应先造镐）、阶段2 无人扎堆同一工地、阶段3 战斗减员下降。

## 5. 自动建造：AI 推荐布局，玩家确认后再盖【半落地：防线预览已在，种类/排序待扩】
- [x] `propose_defense()` / `confirm_defense()` / `cancel_defense()` 已在（main.gd:139~177）：基地外圈 ±5 格城墙 + 南北门 + 内侧四角 wood_tower，`layout_preview` 预览 + 确认框（确认建造/取消）→ 确认后转蓝图。
- [ ] 只做了“防线”一种布局：农田区、炮塔火力覆盖等预设未做；施工顺序仍自然认领、无 AI 排序。

## 6. UI：先解决建造栏太长【已落地，剩折叠】
- [x] 建造栏时代分组 + 搜索已在：`build_blueprint_bar()`（main.gd:1344）有 `build_era` 时代下拉（全部/基础/木器/石器/铁器/火力/蒸汽/电气/核能）+ `build_search` 搜索框，经 `filter_buildings()`（main.gd:1414）按 `building_era()`（main.gd:1396）+ 中文名/英文名过滤；`refresh_blueprint_bar()` 未解锁科技置灰。
- [ ] 待做：分组折叠（现为下拉过滤，按钮仍平铺在一行横滚）；状态面板、操作手感、新手引导排后面。

## 7. 做事顺序建议
1. [x] ~~碰撞数组整理~~ → 2. [x] ~~弹药数据+建筑 / 炮塔飞行弹丸 / 补给链 / 殖民者弓箭 / 补给优先级~~ → 3. [x] ~~建造栏时代分组+搜索~~（剩折叠）→ 4. [x] ~~蓝图拖拽闭环 + 拆除系统~~ → 5. [x] ~~床位独占+躺下不动~~ → 6. [ ] 派活防扎堆 + 多施工者 + 缺料先采料 → 7. [ ] 更多布局预设 + 施工排序 → 8. [ ] 全链路自测通关。

## 8. 蓝图闭环 + 拆除系统【已落地】
- [x] Shift+左键框选修复：`begin_drag()` 按模式分流（SELECT/DEMOLISH 不再复用建筑虚影，只画黄框/橙框包围框）；删掉“松开 Ctrl 就 cancel_drag”的旧逻辑，框选不再被吞；`finish_drag()` 左右键错配给提示不再静默丢单。
- [x] 拆除闭环：`Drag.DEMOLISH` + `demolish_mode`（X 键进/出，右键/Esc 退出）→ 左键点/拖框 `mark_demolish_rect()` 只收已有建筑（空地/蓝图/自然资源跳过）→ `demolish_marks` + `demolish_undo` 栈 → 殖民者 `task_demolish()` 走到相邻格读条 2 秒、无材料消耗、`destroy_struct()` 恢复草地/下层地板 → 世界层红 X 常驻显示（`demolish_mark_cells` + `sync_demolish_draw()`，claim/完工/撤销都同步）。
- [x] 认领防扎堆：`claim_demolish()` 饥饿<75/疲劳<80、跳过已被别人盯上的格、最近 + `find_path` 可达才派；`dispatch("demolish")` 无标记直接提示先用 X 标记，派活走 build 技能分。
- [x] 指令通道：`ActionTable.DEFS` 新增 `demolish` + 中文回复；`rule_parser` 拆/推倒/铲除关键词 → demolish；`ai_manager` prompt 加 4b 条（只拆已标记、绝不替玩家选位置、无标记回 reply 提醒）。
- 操作：X 进拆除模式 → 左键点/拖框标记 → 空闲殖民者自动来拆（也可聊天框说“拆墙”）；Ctrl+Z 撤销上次标记。
- 验收：自测 4 杀 1 残、无 SCRIPT ERROR；拆除标记→认领→读条→草地恢复全链路代码已通（手测 X 框选 + Ctrl+Z 待玩家确认）。

## 9. 床位：无碰撞 + 一人一床 + 躺下不动【已落地】
- [x] 床无碰撞：`SOLID_P[8]`=false（床可站人），人不被床卡住；`SOLID_B[8]`=false，野兽也不被床挡（挡兽靠门/墙/栅栏）。
- [x] 一人一床：`find_bed()`（colonist.gd）只找无认领的床——已被别人当 `bed_goal` 目标或已躺上（`at_post` + 同格）的床直接跳过；最近 + `find_path` 可达才选，无空床返回 (-1,-1) 就地睡。
- [x] 找到床就躺下不动：`task_sleep()` 到达 `bed_goal` 格后置 `at_post`，之后只回疲劳不再走动；床被拆则重找；新指令/挨打/野兽近身仍可打断（`interrupt_sleep`/`wake_up` 不变）。
- 验收：自测无 SCRIPT ERROR；多人同时睡觉不再叠在同一张床上（手测多床多人群睡待玩家确认）。
