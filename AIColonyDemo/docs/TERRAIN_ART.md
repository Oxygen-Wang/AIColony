# 地表贴图升级

通过内置 image_gen 工具生成；原图保存在 `image/tiles/terrain/terrain_atlas_v1.png`，未修改生成像素。生成结果为 1254×1254，运行时按实际 UV 分成四个等大区域，不依赖请求尺寸。

左上草地、右上泥土、左下岩面、右下林地苔藓。地表使用连续世界坐标铺贴、镜像接缝和噪声混合，替代旧版逐格随机颜色。林地与洞穴的权重来自地图；不改变格子碰撞、资源数量、任务或寻路。树石与建筑精灵仍在地表上方独立绘制，并增加落地阴影。

接入文件：`script/core/terrain_surface.gd`、`shader/terrain.gdshader`、`script/core/world.gd`。

## 原始生成提示词

Use case: stylized-concept. Asset type: production terrain texture atlas for a top-down 2D colony survival game, not a screenshot or mockup. Generate one square 1024x1024 PNG containing exactly FOUR equal edge-to-edge 512x512 material swatches arranged as a strict 2x2 atlas with NO gutters, NO border, NO text. Upper left quadrant: subdued sage and olive short meadow grass, delicate individual grass blades, tiny scattered clover and a few tiny dry straw specks, fairly even density. Upper right: warm umber and muted ochre compact forest soil, fine earthy granular detail, small gravel, subtle faded foot-worn areas, no large stones. Lower left: cool slate grey bedrock, finely fractured weathered stone with hairline fissures, faint moss in cracks, low contrast. Lower right: deep olive woodland floor, velvety moss, tiny leaf litter and dry needles. All four have consistent small feature scale, each quadrant covering about 16 by 16 in-game 32px tiles. Style: beautifully crafted hand-painted pixel-compatible strategy game ground material, restrained natural earthy palette, fine organic detail, readable beneath small colorful RPG character sprites. Orthographic directly overhead, perfectly flat diffuse lighting, no directional shadows or perspective, no large objects, no trees, no buildings, no characters, no grid or checkerboard, no vignette, no dramatic lighting. Each quadrant must be a homogeneous seamless repeatable material swatch with matched opposite edges, absolutely no artificial rectangular subdivisions inside a quadrant. Full bleed atlas to image edges. Subtle variation instead of bright saturated green; professional cohesive game art.
