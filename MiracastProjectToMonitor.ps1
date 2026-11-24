# =============================================================
# 0. Accept arguments
# =============================================================
# 
# Be sure to replace "DUMMY_TARGET" either here as the default or pass in with ==> pass -Target "ReceiverName" <== in batch file
param(
    [string]$Target = "DUMMY_TARGET",
    [ValidateSet("extend", "clone", "internal", "external")]
    [string]$Mode = "extend",
    [switch]$NoFlyout
)


# =============================================================
# 1. Auto-elevate if not running as Administrator (for UAC machines)
# =============================================================
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) {
            if ($kv.Value.IsPresent) { $argList += "-$($kv.Key)" }
        } else {
            $argList += @("-$($kv.Key)", "`"$($kv.Value)`"")
        }
    }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}


# =============================================================
# 2. Declare Types
# =============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName UIAutomationClient


# =============================================================
# 3. Protect against "running over itself"
# =============================================================
if (Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*MiracastProjectToMonitor.ps1*" }) {
    Write-Host "Projection is already connected.  Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# =============================================================
# 4. Includes
# =============================================================
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptDir\MiracastHelper.ps1"
Import-Module "$ScriptDir\SystemHelper.psm1" -Force


# =============================================================
# 5. Initializations
# =============================================================
function Exit-WithCleanup([string]$Message) {
    Set-ParentWindowFocus $true
    Start-Sleep -Milliseconds 500
    [MiracastTarget]::SetWifiDirectEnabled($false) | Out-Null
    Write-Host ""
    Write-Host $Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Miracast Wi-Fi adapter now disabled." -ForegroundColor Yellow
    Write-Host ""
    [console]::beep(400, 800)
    Write-Host "  Press any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

[MiracastTarget]::CaptureBaseline()
[MiracastTarget]::SetWifiDirectEnabled($true) | Out-Null
Start-Sleep -Milliseconds 500
Write-Host "Miracast Wi-Fi adapter now active." -ForegroundColor Yellow
Write-Host ""


# =============================================================
# 6. Open CONNECT panel
# =============================================================
Write-Host "Opening the CONNECT panel." -ForegroundColor Cyan
Write-Host ""
Start-Process "ms-settings-connectabledevices:devicediscovery"
Start-Sleep -Seconds 2


# =============================================================
# 7. Execute Connection
# =============================================================
$connectWin = [System.Windows.Automation.AutomationElement]::FocusedElement
while ($null -ne $connectWin -and $connectWin.Current.Name -ne "Connect" -and $connectWin.Current.ClassName -ne "Windows.UI.Core.CoreWindow") {
    $connectWin = [System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($connectWin)
}

if ($null -eq $connectWin) {
    Exit-WithCleanup "CONNECT flyout is not open or lost focus.  Aborting."
}

$listItemCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::ListItem
)

$targetItem = $null
for ($i = 0; $i -lt 15; $i++) {
    $items = $connectWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, $listItemCond)
    foreach ($item in $items) {
        if ($item.Current.Name -like "*$Target*") {
            $targetItem = $item
            break
        }
    }
    if ($null -ne $targetItem) { break }
    Start-Sleep -Milliseconds 200
}

if ($null -eq $targetItem) {
    Exit-WithCleanup "Target '$Target' not found in CONNECT flyout list.  Aborting."
}

try {
    $targetItem.SetFocus()
} catch {
    Exit-WithCleanup "Failed CONNECT flyout focus.  Aborting."
}
Start-Sleep -Milliseconds 150

$focusedNow = [System.Windows.Automation.AutomationElement]::FocusedElement
$focusedName = if ($null -ne $focusedNow) { $focusedNow.Current.Name } else { "" }
if ($focusedName -notlike "*$Target*") {
    Exit-WithCleanup "Focus verification failed for '$Target' (focused: '$focusedName').  Aborting."
}

Write-Host "Executing the connection to '$Target'." -ForegroundColor Cyan
Write-Host ""
try {
    $invokePattern = $targetItem.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $invokePattern.Invoke()
} catch {
    Exit-WithCleanup "Failed to invoke '$Target' (flyout may have closed).  Aborting."
}


# =============================================================
# 8. Set preferred mode and give user the flyout
# =============================================================
Write-Host "Starting projection." -ForegroundColor Cyan
Write-Host ""
$Connected = $false
for ($i = 0; $i -lt 60; $i++) {
    Write-Host "Waiting for projection completion... ($($i * 250) ms)" -ForegroundColor Cyan
    if ([MiracastTarget]::IsConnected()) {
        $Connected = $true
        break
    }
    Start-Sleep -Milliseconds 250
}

if ($Connected) {
    Write-Host "Setting chosen '$Mode' mode." -ForegroundColor Cyan
    Write-Host ""
    [MiracastTarget]::SetMode($Mode) | Out-Null
    for ($j = 0; $j -lt 48; $j++) {
        if ([MiracastTarget]::IsModeActive($Mode)) {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $NoFlyout) {
        Start-Process "DisplaySwitch.exe"
    }
} else {
    Exit-WithCleanup "Timed out waiting for '$Target' to connect.  Aborting."
}


# =============================================================
# 9. Spawn hidden disconnect.ps1 popup watcher
# =============================================================
$wsh = New-Object -ComObject WScript.Shell
$wsh.Run("powershell.exe -STA -ExecutionPolicy Bypass -File `"$ScriptDir\MiracastProjectToMonitorWaitToClose.ps1`"", 0, $false) | Out-Null
