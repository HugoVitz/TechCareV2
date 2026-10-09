@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0preparar-mobile.ps1" %*
pause
