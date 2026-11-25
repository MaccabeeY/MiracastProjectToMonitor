# =============================================================
# 0. Accept arguments
# =============================================================
# 
# Be sure to replace "DUMMY_TARGET" either here as the default or pass in with ==> pass -Target "ReceiverName" <== in batch file
param(
    [string]$Target = "",
    [ValidateSet("extend", "clone", "internal", "external")]
    [string]$Mode = "extend",
    [switch]$NoFlyout
)
$Target = [WildcardPattern]::Escape($Target.Trim())


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
# 2. Type Declarations
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
if (-not ([System.Management.Automation.PSTypeName]'MiracastTarget').Type) {
    Add-Type -Path "$ScriptDir\MiracastHelper.cs"
}
Import-Module "$ScriptDir\SystemHelper.psm1" -Force


# =============================================================
# 5. Initializations/Function Declarations
# =============================================================
function Exit-WithCleanup([string]$Message) {
    Write-Host ""
    Write-Host $Message -ForegroundColor Red
    Set-ParentWindowFocus $true
    Start-Sleep -Milliseconds 500
    $wasWfdEnabled = [MiracastTarget]::IsWifiDirectEnabled()
    if ($wasWfdEnabled) {
        [MiracastTarget]::SetWifiDirectEnabled($false) | Out-Null
        Write-Host ""
        Write-Host "Miracast Wi-Fi Direct adapter now disabled." -ForegroundColor Yellow
    }
    Write-Host ""
    [console]::beep(400, 800)
    Write-Host "  Press any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

function Show-ReceiverPickerMenu([string[]]$Receivers, [string]$Notice = "") {
    Set-ParentWindowFocus $false
    Start-Sleep -Milliseconds 150
    Write-Host ""
    if ($Notice) {
        Write-Host $Notice -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "Available Miracast Receivers:" -ForegroundColor Cyan
    for ($idx = 0; $idx -lt $Receivers.Count; $idx++) {
        Write-Host "  [$($idx + 1)] $($Receivers[$idx])" -ForegroundColor White
    }
    Write-Host "  [R] Rescan" -ForegroundColor Yellow
    Write-Host "  [0] Cancel to exit" -ForegroundColor Red
    Write-Host ""
    while ($true) {
        $choice = (Read-Host "Select a receiver [0-$($Receivers.Count), R]").Trim()
        if ($choice -eq "0") { return $null }
        if ($choice -match "^[Rr]$") { return "__RESCAN__" }
        $num = 0
        if ([int]::TryParse($choice, [ref]$num) -and $num -ge 1 -and $num -le $Receivers.Count) {
            return $Receivers[$num - 1]
        }
        Write-Host "Invalid selection. Enter 1-$($Receivers.Count), R to rescan, or 0 to cancel." -ForegroundColor Red
    }
}

function Invoke-ConnectFlyoutTarget([string]$TargetPattern) {
    Write-Host "Opening the CONNECT panel and collecting available targets. Please wait..." -ForegroundColor Cyan
    Write-Host ""
    Start-Process "ms-settings-connectabledevices:devicediscovery"
    Start-Sleep -Seconds 2

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

    $wiredMonitors = [MiracastTarget]::GetWiredMonitorNames()
    $targetItem = $null
    $discoveredNames = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt 15; $i++) { # 3 seconds
        $items = $connectWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, $listItemCond)
        $discoveredNames.Clear()
        foreach ($item in $items) {
            $itemName = $item.Current.Name
            if (-not [string]::IsNullOrWhiteSpace($itemName)) {
                if ($wiredMonitors -contains $itemName.Trim()) { continue }
                $discoveredNames.Add($itemName)
                if (-not [string]::IsNullOrWhiteSpace($TargetPattern) -and $itemName -like "*$TargetPattern*") {
                    $targetItem = $item
                    break
                }
            }
        }
        if ($null -ne $targetItem) { break }
        Start-Sleep -Milliseconds 200
    }

    if ($null -eq $targetItem) {
        return [pscustomobject]@{
            Connected = $false
            Receivers = $discoveredNames.ToArray()
            Reason    = if ([string]::IsNullOrWhiteSpace($TargetPattern)) { "" } else { "Target '$TargetPattern' not found in CONNECT flyout list." }
        }
    }

    try {
        $targetItem.SetFocus()
    } catch {
        return [pscustomobject]@{
            Connected = $false
            Receivers = $discoveredNames.ToArray()
            Reason    = "Lost focus on '$TargetPattern' - pick a receiver to retry:"
        }
    }
    Start-Sleep -Milliseconds 150

    $focusedNow = [System.Windows.Automation.AutomationElement]::FocusedElement
    $focusedName = if ($null -ne $focusedNow) { $focusedNow.Current.Name } else { "" }
    if ($focusedName -notlike "*$TargetPattern*") {
        return [pscustomobject]@{
            Connected = $false
            Receivers = $discoveredNames.ToArray()
            Reason    = "Focus check missed '$TargetPattern' - pick a receiver to retry:"
        }
    }

    Write-Host "Executing the connection to '$TargetPattern'." -ForegroundColor Cyan
    Write-Host ""
    try {
        $invokePattern = $targetItem.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $invokePattern.Invoke()
        return [pscustomobject]@{ Connected = $true; Receivers = @(); Reason = "" }
    } catch {
        return [pscustomobject]@{
            Connected = $false
            Receivers = $discoveredNames.ToArray()
            Reason    = "Failed to invoke '$TargetPattern' (receiver may have dropped) - pick another receiver:"
        }
    }
}


function Stop-ConnectFlyoutAttempt {
    try {
        Start-Process "ms-settings-connectabledevices:devicediscovery"
        Start-Sleep -Milliseconds 500

        $connectWin = [System.Windows.Automation.AutomationElement]::FocusedElement
        while ($null -ne $connectWin -and $connectWin.Current.Name -ne "Connect" -and $connectWin.Current.ClassName -ne "Windows.UI.Core.CoreWindow") {
            $connectWin = [System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($connectWin)
        }
        if ($null -eq $connectWin) { return }

        $btnCond = New-Object System.Windows.Automation.AndCondition(
            (New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::Button
            )),
            (New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::NameProperty,
                "Cancel"
            ))
        )
        $cancelBtn = $connectWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
        if ($null -ne $cancelBtn) {
            $invokePattern = $cancelBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $invokePattern.Invoke()
            Start-Sleep -Milliseconds 250
        }
    } catch {
        # Best-effort cleanup only
    }
}


# =============================================================
# 6. Activate Miracast Wi-Fi Direct Adapter
# =============================================================
if (-not [MiracastTarget]::IsWifiRadioOn()) {
    Exit-WithCleanup "Wi-Fi radio is unavailable.  Check Wi-Fi function."
}
[MiracastTarget]::CaptureBaseline()
$wfdResult = [MiracastTarget]::SetWifiDirectEnabled($true)
if ($wfdResult -ne 0) {
    Exit-WithCleanup "Miracast Wi-Fi Direct adapter failed to start (code: $wfdResult)."
}
Start-Sleep -Milliseconds 500
Write-Host "Miracast Wi-Fi adapter now active." -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Milliseconds 500


# =============================================================
# 7. Execute Connection
# =============================================================
$pickerNotice = ""
while ($true) {
    $attempt = Invoke-ConnectFlyoutTarget -TargetPattern $Target
    if ($attempt.Connected) { break }

    if ($attempt.Receivers.Count -eq 0) {
        Exit-WithCleanup "No Miracast receivers found in CONNECT flyout list.  Aborting."
    }

    $notice = if (-not [string]::IsNullOrWhiteSpace($pickerNotice)) { $pickerNotice } else { $attempt.Reason }
    $picked = Show-ReceiverPickerMenu -Receivers $attempt.Receivers -Notice $notice
    $pickerNotice = ""

    if ($null -eq $picked) {
        Exit-WithCleanup "Miracast receiver selection cancelled by user."
    }
    if ($picked -eq "__RESCAN__") {
        $Target = ""
        continue
    }

    $Target = [WildcardPattern]::Escape($picked.Trim())
    $pickerNotice = "'$picked' is no longer available - pick another receiver:"
}


# =============================================================
# 8. Set preferred mode and give user the flyout
# =============================================================
Write-Host "Starting projection process." -ForegroundColor Cyan
Write-Host ""
$Connected        = $false
$barSeen          = $false
$handshakeDone    = $false
$connectStartTick = 0
$msPollInterval   = 250
$msHandshakeWait  = 4000
$msMaxConnectWait = 30000
$ticksHandshake   = [int]($msHandshakeWait / $msPollInterval) # 16 loops = 4 seconds
$ticksMaxConnect  = [int]($msMaxConnectWait / $msPollInterval) # 120 loops = 30 seconds

for ($i = 0; $i -lt $ticksMaxConnect; $i++) {
    $barStatus = Get-BlackBarStatus

    if (-not [string]::IsNullOrEmpty($barStatus) -and $barStatus -notlike 'Disconnected*') {
        $barSeen = $true
        if (-not $handshakeDone) {
            $handshakeDone    = $true
            $connectStartTick = $i
            Write-Host ""
            Write-Host "Projection handshake from '$Target' successful." -ForegroundColor Cyan
            Write-Host ""
        }
    } elseif ($barSeen) {
        Write-Host ""
        Write-Host "Projection attempt to '$Target' was disconnected or cancelled.  Aborting." -ForegroundColor Yellow
        break
    }

    if (-not $handshakeDone -and $i -ge $ticksHandshake) {
        Write-Host "No active projection receiver detected from '$Target'.  Aborting." -ForegroundColor Yellow
        break
    }

    if (-not $handshakeDone) {
        Write-Host "Checking for projection handshake from '$Target'... ($($i * $msPollInterval) ms)" -ForegroundColor Cyan
    } else {
        Write-Host "Waiting for projection completion... ($(($i - $connectStartTick) * $msPollInterval) ms)" -ForegroundColor Cyan
    }

    if ([MiracastTarget]::IsConnected()) {
        $Connected = $true
        break
    }
    Start-Sleep -Milliseconds $msPollInterval
}

if ($Connected) {
    Write-Host "Setting chosen '$Mode' mode." -ForegroundColor Cyan
    Write-Host ""
    [MiracastTarget]::SetMode($Mode) | Out-Null
    for ($j = 0; $j -lt 48; $j++) { # 12 seconds
        if ([MiracastTarget]::IsModeActive($Mode)) {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $NoFlyout) {
        Start-Process "DisplaySwitch.exe"
    }
} else {
    Write-Host ""
    Write-Host "Timed out waiting for '$Target' to project.  Aborting." -ForegroundColor Yellow
    Stop-ConnectFlyoutAttempt
    Exit-WithCleanup "Projection attempt to '$Target' failed."
}


# =============================================================
# 9. Spawn hidden disconnection popup watcher
# =============================================================
$wsh = New-Object -ComObject WScript.Shell
$wsh.Run("powershell.exe -STA -ExecutionPolicy Bypass -File `"$ScriptDir\MiracastProjectToMonitorWaitToClose.ps1`"", 0, $false) | Out-Null
