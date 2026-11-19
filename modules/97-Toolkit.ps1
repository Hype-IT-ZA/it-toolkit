# Toolkit - checks on the toolkit itself
Register-Tool 'Toolkit' 'Toolkit self-test' 'Checks this PC is ready: admin rights, PowerShell, internet, winget, run-as-user and more' {
    $script:stPass = 0; $script:stWarn = 0; $script:stFail = 0
    function Out-Check([string]$Name, [string]$State, [string]$Detail) {
        switch ($State) { 'Pass' { $script:stPass++; $lvl = 'OK' } 'Warn' { $script:stWarn++; $lvl = 'WARN' } 'Fail' { $script:stFail++; $lvl = 'ERROR' } default { $lvl = 'INFO' } }
        Log ('{0,-5} {1,-26} {2}' -f $State.ToUpper(), $Name, $Detail) $lvl
    }
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Out-Check 'Elevated (admin)' $(if ($admin) { 'Pass' } else { 'Fail' }) $(if ($admin) { 'Yes' } else { 'No - most tools need admin rights. Start PowerShell as administrator.' })
    Out-Check 'Running as' 'Info' $(if ($id.IsSystem) { 'SYSTEM (ScreenConnect Backstage or a service)' } else { $id.Name })
    $v = $PSVersionTable.PSVersion
    Out-Check 'PowerShell' $(if ($v -ge [version]'5.1') { 'Pass' } else { 'Fail' }) "$v ($($PSVersionTable.PSEdition))"
    Out-Check 'Language mode' $(if ($ExecutionContext.SessionState.LanguageMode -eq 'FullLanguage') { 'Pass' } else { 'Fail' }) "$($ExecutionContext.SessionState.LanguageMode)$(if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') { ' - AppLocker / WDAC is restricting PowerShell' })"
    $net = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
    Out-Check '.NET Framework' $(if ($net -ge 461808) { 'Pass' } else { 'Warn' }) $(if ($net) { "release $net$(if ($net -lt 461808) { ' - 4.7.2 or newer recommended' })" } else { 'not found' })
    try {
        New-Item -ItemType Directory -Path $ITK_DataDir -Force | Out-Null
        $t = Join-Path $ITK_DataDir 'selftest.tmp'; Set-Content $t 'ok' -ErrorAction Stop; Remove-Item $t -Force
        Out-Check 'Data folder' 'Pass' "$ITK_DataDir is writable"
    } catch { Out-Check 'Data folder' 'Fail' "$ITK_DataDir is not writable: $($_.Exception.Message)" }
    try { $cs = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; Out-Check 'WMI / CIM' 'Pass' "$($cs.Caption) build $($cs.BuildNumber)" }
    catch { Out-Check 'WMI / CIM' 'Fail' "WMI is broken: $($_.Exception.Message). Try: winmgmt /verifyrepository" }
    $tls = [Net.ServicePointManager]::SecurityProtocol
    Out-Check 'TLS 1.2' $(if ($tls -band [Net.SecurityProtocolType]::Tls12) { 'Pass' } else { 'Warn' }) "$tls"
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $latest = (Invoke-RestMethod -Uri ("https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/version.txt?t=" + [DateTime]::UtcNow.Ticks) -TimeoutSec 10 -UseBasicParsing).ToString().Trim()
        Out-Check 'Internet / GitHub' 'Pass' ('reachable in {0} ms' -f $sw.ElapsedMilliseconds)
        $mine = $ITK_Version
        if ($mine) { Out-Check 'Toolkit version' $(if ([version]$mine -ge [version]$latest) { 'Pass' } else { 'Warn' }) "installed $mine, latest $latest$(if ([version]$mine -lt [version]$latest) { ' - run the one-liner again to update' })" }
        else { Out-Check 'Toolkit version' 'Info' "latest is $latest" }
    } catch { Out-Check 'Internet / GitHub' 'Warn' "cannot reach GitHub: $($_.Exception.Message)" }
    $wg = Get-WingetPath
    if ($wg) { $ver = (& $wg --version 2>$null | Select-Object -First 1); Out-Check 'winget' 'Pass' "$ver ($wg)" }
    else { Out-Check 'winget' 'Warn' 'not found - Install tab will not work. Use Software > "Install / repair winget".' }
    $sch = Get-Service Schedule -ErrorAction SilentlyContinue
    Out-Check 'Task Scheduler' $(if ($sch.Status -eq 'Running') { 'Pass' } else { 'Fail' }) "$($sch.Status) - needed to run tools as the signed-in user"
    $user = Get-ConsoleUser
    if ($user) {
        try {
            $who = (Invoke-AsUser -Script 'whoami' -TimeoutSec 45).Trim()
            Out-Check 'Run as signed-in user' $(if ($who) { 'Pass' } else { 'Warn' }) "ran as $who"
        } catch { Out-Check 'Run as signed-in user' 'Fail' $_.Exception.Message }
    } else { Out-Check 'Run as signed-in user' 'Info' 'nobody is signed in - User Session tools will not work until someone signs in' }
    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    Out-Check 'Windows Update service' $(if ($wu -and $wu.StartType -ne 'Disabled') { 'Pass' } else { 'Warn' }) $(if ($wu) { "$($wu.Status), start type $($wu.StartType)" } else { 'missing' })
    Out-Check 'Defender cmdlets' $(if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) { 'Pass' } else { 'Info' }) $(if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) { 'available' } else { 'not available (other antivirus or Server Core)' })
    $sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction SilentlyContinue
    if ($sys) { Out-Check 'Free space' $(if ($sys.FreeSpace -gt 5GB) { 'Pass' } else { 'Warn' }) "$(Format-Size $sys.FreeSpace) free on $env:SystemDrive" }
    Out-Check 'Pending reboot' $(if (Test-PendingReboot) { 'Warn' } else { 'Pass' }) $(if (Test-PendingReboot) { 'yes - some repairs and installs may fail until the PC restarts' } else { 'no' })
    Log ("Self-test: {0} passed, {1} warnings, {2} failed." -f $script:stPass, $script:stWarn, $script:stFail) $(if ($script:stFail) { 'ERROR' } elseif ($script:stWarn) { 'WARN' } else { 'OK' })
}
Register-Tool 'Toolkit' 'Report a problem' 'Opens the GitHub bug report form' {
    $url = 'https://github.com/Hype-IT-ZA/it-toolkit/issues/new?template=bug_report.yml'
    try { Start-Process $url -ErrorAction Stop; Log "Opened $url" 'OK' } catch { Log "Open this in a browser: $url" 'WARN' }
} -Launch
