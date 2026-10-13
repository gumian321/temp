# Run Build Pew! → Godot 蜈蚣迁移

来源：gumian321/temp，codex/run-build-pew-unity-core-20261012，5045ffca4134d1a29052477a9d328477c4c07993。
独立云端目录 /workspace/centipede-godot；独立本地分支 codex/centipede-godot-20261012。没有远端写入。

## 验收约束

2026-10-13 用户最新要求优先：游戏以 blue-ink 美术为基调，先提供简体中文，主角为可逐节生长的蜈蚣。默认只有头部、身体 0 节；每个新元素奖励只提供一个待装元素，拖到头后、身体之间或尾部新增一节。用户已明确属性升级直接生效、不新增体节。每节一个元素、独立血量，整节可自由拖拽排序；中间节被打爆后移除该节，后面的节自动补位。实际游戏使用 chain_centipede.gd 与横向整节装配界面；旧九格与二维接口保留为历史对照。炮塔放大、等比显示，底座柔软摆动，实际枪口同步显示位置；炮塔和技能保留彩色。地图加入固定世界坐标的砂点与碎石纹，移动和缩放提供参照。开机直接进入主菜单，不再播放商业 Logo 和手柄提示轮播，也关闭引擎开屏图。头部引导转弯、身体跟随与独立摆动保留，关节间距58、总上限60节。Unity 和 chonglai 均为只读参考来源，和驾校工程无关。详情见 CHAIN_UPDATE.txt。

此前“不进行 blue-ink 美术改版”和“保留自由二维建造”的约束已被这次明确要求更新；历史功能表仍用于记录迁移差距，不代表本轮验收结果。

后续外观修正：零体节也必须保留屁股/尾部，接在最后一个存活部件之后，不占元素数量。装配条必须按完整蜈蚣的方向排列：头部在左并向左看，体节、炮口和尾部统一朝左并在同一轴线上。

后续交互修正：放好最后一个元素后禁止自动关闭装配窗口或跳到下一包奖励，战斗保持暂停，留出调整顺序的时间。玩家通过“完成调整”、E 或 Esc 手动关闭；未领取的奖励保留。

## 源工程已知限制（不是迁移完成项）

README.txt 明确为逆向恢复实验工程。未恢复作者原始注释、Editor 工具和未打包资产。SteamTester、SteamAppIDSetter 是空兼容组件，Editor 中关闭 Steam；两个 Cartoon FX shader 是近似实现；独立 Windows Unity 构建未验证。Validation.json 记录的是源 Unity 16 秒运行，不可作为 Godot 验收证据。

## 当前实证

- 云端终端运行成功，scratch/environment-check.txt 写入并读回。
- 指定远端分支 ls-remote、fetch 和 archive 成功。
- Godot 4.6.3.stable.official.7d41c59c4 可执行。
- 工作区 .agents 为空；源提交没有 AGENTS.md 或 .agents/skills。
- 全量源资产和组件引用由 tools/import_unity.py 提取，错误将显式列入 source_manifest.json。

所有功能状态只能在实际实现和验证后更新。数据导入不代表功能已移植。
