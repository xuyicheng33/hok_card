@echo off
chcp 65001 >nul
echo ====================================
echo 王者荣耀卡牌游戏 - 双人对战测试 v2
echo ====================================
echo.
echo ⚠️  使用前请确保：
echo    1. 已在Godot编辑器中打开项目
echo    2. 确认代码编译无错误
echo    3. 用F5测试过至少一次
echo.
pause
echo.
echo 正在启动第一个游戏窗口（左侧 - 房主）...
start "" "D:\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "f:\QQ\Downloads\hok_card" --resolution 1280x720 --position 0,50

timeout /t 3 /nobreak >nul

echo 正在启动第二个游戏窗口（右侧 - 客户端）...
start "" "D:\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "f:\QQ\Downloads\hok_card" --resolution 1280x720 --position 1300,50

echo.
echo ====================================
echo ✓ 两个游戏窗口已启动！
echo.
echo 🌐 在线对战测试步骤：
echo 1. 【左侧窗口】点击"在线对战"
echo 2. 【左侧窗口】点击"创建房间"，记住房间号
echo 3. 【右侧窗口】点击"在线对战"
echo 4. 【右侧窗口】点击"加入房间"，输入房间号
echo 5. 【左侧窗口】点击"开始游戏"
echo.
echo 🔧 服务器地址：ws://121.199.78.133:3000
echo 🛡️ 最大连接数：2
echo ====================================
pause
