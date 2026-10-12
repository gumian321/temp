Run Build Pew! Unity 核心恢复工程

打开运行
1. 将仓库克隆到本地，在 Unity Hub 中添加 UnityCore 目录。
2. 使用 Unity 2021.3.1f1c1（本次验证版本）。
3. 打开 Assets/Scenes/IntroScene.unity，点击 Play。
4. 进入主菜单，选择任务并开始游戏；加载完成后点击继续。
5. Windows 默认安装路径也可使用 OpenInUnity.cmd。

内容
Assets：游戏 C# 源码、运行插件、3 个场景、286 个 Prefab，以及运行需要的贴图、音频、视频和数据。
Packages：模块声明和 URP 官方 Shader 源码。
ProjectSettings：Unity 工程设置。
复制时保留了全部 .meta 文件，以维护场景与资源引用。
工程从 IntroScene 开始 Play；实验存档保存在本目录的 LocalData 中。

验证和限制
原游戏由 Unity 2020.3.30f1 构建，本工程已适配本机 Unity 2021.3.1f1c1。
已验证脚本编译、三个场景（均无缺失脚本）、启动到菜单与关卡、全新存档和键盘移动。
最后一次实际关卡运行 16 秒，捕获的运行异常为 0。
UnityEngine.UI、TextMeshPro、Input System 使用官方源码重新编译为 Editor 兼容 DLL。
Unity Editor 中关闭 Steam。SteamTester 与 SteamAppIDSetter 是注明来源的空兼容组件。
两个 Cartoon FX Shader 为近似实现；原始特效的溶解、扭曲、光照可能不同。
这是逆向恢复实验工程，并非作者原始工程；原始注释、Editor 工具和未打包资产未完整恢复。
当前 DLL 面向 Unity Editor，独立 Windows 构建需要另行适配与验证。

排除内容
Library、Temp、Logs、UserSettings、LocalData、构建产物、反编译工具、实验验证脚本和日志未提交。
可选第三方参考源码未提交；实际运行所需的 DLL 已保留在 Assets/Plugins 中。
第三方许可证和来源信息在 ThirdPartyNotices 中；URP Shader 包内也保留许可证。
