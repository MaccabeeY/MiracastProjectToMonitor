@echo off
REM ============================================================================
REM  Miracast Auto-Connect Launcher
REM
REM  Run with no arguments to open the interactive receiver picker menu, or
REM  pass optional arguments (via shortcut or by adding them to the line below):
REM    -Target "ReceiverName"   Auto-connect to a specific TV/PC/monitor name
REM    -Mode extend             extend | clone | internal | external (default: extend)
REM    -NoFlyout                Skip opening the Windows Project (Win+P) flyout
REM
REM  Example (hardcoded auto-connect):
REM    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiracastProjectToMonitor.ps1" -Target "LivingRoomTV" -Mode extend -NoFlyout
REM ============================================================================


powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiracastProjectToMonitor.ps1" %*
