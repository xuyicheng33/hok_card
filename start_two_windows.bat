@echo off
echo 正在启动两个游戏窗口...
start "" "builds\windows\hok_card.exe"
timeout /t 1 /nobreak >nul
start "" "builds\windows\hok_card.exe"
echo 完成！两个窗口已启动。
