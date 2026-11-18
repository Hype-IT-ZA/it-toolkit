# Security & Users
Register-Tool 'Security & Users' 'Antivirus status' 'Defender + registered AV products' {
    try { Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
            Select-Object @{ n = 'Registered AV'; e = { $_.displayName } }, @{ n = 'Enabled'; e = { ($_.productState -band 0x1000) -ne 0 } } | Format-Table -AutoSize } catch {}
    try {
        Get-MpComputerStatus -ErrorAction Stop | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanEndTime, FullScanEndTime | Format-List
    } catch { Log 'Defender status unavailable (another AV may be in charge).' 'WARN' }
}
Register-Tool 'Security & Users' 'Update Defender signatures' 'Pull the latest definitions' { Update-MpSignature -ErrorAction Stop; Log 'Signatures updated.' 'OK' }
Register-Tool 'Security & Users' 'Defender quick scan' 'Runs a quick scan (several minutes)' { Log 'Quick scan started...'; Start-MpScan -ScanType QuickScan -ErrorAction Stop; Log 'Quick scan finished.' 'OK'; Get-MpThreatDetection | Select-Object -First 10 | Format-Table -AutoSize }
Register-Tool 'Security & Users' 'Microsoft Safety Scanner' 'Second-opinion scan, detect only (downloads ~200 MB)' {
    $exe = Join-Path $env:TEMP 'msert.exe'
    Log 'Downloading Microsoft Safety Scanner...'
    $url = if ([Environment]::Is64BitOperatingSystem) { 'https://go.microsoft.com/fwlink/?LinkId=212732' } else { 'https://go.microsoft.com/fwlink/?LinkId=212733' }
    Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing -ErrorAction Stop
    Log 'Scanning (quick scan, detect only - nothing is removed). This can take 10+ minutes...'
    $p = Start-Process -FilePath $exe -ArgumentList '/Q', '/N' -Wait -PassThru
    $logFile = "$env:windir\debug\msert.log"
    if (Test-Path $logFile) { Get-Content $logFile -Tail 25 }
    Log "Scan finished (exit code $($p.ExitCode)). Full log: $logFile" 'OK'
    Remove-Item $exe -Force -ErrorAction SilentlyContinue
}
Register-Tool 'Security & Users' 'Firewall status' 'Domain / Private / Public profiles' { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize }
Register-Tool 'Security & Users' 'BitLocker recovery key' 'Show recovery passwords to back them up' {
    try {
        $vols = Get-BitLockerVolume -ErrorAction Stop
        foreach ($v in $vols) {
            $keys = $v.KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword'
            if ($keys) { foreach ($k in $keys) { Log ("{0}  ID {1}  Key {2}" -f $v.MountPoint, $k.KeyProtectorId, $k.RecoveryPassword) 'OK' } }
            else { Log "$($v.MountPoint): $($v.VolumeStatus) - no recovery password" }
        }
    } catch { manage-bde -protectors -get "$env:SystemDrive" }
}
Register-Tool 'Security & Users' 'BitLocker status' 'Encryption state of each volume' {
    try { Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage, EncryptionMethod | Format-Table -AutoSize }
    catch { manage-bde -status }
}
Register-Tool 'Security & Users' 'Enable Remote Desktop' 'Turns on RDP with NLA and opens the firewall' -Confirm 'Remote Desktop will be turned on for this PC. Continue?' {
    Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
    Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue
    Log 'Remote Desktop enabled (Network Level Authentication on).' 'OK'
}
Register-Tool 'Security & Users' 'Disable Remote Desktop' 'Turns RDP off and closes the firewall rule' -Confirm 'Remote Desktop will be turned off for this PC. Continue?' {
    Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 1
    Disable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue
    Log 'Remote Desktop disabled.' 'OK'
}
Register-Tool 'Security & Users' 'Local users' 'Accounts, enabled, last logon' { Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordLastSet, PasswordExpires | Format-Table -AutoSize }
Register-Tool 'Security & Users' 'Local administrators' 'Members of the Administrators group' {
    try { Get-LocalGroupMember -Group Administrators -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource | Format-Table -AutoSize } catch { net localgroup administrators }
}
Register-Tool 'Security & Users' 'Failed logons (24h)' 'Event 4625 summary by account' {
    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = (Get-Date).AddHours(-24) } -ErrorAction SilentlyContinue
    if (-not $ev) { Log 'No failed logons in the last 24 hours.' 'OK'; return }
    Log "$(@($ev).Count) failed logons in the last 24 hours" 'WARN'
    $ev | ForEach-Object { ([xml]$_.ToXml()).Event.EventData.Data | Where-Object Name -eq 'TargetUserName' | ForEach-Object { $_.'#text' } } |
        Group-Object | Sort-Object Count -Descending | Select-Object @{ n = 'Account'; e = { $_.Name } }, Count | Format-Table -AutoSize
}
Register-Tool 'Security & Users' 'Recent errors (24h)' 'Critical + error events, System & Application' {
    Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddHours(-24) } -MaxEvents 40 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, LogName, ProviderName, Id, @{ n = 'Message'; e = { $m = ("$($_.Message)" -split "`n")[0].Trim(); if ($m.Length -gt 100) { $m.Substring(0, 100) + '...' } else { $m } } } |
        Format-Table -AutoSize
}
Register-Tool 'Security & Users' 'Shutdown history (30 days)' 'Restarts, crashes, unexpected shutdowns' {
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 1074, 6008; StartTime = (Get-Date).AddDays(-30) } -MaxEvents 30 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, @{ n = 'Type'; e = { @{41 = 'Crash / power loss'; 1074 = 'Planned restart/shutdown'; 6008 = 'Unexpected shutdown' }[$_.Id] } },
            @{ n = 'Detail'; e = { $m = ("$($_.Message)" -split "`n")[0].Trim(); if ($m.Length -gt 90) { $m.Substring(0, 90) + '...' } else { $m } } } |
        Format-Table -AutoSize
}
