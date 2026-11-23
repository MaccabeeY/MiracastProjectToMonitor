# MiracastProjectToMonitor

Automated **Miracast / Wireless Display** launcher and clean teardown utility for Windows 10 and Windows 11.

## What It Solves
1. **Eliminates Network Folder Lag:** Automatically enables the primary `Microsoft Wi-Fi Direct Virtual Adapter` (`VWIFIMP_WFD`) only while projecting, and disables it immediately on disconnect or failure so Windows Explorer stops stalling on networked (`SMB`) folders.
2. **Preserves Custom Display Resolutions:** Disconnects the Miracast session directly via Windows Configuration Manager (`cfgmgr32.dll` / `CM_Disable_DevNode`) rather than forcing `DisplaySwitch.exe /internal`, keeping custom screen resolutions intact across reconnects.
3. **Zero-Keystroke UI Automation:** Opens the Windows Connect panel, locates your target receiver via UI Automation, switches to your preferred display mode (`extend`, `clone`, `internal`, or `external`), and spawns an always-on-top status popup with a one-click **`X`** disconnect.

## Included Files

| File | Purpose |
| :--- | :--- |
| `MiracastProjectToMonitor.bat` | Main launcher (configure your receiver name here) |
| `MiracastProjectToMonitor.ps1` | Adapter toggle, UI Automation connect, and display mode setup |
| `MiracastProjectToMonitorWaitToClose.ps1` | Always-on-top status popup and clean disconnect teardown |
| `MiracastHelper.ps1` | Win32 `DisplayConfig` and `cfgmgr32.dll` P/Invoke helpers |
| `MiracastProjectToMonitor.lnk` | Sample desktop shortcut |
| `README.txt` / `README.md` | Documentation |

## Quick Setup
1. Extract the `MiracastProjectToMonitor` folder anywhere on your PC (e.g., `Desktop\MiracastProjectToMonitor`).
2. Open `MiracastProjectToMonitor.bat` in Notepad.
3. Replace `"DUMMY_TARGET"` with your Miracast receiver's exact name from the Windows Connect (`Win + K`) panel.
4. Save and run `MiracastProjectToMonitor.bat` (or the shortcut).

## Optional Parameters
```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiracastProjectToMonitor.ps1" -Target "LivingRoomTV" -Mode extend -NoFlyout
```
* **`-Target "ReceiverName"`** — Exact name of your Miracast TV, monitor, or PC.
* **`-Mode`** — `extend` | `clone` | `internal` | `external` (default: `extend`).
* **`-NoFlyout`** — Suppresses opening the Windows Project (`Win + P`) flyout after connecting.

> **Note:** Toggling the Wi-Fi Direct Virtual Adapter requires Administrator privileges. On standard UAC systems, the script automatically prompts for elevation.
