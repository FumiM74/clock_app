!macro NSIS_HOOK_PREINSTALL
  ; Force per-user install location to %LOCALAPPDATA%\clock_app
  StrCpy $INSTDIR "$LOCALAPPDATA\clock_app"
!macroend

!macro NSIS_HOOK_PREUNINSTALL
  ; Ensure uninstaller resolves the same install directory
  StrCpy $INSTDIR "$LOCALAPPDATA\clock_app"
!macroend
