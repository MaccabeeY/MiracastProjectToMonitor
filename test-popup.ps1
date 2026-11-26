Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Miracast Project to Monitor"
$Form.Size = New-Object System.Drawing.Size(380, 155)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedSingle"
$Form.MinimizeBox = $true
$Form.MaximizeBox = $false
$Form.TopMost = $true

$Label = New-Object System.Windows.Forms.Label
$Label.Dock = "Top"
$Label.Height = 42
$Label.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$Label.TextAlign = "TopCenter"
$Label.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$Label.Text = "Unexpected Projection Termination."
$Form.Controls.Add($Label)

$BodyLabel1 = New-Object System.Windows.Forms.Label
$BodyLabel1.Text = "Click <X> to close and then run"
$BodyLabel1.AutoSize = $true
$BodyLabel1.Location = New-Object System.Drawing.Point(80, 48)
$BodyLabel1.Font = $Label.Font
$Form.Controls.Add($BodyLabel1)

$BodyLabel2 = New-Object System.Windows.Forms.Label
$BodyLabel2.Text = "`"MiracastProjectToMonitor`""
$BodyLabel2.AutoSize = $true
$BodyLabel2.Location = New-Object System.Drawing.Point(85, 68)
$BodyLabel2.Font = $Label.Font
$Form.Controls.Add($BodyLabel2)

$BodyLabel3 = New-Object System.Windows.Forms.Label
$BodyLabel3.Text = "to start a new projection."
$BodyLabel3.AutoSize = $true
$BodyLabel3.Location = New-Object System.Drawing.Point(95, 88)
$BodyLabel3.Font = $Label.Font
$Form.Controls.Add($BodyLabel3)

$BodyLabel1.BringToFront()
$BodyLabel2.BringToFront()
$BodyLabel3.BringToFront()

[void]$Form.ShowDialog()
