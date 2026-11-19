# Reports
Register-Tool 'Reports' 'Health check report' 'Runs 15+ checks and saves an HTML report' {
    $checks = New-Object System.Collections.Generic.List[object]
    function Add-Check([string]$Name, [string]$Status, [string]$Detail) {
        $checks.Add([pscustomobject]@{ Status = $Status; Check = $Name; Detail = $Detail })
        Log ('{0,-5} {1} - {2}' -f $Status.ToUpper(), $Name, $Detail) $(switch ($Status) { 'Pass' { 'OK' } 'Info' { 'INFO' } default { 'WARN' } })
    }
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem; $bios = Get-CimInstance Win32_BIOS
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $dv = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion

    # Windows version
    if ($os.Caption -match 'Windows 10') { Add-Check 'Windows version' 'Warn' "$($os.Caption) $dv - Windows 10 support ended on 14 Oct 2025 (unless enrolled in ESU)" }
    else { Add-Check 'Windows version' 'Info' "$($os.Caption) $dv (build $($os.BuildNumber))" }
    # Disk space
    $sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $pct = [math]::Round($sys.FreeSpace / $sys.Size * 100, 1)
    Add-Check 'System drive free space' $(if ($pct -lt 10) { 'Fail' } elseif ($pct -lt 20) { 'Warn' } else { 'Pass' }) ('{0} free of {1} ({2}%)' -f (Format-Size $sys.FreeSpace), (Format-Size $sys.Size), $pct)
    # Disk health
    try {
        $pd = @(Get-PhysicalDisk -ErrorAction Stop); $bad = @($pd | Where-Object HealthStatus -ne 'Healthy')
        Add-Check 'Physical disk health' $(if ($bad) { 'Fail' } else { 'Pass' }) $(if ($bad) { 'Unhealthy: ' + ($bad.FriendlyName -join ', ') } else { "$($pd.Count) disk(s) healthy" })
    } catch { Add-Check 'Physical disk health' 'Info' 'Not available' }
    # Memory
    $ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $memUsed = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100)
    Add-Check 'Installed memory' $(if ($ramGb -lt 4) { 'Fail' } elseif ($ramGb -lt 8) { 'Warn' } else { 'Pass' }) "$ramGb GB"
    Add-Check 'Memory in use' $(if ($memUsed -gt 90) { 'Warn' } else { 'Pass' }) "$memUsed% right now"
    # Uptime + reboot
    $up = (Get-Date) - $os.LastBootUpTime
    Add-Check 'Uptime' $(if ($up.TotalDays -gt 14) { 'Warn' } else { 'Pass' }) ('{0}d {1}h since last restart' -f $up.Days, $up.Hours)
    Add-Check 'Pending reboot' $(if (Test-PendingReboot) { 'Warn' } else { 'Pass' }) $(if (Test-PendingReboot) { 'Windows is waiting for a restart' } else { 'None' })
    # Antivirus
    $av = @(Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue)
    $thirdParty = @($av | Where-Object { $_.displayName -notmatch 'Windows Defender|Microsoft Defender' -and (($_.productState -band 0x1000) -ne 0) })
    if ($thirdParty) { Add-Check 'Antivirus' 'Pass' (($thirdParty.displayName) -join ', ') }
    else {
        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            Add-Check 'Defender real-time protection' $(if ($mp.RealTimeProtectionEnabled) { 'Pass' } else { 'Fail' }) $(if ($mp.RealTimeProtectionEnabled) { 'On' } else { 'Off' })
            $age = [math]::Round(((Get-Date) - $mp.AntivirusSignatureLastUpdated).TotalDays, 1)
            Add-Check 'Antivirus definitions' $(if ($age -lt 3) { 'Pass' } elseif ($age -lt 7) { 'Warn' } else { 'Fail' }) "Updated $($mp.AntivirusSignatureLastUpdated) ($age days ago)"
        } catch { Add-Check 'Antivirus' 'Fail' 'No active antivirus detected' }
    }
    # Firewall
    $fwOff = @(Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Enabled })
    Add-Check 'Firewall' $(if ($fwOff) { 'Fail' } else { 'Pass' }) $(if ($fwOff) { 'Off for: ' + ($fwOff.Name -join ', ') } else { 'All profiles on' })
    # Updates
    $last = Get-HotFix -ErrorAction SilentlyContinue | Where-Object InstalledOn | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($last) {
        $days = [math]::Round(((Get-Date) - $last.InstalledOn).TotalDays)
        Add-Check 'Windows updates' $(if ($days -le 35) { 'Pass' } elseif ($days -le 60) { 'Warn' } else { 'Fail' }) "Last update $($last.HotFixID) installed $days days ago"
    } else { Add-Check 'Windows updates' 'Warn' 'No update history found' }
    # Events
    $errs = @(Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddHours(-24) } -MaxEvents 500 -ErrorAction SilentlyContinue)
    Add-Check 'Error events (24h)' $(if ($errs.Count -gt 25) { 'Warn' } else { 'Pass' }) "$($errs.Count) critical/error events"
    $crash = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 6008; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue)
    Add-Check 'Unexpected shutdowns (7 days)' $(if ($crash.Count) { 'Warn' } else { 'Pass' }) "$($crash.Count) found"
    # Devices
    $badDev = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 })
    Add-Check 'Device Manager' $(if ($badDev.Count) { 'Warn' } else { 'Pass' }) $(if ($badDev.Count) { "$($badDev.Count) problem device(s): " + (($badDev | Select-Object -First 3).Name -join ', ') } else { 'No problem devices' })
    # Activation
    $lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lic) { Add-Check 'Windows activation' $(if ($lic.LicenseStatus -eq 1) { 'Pass' } else { 'Fail' }) $(if ($lic.LicenseStatus -eq 1) { 'Licensed' } else { "Not activated (status $($lic.LicenseStatus))" }) }
    # BitLocker
    try { $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop; Add-Check 'BitLocker (system drive)' 'Info' "$($bl.VolumeStatus), protection $($bl.ProtectionStatus)" } catch {}
    # Battery
    try {
        $full = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        if ($full -and $design) { $h = [math]::Round($full / $design * 100); Add-Check 'Battery health' $(if ($h -lt 60) { 'Warn' } else { 'Pass' }) "$h% of design capacity" }
    } catch {}

    # Sections
    $sysRows = [ordered]@{
        Computer = $env:COMPUTERNAME; Domain = $cs.Domain; 'Signed-in user' = (Get-ConsoleUser); Manufacturer = $cs.Manufacturer; Model = $cs.Model
        Serial = $bios.SerialNumber; BIOS = $bios.SMBIOSBIOSVersion; OS = "$($os.Caption) $dv"; Build = $os.BuildNumber
        CPU = $cpu.Name.Trim(); RAM = "$ramGb GB"; 'Last boot' = $os.LastBootUpTime
    }
    $sections = @(
        @{ Title = 'System'; Rows = @($sysRows.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Item = $_.Key; Value = $_.Value } }) }
        @{ Title = 'Drives'; Rows = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { [pscustomobject]@{ Drive = $_.DeviceID; Label = $_.VolumeName; Size = (Format-Size $_.Size); Free = (Format-Size $_.FreeSpace) } }) }
        @{ Title = 'Network'; Rows = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq 'Up' } | ForEach-Object { [pscustomobject]@{ Adapter = $_.InterfaceAlias; IPv4 = ($_.IPv4Address.IPAddress -join ', '); Gateway = ($_.IPv4DefaultGateway.NextHop -join ', '); DNS = (($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ', ') } }) }
        @{ Title = 'Top processes by memory'; Rows = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object { [pscustomobject]@{ Process = $_.Name; PID = $_.Id; RAM = (Format-Size $_.WorkingSet64) } }) }
        @{ Title = 'Recent errors (24h)'; Rows = @($errs | Select-Object -First 15 | ForEach-Object { [pscustomobject]@{ Time = $_.TimeCreated; Log = $_.LogName; Source = $_.ProviderName; Id = $_.Id; Message = (("$($_.Message)" -split "`n")[0]) } }) }
        @{ Title = 'Installed software'; Rows = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and -not $_.SystemComponent } | Sort-Object DisplayName -Unique | ForEach-Object { [pscustomobject]@{ Name = $_.DisplayName; Version = $_.DisplayVersion; Publisher = $_.Publisher } }) }
    )
    $settings = Get-ToolkitSettings
    $title = if ($settings.ReportTitle) { "$($settings.ReportTitle) - Health check: $env:COMPUTERNAME" } else { "Health check: $env:COMPUTERNAME" }
    $path = Join-Path $ITK_ReportDir ('HealthCheck_{0}_{1:yyyyMMdd_HHmm}.html' -f $env:COMPUTERNAME, (Get-Date))
    New-HtmlReport -Title $title -Subtitle "$($cs.Manufacturer) $($cs.Model) - $($os.Caption) - $(Get-Date -Format 'd MMMM yyyy HH:mm')" -Checks $checks -Sections $sections -Path $path
    $pass = @($checks | Where-Object Status -eq 'Pass').Count; $warn = @($checks | Where-Object Status -in 'Warn', 'Fail').Count
    Log "Health check: $pass passed, $warn need attention." $(if ($warn) { 'WARN' } else { 'OK' })
    Log "Report saved: $path" 'OK'
}

Register-Tool 'Reports' 'Inventory export' 'Hardware + software CSV for asset records' {
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem; $bios = Get-CimInstance Win32_BIOS
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $net = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object IPv4DefaultGateway | Select-Object -First 1
    $disks = (Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FriendlyName) $([math]::Round($_.Size / 1GB))GB $($_.MediaType)" }) -join '; '
    $row = [pscustomobject]@{
        Computer = $env:COMPUTERNAME; Domain = $cs.Domain; Manufacturer = $cs.Manufacturer; Model = $cs.Model; Serial = $bios.SerialNumber
        BIOS = $bios.SMBIOSBIOSVersion; OS = $os.Caption; Version = $os.Version; Build = $os.BuildNumber; Installed = $os.InstallDate
        CPU = $cpu.Name.Trim(); Cores = $cpu.NumberOfCores; 'RAM (GB)' = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1); Disks = $disks
        IP = ($net.IPv4Address.IPAddress -join ', '); MAC = $net.NetAdapter.MacAddress; 'Signed-in user' = (Get-ConsoleUser); 'Last boot' = $os.LastBootUpTime
        Exported = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }
    New-Item -ItemType Directory -Path $ITK_ReportDir -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $hw = Join-Path $ITK_ReportDir "Inventory_$($env:COMPUTERNAME)_$stamp.csv"
    $sw = Join-Path $ITK_ReportDir "Software_$($env:COMPUTERNAME)_$stamp.csv"
    $row | Export-Csv -Path $hw -NoTypeInformation -Encoding UTF8
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } | Sort-Object DisplayName -Unique |
        Select-Object @{ n = 'Computer'; e = { $env:COMPUTERNAME } }, DisplayName, DisplayVersion, Publisher, InstallDate |
        Export-Csv -Path $sw -NoTypeInformation -Encoding UTF8
    $row | Format-List
    Log "Hardware: $hw" 'OK'
    Log "Software: $sw" 'OK'
}

Register-Tool 'Reports' 'Ticket notes' 'Summary of this session to paste into a ticket' { Show-TicketNotes } -Launch
Register-Tool 'Reports' 'Open latest report' 'Opens the newest saved report' { Open-LatestReport } -Launch

Register-Tool 'Reports' 'Log bundle for escalation' 'One zip with event logs, system info, drivers, dumps, reports and this session''s log' -SaveSessionLog {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $dir = Join-Path $ITK_TempDir "LogBundle_$($env:COMPUTERNAME)_$stamp"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Log 'Collecting system information...'
    systeminfo.exe | Out-File "$dir\systeminfo.txt" -Encoding UTF8
    ipconfig.exe /all | Out-File "$dir\ipconfig.txt" -Encoding UTF8
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object DisplayName | Sort-Object DisplayName -Unique | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Export-Csv "$dir\software.csv" -NoTypeInformation -Encoding UTF8
    Get-Service | Select-Object Name, DisplayName, Status, StartType | Export-Csv "$dir\services.csv" -NoTypeInformation -Encoding UTF8
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object Name, Id, @{ n = 'RAM MB'; e = { [math]::Round($_.WorkingSet64 / 1MB) } }, Path | Export-Csv "$dir\processes.csv" -NoTypeInformation -Encoding UTF8
    driverquery.exe /v /fo csv | Out-File "$dir\drivers.csv" -Encoding UTF8
    Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | Select-Object Name, ConfigManagerErrorCode, DeviceID | Export-Csv "$dir\problem-devices.csv" -NoTypeInformation -Encoding UTF8
    Log 'Exporting event logs (last 7 days)...'
    foreach ($log in 'System', 'Application', 'Setup') {
        wevtutil.exe epl $log "$dir\$log.evtx" "/q:*[System[TimeCreated[timediff(@SystemTime) <= 604800000]]]" 2>&1 | Out-Null
    }
    Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 1000 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, LogName, ProviderName, Id, LevelDisplayName, Message | Export-Csv "$dir\errors-7days.csv" -NoTypeInformation -Encoding UTF8
    Log 'Running dxdiag...'
    Start-Process dxdiag.exe -ArgumentList '/t', "`"$dir\dxdiag.txt`"" -Wait -ErrorAction SilentlyContinue
    gpresult.exe /scope computer /h "$dir\gpresult-computer.html" /f 2>&1 | Out-Null
    Log 'Running msinfo32 (this takes a minute or two)...'
    Start-Process msinfo32.exe -ArgumentList '/report', "`"$dir\msinfo32.txt`"" -Wait -ErrorAction SilentlyContinue
    $dumps = @(Get-ChildItem "$env:windir\Minidump\*.dmp" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5)
    if ($dumps) { New-Item -ItemType Directory -Path "$dir\Minidump" -Force | Out-Null; $dumps | Copy-Item -Destination "$dir\Minidump" -ErrorAction SilentlyContinue }
    $cbs = "$env:windir\Logs\CBS\CBS.log"
    if ((Test-Path $cbs) -and (Get-Item $cbs).Length -lt 50MB) { Copy-Item $cbs "$dir\CBS.log" -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path "$dir\ITToolkit" -Force | Out-Null
    Get-ChildItem $ITK_ReportDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.html', '.csv', '.txt' } | Sort-Object LastWriteTime -Descending | Select-Object -First 8 | Copy-Item -Destination "$dir\ITToolkit" -ErrorAction SilentlyContinue
    Get-ChildItem (Join-Path $ITK_DataDir 'Logs') -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | Copy-Item -Destination "$dir\ITToolkit" -ErrorAction SilentlyContinue
    $zip = Join-Path $ITK_ReportDir "LogBundle_$($env:COMPUTERNAME)_$stamp.zip"
    Log 'Zipping...'
    Compress-Archive -Path "$dir\*" -DestinationPath $zip -Force
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    Log ("Log bundle saved: {0} ({1})" -f $zip, (Format-Size (Get-Item $zip).Length)) 'OK'
}

Register-Tool 'Reports' 'Take snapshot' 'Records apps, services, startup, drivers, printers and settings to compare later' {
    $dir = Join-Path $ITK_DataDir 'Snapshots'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $snap = Get-SystemSnapshot
    $file = Join-Path $dir ('Snapshot_{0}_{1:yyyyMMdd_HHmmss}.json' -f $env:COMPUTERNAME, (Get-Date))
    $snap | ConvertTo-Json -Depth 5 | Set-Content -Path $file -Encoding UTF8
    foreach ($k in $snap.Sections.Keys) { Log ('{0,-24} {1}' -f $k, $snap.Sections[$k].Count) }
    Log "Snapshot saved: $file. Do your work, then run 'Compare with snapshot'." 'OK'
}
Register-Tool 'Reports' 'Compare with snapshot' 'Shows what changed since the last snapshot (added, removed, changed)' {
    $dir = Join-Path $ITK_DataDir 'Snapshots'
    $last = Get-ChildItem $dir -Filter 'Snapshot_*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $last) { Log "No snapshot yet. Run 'Take snapshot' first." 'WARN'; return }
    $old = Get-Content $last.FullName -Raw | ConvertFrom-Json
    $new = Get-SystemSnapshot
    Log "Comparing with snapshot from $($old.Taken)"
    $report = New-Object System.Collections.Generic.List[string]
    $report.Add("Changes on $env:COMPUTERNAME since $($old.Taken) (compared $($new.Taken))")
    $total = 0
    foreach ($section in $new.Sections.Keys) {
        $o = @{}; if ($old.Sections.$section) { foreach ($p in $old.Sections.$section.PSObject.Properties) { $o[$p.Name] = [string]$p.Value } }
        $n = $new.Sections[$section]
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($k in $n.Keys) {
            if (-not $o.ContainsKey($k)) { $lines.Add("  + $k  ($($n[$k]))") }
            elseif ($o[$k] -ne [string]$n[$k]) { $lines.Add("  ~ $k  ($($o[$k]) -> $($n[$k]))") }
        }
        foreach ($k in $o.Keys) { if (-not $n.Contains($k)) { $lines.Add("  - $k  ($($o[$k]))") } }
        if ($lines.Count) {
            $total += $lines.Count
            Log "$section ($($lines.Count) change$(if ($lines.Count -ne 1) { 's' }))" 'WARN'
            Log ($lines -join "`n")
            $report.Add(''); $report.Add($section); $report.AddRange($lines)
        }
    }
    if (-not $total) { Log 'No changes found.' 'OK'; return }
    $file = Join-Path $ITK_ReportDir "Changes_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd_HHmm).txt"
    New-Item -ItemType Directory -Path $ITK_ReportDir -Force | Out-Null
    $report | Set-Content -Path $file -Encoding UTF8
    Log "$total change(s). Saved: $file   (+ added, - removed, ~ changed)" 'OK'
}
