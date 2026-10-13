@echo off
chcp 65001 >nul
setlocal
if exist "D:\godot\Godot_v4.6.3-stable_win64.exe" (
  start "" "D:\godot\Godot_v4.6.3-stable_win64.exe" --path "%~dp0."
  exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
  start "" godot --path "%~dp0."
  exit /b
)
echo 未找到 Godot。请用 Godot 4.6.3 打开本目录的 project.godot，然后按 F5 运行。
pause
