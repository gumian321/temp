# Run Build Pew! → Godot 蜈蚣迁移

来源：gumian321/temp，codex/run-build-pew-unity-core-20261012，5045ffca4134d1a29052477a9d328477c4c07993。
独立云端目录 /workspace/centipede-godot；独立本地分支 codex/centipede-godot-20261012。没有远端写入。

## 验收约束

逐项复刻实际恢复源码，唯一玩法变更为可装炮蜈蚣：头部运动，身体沿头部历史路径按弧长采样。保留自由二维建造，安装在不同身体节的模块随所属节运动；不能用固定武器槽代替自由建造。不进行 blue-ink 美术改版，不新增替代敌人。Unity 只读来源，和驾校工程无关。

## 源工程已知限制（不是迁移完成项）

README.txt 明确为逆向恢复实验工程。未恢复作者原始注释、Editor 工具和未打包资产。SteamTester、SteamAppIDSetter 是空兼容组件，Editor 中关闭 Steam；两个 Cartoon FX shader 是近似实现；独立 Windows Unity 构建未验证。Validation.json 记录的是源 Unity 16 秒运行，不可作为 Godot 验收证据。

## 当前实证

- 云端终端运行成功，scratch/environment-check.txt 写入并读回。
- 指定远端分支 ls-remote、fetch 和 archive 成功。
- Godot 4.6.3.stable.official.7d41c59c4 可执行。
- 工作区 .agents 为空；源提交没有 AGENTS.md 或 .agents/skills。
- 全量源资产和组件引用由 tools/import_unity.py 提取，错误将显式列入 source_manifest.json。

所有功能状态只能在实际实现和验证后更新。数据导入不代表功能已移植。
