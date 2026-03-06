!macro NSIS_HOOK_PREINSTALL
  ; Force per-user install location to %LOCALAPPDATA%\clock_app
  StrCpy $INSTDIR "$LOCALAPPDATA\clock_app"
!macroend

!macro NSIS_HOOK_POSTINSTALL
  ; Ensure Windows "Apps & features" uses uninstaller binary directly.
  ; This avoids relying on re-launching setup installer for uninstall.
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\clock_app" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\clock_app" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\clock_app" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
!macroend
