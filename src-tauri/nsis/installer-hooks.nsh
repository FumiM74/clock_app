!macro NSIS_HOOK_PREINSTALL
  ; Force per-user install location to %LOCALAPPDATA%\clock_app
  StrCpy $INSTDIR "$LOCALAPPDATA\clock_app"
!macroend

!macro NSIS_HOOK_PREUNINSTALL
  ; Ensure uninstaller resolves the same install directory
  StrCpy $INSTDIR "$LOCALAPPDATA\clock_app"
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  ; Safe cleanup: remove known leftovers only.
  ; Avoid recursive force-delete here because uninstall internals may still be active.
  Delete "$LOCALAPPDATA\clock_app\clock_app_setup*.exe"
  Delete "$LOCALAPPDATA\clock_app\setup_clock_app.bat"
  Delete "$LOCALAPPDATA\clock_app\settings.json"
  RMDir /REBOOTOK "$LOCALAPPDATA\clock_app"
!macroend
