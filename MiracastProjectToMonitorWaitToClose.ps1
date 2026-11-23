Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptDir\MiracastHelper.ps1"


try {
# =============================================================
# 1. Wait for Miracast connection before showing popup
# =============================================================
$Connected = $false
for ($i = 0; $i -lt 20; $i++) {
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
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Wireless Display"
$Form.Size = New-Object System.Drawing.Size(320, 120)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedSingle"
$Form.MinimizeBox = $true
$Form.MaximizeBox = $false
$Form.TopMost = $true

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Projection: close to disconnect."
$Label.AutoSize = $false
$Label.TextAlign = "MiddleCenter"
$Label.Dock = "Fill"
$Label.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$Form.Controls.Add($Label)

$Form.Add_Shown({ $Form.Visible = $true; $Form.Activate() })

# Stops here until you click X to close the popup
[void]$Form.ShowDialog()

if ([MiracastTarget]::IsMiracastActive()) {
    [MiracastTarget]::Disconnect() | Out-Null
}
[MiracastTarget]::SetWifiDirectEnabled($false) | Out-Null
}
# =============================================================
# 3. Kill (cleanup) myself "not matter what"
# =============================================================
finally {
    Get-CimInstance Win32_Process -Filter "ProcessId = $PID" |
        Where-Object { $_.CommandLine -like "*MiracastProjectToMonitorWaitToClose.ps1*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}
