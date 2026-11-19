# Domain & Entra - workstation-side checks only (no domain controller access needed)
Register-Tool 'Domain & Entra' 'Join status' 'Domain, Entra ID (Azure AD), hybrid and Intune enrolment state' {
    $cs = Get-CimInstance Win32_ComputerSystem
    Log ('Computer: {0}   Domain / workgroup: {1}   Domain joined: {2}' -f $env:COMPUTERNAME, $cs.Domain, $cs.PartOfDomain)
    $want = 'AzureAdJoined', 'EnterpriseJoined', 'DomainJoined', 'DomainName', 'DeviceName', 'TenantName', 'TenantId', 'DeviceId', 'DeviceAuthStatus', 'MdmUrl', 'KeySignTest'
    $rows = foreach ($l in (dsregcmd.exe /status)) {
        if ($l -match '^\s*(\w+)\s*:\s*(.*)$' -and $want -contains $Matches[1]) { [pscustomobject]@{ Setting = $Matches[1]; Value = $Matches[2].Trim() } }
    }
    $rows | Format-Table -AutoSize
    $mdm = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.ProviderID -eq 'MS DM Server' } | Select-Object -First 1
    if ($mdm) { Log "Intune / MDM enrolled as $($mdm.UPN)" 'OK' } else { Log 'Not enrolled in Intune / MDM.' }
}
Register-Tool 'Domain & Entra' 'User sign-in state (SSO)' 'Entra sign-in token (PRT) and work account state for the signed-in user' {
    $out = Invoke-AsUser -Script 'dsregcmd.exe /status'
    $want = 'AzureAdPrt', 'AzureAdPrtUpdateTime', 'AzureAdPrtExpiryTime', 'WorkplaceJoined', 'WamDefaultSet', 'NgcSet', 'NgcKeyId', 'IsUserAzureAD', 'Executing Account Name'
    foreach ($l in ($out -split "`r?`n")) {
        if ($l -match '^\s*([\w ]+?)\s*:\s*(.*)$' -and $want -contains $Matches[1]) {
            $lvl = if ($Matches[1] -eq 'AzureAdPrt') { if ($Matches[2] -match 'YES') { 'OK' } else { 'WARN' } } else { 'INFO' }
            Log ('{0,-24} {1}' -f $Matches[1], $Matches[2].Trim()) $lvl
        }
    }
    Log 'AzureAdPrt = NO on an Entra-joined PC usually means the user needs to sign out and in, or the device lost its trust.'
}
Register-Tool 'Domain & Entra' 'Test domain connection' 'Finds a domain controller, checks the secure channel, DNS records and time source' {
    $cs = Get-CimInstance Win32_ComputerSystem
    if (-not $cs.PartOfDomain) { Log 'This PC is not joined to an on-premises domain.' 'WARN'; return }
    $d = $cs.Domain
    Log "Domain: $d"
    Log 'Domain controller:'; nltest.exe /dsgetdc:$d
    try { $ok = Test-ComputerSecureChannel -ErrorAction Stop; Log "Secure channel (computer trust): $(if ($ok) { 'OK' } else { 'BROKEN - needs Test-ComputerSecureChannel -Repair with domain admin credentials' })" $(if ($ok) { 'OK' } else { 'ERROR' }) }
    catch { Log "Secure channel check failed: $($_.Exception.Message)" 'ERROR' }
    try { Resolve-DnsName "_ldap._tcp.dc._msdcs.$d" -Type SRV -ErrorAction Stop | Where-Object Type -eq 'SRV' | Select-Object NameTarget, Port, Priority | Format-Table -AutoSize }
    catch { Log "DNS cannot find domain controllers for $d - check the PC's DNS servers point at the domain DNS." 'ERROR' }
    Log "Time source: $(w32tm /query /source)"
}
Register-Tool 'Domain & Entra' 'Group Policy results' 'Applied policies for the computer and the signed-in user, plus an HTML report' {
    New-Item -ItemType Directory -Path $ITK_ReportDir -Force | Out-Null
    $html = Join-Path $ITK_ReportDir "GPResult_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd_HHmm).html"
    Log 'Computer policies:'
    gpresult.exe /scope computer /r
    gpresult.exe /scope computer /h $html /f | Out-Null
    if (Get-ConsoleUser) { Log 'User policies (signed-in user):'; Invoke-AsUser -TimeoutSec 180 -Script 'gpresult.exe /scope user /r' }
    if (Test-Path $html) { Log "HTML report saved: $html" 'OK' }
}
Register-Tool 'Domain & Entra' 'Intune sync now' 'Triggers an Intune check-in and an app (IME) refresh' {
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq 'PushLaunch' -or ($_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*' -and $_.TaskName -like '*Schedule #3*') })
    if (-not $tasks) { Log 'No Intune enrolment tasks found - this PC is probably not enrolled.' 'WARN' }
    foreach ($t in $tasks) { Start-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName; Log "Started $($t.TaskName)" 'OK' }
    if (Get-Service IntuneManagementExtension -ErrorAction SilentlyContinue) { Restart-Service IntuneManagementExtension -Force; Log 'Intune Management Extension restarted (Win32 apps and scripts re-check).' 'OK' }
}
Register-Tool 'Domain & Entra' 'Intune diagnostics bundle' 'MDM diagnostics zip for enrolment / Autopilot problems' {
    New-Item -ItemType Directory -Path $ITK_ReportDir -Force | Out-Null
    $zip = Join-Path $ITK_ReportDir "MDMDiag_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd_HHmm).zip"
    MdmDiagnosticsTool.exe -area 'DeviceEnrollment;DeviceProvisioning;Autopilot' -zip $zip
    if (Test-Path $zip) { Log "Saved: $zip" 'OK' } else { Log 'MdmDiagnosticsTool did not create a file.' 'WARN' }
}
Register-Tool 'Domain & Entra' 'Intune app errors (IME log)' 'Recent errors from the Intune Management Extension log' {
    $log = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
    if (-not (Test-Path $log)) { Log 'Intune Management Extension is not installed on this PC.' 'WARN'; return }
    $hits = Select-String -Path $log -Pattern 'error|failed|exception' -SimpleMatch:$false | Select-Object -Last 30
    if (-not $hits) { Log 'No recent errors in the IME log.' 'OK'; return }
    foreach ($h in $hits) { $t = ($h.Line -replace '<!\[LOG\[', '' -replace '\]LOG\]!>.*$', ''); if ($t.Length -gt 220) { $t = $t.Substring(0, 220) + '...' }; Log $t 'WARN' }
}
