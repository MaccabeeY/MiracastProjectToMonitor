================================================================================
MiracastProjectToMonitor - Automated Miracast Display Projector (Windows 10/11)
================================================================================

WHAT THIS DOES
--------------
1. Automatically enables the primary Microsoft Wi-Fi Direct Virtual Adapter
   only while projecting (and disables it immediately on disconnect or failure
   so Windows Explorer never stalls when browsing networked folders).
2. Opens the Windows Connect panel, lets you pick your receiver with a single
   keypress (1-9, A-Z, R to rescan, 0 to cancel - no Enter needed) or
   auto-connects to a -Target receiver, and switches to your chosen display
   mode (Extend, Clone, Internal, or External) while preserving your custom
   display resolution across disconnects.
3. Displays a clean, always-on-top status popup ("Projection Active: close to
   disconnect.") with an X button that cleanly tears down the Miracast session
   and turns off the Wi-Fi Direct Virtual Adapter.
4. Returns automatically to the receiver menu if a connection times out, is
   cancelled, or loses focus - and immediately disables the Wi-Fi Direct
   adapter if projection drops mid-session while updating the status popup.


INCLUDED FILES
--------------
- MiracastProjectToMonitor.bat              Main launcher (run for menu or pass options)
- MiracastProjectToMonitor.ps1              Connection, receiver menu & display-mode automation
- MiracastProjectToMonitorWaitToClose.ps1   Popup status window, disconnect monitor & teardown
- MiracastHelper.cs                         Windows display configuration & adapter helpers
- SystemHelper.psm1                         Console window focus & visibility helpers
- MiracastProjectToMonitor.lnk              Sample shortcut (customize path if moved)
- README.txt / README.md                    Documentation


QUICK SETUP
-----------
1. Extract the "MiracastProjectToMonitor" folder anywhere on your PC
   (for example: Desktop\MiracastProjectToMonitor).
2. Double-click "MiracastProjectToMonitor.bat" (or use the desktop shortcut) to
   open the single-key receiver menu.
3. Optional: To skip the menu and auto-connect every time, right-click
   "MiracastProjectToMonitor.bat" -> Edit (open in Notepad) and add
   -Target "YourReceiverName" to the last line, then save and close Notepad.


OPTIONAL PARAMETERS (IN THE .BAT FILE)
--------------------------------------
-Target "ReceiverName"   Optional name (or partial match) of your Miracast TV,
                         monitor, or wireless display. Opens the receiver menu
                         automatically if omitted, not found, or if connection
                         fails.
-Mode extend             Display mode: extend | clone | internal | external
                         (default: extend)
-NoFlyout                Do not open the Windows Project (Win + P) flyout after
                         connecting

Example:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiracastProjectToMonitor.ps1" -Target "LivingRoomTV" -Mode extend -NoFlyout


USING THE SHORTCUT (.LNK)
-------------------------
- The included shortcut assumes the folder lives at:
  %USERPROFILE%\Desktop\MiracastProjectToMonitor\MiracastProjectToMonitor.bat
- If you move the folder elsewhere, right-click "MiracastProjectToMonitor.bat" ->
  Send to -> Desktop (create shortcut), or update the shortcut's Target path.
- Note: Administrator privileges are required to toggle the Wi-Fi Direct
  Virtual Adapter; if UAC is enabled, the script will prompt automatically.
================================================================================
