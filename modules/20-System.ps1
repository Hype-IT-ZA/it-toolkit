# System
Register-Tool 'System' 'System summary' 'Model, serial, OS, CPU, RAM, uptime' {
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS; $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $up = (Get-Date) - $os.LastBootUpTime
    $dv = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
    [pscustomobject]@{
        Computer = $env:COMPUTERNAME; Domain = $cs.Domain; 'Signed-in user' = (Get-ConsoleUser)
        Manufacturer = $cs.Manufacturer; Model = $cs.Model; Serial = $bios.SerialNumber; BIOS = $bios.SMBIOSBIOSVersion
        OS = "$($os.Caption) $dv"; Version = "$($os.Version) (build $($os.BuildNumber))"; Installed = $os.InstallDate
        CPU = $cpu.Name.Trim(); Cores = "$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
        'RAM (GB)' = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        'Last boot' = $os.LastBootUpTime; Uptime = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
    } | Format-List
}
Register-Tool 'System' 'Performance snapshot' 'CPU load, memory use, top CPU processes' {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
    $memUsed = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    Log ('CPU load: {0}%   Memory used: {1}% of {2:N1} GB' -f $cpuLoad, $memUsed, ($os.TotalVisibleMemorySize / 1MB)) $(if ($cpuLoad -gt 85 -or $memUsed -gt 90) { 'WARN' } else { 'OK' })
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -notin '_Total', 'Idle' } | Sort-Object PercentProcessorTime -Descending | Select-Object -First 10 |
        Select-Object @{ n = 'Process'; e = { $_.Name } }, @{ n = 'PID'; e = { $_.IDProcess } }, @{ n = 'CPU % (all cores)'; e = { $_.PercentProcessorTime } }, @{ n = 'RAM (MB)'; e = { [math]::Round($_.WorkingSetPrivate / 1MB) } } |
        Format-Table -AutoSize
}
Register-Tool 'System' 'Pending reboot check' 'Is Windows waiting for a restart?' {
    $checks = [ordered]@{
        'Component Based Servicing' = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'Windows Update'            = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        'Pending file renames'      = [bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    }
    foreach ($k in $checks.Keys) { Log ('{0,-28} {1}' -f $k, $(if ($checks[$k]) { 'PENDING' } else { 'no' })) $(if ($checks[$k]) { 'WARN' } else { 'INFO' }) }
    if ($checks.Values -contains $true) { Log 'A reboot is pending.' 'WARN' } else { Log 'No reboot pending.' 'OK' }
}
Register-Tool 'System' 'Windows 11 readiness' 'TPM, Secure Boot, CPU, RAM and disk check' {
    $fail = 0
    function Out-Check($name, $ok, $detail) { Log ('{0,-14} {1,-5} {2}' -f $name, $(if ($ok -eq $true) { 'PASS' } elseif ($ok -eq $false) { 'FAIL' } else { 'CHECK' }), $detail) $(if ($ok -eq $true) { 'OK' } elseif ($ok -eq $false) { 'ERROR' } else { 'WARN' }) }
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem
    if ($os.Caption -match 'Windows 11') { Log "This PC already runs $($os.Caption)." 'OK' }
    $tpm = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if ($tpm) {
        $spec = [double](($tpm.SpecVersion -split ',')[0])
        Out-Check 'TPM' ($spec -ge 2.0 -and $tpm.IsEnabled_InitialValue) "Version $spec, enabled: $($tpm.IsEnabled_InitialValue)"
    } else { Out-Check 'TPM' $false 'No TPM found (check BIOS: PTT / fTPM)' }
    try { $sb = Confirm-SecureBootUEFI -ErrorAction Stop; Out-Check 'Secure Boot' $sb $(if ($sb) { 'On (UEFI)' } else { 'UEFI but Secure Boot is off' }) }
    catch { Out-Check 'Secure Boot' $false 'Legacy BIOS boot or not supported' }
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuOk = $null; $n = $cpu.Name
    if ($n -match 'Intel.*Core.*i[3579]-(\d{4,5})') { $gen = [int]($Matches[1].Substring(0, $(if ($Matches[1].Length -eq 5) { 2 } else { 1 }))); $cpuOk = $gen -ge 8 }
    elseif ($n -match 'Core\(TM\) Ultra|Core Ultra') { $cpuOk = $true }
    elseif ($n -match 'Ryzen \d+ (\d)\d{3}') { $cpuOk = [int]$Matches[1] -ge 2 }
    Out-Check 'CPU' $cpuOk "$($n.Trim())$(if ($null -eq $cpuOk) { ' - check Microsoft''s supported CPU list' })"
    $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1); Out-Check 'RAM' ($ram -ge 3.8) "$ram GB (4 GB minimum)"
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"; $gb = [math]::Round($disk.Size / 1GB)
    Out-Check 'System disk' ($gb -ge 64) "$gb GB (64 GB minimum)"
    Out-Check '64-bit OS' ([Environment]::Is64BitOperatingSystem) $os.OSArchitecture
}
Register-Tool 'System' 'Startup programs' 'Apps that start with Windows' {
    Get-CimInstance Win32_StartupCommand | Select-Object Name, User, Location, Command | Format-Table -AutoSize -Wrap
}
Register-Tool 'System' 'Scheduled tasks (non-Microsoft)' 'Third-party scheduled tasks' {
    Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.TaskName -notlike 'ITToolkit_*' } |
        Select-Object TaskName, State, TaskPath, @{ n = 'Runs'; e = { ($_.Actions | ForEach-Object { $_.Execute }) -join '; ' } } | Format-Table -AutoSize
}
Register-Tool 'System' 'Windows activation' 'License status and partial key' {
    Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" |
        Select-Object Name, @{ n = 'Status'; e = { @{0 = 'Unlicensed'; 1 = 'Licensed'; 2 = 'OOB grace'; 3 = 'OOT grace'; 4 = 'Non-genuine grace'; 5 = 'Notification'; 6 = 'Extended grace' }[[int]$_.LicenseStatus] } }, PartialProductKey |
        Format-List
}
Register-Tool 'System' 'Devices with problems' 'Device Manager errors (yellow bangs)' {
    $bad = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    if (-not $bad) { Log 'No problem devices found.' 'OK'; return }
    $bad | Select-Object Name, @{ n = 'Error code'; e = { $_.ConfigManagerErrorCode } }, PNPClass, DeviceID | Format-Table -AutoSize
}
Register-Tool 'System' 'Battery health' 'Capacity vs design + full HTML report' {
    try {
        $full = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        if ($full -and $design) {
            $h = [math]::Round($full / $design * 100)
            Log ('Design: {0:N0} mWh   Full charge: {1:N0} mWh   Health: {2}%' -f $design, $full, $h) $(if ($h -lt 60) { 'WARN' } else { 'OK' })
        }
    } catch { Log 'No battery detected (desktop?).' 'WARN'; return }
    $out = Join-Path $ITK_ReportDir "Battery_$($env:COMPUTERNAME).html"
    New-Item -ItemType Directory -Path $ITK_ReportDir -Force | Out-Null
    powercfg /batteryreport /output $out | Out-Null
    if (Test-Path $out) { Log "Full report saved to $out" }
}
Register-Tool 'System' 'Drivers (third-party)' 'Non-Microsoft drivers with versions and dates' {
    Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DriverProviderName -and $_.DriverProviderName -notmatch '^Microsoft' } |
        Sort-Object DeviceClass, DeviceName | Select-Object DeviceClass, DeviceName, DriverProviderName, DriverVersion, @{ n = 'Date'; e = { if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } } } |
        Format-Table -AutoSize
}
