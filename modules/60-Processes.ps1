# Services & Processes
Register-Tool 'Services & Processes' 'Top processes (RAM)' '15 biggest processes by memory' {
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id,
        @{ n = 'RAM (MB)'; e = { [math]::Round($_.WorkingSet64 / 1MB) } }, @{ n = 'CPU (s)'; e = { [math]::Round($_.CPU, 1) } } | Format-Table -AutoSize
}
Register-Tool 'Services & Processes' 'Stopped auto services' 'Automatic services that are not running' {
    Log 'Note: some trigger-start services are normally stopped.'
    Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" | Select-Object Name, DisplayName, State | Format-Table -AutoSize
}
Register-Tool 'Services & Processes' 'Restart a service' 'Restart by service name' -Inputs 'Name|Service name (e.g. Spooler)|' {
    param($P)
    Restart-Service -Name $P.Name -Force -ErrorAction Stop
    Get-Service -Name $P.Name | Select-Object Name, DisplayName, Status | Format-Table -AutoSize
}
Register-Tool 'Services & Processes' 'End a process' 'Kill by name or PID' -Inputs 'Target|Process name or PID|' -Confirm 'Unsaved work in that program will be lost. Continue?' {
    param($P)
    $t = $P.Target
    $found = if ($t -match '^\d+$') { Get-Process -Id $t -ErrorAction SilentlyContinue } else { Get-Process -Name ($t -replace '\.exe$', '') -ErrorAction SilentlyContinue }
    if (-not $found) { Log "No process found matching '$t'" 'WARN'; return }
    foreach ($proc in $found) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop; Log "Ended $($proc.Name) (PID $($proc.Id))" 'OK' } catch { Log "Failed: $($_.Exception.Message)" 'ERROR' }
    }
}
