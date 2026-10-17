@echo off
setlocal EnableExtensions

set "PWSH="
where.exe pwsh.exe >nul 2>nul
if not errorlevel 1 set "PWSH=pwsh.exe"
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH if exist "%LOCALAPPDATA%\Programs\PowerShell\7\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Programs\PowerShell\7\pwsh.exe"

if not defined PWSH (
  echo PowerShell 7.4 or later is required.
  echo Install it with: winget install --id Microsoft.PowerShell --exact
  echo Then double-click start-local.cmd again.
  set "RESULT=1"
  goto finish
)

"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\local.ps1" %*
set "RESULT=%ERRORLEVEL%"

:finish
if not "%RESULT%"=="0" (
  echo.
  pause
)
exit /b %RESULT%
