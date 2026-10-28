@echo off
chcp 65001 >nul
title LifeFit - Запуск приложения и сервера
echo ========================================================
echo         LifeFit — Мой контроль здоровья
echo           Запуск локального бэкенд сервера...
echo ========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Попытка запуска через браузер напрямую...
    start "" "%~dp0index.html"
)
pause
