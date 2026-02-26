@echo off
setlocal EnableExtensions

set "APP_DIR=%LOCALAPPDATA%\clock_app"
set "SCRIPT_DIR=%~dp0"
set "EXE_NAME=clock_app_setup.exe"
set "INSTALLER_PATH=%~1"
set "COPIED_INSTALLER="

if not defined INSTALLER_PATH (
  if exist "%SCRIPT_DIR%%EXE_NAME%" (
    set "INSTALLER_PATH=%SCRIPT_DIR%%EXE_NAME%"
    goto :found_installer
  )
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
  echo Installer not found.
  echo Expected file: %EXE_NAME%
  echo Put this bat file and the NSIS installer (.exe) in the same folder.
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

if not exist "%APP_DIR%" mkdir "%APP_DIR%"
if not exist "%APP_DIR%" (
  echo Failed to create install directory.
  pause
  exit /b 1
)

for %%I in ("%INSTALLER_PATH%") do set "COPIED_INSTALLER=%APP_DIR%\%%~nxI"

echo [1/5] Copying installer to local app folder...
copy /Y "%INSTALLER_PATH%" "%COPIED_INSTALLER%" >nul
if %errorlevel% neq 0 (
  echo Failed to copy installer to "%APP_DIR%".
  pause
  exit /b 1
)

echo [2/5] Unblocking copied installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Unblock-File -LiteralPath '%COPIED_INSTALLER%'"
if %errorlevel% neq 0 (
  echo Failed to unblock copied installer.
  pause
  exit /b 1
)

echo [3/5] Adding Defender exclusion...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=(Get-MpPreference).ExclusionPath; if ($p -notcontains '%APP_DIR%') { Add-MpPreference -ExclusionPath '%APP_DIR%' }"
if %errorlevel% neq 0 (
  echo Failed to add Defender exclusion. Check Windows Defender policy.
  pause
  exit /b 1
)

echo [4/5] Verifying Defender exclusion...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=(Get-MpPreference).ExclusionPath; if ($p -contains '%APP_DIR%') { exit 0 } else { exit 2 }"
if %errorlevel% neq 0 (
  echo Defender exclusion was not confirmed. Check Windows Defender policy.
  pause
  exit /b 1
)

echo [5/5] Launching installer from local app folder...
start "" "%COPIED_INSTALLER%"

echo Done. Continue installation in the installer window.
pause
endlocal
