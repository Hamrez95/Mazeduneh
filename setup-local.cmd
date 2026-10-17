@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-local.ps1"
if errorlevel 1 (
  pause
  exit /b 1
)
call "%~dp0start-local.cmd" %*
