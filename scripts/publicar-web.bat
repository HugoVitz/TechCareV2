@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar-web.ps1" %*
pause
