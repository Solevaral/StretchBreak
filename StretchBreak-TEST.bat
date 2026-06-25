@echo off
REM Единичный тест: заглушка сразу на 10 секунд (берёт путь от своего расположения)
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0StretchBreak.ps1" -TestNow
