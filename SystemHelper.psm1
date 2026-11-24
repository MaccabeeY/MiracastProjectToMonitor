enum FocusShellState {
    None     = 0
    Flyout   = 1
    BlackBar = 2
}

if (-not ('Win32ConsoleFocus' -as [type])) {
    Add-Type -TypeDefinition '
    using System;
    using System.Text;
    using System.Runtime.InteropServices;

    public class Win32ConsoleFocus {
        [StructLayout(LayoutKind.Explicit, Size = 40)]
        public struct INPUT {
            [FieldOffset(0)]  public uint type;
            [FieldOffset(8)]  public ushort wVk;
            [FieldOffset(12)] public uint dwFlags;
        }

        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int nCmdShow);
        [DllImport("user32.dll")] public static extern uint SendInput(uint n, ref INPUT p, int s);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
        [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
        [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr hAfter, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
    }'
}


function Set-ParentWindowFocus([bool]$TopMost = $false) {
    $c = [Win32ConsoleFocus]::GetConsoleWindow()
    if ($c -eq [IntPtr]::Zero) { return }
    $h = [Win32ConsoleFocus]::GetAncestor($c, 3) # GA_ROOTOWNER (handles Windows Terminal & conhost)
    if ($h -eq [IntPtr]::Zero) { $h = $c }

    $focusState   = [FocusShellState]::None
    $blackBarHwnd = [IntPtr]::Zero

    try {
        # Dismiss frameless shell flyouts ONLY if one currently holds focus
        $fg = [Win32ConsoleFocus]::GetForegroundWindow()
        if ($fg -ne [IntPtr]::Zero -and $fg -ne $h) {
            $sb = New-Object System.Text.StringBuilder 256
            [void][Win32ConsoleFocus]::GetClassName($fg, $sb, 256)
            $fgPid = 0
            [void][Win32ConsoleFocus]::GetWindowThreadProcessId($fg, [ref]$fgPid)
            $proc = (Get-Process -Id $fgPid -ErrorAction SilentlyContinue).ProcessName

            if (($sb.ToString() -eq 'Windows.UI.Core.CoreWindow') -or ($proc -eq 'ShellExperienceHost')) {
                $titleSb = New-Object System.Text.StringBuilder 256
                [void][Win32ConsoleFocus]::GetWindowText($fg, $titleSb, 256)
                $title = $titleSb.ToString()

                switch ($title) {
                    { $_ -in @('Connect', 'Project') } {
                        # Connect / Project shell flyout detected ($fg)
                        $focusState = [FocusShellState]::Flyout
                        1..2 | ForEach-Object {
                            $esc = New-Object Win32ConsoleFocus+INPUT
                            $esc.type = 1
                            $esc.wVk  = 0x1B
                            [void][Win32ConsoleFocus]::SendInput(1, [ref]$esc, 40)
                            $esc.dwFlags = 2
                            [void][Win32ConsoleFocus]::SendInput(1, [ref]$esc, 40)
                            Start-Sleep -Milliseconds 30
                        }
                        Start-Sleep -Milliseconds 40
                        break
                    }
                    'Wireless display toolbar' {
                        # Black Miracast bar shell flyout detected ($fg)
                        $focusState   = [FocusShellState]::BlackBar
                        $blackBarHwnd = $fg
                        break
                    }
                    default {
                        # Any other shell flyout (Start, Search, Action Center, Volume, etc.)
                        break
                    }
                }
            }
        }
    }
    finally {
        if ($focusState -eq [FocusShellState]::BlackBar -and $blackBarHwnd -ne [IntPtr]::Zero) {
            for ($i = 0; $i -lt 14; $i++) {
                if (-not [Win32ConsoleFocus]::IsWindowVisible($blackBarHwnd)) {
                    break
                }
                Write-Host "Waiting for system toolbar to close... ($($i * 2000) ms)" -ForegroundColor Cyan
                Start-Sleep -Milliseconds 2000
            }
        }

        # Restore only if minimized
        if ([Win32ConsoleFocus]::IsIconic($h)) {
            [void][Win32ConsoleFocus]::ShowWindow($h, 9) # SW_RESTORE
        }

        Set-AttachThread $TopMost
    }
}


function Set-AttachThread([bool]$TopMost = $false) {
    $c = [Win32ConsoleFocus]::GetConsoleWindow()
    if ($c -eq [IntPtr]::Zero) { return }
    $h = [Win32ConsoleFocus]::GetAncestor($c, 3)
    if ($h -eq [IntPtr]::Zero) { $h = $c }

    if ([Win32ConsoleFocus]::IsIconic($h)) {
        [void][Win32ConsoleFocus]::ShowWindow($h, 9)
    }

    $fg = [Win32ConsoleFocus]::GetForegroundWindow()
    $fgPid = 0
    $fgTid = [Win32ConsoleFocus]::GetWindowThreadProcessId($fg, [ref]$fgPid)
    $myTid = [Win32ConsoleFocus]::GetCurrentThreadId()

    $attached = $false
    try {
        if ($fgTid -ne 0 -and $fgTid -ne $myTid) {
            $attached = [Win32ConsoleFocus]::AttachThreadInput($myTid, $fgTid, $true)
        }

        [void][Win32ConsoleFocus]::SetForegroundWindow($h)
        [void][Win32ConsoleFocus]::SetFocus($h)
    }
    finally {
        if ($attached) {
            [void][Win32ConsoleFocus]::AttachThreadInput($myTid, $fgTid, $false)
        }
        if ($TopMost) {
            Set-WindowTopMost
        }
    }
}

function Set-WindowTopMost {
    $c = [Win32ConsoleFocus]::GetConsoleWindow()
    if ($c -eq [IntPtr]::Zero) { return }
    $h = [Win32ConsoleFocus]::GetAncestor($c, 3)
    if ($h -eq [IntPtr]::Zero) { $h = $c }

    [void][Win32ConsoleFocus]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0043)
}

Export-ModuleMember -Function Set-ParentWindowFocus
