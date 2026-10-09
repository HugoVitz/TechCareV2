@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar.ps1" %*
rem Se deu erro, segura a tela para dar tempo de ler. Se deu certo, fecha sozinha.
if errorlevel 1 pause
