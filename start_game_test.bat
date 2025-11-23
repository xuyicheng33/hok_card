@echo off
chcp 65001 >nul
echo ====================================
echo 王者荣耀卡牌游戏 - 双人对战测试
echo ====================================
echo.
echo 正在启动第一个游戏窗口（左侧）...
start "" "D:\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "f:\QQ\Downloads\hok_card" --resolution 1280x720 --position 0,50

timeout /t 2 /nobreak >nul

echo 正在启动第二个游戏窗口（右侧）...
start "" "D:\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "f:\QQ\Downloads\hok_card" --resolution 1280x720 --position 1300,50

echo.
echo ====================================
echo ✓ 两个游戏窗口已启动！
echo.
echo 测试步骤：
echo 1. 窗口1: 创建房间，记住房间ID
echo 2. 窗口2: 加入房间，输入房间ID
echo ====================================
pause
