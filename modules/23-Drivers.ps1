# Drivers & Blue screens
Register-Tool 'Drivers' 'Scan for manufacturer updates' 'Dell Command Update, HP Image Assistant or Lenovo System Update - list only' {
    Invoke-OemUpdates -Mode Scan
}
Register-Tool 'Drivers' 'Install manufacturer updates' 'Drivers, firmware and BIOS from Dell, HP or Lenovo (no automatic restart)' `
    -Confirm 'Drivers, firmware and possibly BIOS updates will be installed. The screen may flicker and a restart may be needed afterwards. Make sure a laptop is plugged in. Continue?' {
    Invoke-OemUpdates -Mode Install
}
Register-Tool 'Drivers' 'Windows Update drivers' 'Driver updates Windows Update has for this PC' {
    Log 'Searching Windows Update for drivers...'
    $r = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search("IsInstalled=0 and Type='Driver'")
    if ($r.Updates.Count -eq 0) { Log 'No driver updates available from Windows Update.' 'OK'; return }
    $r.Updates | ForEach-Object { [pscustomobject]@{ Driver = $_.Title; Class = $_.DriverClass; Date = $(if ($_.DriverVerDate) { $_.DriverVerDate.ToString('yyyy-MM-dd') }) } } | Format-Table -AutoSize
}
Register-Tool 'Drivers' 'Install Windows Update drivers' 'Download and install every driver Windows Update offers' -Confirm 'All driver updates from Windows Update will be installed. A restart may be needed. Continue?' {
    $session = New-Object -ComObject Microsoft.Update.Session
    $found = $session.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Driver'").Updates
    if ($found.Count -eq 0) { Log 'No driver updates available.' 'OK'; return }
    $list = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in $found) { if (-not $u.EulaAccepted) { $u.AcceptEula() }; [void]$list.Add($u); Log "Queued: $($u.Title)" }
    $dl = $session.CreateUpdateDownloader(); $dl.Updates = $list; [void]$dl.Download()
    $inst = $session.CreateUpdateInstaller(); $inst.Updates = $list; $res = $inst.Install()
    for ($i = 0; $i -lt $list.Count; $i++) { $rc = $res.GetUpdateResult($i).ResultCode; Log ('{0} - {1}' -f $list.Item($i).Title, @{2 = 'installed'; 3 = 'installed with errors'; 4 = 'FAILED'; 5 = 'aborted' }[[int]$rc]) $(if ($rc -eq 2) { 'OK' } else { 'WARN' }) }
    if ($res.RebootRequired) { Log 'A restart is required to finish.' 'WARN' }
}
Register-Tool 'Drivers' 'Export drivers (backup)' 'Copies all third-party drivers to a folder before a reinstall' {
    $dir = Join-Path $ITK_ReportDir "DriverBackup_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd)"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Log "Exporting drivers to $dir ..."
    $n = @(Export-WindowsDriver -Online -Destination $dir -ErrorAction Stop).Count
    Log "Exported $n driver packages. Reinstall later with: pnputil /add-driver `"$dir\*.inf`" /subdirs /install" 'OK'
}

Register-Tool 'Blue screens' 'Recent blue screens' 'Stop codes from the last 90 days with what they usually mean' {
    $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = (Get-Date).AddDays(-90) } -ErrorAction SilentlyContinue)
    $crashes = foreach ($e in $ev) {
        if ($e.Message -match '(0x[0-9a-fA-F]{8})') { $i = Get-StopCodeInfo $Matches[1]; [pscustomobject]@{ Time = $e.TimeCreated; Code = $i.Code; Name = $i.Name; 'Usual cause' = $i.Advice } }
    }
    $dumps = @(Get-ChildItem "$env:windir\Minidump\*.dmp" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    $power = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41; StartTime = (Get-Date).AddDays(-90) } -ErrorAction SilentlyContinue).Count
    $whea = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = (Get-Date).AddDays(-90) } -ErrorAction SilentlyContinue).Count
    if (-not $crashes) { Log 'No blue screens recorded in the last 90 days.' 'OK' }
    else {
        Log "$(@($crashes).Count) blue screen(s) in the last 90 days" 'WARN'
        $crashes | Format-Table -AutoSize -Wrap
        $top = $crashes | Group-Object Code | Sort-Object Count -Descending | Select-Object -First 1
        $i = Get-StopCodeInfo $top.Name
        Log "Most common: $($i.Name) ($($top.Count)x) - $($i.Advice)" 'WARN'
    }
    Log "Unexpected power losses / hard resets (event 41): $power" $(if ($power) { 'WARN' } else { 'INFO' })
    Log "Hardware error reports (WHEA): $whea" $(if ($whea) { 'WARN' } else { 'INFO' })
    if ($dumps) { Log "Minidumps: $($dumps.Count), newest $($dumps[0].LastWriteTime) - use 'Analyse crash dumps' to see the driver involved." }
    else { Log 'No minidump files in C:\Windows\Minidump.' }
}
Register-Tool 'Blue screens' 'Analyse crash dumps' 'Shows the driver involved in each crash (NirSoft BlueScreenView, free)' {
    $dumps = @(Get-ChildItem "$env:windir\Minidump\*.dmp" -ErrorAction SilentlyContinue)
    if (-not $dumps) { Log 'No minidump files to analyse in C:\Windows\Minidump.' 'WARN'; return }
    $dir = Join-Path $ITK_DataDir 'Apps\BlueScreenView'
    $exe = Join-Path $dir 'BlueScreenView.exe'
    if (-not (Test-Path $exe)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $zip = Join-Path $dir 'bsv.zip'
        $url = if ([Environment]::Is64BitOperatingSystem) { 'https://www.nirsoft.net/utils/bluescreenview-x64.zip' } else { 'https://www.nirsoft.net/utils/bluescreenview.zip' }
        Log 'Downloading BlueScreenView from nirsoft.net...'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $zip -DestinationPath $dir -Force
        Remove-Item $zip -Force
    }
    $csv = Join-Path $ITK_TempDir 'bsv.csv'
    New-Item -ItemType Directory -Path $ITK_TempDir -Force | Out-Null
    Start-Process -FilePath $exe -ArgumentList '/scomma', "`"$csv`"" -Wait
    $html = Join-Path $ITK_ReportDir "BlueScreens_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd_HHmm).html"
    Start-Process -FilePath $exe -ArgumentList '/shtml', "`"$html`"" -Wait
    if (-not (Test-Path $csv)) { Log 'BlueScreenView did not produce a result.' 'ERROR'; return }
    $rows = Import-Csv $csv -Header 'Dump', 'Time', 'BugCheck', 'Code', 'P1', 'P2', 'P3', 'P4', 'Driver', 'Address', 'Description', 'Product', 'Company', 'Version'
    $rows | Select-Object Time, BugCheck, Code, @{ n = 'Caused by driver'; e = { $_.Driver } }, Description, Company | Format-Table -AutoSize -Wrap
    $top = $rows | Where-Object Driver | Group-Object Driver | Sort-Object Count -Descending | Select-Object -First 1
    if ($top) { Log "Driver seen most often: $($top.Name) ($($top.Count)x). ntoskrnl.exe / hal.dll usually means hardware or RAM rather than a specific driver." 'WARN' }
    Remove-Item $csv -Force -ErrorAction SilentlyContinue
    if (Test-Path $html) { Log "Full report: $html" 'OK' }
}
Register-Tool 'Blue screens' 'Memory test on next restart' 'Schedules Windows Memory Diagnostic for the next restart' -Confirm 'Windows Memory Diagnostic will run on the next restart (takes 15-30 minutes, then Windows starts normally). Schedule it?' {
    bcdedit /bootsequence '{memdiag}' /addfirst | Out-Null
    Log 'Memory test scheduled. Restart the PC to run it. Results appear later in Event Viewer (MemoryDiagnostics-Results).' 'OK'
}
Register-Tool 'Blue screens' 'Memory test results' 'Result of the last Windows Memory Diagnostic run' {
    $e = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-MemoryDiagnostics-Results' } -MaxEvents 3 -ErrorAction SilentlyContinue
    if (-not $e) { Log 'No memory test results found.' 'WARN'; return }
    $e | Select-Object TimeCreated, @{ n = 'Result'; e = { ("$($_.Message)" -split "`n")[0] } } | Format-Table -AutoSize -Wrap
}
