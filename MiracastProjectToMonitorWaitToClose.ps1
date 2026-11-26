Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not ([System.Management.Automation.PSTypeName]'MiracastTarget').Type) {
    Add-Type -Path "$ScriptDir\MiracastHelper.cs"
}


function New-ProjectionActiveUI {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Miracast Project to Monitor"
    $form.Size = New-Object System.Drawing.Size(380, 155)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MinimizeBox = $true
    $form.MaximizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Projection Active: close to disconnect."
    $label.AutoSize = $false
    $label.TextAlign = "MiddleCenter"
    $label.Dock = "Fill"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $form.Controls.Add($label)

    return [pscustomobject]@{
        Form  = $form
        Label = $label
    }
}


function Show-UnexpectedTerminationUI {
    param(
        [System.Windows.Forms.Form]$TargetForm,
        [System.Windows.Forms.Label]$HeaderLabel
    )

    $TargetForm.Size = New-Object System.Drawing.Size(380, 155)

    $HeaderLabel.Dock = "Top"
    $HeaderLabel.Height = 42
    $HeaderLabel.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
    $HeaderLabel.TextAlign = "TopCenter"
    $HeaderLabel.Text = "Unexpected Projection Termination."

    $BodyLabel1 = New-Object System.Windows.Forms.Label
    $BodyLabel1.Text = "Click <X> to close and then run"
    $BodyLabel1.AutoSize = $true
    $BodyLabel1.Location = New-Object System.Drawing.Point(80, 48)
    $BodyLabel1.Font = $HeaderLabel.Font
    $TargetForm.Controls.Add($BodyLabel1)

    $BodyLabel2 = New-Object System.Windows.Forms.Label
    $BodyLabel2.Text = "`"MiracastProjectToMonitor`""
    $BodyLabel2.AutoSize = $true
    $BodyLabel2.Location = New-Object System.Drawing.Point(85, 68)
    $BodyLabel2.Font = $HeaderLabel.Font
    $TargetForm.Controls.Add($BodyLabel2)

    $BodyLabel3 = New-Object System.Windows.Forms.Label
    $BodyLabel3.Text = "to start a new projection."
    $BodyLabel3.AutoSize = $true
    $BodyLabel3.Location = New-Object System.Drawing.Point(95, 88)
    $BodyLabel3.Font = $HeaderLabel.Font
    $TargetForm.Controls.Add($BodyLabel3)

    $BodyLabel1.BringToFront()
    $BodyLabel2.BringToFront()
    $BodyLabel3.BringToFront()
}


try {
# =============================================================
# 1. Wait for Miracast connection before showing popup
# =============================================================
$Connected = $false
for ($i = 0; $i -lt 20; $i++) { # 10 seconds
    if ([MiracastTarget]::IsMiracastActive()) {
        $Connected = $true
        break
    }
    Start-Sleep -Milliseconds 500
}

if (-not $Connected) {
    [MiracastTarget]::SetWifiDirectEnabled($false) | Out-Null
    Start-Process "ms-settings-connectabledevices:devicediscovery"
    return
}


# =============================================================
# 2. Show minimizable popup window
# =============================================================
$ui = New-ProjectionActiveUI
$Form = $ui.Form
$Label = $ui.Label

$script:CleanedUp = $false
$InvokeCleanup = {
    if ($script:CleanedUp) { return }
    $script:CleanedUp = $true
    if ([MiracastTarget]::IsMiracastActive()) {
        [MiracastTarget]::Disconnect() | Out-Null
    }
    [MiracastTarget]::SetWifiDirectEnabled($false) | Out-Null
}

$PollIntervalMs = 1000
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = $PollIntervalMs
$Timer.Add_Tick({
    if (-not [MiracastTarget]::IsMiracastActive()) {
        $Timer.Stop()
        & $InvokeCleanup
        Show-UnexpectedTerminationUI -TargetForm $Form -HeaderLabel $Label
        if ($Form.WindowState -eq "Minimized") {
            $Form.WindowState = "Normal"
        }
        $Form.Activate()
    }
})

$Form.Add_Shown({
    $Form.Visible = $true
    $Form.Activate()
    $Timer.Start()
})

$Form.Add_FormClosing({
    $Timer.Stop()
    $Timer.Dispose()
    & $InvokeCleanup
})

# Stops here until you click X to close the popup
[void]$Form.ShowDialog()
}


# =============================================================
# 3. Kill (cleanup) myself "not matter what"
# =============================================================
finally {
    Get-CimInstance Win32_Process -Filter "ProcessId = $PID" |
        Where-Object { $_.CommandLine -like "*MiracastProjectToMonitorWaitToClose.ps1*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}
