================================================================================
MiracastProjectToMonitor - Automated Miracast Display Projector (Windows 10/11)
================================================================================

WHAT THIS DOES
--------------
1. Automatically enables the primary Microsoft Wi-Fi Direct Virtual Adapter
   only while projecting (and disables it afterward so Windows Explorer never
   stalls when browsing networked folders).
2. Opens the Windows Connect panel, selects your Miracast receiver without
   fragile simulated keystrokes, and switches to your chosen display mode
   (Extend, Clone, Internal, or External) while preserving your custom display
   resolution across disconnects.
3. Displays a clean, always-on-top status popup ("Connected to ...") with an X
   button that cleanly tears down the Miracast session and turns off the
   Wi-Fi Direct Virtual Adapter.


INCLUDED FILES
--------------
- MiracastProjectToMonitor.bat              Main launcher (edit receiver name here)
- MiracastProjectToMonitor.ps1              Connection & display-mode automation
- MiracastProjectToMonitorWaitToClose.ps1   Popup status window & clean teardown
- MiracastHelper.ps1                        Win32 DisplayConfig & PnP device APIs
- MiracastProjectToMonitor.lnk              Sample shortcut (customize path if moved)
- README.txt / README.md                    Documentation


QUICK SETUP
-----------
1. Extract the "MiracastProjectToMonitor" folder anywhere on your PC
   (for example: Desktop\MiracastProjectToMonitor).
2. Right-click "MiracastProjectToMonitor.bat" -> Edit (open in Notepad).
3. Replace "DUMMY_TARGET" with the exact name of your Miracast receiver as it
   appears in the Windows Connect (Win + K) list.
4. Save and close Notepad.


OPTIONAL PARAMETERS (IN THE .BAT FILE)
--------------------------------------
-Target "ReceiverName"   Name of your Miracast TV, monitor, or wireless display
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
