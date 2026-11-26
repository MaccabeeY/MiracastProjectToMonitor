# MiracastProjectToMonitor

Automated **Miracast / Wireless Display** launcher and clean teardown utility for Windows 10 and Windows 11.

## What It Solves
1. **Eliminates Network Folder Lag:** Automatically enables the primary Microsoft Wi-Fi Direct Virtual Adapter only while projecting, and disables it immediately on disconnect or failure so Windows Explorer stops stalling on networked folders.
2. **Preserves Custom Display Resolutions:** Disconnects the Miracast session cleanly rather than forcing a display-switch reset, keeping custom screen resolutions intact across reconnects.
3. **Zero-Keystroke UI Automation & Receiver Menu:** Opens the Windows Connect panel, lets you select your receiver with a single keypress (`1`-`9`, `A`-`Z`, `R` to rescan, `0` to cancel - no `Enter` needed) or auto-connects to a `-Target` receiver, switches to your preferred display mode (`extend`, `clone`, `internal`, or `external`), and spawns an always-on-top status popup with a one-click **`X`** disconnect.
4. **Resilient Connection & Disconnect Handling:** Returns automatically to the receiver menu if a connection times out, is cancelled, or loses focus - and immediately disables the Wi-Fi Direct adapter if projection drops mid-session while updating the status popup.

## Included Files

| File | Purpose |
| :--- | :--- |
| `MiracastProjectToMonitor.bat` | Main launcher (run directly for the menu, or pass options) |
| `MiracastProjectToMonitor.ps1` | Adapter toggle, UI Automation connect, receiver menu, and display mode setup |
| `MiracastProjectToMonitorWaitToClose.ps1` | Always-on-top status popup, live disconnect monitor, and clean disconnect teardown |
| `MiracastHelper.cs` | Windows display configuration and adapter helpers |
| `SystemHelper.psm1` | Console window focus and window visibility helpers |
| `MiracastProjectToMonitor.lnk` | Sample desktop shortcut |
| `README.txt` / `README.md` | Documentation |

## Quick Setup
1. Extract the `MiracastProjectToMonitor` folder anywhere on your PC (e.g., `Desktop\MiracastProjectToMonitor`).
2. Run `MiracastProjectToMonitor.bat` (or the desktop shortcut) to open the receiver menu, or optionally open `MiracastProjectToMonitor.bat` in Notepad and add `-Target "YourReceiverName"` to the last line to auto-connect every time.
3. While projecting, an always-on-top **"Projection Active: close to disconnect."** popup stays on screen (minimizable anytime). Click its **`X`** button when you are ready to disconnect.

## Optional Parameters
```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiracastProjectToMonitor.ps1" -Target "LivingRoomTV" -Mode extend -NoFlyout
```
* **`-Target "ReceiverName"`** - Exact (or partial) name of your Miracast TV, monitor, or PC from the Windows Connect (`Win + K`) panel. Opens the receiver menu automatically if not found or if connection fails.
* **`-Mode`** - `extend` | `clone` | `internal` | `external` (default: `extend`).
* **`-NoFlyout`** - Suppresses opening the Windows Project (`Win + P`) flyout after connecting.

> **Note:** Toggling the Wi-Fi Direct Virtual Adapter requires Administrator privileges. On standard UAC systems, the script automatically prompts for elevation.
