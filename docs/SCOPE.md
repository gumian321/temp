# Run Build Pew! → Godot 蜈蚣迁移

来源：gumian321/temp，codex/run-build-pew-unity-core-20261012，5045ffca4134d1a29052477a9d328477c4c07993。
独立云端目录 /workspace/centipede-godot；独立本地分支 codex/centipede-godot-20261012。没有远端写入。

## 验收约束

2026-10-13 用户最新要求优先：游戏以 blue-ink 美术为基调，先提供简体中文，主角为可逐节装塔的蜈蚣。炮塔、技能及相关图标保留彩色；炮塔按原始宽高比显示。体节接近正方形，嘴部拆成独立动画颚片。用户已选择每节 3×3 九格自由安装武器或辅助模块；装配界面放大九宫格，战斗中紧凑排列，身体不因安装变宽。支持拖入、跨节移动、交换、复制和拖到尾部自动增节；保留点击放置。旧二维接口和原逐轴加速留作源码对照测试，实际游戏使用九格身体。根据用户后续反馈，实际移动改为参考 chonglai 蛇的快速起停、头部引导转弯、独立路径与身体摆动，关节间距保持58。奖励包入口说明三选一和后续安装流程。敌人、武器和任务仍使用恢复源码的数据。Unity 和 chonglai 均为只读参考来源，和驾校工程无关。

此前“不进行 blue-ink 美术改版”和“保留自由二维建造”的约束已被这次明确要求更新；历史功能表仍用于记录迁移差距，不代表本轮验收结果。

## 源工程已知限制（不是迁移完成项）

README.txt 明确为逆向恢复实验工程。未恢复作者原始注释、Editor 工具和未打包资产。SteamTester、SteamAppIDSetter 是空兼容组件，Editor 中关闭 Steam；两个 Cartoon FX shader 是近似实现；独立 Windows Unity 构建未验证。Validation.json 记录的是源 Unity 16 秒运行，不可作为 Godot 验收证据。

## 当前实证

- 云端终端运行成功，scratch/environment-check.txt 写入并读回。
- 指定远端分支 ls-remote、fetch 和 archive 成功。
- Godot 4.6.3.stable.official.7d41c59c4 可执行。
- 工作区 .agents 为空；源提交没有 AGENTS.md 或 .agents/skills。
- 全量源资产和组件引用由 tools/import_unity.py 提取，错误将显式列入 source_manifest.json。

所有功能状态只能在实际实现和验证后更新。数据导入不代表功能已移植。
