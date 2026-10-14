Run Build Pew! — Godot 蜈蚣迁移工程

最新：加特林来弹辨识与特斯拉电弧（2026-10-13）
敌人本来就会使用加特林；本次区分我方金色弹和敌方玫红来弹，亮弹头与短拖尾明确表示方向。
特斯拉增加深蓝轮廓、加粗青色电弧、命中电光和更清晰的短暂余辉。伤害、射速、射程不变。
说明：docs/WEAPON_READABILITY_20261013.txt；继续直接使用本分支Godot工程，不含新导出EXE。

最新：断节反馈与装配交互更新（2026-10-13）
新增每节受击闪光与裂纹、体节损毁提示、甲壳碎片散开、武器翻落及节制的破坏音效。
装配页改为深蓝/米白卡片式身体轨道：拖入间隙插入，拖到卡片中央交换，落点预览与落下反馈清晰；长身体可边缘滚动。
选中元素不再整体重建界面；Esc/右键取消、无效拖放不丢失元素，保留滚动和焦点。
这版复用现有美术素材，没有新调用生图服务；提供 Godot 源码工程，不含重新导出的 Windows EXE。
请使用 Godot 4.6.3 打开 project.godot，首次等待导入后按 F5。建议先解压到新目录试用，避免覆盖自己的改动。
本次更新基于 codex/godot-centipede-game-20261012 的 8a69be59c706e34212cfc118cbd77039bab3de8e。
详细说明：docs/EQUIPMENT_UI_20261013.txt 与 docs/SEGMENT_FEEDBACK_20261013.txt。

最新：单节单元素更新（2026-10-13）
开局只有头部、身体默认 0 节。每次选择新元素奖励获得一个待装元素，拖到头后、两节之间或尾部即可新增一节；属性升级直接生效。
每节只有一个元素和独立血量。整节可自由拖动排序；某节被打爆后，后面的体节自动向前补位。身体最多 60 节。
装配页改为横向身体条与插入位置，显示每节血量；长身体支持滚动。炮塔放大并保留柔软底座摆动与等比显示。
地图加入固定世界坐标的砂点和碎石纹，移动、缩放时有清晰参照。开机直接进菜单，去掉商业 Logo 轮播和引擎开屏图。
运行：关闭旧游戏后，双击“启动蜈蚣中文版.cmd”。本次修改工程，未重新导出独立 EXE。
说明：docs/CHAIN_UPDATE.txt；当前回归与实际渲染报告：docs/test-evidence/chain-*。

此前更新记录（玩法描述以最新单节单元素规则为准）

转弯与视觉装备界面更新（2026-10-13）
头部转向连续缓动，每节保留自己的世界位置并逐节跟随；体节姿态与连接方向分开，急转时身体不会被统一甩动。
60 FPS 连续急转中，6 节与 60 节身体的最大单帧位移分别约 2.57 与 2.86 像素；30/60/120 FPS 路径一致。
装备页改为图标库存、整条身体选择、放大的九格和实际挂载预览。有效空位高亮，拖动图标等比居中，悬停落点预览实际装上去的位置。
名称和属性放到悬停提示；选中已有模块才显示复制/加固图标。芯片、维修邻接和护盾覆盖直接在格位上标出。
截图：artifacts/visual-assembly-drag.png；实机连续转弯动图：artifacts/centipede-fluid-motion.webp。
说明：docs/VISUAL_ASSEMBLY.txt；本轮最终验证：docs/test-evidence/visual-steering-final-validation.json。

全武器主题素材更新（2026-10-13）
15 种武器/装置与攻击无人机、孢雷实体共 17 张透明图片已重新生成并接入，统一蓝墨甲壳与更明显的彩色树脂。
覆盖头部、身上、敌方、装配和奖励引用；两种布雷装置外形分别区分。原图等比显示，九格混装不拉伸。
完整图集：artifacts/armament-v2-lineup.png；说明与提示词索引：docs/ARMAMENT_ART.txt。

全武器打击反馈更新（2026-10-13）
12 类枪械、地雷与攻击无人机已分别增强枪口、弹道、命中、爆炸、后坐与音效。
重武器带短促命中顿挫，移动仍实时响应；彩色火力与蓝墨世界并存，旧版遮挡画面的重复爆闪已去除。
详细说明见 docs/WEAPON_FEEDBACK.txt；实际渲染预览位于 artifacts/weapon-feedback-preview.webp。

生体武装与虫群更新（2026-10-13）
12 类射击武器与孢雷装置已换成全新生体甲壳素材，装配、奖励和战斗共用；敌人已换为 6 类蓝墨虫怪。
虫怪腹部使用贴图网格 + 15 根弹性骨骼，受击局部压缩回弹；六足使用独立刚性腿节和关节迈步，飞蛾翅片绕翅根扇动，触须单独轻摆，死亡腹部塌软、足部收折。辅助模块保留已有资源。
资源、可编辑骨骼场景与逐张生成提示词位于 assets/blue_ink/brood/；详细说明见 docs/BROOD_THEME.txt。
虫怪动作已加大，受击增加第一帧压扁、短暂停顿、后仰回弹、暖色闪击、蓝色体液与湿润拍击声。
增强动作和软腹受击预览位于 artifacts/brood-impact-v2.webp，湿声样本位于 artifacts/brood-wet-hit.wav。

本地蓝墨中文版更新（2026-10-13）
双击“启动蜈蚣中文版.cmd”，或在 Godot 中打开本目录的 project.godot 后按 F5 运行。
整套游戏以 blue-ink 为基调：米白纸面、蓝墨蜈蚣与敌人、中文界面和墨线爆炸；炮塔、技能及相关图标保留颜色，方便辨认。
主角使用生成的蓝墨甲壳素材；每节按 54×54 显示，嘴巴分成两片独立颚片，可开合。
开局只有头部；触角和步足独立运动，开火时颚片加快咬合。
获得元素后按 E 进入“身体装配”：每节一个武器或辅助元素。
战斗掉落或废料兑换的奖励包，提供一次三选一机会。装配页点击“领奖”：模块进入待装列表，属性升级与操作次数直接生效。
从左侧把元素拖到身体之间的 + 号，或拖到尾部新增一节。也支持点选元素后点击插入位置。
炮塔放大，按原图宽高比等比缩放；底座随身体运动柔软摆动。
整节身体可以直接拖动排序，不消耗操作次数；加固仍使用奖励次数，无效投放不丢失元素。
芯片、维修和隐形作用于相邻体节；护盾按真实世界距离覆盖。体节总上限仍为60，按 E 返回战斗。
默认简体中文，旧英文默认存档会一次切换为简体中文，研究、任务和按键进度保留。
Unity 对照源位于 E:\_Nlv\-a\run_build_pew_unity_core\UnityCore；该目录仅用于核对，未修改。
WASD 移动已参考 chonglai 的蛇调整：快速起停、头部带领弧线转弯、身体逐节传递摆动，静止时尾部轻摆；炮塔瞄准独立，体节间距保持58。开火有枪口墨线与后坐，爆炸按大小使用原音效。
移动实现与验证见 docs/CENTIPEDE_MOTION.txt；实际游戏输入预览位于 artifacts/centipede-fluid-motion.webp。
爆炸素材的红通道已作为透明遮罩读取，烟雾保留序列帧，不再显示原来的黑色贴图方块。
本轮实现和验收说明见 docs/BLUE_INK_UPDATE.txt；生成素材与提示词保存在 assets/blue_ink/。
下方是此前迁移检查点的背景与交付说明，历史测试数字不代表本轮测试结果。

历史检查点状态：可运行离线迁移版本，完整逐项等价尚未验收。当时尚未进行 blue-ink 改版；以上方本地更新为准。
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
该命令运行35套独立headless测试，将摘要和日志写入忽略的artifacts/，并隔离测试存档。
Windows 可加 --godot "D:\godot\Godot_v4.6.3-stable_win64.exe"；实际渲染检查追加 blue_ink blue_ink_scene --render。
GUI输入/性能测试需要X11等额外环境；tools中的历史云端性能、打包与输入脚本可能含该环境默认路径，不是打开/重建游戏的必要步骤。
docs/test-evidence包含已完成的测试JSON快照；这些是历史证据，不表示在读者机器上重新通过。

范围与限制
完整源类对照：docs/source_feature_matrix.csv；功能表：docs/FEATURE_PARITY.md。
验收状态：docs/acceptance.json；剩余工作：docs/REMAINING_WORK.md。
当前已验证Linux实际导出运行、20套件、真实输入与读档、六任务长流程等。
未签收：Unity/Godot逐帧视觉等价、在线Steam/Analytics、实体手柄、独显性能、Windows原生运行。
最终llvmpipe软件渲染约20.53FPS，不代表60FPS或独显性能。
角色头部带路、身体沿路径跟随是明确变更；当前改为逐节装塔，每个模块拥有独立体节位置。

来源与权利
资源来自用户提供的UnityCore恢复工程，不因本次发布而变更原作者/第三方权利。
保留docs/UNITY_SOURCE_README.txt及docs/UnityThirdPartyNotices；Godot许可见distribution/GODOT_LICENSE.txt。
没有给原游戏资产添加新的开源许可。重新提取Unity数据时设置RBPEW_UNITYCORE指向自备UnityCore；可选Python依赖见tools/requirements.txt。
Library/Steam历史403仍未绕过；源码Git发布是用户单独授权的交付动作，不代表Library文件已上传。
