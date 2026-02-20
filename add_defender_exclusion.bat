@echo off
setlocal

rem Run this script as administrator (self-elevate if needed)
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "TARGET=%LOCALAPPDATA%\clock_app"
echo Adding Defender exclusion path: "%TARGET%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-MpPreference -ExclusionPath '%TARGET%'"

if %errorlevel% equ 0 (
  echo Done.
) else (
  echo Failed. Check administrator rights and Defender policy.
)

pause
endlocal
