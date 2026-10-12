Run Build Pew! — Godot 蜈蚣迁移工程

当前状态：可运行离线迁移版本，完整逐项等价尚未验收，尚未进行blue-ink改版。
发布快照基于本地检查点0ec582cb13fe80ac12f96a4c3ec5466b9dd162e9。
Unity源：gumian321/temp，codex/run-build-pew-unity-core-20261012，提交5045ffca4134d1a29052477a9d328477c4c07993。
本分支根目录仅包含独立Godot工程；不修改其他分支的Unity或驾校工程。

运行与重建
1. 安装Godot 4.6.3标准版；本工程使用GDScript，无需.NET或Unity。
2. 在本目录执行 godot --headless --editor --path . --import
3. 执行 godot --path .，或编辑器打开project.godot后运行。
必要代码、生成数据、贴图、音频、预览视频与导入设置均已包含；无需重新提取Unity资源。
操作：WASD移动，鼠标瞄准/左键开火，Shift推进，E进入/退出建造，Esc暂停。
存档写入Godot user://，与原Unity存档独立。

导出
先安装与Godot 4.6.3匹配的官方导出模板，并创建artifacts/windows目录。
Linux：godot --headless --path . --export-release Linux artifacts/centipede.x86_64
Windows：godot --headless --path . --export-release "Windows Desktop" artifacts/windows/RunBuildPewCentipede.exe
Windows预设已经提供，但本云端缺模板，未生成EXE或验证原生Windows运行。
仅导出资源：godot --headless --path . --export-pack Linux artifacts/game.pck
也可使用同版本Godot执行 godot --main-pack artifacts/game.pck；不要把PCK单独当成可执行文件。
导出的EXE/可执行文件、PCK及平台必要依赖应一起分发。本仓库不包含大型预编译运行包。

测试
安装Python 3并将godot加入PATH，执行 python3 tools/run_checks.py。
该命令运行20套独立headless测试，将摘要和日志写入忽略的artifacts/，并隔离测试存档。
GUI输入/性能测试需要X11等额外环境；tools中的历史云端性能、打包与输入脚本可能含该环境默认路径，不是打开/重建游戏的必要步骤。
docs/test-evidence包含已完成的测试JSON快照；这些是历史证据，不表示在读者机器上重新通过。

范围与限制
完整源类对照：docs/source_feature_matrix.csv；功能表：docs/FEATURE_PARITY.md。
验收状态：docs/acceptance.json；剩余工作：docs/REMAINING_WORK.md。
当前已验证Linux实际导出运行、20套件、真实输入与读档、六任务长流程等。
未签收：Unity/Godot逐帧视觉等价、在线Steam/Analytics、实体手柄、独显性能、Windows原生运行。
最终llvmpipe软件渲染约20.53FPS，不代表60FPS或独显性能。
角色头部带路、身体沿路径跟随是明确变更；保留自由建造，当前身体密集聚拢/重叠仍可见。

来源与权利
资源来自用户提供的UnityCore恢复工程，不因本次发布而变更原作者/第三方权利。
保留docs/UNITY_SOURCE_README.txt及docs/UnityThirdPartyNotices；Godot许可见distribution/GODOT_LICENSE.txt。
没有给原游戏资产添加新的开源许可。重新提取Unity数据时设置RBPEW_UNITYCORE指向自备UnityCore；可选Python依赖见tools/requirements.txt。
Library/Steam历史403仍未绕过；源码Git发布是用户单独授权的交付动作，不代表Library文件已上传。
