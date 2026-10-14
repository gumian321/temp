@echo off
chcp 65001 >nul
setlocal
set "GODOT_EXE="
if exist "D:\godot\Godot_v4.6.3-stable_win64.exe" set "GODOT_EXE=D:\godot\Godot_v4.6.3-stable_win64.exe"
if defined GODOT_EXE goto import_assets
where godot >nul 2>nul
if not errorlevel 1 set "GODOT_EXE=godot"
if defined GODOT_EXE goto import_assets
echo 未找到 Godot。请用 Godot 4.6.3 打开本目录的 project.godot，然后按 F5 运行。
pause
exit /b 1

:import_assets
rem A git pull includes PNG sources, but never the local .godot import cache.
rem Wait for all new/changed textures to import before starting the game.
echo 正在检查并导入游戏资源，请稍候……
"%GODOT_EXE%" --headless --path "%~dp0." --import
if errorlevel 1 (
  echo 资源导入失败。请用 Godot 打开 project.godot 查看错误；游戏尚未启动。
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0."
exit /b 0
