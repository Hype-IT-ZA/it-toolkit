# =====================================================================
#  Example plugin for IT Toolkit
#  Every .ps1 file in this Tools folder is loaded when the toolkit starts.
#  Copy this file, rename it, and add your own tools and tweaks.
#
#  Inside an action you can use:
#    Log 'text' 'INFO|OK|WARN|ERROR'      write to the output console
#    Invoke-AsUser -Script '...'          run as the signed-in user (not SYSTEM)
#    Set-RegValue 'HKCU:\...' Name Value  HKCU:\ = every signed-in user
#    Format-Size, Get-ConsoleUser, Test-PendingReboot, Invoke-WingetApps ...
#  (all in core\Helpers.ps1)
# =====================================================================

# A simple tool: anything it outputs is shown in the console
Register-Tool -Category 'Custom' -Name 'Hello world' -Description 'Example tool - copy me to make your own' -Action {
    Log 'Hello from a plugin!' 'OK'
    Get-Date
}

# Ask for input first ('Key|Prompt|Default'), read it with param($P)
Register-Tool -Category 'Custom' -Name 'Check website' -Description 'HTTP status and response time for a URL' `
    -Inputs 'Url|Website address|https://www.google.com' -Action {
    param($P)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-WebRequest -Uri $P.Url -UseBasicParsing -TimeoutSec 15
        Log ('{0} -> HTTP {1} in {2} ms' -f $P.Url, $r.StatusCode, $sw.ElapsedMilliseconds) 'OK'
    } catch {
        Log "Failed: $($_.Exception.Message)" 'ERROR'
    }
}

# Run something as the signed-in user
Register-Tool -Category 'Custom' -Name 'User desktop files' -Description 'Lists files on the signed-in user''s desktop' -Action {
    Invoke-AsUser -Script 'Get-ChildItem ([Environment]::GetFolderPath("Desktop")) | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize'
}

# A launcher: runs instantly on the UI thread (use for opening programs)
Register-Tool -Category 'Custom' -Name 'Open Notepad' -Description 'Example launcher' -Launch -Action {
    Start-Process notepad.exe
}

# A tweak shows up on the Tweaks tab with Apply / Undo / status
Register-Tweak -Category 'Custom' -Name 'Show seconds on the taskbar clock' -Description 'Example tweak (Windows 11 23H2+)' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSecondsInSystemClock'; Value = 1; Revert = 0 }
)
