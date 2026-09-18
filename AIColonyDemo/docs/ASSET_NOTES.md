> 本文为早期设计或素材记录。当前接线、目录和功能范围见 [INTEGRATION_REPORT.md](INTEGRATION_REPORT.md)。

# 素材说明

项目使用 `assets/sprites/characters/People1.png` 和 `assets/sprites/creatures/Monster1.png` 作为角色与敌人精灵表。它们从工作区已有素材库复制而来，原始库未改动。

实体脚本按每帧 32×32 像素读取精灵表；项目已设为最近邻过滤，保持像素画清晰。替换素材时请保持该尺寸，或同步更新实体脚本顶部的精灵常量。

更完整的素材来源与后续接入建议见 `ASSET_CATALOG.md`。
