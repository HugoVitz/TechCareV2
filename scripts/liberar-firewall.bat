@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0liberar-firewall.ps1" %*
pause
