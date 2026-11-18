# =====================================================================
#  Example plugin for IT Toolkit
#  Every .ps1 file in this Tools folder is loaded when the toolkit starts.
#  Copy this file, rename it, and add your own tools with Register-Tool.
# =====================================================================

# A simple tool: output is shown in the console automatically
Register-Tool -Category 'Custom' -Name 'Hello world' -Description 'Example tool - copy me to make your own' -Action {
    Log 'Hello from a plugin!' 'OK'
    Get-Date
}

# A tool that asks for input first (Key|Prompt|Default) - read it with param($P)
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

# A tool that asks "are you sure?" first
Register-Tool -Category 'Custom' -Name 'Clear Teams cache' -Description 'Classic Teams cache for all users (Teams must be closed)' `
    -Confirm 'Teams must be closed on this PC. Clear the cache now?' -Action {
    Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath } | ForEach-Object {
        foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'blob_storage', 'IndexedDB') {
            $path = Join-Path $_.LocalPath "AppData\Roaming\Microsoft\Teams\$c"
            if (Test-Path $path) { Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue; Log "Cleared $path" }
        }
    }
    Log 'Done.' 'OK'
}

# A launcher: runs instantly on the UI thread (use for opening programs)
Register-Tool -Category 'Custom' -Name 'Open Notepad' -Description 'Example launcher' -Launch -Action {
    Start-Process notepad.exe
}
