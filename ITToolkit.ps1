<#
.SYNOPSIS
    IT Toolkit - a themed (dark / light) GUI toolbox of everyday IT tools.
    Built to run inside ScreenConnect Backstage (runs fine as SYSTEM, no Explorer needed).

.HOW TO RUN
    One-liner (downloads the latest version to C:\ProgramData\ITToolkit and starts it):
        irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex

    From a local copy:
        powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "C:\ProgramData\ITToolkit\ITToolkit.ps1"

.LINK
    https://github.com/Hype-IT-ZA/it-toolkit

.ADDING YOUR OWN TOOLS
    Drop any .ps1 file into a "Tools" folder next to this script. Each file just calls Register-Tool:

        Register-Tool -Category 'My Tools' -Name 'Hello' -Description 'Says hi' -Action {
            Log 'Hello!' 'OK'          # Log levels: INFO, OK, WARN, ERROR
            Get-Date                   # any output is shown in the console
        }

    Options:
        -Inputs  'Key|Prompt text|Default'   ask for values first -> use param($P) and $P.Key
        -Confirm 'Are you sure?'             show a Yes/No warning before running
        -Launch                              run instantly on the UI thread (for opening apps)

    Normal tools run in the background, so the window never freezes and you can run several at once.

.NOTES
    Settings + logs: C:\ProgramData\ITToolkit
#>
param([switch]$NoRelaunch)

# WinForms needs an STA thread - relaunch if needed
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA' -and -not $NoRelaunch -and $PSCommandPath) {
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"", '-NoRelaunch')
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

if (-not ('ITK.Native' -as [type])) {
    Add-Type -Namespace ITK -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
'@
}

# =====================================================================
#  CONFIG
# =====================================================================
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Config = @{
    AppName  = 'IT Toolkit'
    Version  = '1.0.0'
    DataDir  = Join-Path $env:ProgramData 'ITToolkit'
    ToolsDir = Join-Path $ScriptDir 'Tools'
}
$Config.LogDir = Join-Path $Config.DataDir 'Logs'
$SettingsFile  = Join-Path $Config.DataDir 'settings.json'
New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null

$Settings = @{ Theme = 'Dark' }
if (Test-Path $SettingsFile) {
    try { $s = Get-Content $SettingsFile -Raw | ConvertFrom-Json; if ($s.Theme) { $Settings.Theme = $s.Theme } } catch {}
}

$Themes = @{
    Dark  = @{
        Bg = '#15171c'; Sidebar = '#1b1e24'; Surface = '#1f2229'; Card = '#252932'; CardHover = '#2e3340'
        Border = '#353b47'; Text = '#e7e9ee'; Muted = '#98a1b0'; Accent = '#2563eb'; AccentHover = '#1d4fc4'; Link = '#60a5fa'
        AccentText = '#ffffff'; Console = '#0f1115'; ConsoleText = '#d5d9e0'; Input = '#252932'
        Ok = '#4ade80'; Warn = '#fbbf24'; Err = '#f87171'
    }
    Light = @{
        Bg = '#f3f4f7'; Sidebar = '#ffffff'; Surface = '#ffffff'; Card = '#ffffff'; CardHover = '#eef3ff'
        Border = '#dde1e8'; Text = '#1d2330'; Muted = '#5d6878'; Accent = '#2563eb'; AccentHover = '#1d4fc4'; Link = '#1d4fc4'
        AccentText = '#ffffff'; Console = '#fafbfc'; ConsoleText = '#1d2330'; Input = '#ffffff'
        Ok = '#15803d'; Warn = '#b45309'; Err = '#b91c1c'
    }
}
$script:ThemeName = if ($Themes.ContainsKey($Settings.Theme)) { $Settings.Theme } else { 'Dark' }
$script:CurrentCategory = 'All tools'

# =====================================================================
#  TOOL REGISTRY
# =====================================================================
$script:Tools = New-Object System.Collections.Generic.List[object]
$script:CategoryOrder = New-Object System.Collections.Generic.List[string]

function Register-Tool {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Name,
        [string]$Description = '',
        [Parameter(Mandatory)][scriptblock]$Action,
        [string[]]$Inputs = @(),
        [string]$Confirm,
        [switch]$Launch
    )
    if (-not $script:CategoryOrder.Contains($Category)) { $script:CategoryOrder.Add($Category) }
    $script:Tools.Add([pscustomobject]@{
        Category = $Category; Name = $Name; Description = $Description; Action = $Action
        Inputs = @($Inputs | Where-Object { $_ }); Confirm = $Confirm; Launch = [bool]$Launch
    })
}

# ---------------- Quick Launch (opens on the Backstage desktop) ----------------
Register-Tool 'Quick Launch' 'Task Manager'        'Processes, performance, startup apps'      { Start-Process taskmgr.exe } -Launch
Register-Tool 'Quick Launch' 'Command Prompt'      'New cmd.exe window'                         { Start-Process cmd.exe } -Launch
Register-Tool 'Quick Launch' 'PowerShell'          'New PowerShell window'                      { Start-Process powershell.exe -ArgumentList '-NoExit', '-NoProfile' } -Launch
Register-Tool 'Quick Launch' 'Registry Editor'     'regedit'                                    { Start-Process regedit.exe } -Launch
Register-Tool 'Quick Launch' 'Services'            'services.msc'                               { Start-Process mmc.exe 'services.msc' } -Launch
Register-Tool 'Quick Launch' 'Event Viewer'        'eventvwr.msc'                               { Start-Process mmc.exe 'eventvwr.msc' } -Launch
Register-Tool 'Quick Launch' 'Device Manager'      'devmgmt.msc'                                { Start-Process mmc.exe 'devmgmt.msc' } -Launch
Register-Tool 'Quick Launch' 'Computer Management' 'compmgmt.msc'                               { Start-Process mmc.exe 'compmgmt.msc' } -Launch
Register-Tool 'Quick Launch' 'Disk Management'     'diskmgmt.msc'                               { Start-Process mmc.exe 'diskmgmt.msc' } -Launch
Register-Tool 'Quick Launch' 'Local Users & Groups' 'lusrmgr.msc (Pro / Enterprise only)'       { Start-Process mmc.exe 'lusrmgr.msc' } -Launch
Register-Tool 'Quick Launch' 'System Information'  'msinfo32'                                   { Start-Process msinfo32.exe } -Launch
Register-Tool 'Quick Launch' 'Edit hosts file'     'Opens the hosts file in Notepad'            { Start-Process notepad.exe "$env:windir\System32\drivers\etc\hosts" } -Launch

# ---------------- System ----------------
Register-Tool 'System' 'System summary' 'Model, serial, OS, CPU, RAM, uptime' {
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS; $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $up = (Get-Date) - $os.LastBootUpTime
    [pscustomobject]@{
        Computer = $env:COMPUTERNAME; Domain = $cs.Domain; 'Logged-on user' = $cs.UserName
        Manufacturer = $cs.Manufacturer; Model = $cs.Model; Serial = $bios.SerialNumber; BIOS = $bios.SMBIOSBIOSVersion
        OS = $os.Caption; Version = "$($os.Version) (build $($os.BuildNumber))"; Installed = $os.InstallDate
        CPU = $cpu.Name.Trim(); Cores = "$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
        'RAM (GB)' = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        'Last boot' = $os.LastBootUpTime; Uptime = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
    } | Format-List
}
Register-Tool 'System' 'Performance snapshot' 'CPU load, memory use, top CPU processes' {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
    $memUsed = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    Log ("CPU load: {0}%   Memory used: {1}% of {2:N1} GB" -f $cpuLoad, $memUsed, ($os.TotalVisibleMemorySize / 1MB)) $(if ($cpuLoad -gt 85 -or $memUsed -gt 90) { 'WARN' } else { 'OK' })
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -notin '_Total', 'Idle' } | Sort-Object PercentProcessorTime -Descending | Select-Object -First 10 |
        Select-Object @{n = 'Process'; e = { $_.Name } }, @{n = 'PID'; e = { $_.IDProcess } }, @{n = 'CPU % (all cores)'; e = { $_.PercentProcessorTime } }, @{n = 'RAM (MB)'; e = { [math]::Round($_.WorkingSetPrivate / 1MB) } } |
        Format-Table -AutoSize
}
Register-Tool 'System' 'Installed software' 'List installed programs (optional filter)' -Inputs 'Filter|Name contains (leave blank for all)|' {
    param($P)
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $f = $P.Filter
    $apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent -and (-not $f -or $_.DisplayName -like "*$f*") } |
        Sort-Object DisplayName -Unique
    Log "$(@($apps).Count) programs found"
    $apps | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table -AutoSize
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
Register-Tool 'System' 'Startup programs' 'Apps that start with Windows' {
    Get-CimInstance Win32_StartupCommand | Select-Object Name, User, Location, Command | Format-Table -AutoSize -Wrap
}
Register-Tool 'System' 'Scheduled tasks (non-Microsoft)' 'Third-party scheduled tasks' {
    Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
        Select-Object TaskName, State, TaskPath, @{n = 'Runs'; e = { ($_.Actions | ForEach-Object { $_.Execute }) -join '; ' } } | Format-Table -AutoSize
}
Register-Tool 'System' 'Windows activation' 'License status and partial key' {
    Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" |
        Select-Object Name, @{n = 'Status'; e = { @{0 = 'Unlicensed'; 1 = 'Licensed'; 2 = 'OOB grace'; 3 = 'OOT grace'; 4 = 'Non-genuine grace'; 5 = 'Notification'; 6 = 'Extended grace' }[[int]$_.LicenseStatus] } }, PartialProductKey |
        Format-List
}
Register-Tool 'System' 'Devices with problems' 'Device Manager errors (yellow bangs)' {
    $bad = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    if (-not $bad) { Log 'No problem devices found.' 'OK'; return }
    $bad | Select-Object Name, @{n = 'Error code'; e = { $_.ConfigManagerErrorCode } }, PNPClass, DeviceID | Format-Table -AutoSize
}
Register-Tool 'System' 'Battery health' 'Capacity vs design + full HTML report' {
    try {
        $full = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        if ($full -and $design) {
            $h = [math]::Round($full / $design * 100)
            Log ("Design: {0:N0} mWh   Full charge: {1:N0} mWh   Health: {2}%" -f $design, $full, $h) $(if ($h -lt 60) { 'WARN' } else { 'OK' })
        }
    } catch { Log 'No battery detected (desktop?).' 'WARN'; return }
    $out = Join-Path $env:ProgramData 'ITToolkit\battery-report.html'
    powercfg /batteryreport /output $out | Out-Null
    if (Test-Path $out) { Log "Full report saved to $out" }
}
Register-Tool 'System' 'BitLocker status' 'Encryption state of each volume' {
    try { Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage, EncryptionMethod | Format-Table -AutoSize }
    catch { manage-bde -status }
}

# ---------------- Network ----------------
Register-Tool 'Network' 'IP configuration' 'Adapters, IPs, gateways, DNS' {
    Get-NetIPConfiguration | ForEach-Object {
        [pscustomobject]@{
            Adapter = $_.InterfaceAlias; Status = $_.NetAdapter.Status
            IPv4 = ($_.IPv4Address.IPAddress -join ', '); Gateway = ($_.IPv4DefaultGateway.NextHop -join ', ')
            DNS = (($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ', ')
        }
    } | Format-Table -AutoSize
}
Register-Tool 'Network' 'Network adapters' 'Link speed, MAC, status' {
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress | Format-Table -AutoSize
}
Register-Tool 'Network' 'Public IP' 'Internet-facing IP address' {
    try { Log ("Public IP: " + (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10)) 'OK' } catch { Log "Could not reach the internet: $($_.Exception.Message)" 'ERROR' }
}
Register-Tool 'Network' 'Ping' 'Ping a host 4 times' -Inputs 'Target|Hostname or IP|8.8.8.8' { param($P) ping.exe -n 4 $P.Target }
Register-Tool 'Network' 'Traceroute' 'Trace the route to a host' -Inputs 'Target|Hostname or IP|8.8.8.8' { param($P) tracert.exe -d -h 20 -w 800 $P.Target }
Register-Tool 'Network' 'Test port' 'Check if a TCP port is reachable' -Inputs 'Target|Hostname or IP|google.com', 'Port|Port number|443' {
    param($P)
    $r = Test-NetConnection -ComputerName $P.Target -Port ([int]$P.Port) -WarningAction SilentlyContinue
    Log ("{0}:{1} ({2}) -> {3}" -f $P.Target, $P.Port, $r.RemoteAddress, $(if ($r.TcpTestSucceeded) { 'OPEN' } else { 'CLOSED / filtered' })) $(if ($r.TcpTestSucceeded) { 'OK' } else { 'WARN' })
}
Register-Tool 'Network' 'DNS lookup' 'Resolve a name' -Inputs 'Name|Hostname to resolve|google.com' {
    param($P) Resolve-DnsName -Name $P.Name -ErrorAction Stop | Select-Object Name, Type, TTL, IPAddress, NameHost | Format-Table -AutoSize
}
Register-Tool 'Network' 'Flush DNS cache' 'ipconfig /flushdns' { ipconfig /flushdns }
Register-Tool 'Network' 'Renew DHCP lease' 'ipconfig /renew (no release)' -Confirm 'Renewing the IP can briefly drop the ScreenConnect session. It should reconnect by itself. Continue?' { ipconfig /renew }
Register-Tool 'Network' 'Reset network stack' 'Winsock + TCP/IP reset (needs reboot)' -Confirm 'This resets Winsock and TCP/IP settings. Static IPs may need re-entering and a reboot is required. Continue?' {
    netsh winsock reset; netsh int ip reset
    Log 'Done. Restart the PC to finish.' 'WARN'
}
Register-Tool 'Network' 'Wi-Fi status' 'SSID, signal, speed of the Wi-Fi adapter' { netsh wlan show interfaces }
Register-Tool 'Network' 'Active connections' 'Established TCP connections by process' {
    $names = @{}; Get-Process | ForEach-Object { $names[$_.Id] = $_.Name }
    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -notin '127.0.0.1', '::1' } |
        Select-Object @{n = 'Process'; e = { $names[[int]$_.OwningProcess] } }, OwningProcess, LocalPort, RemoteAddress, RemotePort |
        Sort-Object Process | Format-Table -AutoSize
}
Register-Tool 'Network' 'Proxy settings' 'WinHTTP proxy configuration' { netsh winhttp show proxy }

# ---------------- Disk & Cleanup ----------------
Register-Tool 'Disk & Cleanup' 'Disk space' 'Free space per drive' {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $pct = if ($_.Size) { [math]::Round($_.FreeSpace / $_.Size * 100, 1) } else { 0 }
        if ($pct -lt 10) { Log "$($_.DeviceID) is low on space ($pct% free)" 'WARN' }
        [pscustomobject]@{ Drive = $_.DeviceID; Label = $_.VolumeName; 'Size (GB)' = [math]::Round($_.Size / 1GB, 1); 'Free (GB)' = [math]::Round($_.FreeSpace / 1GB, 1); 'Free %' = $pct }
    } | Format-Table -AutoSize
}
Register-Tool 'Disk & Cleanup' 'Safe cleanup' 'Temp files + browser caches older than 2 days (all users)' {
    $cutoff = (Get-Date).AddDays(-2); $freed = 0; $count = 0; $skipped = 0
    $paths = @("$env:windir\Temp", "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue")
    Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath } | ForEach-Object {
        $u = $_.LocalPath
        $paths += "$u\AppData\Local\Temp", "$u\AppData\Local\Microsoft\Windows\INetCache", "$u\AppData\Local\CrashDumps"
        foreach ($b in 'Google\Chrome', 'Microsoft\Edge', 'BraveSoftware\Brave-Browser') {
            foreach ($c in 'Cache', 'Code Cache', 'GPUCache') { $paths += "$u\AppData\Local\$b\User Data\*\$c" }
        }
        $paths += "$u\AppData\Local\Mozilla\Firefox\Profiles\*\cache2"
    }
    $before = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    foreach ($path in $paths) {
        foreach ($dir in @(Get-Item -Path $path -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })) {
            $stack = New-Object System.Collections.Stack; $stack.Push($dir.FullName)
            while ($stack.Count) {
                foreach ($i in Get-ChildItem -LiteralPath $stack.Pop() -Force -ErrorAction SilentlyContinue) {
                    if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }   # never follow junctions
                    if ($i.PSIsContainer) { $stack.Push($i.FullName); continue }
                    if ($i.LastWriteTime -ge $cutoff) { continue }
                    try { $len = $i.Length; Remove-Item -LiteralPath $i.FullName -Force -ErrorAction Stop; $freed += $len; $count++ } catch { $skipped++ }
                }
            }
        }
    }
    $after = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    Log ("Removed {0:N0} files ({1:N1} MB). Skipped {2:N0} in-use files." -f $count, ($freed / 1MB), $skipped) 'OK'
    Log ("Free space: {0:N2} GB -> {1:N2} GB" -f ($before / 1GB), ($after / 1GB)) 'OK'
}
Register-Tool 'Disk & Cleanup' 'Clear Windows Update cache' 'Empties SoftwareDistribution\Download' -Confirm 'Windows Update services will be stopped briefly and downloaded update files removed (they re-download if needed). Continue?' {
    if ((Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or (Get-Process TiWorker -ErrorAction SilentlyContinue)) {
        Log 'Updates are installing or a reboot is pending - skipped for safety. Reboot first.' 'WARN'; return
    }
    $dl = "$env:windir\SoftwareDistribution\Download"
    $size = (Get-ChildItem $dl -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Get-ChildItem $dl -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv, bits -ErrorAction SilentlyContinue
    Log ("Cleared about {0:N1} MB of update downloads." -f ($size / 1MB)) 'OK'
}
Register-Tool 'Disk & Cleanup' 'Empty Recycle Bins' 'All users, system drive' -Confirm 'This permanently deletes everything in every user''s Recycle Bin on the system drive. Continue?' {
    $rb = "$env:SystemDrive\`$Recycle.Bin"
    $size = (Get-ChildItem $rb -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Get-ChildItem $rb -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Log ("Emptied about {0:N1} MB." -f ($size / 1MB)) 'OK'
}
Register-Tool 'Disk & Cleanup' 'Largest folders' 'Top 20 sub-folders by size' -Inputs 'Path|Folder to analyse|C:\Users' {
    param($P)
    if (-not (Test-Path $P.Path)) { Log "Path not found: $($P.Path)" 'ERROR'; return }
    Log "Measuring folders under $($P.Path) - this can take a minute..."
    Get-ChildItem -LiteralPath $P.Path -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object {
        $sum = (Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        [pscustomobject]@{ Folder = $_.FullName; 'Size (GB)' = [math]::Round($sum / 1GB, 2) }
    } | Sort-Object 'Size (GB)' -Descending | Select-Object -First 20 | Format-Table -AutoSize
}
Register-Tool 'Disk & Cleanup' 'Disk health' 'Physical disk status, wear and temperature' {
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus, @{n = 'Size (GB)'; e = { [math]::Round($_.Size / 1GB) } } | Format-Table -AutoSize
    try { Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours | Format-Table -AutoSize }
    catch { Log 'Reliability counters not available for this disk/driver.' 'WARN' }
}
Register-Tool 'Disk & Cleanup' 'Component store cleanup' 'DISM StartComponentCleanup (safe, 5-15 min)' { dism.exe /Online /Cleanup-Image /StartComponentCleanup /NoRestart }
Register-Tool 'Disk & Cleanup' 'Check disk (online scan)' 'chkdsk /scan - read-only check, no reboot' { chkdsk.exe "$env:SystemDrive" /scan }

# ---------------- Repair ----------------
Register-Tool 'Repair' 'SFC scan' 'System File Checker (sfc /scannow)' { sfc.exe /scannow }
Register-Tool 'Repair' 'DISM check health' 'Quick component store check' { dism.exe /Online /Cleanup-Image /CheckHealth }
Register-Tool 'Repair' 'DISM restore health' 'Repair Windows image (10-30 min)' { dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart }
Register-Tool 'Repair' 'Reset Windows Update' 'Renames update caches (kept as backup)' -Confirm 'This stops update services and renames SoftwareDistribution and catroot2 (backups are kept). Continue?' {
    $svcs = 'wuauserv', 'cryptSvc', 'bits', 'msiserver'
    Log 'Stopping update services...'
    foreach ($s in $svcs) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    foreach ($f in "$env:windir\SoftwareDistribution", "$env:windir\System32\catroot2") {
        if (Test-Path $f) {
            try { Rename-Item $f "$(Split-Path $f -Leaf).old_$stamp" -ErrorAction Stop; Log "Renamed $f (backup kept)" 'OK' }
            catch { Log "Could not rename $f : $($_.Exception.Message)" 'WARN' }
        }
    }
    foreach ($s in $svcs) { Start-Service $s -ErrorAction SilentlyContinue }
    Log 'Done. Windows Update will rebuild its cache. The .old folders can be deleted later.' 'OK'
}
Register-Tool 'Repair' 'Sync time' 'Force a Windows time resync' {
    Start-Service w32time -ErrorAction SilentlyContinue
    w32tm /resync /force
    w32tm /query /status
}
Register-Tool 'Repair' 'Group Policy update' 'gpupdate /force' { 'N' | gpupdate.exe /force }

# ---------------- Services & Processes ----------------
Register-Tool 'Services & Processes' 'Top processes (RAM)' '15 biggest processes by memory' {
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id,
        @{n = 'RAM (MB)'; e = { [math]::Round($_.WorkingSet64 / 1MB) } }, @{n = 'CPU (s)'; e = { [math]::Round($_.CPU, 1) } } | Format-Table -AutoSize
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

# ---------------- Security & Users ----------------
Register-Tool 'Security & Users' 'Antivirus status' 'Defender + registered AV products' {
    try {
        Get-MpComputerStatus -ErrorAction Stop | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanEndTime, FullScanEndTime | Format-List
    } catch { Log 'Defender status unavailable (another AV may be in charge).' 'WARN' }
    try { Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | Select-Object @{n = 'Registered AV'; e = { $_.displayName } } | Format-Table -AutoSize } catch {}
}
Register-Tool 'Security & Users' 'Update Defender signatures' 'Pull the latest definitions' { Update-MpSignature -ErrorAction Stop; Log 'Signatures updated.' 'OK' }
Register-Tool 'Security & Users' 'Defender quick scan' 'Runs a quick scan (several minutes)' { Log 'Quick scan started...'; Start-MpScan -ScanType QuickScan -ErrorAction Stop; Log 'Quick scan finished.' 'OK'; Get-MpThreatDetection | Select-Object -First 10 | Format-Table -AutoSize }
Register-Tool 'Security & Users' 'Firewall status' 'Domain / Private / Public profiles' { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize }
Register-Tool 'Security & Users' 'Local users' 'Accounts, enabled, last logon' { Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordLastSet, PasswordExpires | Format-Table -AutoSize }
Register-Tool 'Security & Users' 'Local administrators' 'Members of the Administrators group' {
    try { Get-LocalGroupMember -Group Administrators -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource | Format-Table -AutoSize } catch { net localgroup administrators }
}
Register-Tool 'Security & Users' 'Logged-on users' 'Sessions on this PC (quser)' { quser.exe }
Register-Tool 'Security & Users' 'Failed logons (24h)' 'Event 4625 summary by account' {
    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = (Get-Date).AddHours(-24) } -ErrorAction SilentlyContinue
    if (-not $ev) { Log 'No failed logons in the last 24 hours.' 'OK'; return }
    Log "$(@($ev).Count) failed logons in the last 24 hours" 'WARN'
    $ev | ForEach-Object { ([xml]$_.ToXml()).Event.EventData.Data | Where-Object Name -eq 'TargetUserName' | ForEach-Object { $_.'#text' } } |
        Group-Object | Sort-Object Count -Descending | Select-Object @{n = 'Account'; e = { $_.Name } }, Count | Format-Table -AutoSize
}
Register-Tool 'Security & Users' 'Recent errors (24h)' 'Critical + error events, System & Application' {
    Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddHours(-24) } -MaxEvents 40 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, LogName, ProviderName, Id, @{n = 'Message'; e = { $m = ("$($_.Message)" -split "`n")[0].Trim(); if ($m.Length -gt 100) { $m.Substring(0, 100) + '...' } else { $m } } } |
        Format-Table -AutoSize
}
Register-Tool 'Security & Users' 'Shutdown history (30 days)' 'Restarts, crashes, unexpected shutdowns' {
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 1074, 6008; StartTime = (Get-Date).AddDays(-30) } -MaxEvents 30 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, @{n = 'Type'; e = { @{41 = 'Crash / power loss'; 1074 = 'Planned restart/shutdown'; 6008 = 'Unexpected shutdown' }[$_.Id] } },
            @{n = 'Detail'; e = { $m = ("$($_.Message)" -split "`n")[0].Trim(); if ($m.Length -gt 90) { $m.Substring(0, 90) + '...' } else { $m } } } |
        Format-Table -AutoSize
}

# ---------------- Updates ----------------
Register-Tool 'Updates' 'Update history' 'Last 25 Windows Update results' {
    $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
    $n = $searcher.GetTotalHistoryCount()
    if ($n -eq 0) { Log 'No update history.'; return }
    $searcher.QueryHistory(0, [math]::Min($n, 25)) | Where-Object { $_.Title } | ForEach-Object {
        [pscustomobject]@{ Date = $_.Date; Result = @{1 = 'In progress'; 2 = 'Succeeded'; 3 = 'Succeeded w/ errors'; 4 = 'FAILED'; 5 = 'Aborted' }[[int]$_.ResultCode]; Title = $_.Title }
    } | Format-Table -AutoSize
}
Register-Tool 'Updates' 'Check for updates' 'List available updates (can take minutes)' {
    Log 'Searching for updates...'
    $r = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0')
    if ($r.Updates.Count -eq 0) { Log 'No updates available.' 'OK'; return }
    Log "$($r.Updates.Count) update(s) available" 'WARN'
    $r.Updates | ForEach-Object { [pscustomobject]@{ Title = $_.Title; 'Size (MB)' = [math]::Round($_.MaxDownloadSize / 1MB) } } | Format-Table -AutoSize
}
Register-Tool 'Updates' 'Installed hotfixes' 'Latest 20 installed KBs' { Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 HotFixID, Description, InstalledOn | Format-Table -AutoSize }
Register-Tool 'Updates' 'Start update install' 'Scan, download and install via Windows Update' -Confirm 'Windows Update will scan, download and install updates in the background. The PC may need a restart afterwards. Continue?' {
    foreach ($a in 'StartScan', 'StartDownload', 'StartInstall') { UsoClient.exe $a; Log "UsoClient $a sent"; Start-Sleep -Seconds 5 }
    Log 'Windows Update is working in the background. Check "Update history" later.' 'OK'
}

# ---------------- Printers ----------------
Register-Tool 'Printers' 'List printers' 'Installed printers, drivers, ports' { Get-Printer | Select-Object Name, DriverName, PortName, PrinterStatus, Shared | Format-Table -AutoSize }
Register-Tool 'Printers' 'Print queue' 'Jobs waiting on every printer' {
    $jobs = Get-Printer | ForEach-Object { Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue }
    if (-not $jobs) { Log 'No print jobs waiting.' 'OK'; return }
    $jobs | Select-Object PrinterName, DocumentName, UserName, JobStatus, SubmittedTime | Format-Table -AutoSize
}
Register-Tool 'Printers' 'Restart print spooler' 'Restarts the spooler, keeps jobs' { Restart-Service Spooler -Force; Get-Service Spooler | Select-Object Name, Status | Format-Table -AutoSize }
Register-Tool 'Printers' 'Clear stuck print jobs' 'Stops spooler, clears queue, restarts' -Confirm 'All waiting print jobs will be cancelled. Continue?' {
    Stop-Service Spooler -Force
    Get-ChildItem "$env:windir\System32\spool\PRINTERS" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    Log 'Print queue cleared and spooler restarted.' 'OK'
}

# ---------------- Power ----------------
Register-Tool 'Power' 'Power plans' 'Active and available plans' { powercfg /list }
Register-Tool 'Power' 'Restart in 5 minutes' 'Warns the user, then restarts' -Confirm 'The user will see a 5-minute warning, then the PC restarts. Continue?' {
    shutdown.exe /r /t 300 /d p:4:1 /c 'IT Support: this PC will restart in 5 minutes. Please save your work.'
    Log 'Restart scheduled in 5 minutes. Use "Cancel scheduled restart" to abort.' 'WARN'
}
Register-Tool 'Power' 'Cancel scheduled restart' 'shutdown /a' { shutdown.exe /a; Log 'Scheduled restart cancelled (if one was pending).' 'OK' }
Register-Tool 'Power' 'Restart now' 'Immediate restart' -Confirm 'The PC will restart NOW. Unsaved work will be lost. Continue?' { shutdown.exe /r /t 5 /d p:4:1 /c 'IT Support restart'; Log 'Restarting in 5 seconds...' 'WARN' }
Register-Tool 'Power' 'Turn off hibernation' 'Frees hiberfil.sys space (disables Fast Startup)' -Confirm 'Hibernate and Fast Startup will be turned off. Continue?' { powercfg /h off; Log 'Hibernation turned off.' 'OK' }

# ---------------- Load plugins from .\Tools ----------------
$script:PluginErrors = @()
$builtInCount = $script:Tools.Count
if (Test-Path $Config.ToolsDir) {
    foreach ($file in Get-ChildItem -Path $Config.ToolsDir -Filter '*.ps1' -File) {
        try { . $file.FullName } catch { $script:PluginErrors += "$($file.Name): $($_.Exception.Message)" }
    }
}

# =====================================================================
#  BACKGROUND RUNNER
# =====================================================================
$Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
$Jobs  = New-Object System.Collections.ArrayList
$Pool  = [runspacefactory]::CreateRunspacePool(1, 4)
$Pool.ApartmentState = 'STA'
$Pool.Open()

$Wrapper = {
    param($Queue, $Code, $Params)
    function Log { param([string]$Message, [string]$Level = 'INFO') $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = $Level; Text = $Message }) }
    $ProgressPreference = 'SilentlyContinue'; $ErrorActionPreference = 'Continue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $buffer = New-Object System.Collections.Generic.List[object]
    $flush = { if ($buffer.Count) { $s = ($buffer | Out-String -Width 200).Trim("`r", "`n"); if ($s.Trim()) { Log $s }; $buffer.Clear() } }
    try {
        $sb = [scriptblock]::Create($Code)
        & $sb $Params *>&1 | ForEach-Object {
            $o = $_
            if ($o -is [Management.Automation.ErrorRecord]) { & $flush; Log $o.ToString() 'ERROR' }
            elseif ($o -is [Management.Automation.WarningRecord]) { & $flush; Log $o.Message 'WARN' }
            elseif ($o -is [Management.Automation.InformationRecord]) { & $flush; Log ([string]$o.MessageData) }
            elseif ($o -is [Management.Automation.VerboseRecord] -or $o -is [Management.Automation.DebugRecord]) { }
            elseif ($o -is [string]) {
                & $flush
                $t = (($o -replace "`0", '') -split "`r")[-1]      # strip UTF-16 nulls (sfc) and progress redraws (dism)
                if ($t.Trim()) { Log $t }
            }
            else { $buffer.Add($o) }
        }
        & $flush
    } catch { & $flush; Log $_.Exception.Message 'ERROR' }
}

# =====================================================================
#  UI HELPERS
# =====================================================================
function C([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
function TC([string]$key) { C $Themes[$script:ThemeName][$key] }
function Get-Role($c) { if ($c.Tag -is [hashtable]) { $c.Tag.Role } else { [string]$c.Tag } }

$FontUI    = New-Object Drawing.Font('Segoe UI', 9.5)
$FontBold  = New-Object Drawing.Font('Segoe UI Semibold', 10)
$FontH2    = New-Object Drawing.Font('Segoe UI Semibold', 13)
$FontTitle = New-Object Drawing.Font('Segoe UI Semibold', 14)
$FontSmall = New-Object Drawing.Font('Segoe UI', 8.5)
$FontBadge = New-Object Drawing.Font('Segoe UI Semibold', 7)
$FontMono  = New-Object Drawing.Font('Consolas', 9.5)
$ToolTip   = New-Object Windows.Forms.ToolTip

function New-Label([string]$Text, [int]$X, [int]$Y, $Font, $Role) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $Text; $l.Location = New-Object Drawing.Point($X, $Y); $l.AutoSize = $true; $l.Font = $Font; $l.Tag = $Role
    $l.BackColor = [Drawing.Color]::Transparent; $l.UseMnemonic = $false
    $l
}
function New-Button([string]$Text, [int]$W, $Role = 'btn') {
    $b = New-Object Windows.Forms.Button
    $b.Text = $Text; $b.Size = New-Object Drawing.Size($W, 28); $b.FlatStyle = 'Flat'; $b.Tag = $Role
    $b.Cursor = [Windows.Forms.Cursors]::Hand; $b.Margin = New-Object Windows.Forms.Padding(6, 5, 0, 0)
    $b
}
function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath; $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); $p
}

function Set-CtlTheme($c) {
    $role = Get-Role $c
    switch ($role) {
        'bg'      { $c.BackColor = TC 'Bg'; $c.ForeColor = TC 'Text' }
        'header'  { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text' }
        'surface' { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text' }
        'sidebar' { $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Text' }
        'border'  { $c.BackColor = TC 'Border' }
        'text'    { $c.ForeColor = TC 'Text' }
        'muted'   { $c.ForeColor = TC 'Muted' }
        'badge-confirm' { $c.ForeColor = TC 'Warn' }
        'badge-launch'  { $c.ForeColor = TC 'Link' }
        'badge-input'   { $c.ForeColor = TC 'Muted' }
        'card'    { $c.BackColor = TC 'Card'; $c.Invalidate() }
        'console' { $c.BackColor = TC 'Console'; $c.ForeColor = TC 'ConsoleText' }
        'input'   { $c.BackColor = TC 'Input'; $c.ForeColor = TC 'Text' }
        'btn'     { $c.BackColor = TC 'Card'; $c.ForeColor = TC 'Text'; $c.FlatAppearance.BorderColor = TC 'Border'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        'danger'  { $c.BackColor = TC 'Card'; $c.ForeColor = TC 'Err'; $c.FlatAppearance.BorderColor = TC 'Border'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        'primary' { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.BorderColor = TC 'Accent'; $c.FlatAppearance.MouseOverBackColor = TC 'AccentHover' }
        'nav' {
            $c.FlatAppearance.BorderSize = 0
            if ($c.Tag.Category -eq $script:CurrentCategory) {
                $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.MouseOverBackColor = TC 'Accent'
            } else {
                $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Text'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover'
            }
        }
        'status'  { $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Muted' }
        'toggle'  { $c.BackColor = TC 'Surface'; $c.Invalidate() }
    }
}
function Update-Theme($root) { Set-CtlTheme $root; foreach ($c in $root.Controls) { Update-Theme $c } }

# ---------------- Console / log ----------------
$script:LogLines = New-Object System.Collections.Generic.List[object]
function Get-LevelColor($lvl) {
    switch ($lvl) { 'OK' { TC 'Ok' } 'WARN' { TC 'Warn' } 'ERROR' { TC 'Err' } 'HEAD' { TC 'Link' } default { TC 'ConsoleText' } }
}
function Write-RtbLine($entry) {
    $lines = ($entry.Text -replace "`r", '') -split "`n"
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -eq 0) { [void]$sb.Append('[' + $entry.Time.ToString('HH:mm:ss') + '] ') } else { [void]$sb.Append('           ') }
        [void]$sb.Append($lines[$i]).Append("`n")
    }
    $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
    $rtb.SelectionColor = Get-LevelColor $entry.Level
    $rtb.AppendText($sb.ToString())
}
function Add-LogLine([string]$Level, [string]$Text, $Time = (Get-Date)) {
    $e = [pscustomobject]@{ Time = $Time; Level = $Level; Text = $Text }
    $script:LogLines.Add($e)
    if ($script:LogLines.Count -gt 10000) { $script:LogLines.RemoveRange(0, 2000) }
    Write-RtbLine $e
    $rtb.ScrollToCaret()
}
function Update-Console { $rtb.Clear(); foreach ($e in $script:LogLines) { Write-RtbLine $e }; $rtb.ScrollToCaret() }
function Save-Log([string]$Prefix = 'toolkit') {
    $file = Join-Path $Config.LogDir ('{0}_{1}_{2:yyyyMMdd_HHmmss}.txt' -f $Prefix, $env:COMPUTERNAME, (Get-Date))
    $script:LogLines | ForEach-Object { '[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}' -f $_.Time, $_.Level, $_.Text } | Set-Content -Path $file -Encoding UTF8
    $file
}

# ---------------- Input dialog ----------------
function Show-InputDialog([string]$Title, [string]$Prompt, [string]$Default) {
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text = $Title; $dlg.Size = New-Object Drawing.Size(440, 178); $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.StartPosition = 'CenterParent'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.Font = $FontUI; $dlg.Tag = 'bg'
    $dlg.Controls.Add((New-Label $Prompt 18 16 $FontUI 'text'))
    $tb = New-Object Windows.Forms.TextBox
    $tb.Location = New-Object Drawing.Point(20, 44); $tb.Width = 384; $tb.Text = $Default; $tb.BorderStyle = 'FixedSingle'; $tb.Tag = 'input'
    $dlg.Controls.Add($tb)
    $ok = New-Button 'Run' 84 'primary'; $ok.Location = New-Object Drawing.Point(226, 88); $ok.DialogResult = 'OK'
    $cancel = New-Button 'Cancel' 84 'btn'; $cancel.Location = New-Object Drawing.Point(320, 88); $cancel.DialogResult = 'Cancel'
    $dlg.Controls.AddRange(@($ok, $cancel)); $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    Update-Theme $dlg
    $result = $dlg.ShowDialog($form); $value = $tb.Text.Trim(); $dlg.Dispose()
    if ($result -eq 'OK') { return $value } else { return $null }
}

# ---------------- Running tools ----------------
function Start-BackgroundTask([string]$Name, [string]$Code, [hashtable]$Params) {
    Add-LogLine 'HEAD' ">> $Name"
    $ps = [powershell]::Create(); $ps.RunspacePool = $Pool
    [void]$ps.AddScript($Wrapper.ToString()).AddArgument($Queue).AddArgument($Code).AddArgument($Params)
    $handle = $ps.BeginInvoke()
    [void]$Jobs.Add([pscustomobject]@{ PS = $ps; Handle = $handle; Name = $Name; Start = (Get-Date); Stopped = $false })
    Update-Status
}
function Invoke-Tool($tool) {
    if ($tool.Confirm) {
        $r = [Windows.Forms.MessageBox]::Show($form, $tool.Confirm, $tool.Name, [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -ne 'Yes') { Add-LogLine 'WARN' "Cancelled: $($tool.Name)"; return }
    }
    $params = @{}
    foreach ($spec in $tool.Inputs) {
        $parts = $spec -split '\|', 3
        $prompt = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
        $default = if ($parts.Count -gt 2) { $parts[2] } else { '' }
        $val = Show-InputDialog $tool.Name $prompt $default
        if ($null -eq $val) { Add-LogLine 'WARN' "Cancelled: $($tool.Name)"; return }
        $params[$parts[0]] = $val
    }
    if ($tool.Launch) {
        try { & $tool.Action $params; Add-LogLine 'OK' "Opened: $($tool.Name)" } catch { Add-LogLine 'ERROR' "Could not open $($tool.Name): $($_.Exception.Message)" }
        return
    }
    Start-BackgroundTask -Name $tool.Name -Code $tool.Action.ToString() -Params $params
}

# ---------------- System info for header / status ----------------
$RunAs     = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$IsAdmin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$OsInfo    = Get-CimInstance Win32_OperatingSystem
$ConsoleUser = (Get-CimInstance Win32_ComputerSystem).UserName; if (-not $ConsoleUser) { $ConsoleUser = 'nobody' }
$MainIP    = ''
try { $MainIP = (Get-NetIPConfiguration -ErrorAction Stop | Where-Object IPv4DefaultGateway | Select-Object -First 1).IPv4Address.IPAddress | Select-Object -First 1 } catch {}
if (-not $MainIP) { $MainIP = 'n/a' }

# =====================================================================
#  BUILD THE WINDOW
# =====================================================================
$form = New-Object Windows.Forms.Form
$form.Text = "$($Config.AppName) $($Config.Version) - $env:COMPUTERNAME"
$form.Size = New-Object Drawing.Size(1220, 800); $form.MinimumSize = New-Object Drawing.Size(980, 640)
$form.StartPosition = 'CenterScreen'; $form.Font = $FontUI; $form.Tag = 'bg'; $form.KeyPreview = $true

# ---- Header ----
$header = New-Object Windows.Forms.Panel; $header.Dock = 'Top'; $header.Height = 64; $header.Tag = 'header'
$header.Controls.Add((New-Label $Config.AppName 18 9 $FontTitle 'text'))
$subText = if ($RunAs -match 'SYSTEM$') { "$env:COMPUTERNAME  -  running as SYSTEM (Backstage)" } else { "$env:COMPUTERNAME  -  running as $RunAs" }
if (-not $IsAdmin) { $subText += '  -  NOT ELEVATED: some tools will fail' }
$header.Controls.Add((New-Label $subText 20 38 $FontSmall 'muted'))

$themeArea = New-Object Windows.Forms.Panel; $themeArea.Dock = 'Right'; $themeArea.Width = 150; $themeArea.Tag = 'header'
$lblTheme = New-Label 'Dark mode' 18 22 $FontUI 'muted'
$toggle = New-Object Windows.Forms.Panel
$toggle.Size = New-Object Drawing.Size(46, 24); $toggle.Location = New-Object Drawing.Point(88, 20); $toggle.Cursor = [Windows.Forms.Cursors]::Hand; $toggle.Tag = 'toggle'
$toggle.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $on = $script:ThemeName -eq 'Dark'
    $trackColor = if ($on) { TC 'Accent' } else { C '#c5cbd4' }
    $path = New-RoundRect 0 0 ($s.Width - 1) ($s.Height - 1) (($s.Height - 1) / 2)
    $brush = New-Object Drawing.SolidBrush($trackColor); $g.FillPath($brush, $path); $brush.Dispose(); $path.Dispose()
    $d = $s.Height - 6; $x = if ($on) { $s.Width - $d - 4 } else { 3 }
    $g.FillEllipse([Drawing.Brushes]::White, $x, 3, $d, $d)
})
$toggle.Add_Click({ Set-Theme $(if ($script:ThemeName -eq 'Dark') { 'Light' } else { 'Dark' }) })
$lblTheme.Cursor = [Windows.Forms.Cursors]::Hand
$lblTheme.Add_Click({ Set-Theme $(if ($script:ThemeName -eq 'Dark') { 'Light' } else { 'Dark' }) })
$ToolTip.SetToolTip($toggle, 'Switch between dark and light theme')
$themeArea.Controls.AddRange(@($lblTheme, $toggle))
$header.Controls.Add($themeArea)
$headerLine = New-Object Windows.Forms.Panel; $headerLine.Dock = 'Bottom'; $headerLine.Height = 1; $headerLine.Tag = 'border'
$header.Controls.Add($headerLine)

# ---- Sidebar ----
$sidebar = New-Object Windows.Forms.Panel; $sidebar.Dock = 'Left'; $sidebar.Width = 212; $sidebar.Tag = 'sidebar'
$sidebar.Padding = New-Object Windows.Forms.Padding(12, 14, 12, 12)
$navFlow = New-Object Windows.Forms.FlowLayoutPanel; $navFlow.Dock = 'Fill'; $navFlow.FlowDirection = 'TopDown'
$navFlow.WrapContents = $false; $navFlow.AutoScroll = $true; $navFlow.Tag = 'sidebar'
$sideLine = New-Object Windows.Forms.Panel; $sideLine.Dock = 'Right'; $sideLine.Width = 1; $sideLine.Tag = 'border'
$sidebar.Controls.Add($navFlow); $sidebar.Controls.Add($sideLine); $navFlow.BringToFront()

# ---- Main area ----
$main = New-Object Windows.Forms.Panel; $main.Dock = 'Fill'; $main.Tag = 'bg'; $main.Padding = New-Object Windows.Forms.Padding(18, 12, 18, 14)

$topBar = New-Object Windows.Forms.Panel; $topBar.Dock = 'Top'; $topBar.Height = 54; $topBar.Tag = 'bg'
$lblCat = New-Label 'All tools' 0 2 $FontH2 'text'
$lblCount = New-Label '' 2 30 $FontSmall 'muted'
$searchWrap = New-Object Windows.Forms.Panel; $searchWrap.Dock = 'Right'; $searchWrap.Width = 300; $searchWrap.Tag = 'bg'
$txtSearch = New-Object Windows.Forms.TextBox
$txtSearch.Location = New-Object Drawing.Point(0, 12); $txtSearch.Width = 300; $txtSearch.BorderStyle = 'FixedSingle'; $txtSearch.Tag = 'input'
$txtSearch.Font = New-Object Drawing.Font('Segoe UI', 10.5)
$searchWrap.Controls.Add($txtSearch)
$topBar.Controls.AddRange(@($lblCat, $lblCount, $searchWrap))

$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'; $split.Orientation = 'Horizontal'; $split.SplitterWidth = 8; $split.Tag = 'bg'
$split.Panel1.Tag = 'bg'; $split.Panel2.Tag = 'bg'

$flow = New-Object Windows.Forms.FlowLayoutPanel; $flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.Tag = 'bg'
$split.Panel1.Controls.Add($flow)

# Console box
$conBorder = New-Object Windows.Forms.Panel; $conBorder.Dock = 'Fill'; $conBorder.Tag = 'border'; $conBorder.Padding = New-Object Windows.Forms.Padding(1)
$conInner = New-Object Windows.Forms.Panel; $conInner.Dock = 'Fill'; $conInner.Tag = 'surface'
$conBar = New-Object Windows.Forms.Panel; $conBar.Dock = 'Top'; $conBar.Height = 40; $conBar.Tag = 'surface'
$conBar.Controls.Add((New-Label 'Output' 12 11 $FontBold 'text'))
$conButtons = New-Object Windows.Forms.FlowLayoutPanel; $conButtons.Dock = 'Right'; $conButtons.Width = 360; $conButtons.FlowDirection = 'RightToLeft'; $conButtons.Tag = 'surface'
$btnStop  = New-Button 'Stop' 70 'danger'
$btnClear = New-Button 'Clear' 70
$btnSave  = New-Button 'Save log' 84
$btnCopy  = New-Button 'Copy' 70
$conButtons.Controls.AddRange(@($btnStop, $btnClear, $btnSave, $btnCopy))
$conBar.Controls.Add($conButtons)

$rtb = New-Object Windows.Forms.RichTextBox
$rtb.Dock = 'Fill'; $rtb.ReadOnly = $true; $rtb.BorderStyle = 'None'; $rtb.Font = $FontMono; $rtb.WordWrap = $false
$rtb.DetectUrls = $false; $rtb.Tag = 'console'

$cmdBar = New-Object Windows.Forms.Panel; $cmdBar.Dock = 'Bottom'; $cmdBar.Height = 40; $cmdBar.Tag = 'surface'
$cmdBar.Padding = New-Object Windows.Forms.Padding(10, 6, 10, 6)
$lblPrompt = New-Object Windows.Forms.Label; $lblPrompt.Text = 'PS>'; $lblPrompt.Dock = 'Left'; $lblPrompt.Width = 36; $lblPrompt.Font = $FontMono
$lblPrompt.TextAlign = 'MiddleLeft'; $lblPrompt.Tag = 'muted'
$txtCmd = New-Object Windows.Forms.TextBox; $txtCmd.Dock = 'Fill'; $txtCmd.Font = $FontMono; $txtCmd.BorderStyle = 'FixedSingle'; $txtCmd.Tag = 'input'
$btnRun = New-Button 'Run' 70 'primary'; $btnRun.Dock = 'Right'
$cmdBar.Controls.AddRange(@($lblPrompt, $btnRun, $txtCmd)); $txtCmd.BringToFront()

$conInner.Controls.AddRange(@($conBar, $cmdBar, $rtb)); $rtb.BringToFront()
$conBorder.Controls.Add($conInner)
$split.Panel2.Controls.Add($conBorder)

$main.Controls.Add($topBar); $main.Controls.Add($split); $split.BringToFront()

# ---- Status bar ----
$status = New-Object Windows.Forms.Panel; $status.Dock = 'Bottom'; $status.Height = 26; $status.Tag = 'status'
$lblStatus = New-Object Windows.Forms.Label; $lblStatus.Dock = 'Fill'; $lblStatus.TextAlign = 'MiddleLeft'; $lblStatus.Font = $FontSmall; $lblStatus.Tag = 'status'
$lblStatus.Padding = New-Object Windows.Forms.Padding(10, 0, 0, 0)
$statusLine = New-Object Windows.Forms.Panel; $statusLine.Dock = 'Top'; $statusLine.Height = 1; $statusLine.Tag = 'border'
$status.Controls.Add($lblStatus); $status.Controls.Add($statusLine); $lblStatus.BringToFront()

$form.Controls.AddRange(@($main, $sidebar, $header, $status)); $main.BringToFront()

# =====================================================================
#  BEHAVIOUR
# =====================================================================
function Update-Status {
    $up = (Get-Date) - $OsInfo.LastBootUpTime
    $lblStatus.Text = '{0}   |   {1}   |   IP {2}   |   Console user: {3}   |   Uptime {4}d {5}h   |   Running: {6}' -f `
        $env:COMPUTERNAME, $OsInfo.Caption, $MainIP, $ConsoleUser, $up.Days, $up.Hours, $Jobs.Count
}

function Set-Theme([string]$Name) {
    $script:ThemeName = $Name
    $form.SuspendLayout(); Update-Theme $form; $form.ResumeLayout()
    Update-Console
    try { @{ Theme = $Name } | ConvertTo-Json | Set-Content -Path $SettingsFile -Encoding UTF8 } catch {}
}

$script:CardEnter = {
    $c = if ((Get-Role $this) -eq 'card') { $this } else { $this.Parent }
    $c.BackColor = TC 'CardHover'
}
$script:CardLeave = {
    $c = if ((Get-Role $this) -eq 'card') { $this } else { $this.Parent }
    if (-not $c.ClientRectangle.Contains($c.PointToClient([Windows.Forms.Cursor]::Position))) { $c.BackColor = TC 'Card' }
}
$script:CardClick = { Invoke-Tool $this.Tag.Tool }

function New-ToolCard($tool) {
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size(262, 78); $card.Margin = New-Object Windows.Forms.Padding(0, 0, 10, 10)
    $card.Cursor = [Windows.Forms.Cursors]::Hand; $card.Tag = @{ Role = 'card'; Tool = $tool }
    $card.Add_Paint({ param($s, $e) $pen = New-Object Drawing.Pen((TC 'Border')); $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1); $pen.Dispose() })

    $title = New-Object Windows.Forms.Label
    $title.Text = $tool.Name; $title.Font = $FontBold; $title.Location = New-Object Drawing.Point(12, 10); $title.Size = New-Object Drawing.Size(178, 20)
    $title.AutoEllipsis = $true; $title.UseMnemonic = $false; $title.BackColor = [Drawing.Color]::Transparent; $title.Tag = @{ Role = 'text'; Tool = $tool }

    $desc = New-Object Windows.Forms.Label
    $desc.Text = $tool.Description; $desc.Font = $FontSmall; $desc.Location = New-Object Drawing.Point(12, 32); $desc.Size = New-Object Drawing.Size(240, 38)
    $desc.AutoEllipsis = $true; $desc.UseMnemonic = $false; $desc.BackColor = [Drawing.Color]::Transparent; $desc.Tag = @{ Role = 'muted'; Tool = $tool }

    $parts = @($title, $desc)
    $kind = if ($tool.Launch) { 'launch' } elseif ($tool.Confirm) { 'confirm' } elseif ($tool.Inputs.Count) { 'input' } else { '' }
    if ($kind) {
        $badge = New-Object Windows.Forms.Label
        $badge.Text = $kind.ToUpper(); $badge.Font = $FontBadge; $badge.Location = New-Object Drawing.Point(192, 12); $badge.Size = New-Object Drawing.Size(60, 16)
        $badge.TextAlign = 'MiddleRight'; $badge.BackColor = [Drawing.Color]::Transparent; $badge.Tag = @{ Role = "badge-$kind"; Tool = $tool }
        $parts += $badge
    }
    $card.Controls.AddRange($parts)
    foreach ($ctl in @($card) + $parts) {
        $ctl.Add_Click($script:CardClick); $ctl.Add_MouseEnter($script:CardEnter); $ctl.Add_MouseLeave($script:CardLeave)
        $ToolTip.SetToolTip($ctl, "$($tool.Category): $($tool.Description)")
    }
    $card
}

function Show-Tools {
    $q = $txtSearch.Text.Trim()
    $list = @($script:Tools | Where-Object {
        if ($q) { "$($_.Name) $($_.Description) $($_.Category)" -like "*$q*" }
        else { $script:CurrentCategory -eq 'All tools' -or $_.Category -eq $script:CurrentCategory }
    })
    $lblCat.Text = if ($q) { "Search: $q" } else { $script:CurrentCategory }
    $lblCount.Text = '{0} tool{1}  -  click a card to run it' -f $list.Count, $(if ($list.Count -eq 1) { '' } else { 's' })
    $flow.SuspendLayout()
    $old = @($flow.Controls); $flow.Controls.Clear(); $old | ForEach-Object { $_.Dispose() }
    foreach ($t in $list) { $flow.Controls.Add((New-ToolCard $t)) }
    if ($list.Count -eq 0) { $flow.Controls.Add((New-Label 'No tools match your search.' 4 4 $FontUI 'muted')) }
    Update-Theme $flow
    $flow.ResumeLayout()
}

function Build-Nav {
    $navFlow.Controls.Clear()
    $navFlow.Controls.Add((New-Label 'CATEGORIES' 4 0 $FontBadge 'muted'))
    foreach ($cat in @('All tools') + @($script:CategoryOrder)) {
        $n = if ($cat -eq 'All tools') { $script:Tools.Count } else { @($script:Tools | Where-Object Category -eq $cat).Count }
        $b = New-Object Windows.Forms.Button
        $b.Text = "$cat  ($n)"; $b.Size = New-Object Drawing.Size(184, 34); $b.TextAlign = 'MiddleLeft'; $b.FlatStyle = 'Flat'
        $b.Padding = New-Object Windows.Forms.Padding(8, 0, 0, 0); $b.Margin = New-Object Windows.Forms.Padding(0, 2, 0, 2)
        $b.Cursor = [Windows.Forms.Cursors]::Hand; $b.UseMnemonic = $false; $b.Tag = @{ Role = 'nav'; Category = $cat }
        $b.Add_Click({
            $script:CurrentCategory = $this.Tag.Category
            if ($txtSearch.Text) { $txtSearch.Text = '' } else { Show-Tools }
            Update-Theme $navFlow
        })
        $navFlow.Controls.Add($b)
    }
}

# ---- Events ----
$txtSearch.Add_TextChanged({ Show-Tools })
$btnClear.Add_Click({ $script:LogLines.Clear(); $rtb.Clear() })
$btnCopy.Add_Click({ if ($rtb.TextLength) { [Windows.Forms.Clipboard]::SetText($rtb.Text); Add-LogLine 'OK' 'Output copied to clipboard.' } })
$btnSave.Add_Click({ $f = Save-Log; Add-LogLine 'OK' "Log saved: $f" })
$btnStop.Add_Click({
    if ($Jobs.Count -eq 0) { Add-LogLine 'INFO' 'Nothing is running.'; return }
    foreach ($j in @($Jobs)) { $j.Stopped = $true; [void]$j.PS.BeginStop($null, $null) }
    Add-LogLine 'WARN' 'Stop requested for all running tasks.'
})
$runCmd = {
    $cmd = $txtCmd.Text.Trim(); if (-not $cmd) { return }
    $txtCmd.Clear()
    Start-BackgroundTask -Name "PS> $cmd" -Code $cmd -Params @{}
}
$btnRun.Add_Click($runCmd)
$txtCmd.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true; & $runCmd } })
$form.Add_KeyDown({ param($s, $e) if ($e.Control -and $e.KeyCode -eq 'F') { $txtSearch.Focus(); $txtSearch.SelectAll(); $e.SuppressKeyPress = $true } })

$timer = New-Object Windows.Forms.Timer; $timer.Interval = 150
$timer.Add_Tick({
    $item = $null; $n = 0
    while ($n -lt 300 -and $Queue.TryDequeue([ref]$item)) { Add-LogLine $item.Level $item.Text $item.Time; $n++ }
    foreach ($j in @($Jobs)) {
        if ($j.Handle.IsCompleted) {
            while ($Queue.TryDequeue([ref]$item)) { Add-LogLine $item.Level $item.Text $item.Time }
            try { [void]$j.PS.EndInvoke($j.Handle) } catch {}
            $secs = [math]::Round(((Get-Date) - $j.Start).TotalSeconds, 1)
            if ($j.Stopped) { Add-LogLine 'WARN' "Stopped: $($j.Name) after $secs s" } else { Add-LogLine 'OK' "Done: $($j.Name) ($secs s)" }
            $j.PS.Dispose(); $Jobs.Remove($j); Update-Status
        }
    }
})

$form.Add_Shown({
    Set-CueBanner $txtSearch 'Search tools...  (Ctrl+F)'
    Set-CueBanner $txtCmd 'Type any PowerShell command and press Enter'
    $split.Panel1MinSize = 120; $split.Panel2MinSize = 150
    $split.SplitterDistance = [int]($split.Height * 0.55)
    $timer.Start()
})
$form.Add_FormClosing({
    $timer.Stop()
    foreach ($j in @($Jobs)) { try { $j.PS.Stop(); $j.PS.Dispose() } catch {} }
    if ($script:LogLines.Count -gt 1) { try { [void](Save-Log 'session') } catch {} }
    try { @{ Theme = $script:ThemeName } | ConvertTo-Json | Set-Content -Path $SettingsFile -Encoding UTF8 } catch {}
})

function Set-CueBanner($tb, [string]$text) { try { [void][ITK.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, $text) } catch {} }

# ---- Go ----
Build-Nav
Update-Theme $form
Show-Tools
Update-Status
$pluginCount = $script:Tools.Count - $builtInCount
Add-LogLine 'HEAD' "$($Config.AppName) ready - $($script:Tools.Count) tools loaded ($pluginCount from the Tools folder)."
Add-LogLine 'INFO' "Logs and settings: $($Config.DataDir)"
if (-not $IsAdmin) { Add-LogLine 'WARN' 'Not running elevated - many tools need admin rights.' }
foreach ($err in $script:PluginErrors) { Add-LogLine 'ERROR' "Plugin failed to load - $err" }

[void]$form.ShowDialog()

$Pool.Close(); $Pool.Dispose()
$form.Dispose()
