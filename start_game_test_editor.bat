@echo off
chcp 65001 >nul
echo ====================================
echo 王者荣耀卡牌游戏 - 双人对战测试
echo （使用Godot编辑器运行）
echo ====================================
echo.
echo ⚠️  注意：
echo    这种方式可能无法同时打开两个窗口
echo    建议使用"项目→导出"导出exe后测试
echo.
pause
echo.
echo 正在启动游戏（编辑器模式）...
start "" "D:\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "f:\QQ\Downloads\hok_card"

echo.
echo ====================================
echo 测试说明：
echo 1. 在编辑器中按F5启动第一个窗口
echo 2. 再次点击"播放"按钮启动第二个窗口
echo 或者：
echo 1. 先导出为exe
echo 2. 直接运行两个exe实例
echo ====================================
pause
