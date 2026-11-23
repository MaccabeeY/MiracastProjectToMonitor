@echo off
REM ============================================================================
REM  Miracast Auto-Connect Launcher
REM
REM  Optional arguments you can add after ProjectToMonitorConnect.ps1:
REM    -Target "ReceiverName"   Name of your TV/PC/monitor in the Connect panel
REM    -Mode extend             extend | clone | internal | external (default: extend)
REM    -NoFlyout                Skip opening the Windows Project (Win+P) flyout
REM
REM  Example:
REM    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ProjectToMonitorConnect.ps1" -Target "LivingRoomTV" -Mode extend -NoFlyout
REM ============================================================================


powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiracastProjectToMonitor.ps1" %*
