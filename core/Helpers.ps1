# =====================================================================
#  IT Toolkit - shared helpers
#  Loaded by the main window AND inside every background task, so tool
#  actions can call these functions directly. Must not touch the UI.
#  `Log` and `Send-ToolkitEvent` are provided by whoever loads this file.
# =====================================================================

$ITK_DataDir   = Join-Path $env:ProgramData 'ITToolkit'
$ITK_ReportDir = Join-Path $ITK_DataDir 'Reports'
$ITK_TempDir   = Join-Path $ITK_DataDir 'Temp'
$ITK_Settings  = Join-Path $ITK_DataDir 'settings.json'
$ITK_Root      = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { $ITK_DataDir }
$ITK_Version   = "$(Get-Content (Join-Path $ITK_Root 'version.txt') -ErrorAction SilentlyContinue | Select-Object -First 1)".Trim()

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1TB) { '{0:N2} TB' -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { '{0:N1} MB' -f ($Bytes / 1MB) }
    else { '{0:N0} KB' -f ($Bytes / 1KB) }
}

# ---------------- Settings ----------------
function Get-ToolkitSettings {
    $s = [ordered]@{
        Theme = 'Dark'; ReportTitle = ''; WebhookUrl = ''; SendNotesOnClose = $false; CheckUpdates = $true
        Favorites = @(); Recent = @(); SavedPreset = @()
    }
    if (Test-Path $ITK_Settings) {
        try {
            $j = Get-Content $ITK_Settings -Raw | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { if ($s.Contains($p.Name)) { $s[$p.Name] = $p.Value } }
        } catch {}
    }
    foreach ($k in 'Favorites', 'Recent', 'SavedPreset') { $s[$k] = @($s[$k] | Where-Object { $_ }) }
    $s
}
function Save-ToolkitSettings($Settings) {
    try {
        New-Item -ItemType Directory -Path $ITK_DataDir -Force | Out-Null
        $Settings | ConvertTo-Json -Depth 4 | Set-Content -Path $ITK_Settings -Encoding UTF8
    } catch {}
}

# ---------------- System ----------------
function Get-ConsoleUser {
    $u = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if (-not $u) {
        $e = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($e) {
            $o = Invoke-CimMethod -InputObject $e -MethodName GetOwner -ErrorAction SilentlyContinue
            if ($o -and $o.User) { $u = "$($o.Domain)\$($o.User)" }
        }
    }
    $u
}

function Test-PendingReboot {
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
    [bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
}

function New-ToolkitRestorePoint([string]$Description = 'IT Toolkit') {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $old = (Get-ItemProperty $key -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue).SystemRestorePointCreationFrequency
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $key -Name SystemRestorePointCreationFrequency -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log "Restore point created: $Description" 'OK'
        return $true
    } catch {
        Log "Could not create a restore point: $($_.Exception.Message)" 'WARN'
        return $false
    } finally {
        if ($null -eq $old) { Remove-ItemProperty -Path $key -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue }
        else { Set-ItemProperty -Path $key -Name SystemRestorePointCreationFrequency -Value $old -ErrorAction SilentlyContinue }
    }
}

# ---------------- Registry (HKCU:\ = every signed-in user) ----------------
# In Backstage the toolkit runs as SYSTEM, so the normal HKCU is SYSTEM's own hive.
# Any path starting with HKCU:\ is applied to every loaded user hive in HKEY_USERS instead.
function Get-UserHiveRoots {
    @(Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^S-1-5-21-[\d-]+$' } |
        ForEach-Object { "Registry::HKEY_USERS\$($_.PSChildName)" })
}
function Resolve-RegPath([string]$Path) {
    if ($Path -match '^HKCU:\\(.*)$') {
        $rest = $Matches[1]
        return @(Get-UserHiveRoots | ForEach-Object { "$_\$rest" })
    }
    @($Path)
}
function Set-RegValue([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    $targets = Resolve-RegPath $Path
    if (-not $targets) { Log "No signed-in user found - skipped $Path\$Name" 'WARN'; return }
    foreach ($p in $targets) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        New-ItemProperty -Path $p -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    }
}
function Remove-RegValue([string]$Path, [string]$Name) {
    foreach ($p in (Resolve-RegPath $Path)) { Remove-ItemProperty -Path $p -Name $Name -ErrorAction SilentlyContinue }
}
function Get-RegValue([string]$Path, [string]$Name) {
    $t = Resolve-RegPath $Path | Select-Object -First 1
    if (-not $t) { return $null }
    try { (Get-ItemProperty -Path $t -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Get-UserProfilePaths {
    @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath -and (Test-Path $_.LocalPath) } | ForEach-Object { $_.LocalPath })
}

# ---------------- Tweaks ----------------
function Invoke-Tweak {
    param($Tweak, [ValidateSet('Apply', 'Revert', 'Test')][string]$Mode)
    if ($Mode -eq 'Test') {
        $known = $false
        foreach ($r in @($Tweak.Registry)) {
            if (-not $r) { continue }
            $known = $true
            if ("$(Get-RegValue $r.Path $r.Name)" -ne "$($r.Value)") { return $false }
        }
        foreach ($s in @($Tweak.Services)) {
            if (-not $s) { continue }
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if (-not $svc) { continue }
            $known = $true
            if ("$($svc.StartType)" -ne $s.Startup) { return $false }
        }
        if ($Tweak.TestCode) {
            $known = $true
            if (-not (& ([scriptblock]::Create($Tweak.TestCode)))) { return $false }
        }
        if ($known) { return $true } else { return $null }
    }

    foreach ($r in @($Tweak.Registry)) {
        if (-not $r) { continue }
        $type = if ($r.Type) { $r.Type } else { 'DWord' }
        if ($Mode -eq 'Apply') { Set-RegValue $r.Path $r.Name $r.Value $type }
        elseif ($r.ContainsKey('Revert') -and $null -ne $r.Revert) { Set-RegValue $r.Path $r.Name $r.Revert $type }
        else { Remove-RegValue $r.Path $r.Name }
    }
    foreach ($s in @($Tweak.Services)) {
        if (-not $s) { continue }
        $target = if ($Mode -eq 'Apply') { $s.Startup } else { $s.Revert }
        if (-not $target -or -not (Get-Service -Name $s.Name -ErrorAction SilentlyContinue)) { continue }
        Set-Service -Name $s.Name -StartupType $target -ErrorAction SilentlyContinue
        if ($Mode -eq 'Apply' -and $target -eq 'Disabled') { Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue }
    }
    $code = if ($Mode -eq 'Apply') { $Tweak.ApplyCode } else { $Tweak.RevertCode }
    if ($code) { & ([scriptblock]::Create($code)) | Out-Null }
}

# ---------------- winget ----------------
function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # As SYSTEM winget is not on PATH - find it in WindowsApps
    $found = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object { try { [version](($_.Directory.Name -split '_')[1]) } catch { [version]'0.0' } } -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }
    $null
}

function Invoke-Winget([string]$Winget, [string[]]$Arguments) {
    & $Winget @Arguments 2>&1 | ForEach-Object {
        $l = ("$_" -split "`r")[-1] -replace '\x1b\[[0-9;?]*[A-Za-z]', ''
        if (-not $l.Trim() -or $l -match '[\u2580-\u259F]' -or $l -match '^\s*[-\\|/]\s*$') { return }
        Log $l.TrimEnd()
    }
    [int]$LASTEXITCODE
}

function Get-WingetResultText([int]$Code) {
    switch ($Code) {
        0           { 'done' }
        3010        { 'done - restart required' }
        1641        { 'done - restart started' }
        -1978335189 { 'already up to date' }
        -1978335135 { 'already installed' }
        -1978335212 { 'no package found with that ID' }
        -1978335215 { 'no installer found for this system' }
        -1978334967 { 'a restart is needed first' }
        default     { "failed (exit code $Code)" }
    }
}
$ITK_WingetOkCodes = @(0, 3010, 1641, -1978335189, -1978335135)

function Invoke-WingetApps {
    param([string[]]$Ids, [ValidateSet('Install', 'Uninstall')][string]$Action = 'Install')
    $wg = Get-WingetPath
    if (-not $wg) { Log 'winget was not found. Run "Install / repair winget" (Tools > Software) first.' 'ERROR'; return }
    $ok = 0; $fail = 0; $i = 0
    foreach ($id in $Ids) {
        $i++
        Log ("[{0}/{1}] {2} {3}" -f $i, $Ids.Count, $Action, $id)
        if ($Action -eq 'Install') {
            $base = @('install', '--id', $id, '-e', '--source', 'winget', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
            $code = Invoke-Winget $wg ($base + @('--scope', 'machine'))
            if ($ITK_WingetOkCodes -notcontains $code) {
                Log 'Retrying without machine scope...'
                $code = Invoke-Winget $wg $base
            }
        } else {
            $code = Invoke-Winget $wg @('uninstall', '--id', $id, '-e', '--silent', '--accept-source-agreements', '--disable-interactivity')
        }
        if ($ITK_WingetOkCodes -contains $code) { $ok++; Log "$id - $(Get-WingetResultText $code)" 'OK' }
        else { $fail++; Log "$id - $(Get-WingetResultText $code)" 'ERROR' }
    }
    Log ("{0} finished: {1} succeeded, {2} failed." -f $Action, $ok, $fail) $(if ($fail) { 'WARN' } else { 'OK' })
}

function Get-WingetInstalledIds {
    $wg = Get-WingetPath
    if (-not $wg) { return @() }
    New-Item -ItemType Directory -Path $ITK_TempDir -Force | Out-Null
    $file = Join-Path $ITK_TempDir ("winget_export_{0}.json" -f [guid]::NewGuid().ToString('N'))
    try {
        & $wg export -o $file --accept-source-agreements --source winget 2>&1 | Out-Null
        if (Test-Path $file) {
            $j = Get-Content $file -Raw | ConvertFrom-Json
            return @($j.Sources | ForEach-Object { $_.Packages } | ForEach-Object { $_.PackageIdentifier })
        }
    } catch {} finally { Remove-Item $file -Force -ErrorAction SilentlyContinue }
    @()
}

# ---------------- Run as the signed-in user ----------------
# Backstage runs as SYSTEM. This runs a script in the signed-in user's own session
# (their HKCU, mapped drives, OneDrive...) using a one-off scheduled task, and returns its output.
function Invoke-AsUser {
    param([Parameter(Mandatory)][string]$Script, [int]$TimeoutSec = 120, [switch]$NoWait)
    $user = Get-ConsoleUser
    if (-not $user) { throw 'Nobody is signed in to this PC.' }
    New-Item -ItemType Directory -Path $ITK_TempDir -Force | Out-Null
    & icacls.exe $ITK_TempDir /grant '*S-1-5-32-545:(OI)(CI)M' /Q 2>&1 | Out-Null    # let Users write their output
    $id = [guid]::NewGuid().ToString('N').Substring(0, 10)
    $scriptFile = Join-Path $ITK_TempDir "asuser_$id.ps1"
    $outFile = Join-Path $ITK_TempDir "asuser_$id.txt"
    $body = @"
`$ErrorActionPreference = 'Continue'
try { `$r = & { $Script } *>&1 | Out-String -Width 200 } catch { `$r = `$_ | Out-String }
Set-Content -Path '$outFile' -Value `$r -Encoding UTF8
"@
    Set-Content -Path $scriptFile -Value $body -Encoding UTF8
    $task = "ITToolkit_AsUser_$id"
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptFile`""
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
        Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $task
        if ($NoWait) { Start-Sleep -Seconds 3; return "Started as $user." }
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 500
            if (Test-Path $outFile) { Start-Sleep -Milliseconds 300; break }
        }
        if (Test-Path $outFile) { return (Get-Content $outFile -Raw) }
        throw "Timed out after $TimeoutSec seconds waiting for $user."
    } finally {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        if (-not $NoWait) { Remove-Item $scriptFile, $outFile -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------- Office ----------------
function Get-OfficeC2R {
    $cfg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue
    if (-not $cfg) { return $null }
    $channels = @{
        '492350f6-3a01-4f97-b9c0-c7c6ddf67d60' = 'Current'; '55336b82-a18d-4dd6-b5f6-9e5095c314a6' = 'Monthly Enterprise'
        '7ffbc6bf-bc32-4f92-8982-f9dd17fd3114' = 'Semi-Annual Enterprise'; '64256afe-f5d9-4f86-8936-8840a6a4f5be' = 'Current (Preview)'
        'b8f9b850-328d-4355-9145-c59439a0c4cf' = 'Semi-Annual (Preview)'; '5440fd1f-7ecb-4221-8110-145efaa6372f' = 'Beta'
    }
    $url = if ($cfg.UpdateChannel) { $cfg.UpdateChannel } else { $cfg.CDNBaseUrl }
    $channel = 'Unknown'
    foreach ($k in $channels.Keys) { if ("$url" -match $k) { $channel = $channels[$k] } }
    $shared = Join-Path $env:CommonProgramFiles 'Microsoft Shared\ClickToRun'
    [pscustomobject]@{
        Version = $cfg.VersionToReport; Platform = $cfg.Platform; Culture = $cfg.ClientCulture
        Products = $cfg.ProductReleaseIds; Channel = $channel
        RepairExe = Join-Path $shared 'OfficeClickToRun.exe'; ClientExe = Join-Path $shared 'OfficeC2RClient.exe'
    }
}

# ---------------- HTML reports ----------------
function ConvertTo-HtmlSafe([string]$Text) { [System.Net.WebUtility]::HtmlEncode($Text) }

function ConvertTo-ReportTable($Rows) {
    $rows = @($Rows | Where-Object { $null -ne $_ })
    if (-not $rows) { return '<p class="muted">No data.</p>' }
    $props = @($rows[0].PSObject.Properties.Name)
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('<table><thead><tr>')
    foreach ($p in $props) { [void]$sb.Append("<th>$(ConvertTo-HtmlSafe $p)</th>") }
    [void]$sb.Append('</tr></thead><tbody>')
    foreach ($r in $rows) {
        [void]$sb.Append('<tr>')
        foreach ($p in $props) { [void]$sb.Append("<td>$(ConvertTo-HtmlSafe ([string]$r.$p))</td>") }
        [void]$sb.Append('</tr>')
    }
    [void]$sb.Append('</tbody></table>')
    $sb.ToString()
}

function New-HtmlReport {
    param([string]$Title, [string]$Subtitle, $Checks, $Sections, [string]$Path)
    $checks = @($Checks)
    $pass = @($checks | Where-Object Status -eq 'Pass').Count
    $warn = @($checks | Where-Object Status -eq 'Warn').Count
    $fail = @($checks | Where-Object Status -eq 'Fail').Count
    $sb = New-Object Text.StringBuilder
    foreach ($c in $checks) {
        $cls = $c.Status.ToLower()
        [void]$sb.Append("<tr><td><span class=""pill $cls"">$(ConvertTo-HtmlSafe $c.Status)</span></td><td>$(ConvertTo-HtmlSafe $c.Check)</td><td>$(ConvertTo-HtmlSafe $c.Detail)</td></tr>")
    }
    $checkRows = $sb.ToString()
    $sec = New-Object Text.StringBuilder
    foreach ($s in @($Sections)) {
        $inner = if ($s.Html) { $s.Html } else { ConvertTo-ReportTable $s.Rows }
        [void]$sec.Append("<section><h2>$(ConvertTo-HtmlSafe $s.Title)</h2>$inner</section>")
    }
    $html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>$(ConvertTo-HtmlSafe $Title)</title>
<style>
body{font-family:'Segoe UI',system-ui,sans-serif;margin:0;background:#f3f4f7;color:#1d2330}
.wrap{max-width:1100px;margin:0 auto;padding:32px 24px}
h1{margin:0 0 4px;font-size:26px}h2{font-size:17px;margin:0 0 10px}
.sub{color:#5d6878;margin:0 0 24px}
.summary{display:flex;gap:12px;margin-bottom:24px;flex-wrap:wrap}
.box{background:#fff;border:1px solid #dde1e8;padding:12px 18px;min-width:120px}
.box b{display:block;font-size:24px}
section{background:#fff;border:1px solid #dde1e8;padding:16px 18px;margin-bottom:16px;overflow-x:auto}
table{border-collapse:collapse;width:100%;font-size:13px}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #eceef2;vertical-align:top}
th{color:#5d6878;font-weight:600}
.pill{display:inline-block;padding:2px 8px;font-size:12px;font-weight:700;border-radius:3px}
.pass{background:#dcfce7;color:#14532d}.warn{background:#fef3c7;color:#78350f}.fail{background:#fee2e2;color:#7f1d1d}.info{background:#e0e7ff;color:#1e3a8a}
.muted{color:#5d6878}
@media print{body{background:#fff}section,.box{break-inside:avoid}}
</style></head><body><div class="wrap">
<h1>$(ConvertTo-HtmlSafe $Title)</h1>
<p class="sub">$(ConvertTo-HtmlSafe $Subtitle)</p>
<div class="summary">
<div class="box"><b>$pass</b>Passed</div><div class="box"><b>$warn</b>Warnings</div><div class="box"><b>$fail</b>Failed</div>
</div>
<section><h2>Checks</h2><table><thead><tr><th>Status</th><th>Check</th><th>Detail</th></tr></thead><tbody>$checkRows</tbody></table></section>
$($sec.ToString())
<p class="muted">Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') by IT Toolkit.</p>
</div></body></html>
"@
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Path $Path -Value $html -Encoding UTF8
}

# ---------------- Webhook (Discord / Slack / Teams incoming webhook) ----------------
function Send-Webhook([string]$Url, [string]$Text) {
    if (-not $Url -or -not $Text) { return }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    $body = if ($Url -match 'discord(app)?\.com') {
        @{ content = ('```' + "`n" + $Text.Substring(0, [math]::Min($Text.Length, 1900)) + "`n" + '```') }
    } else { @{ text = $Text } }
    Invoke-RestMethod -Uri $Url -Method Post -ContentType 'application/json' -Body ($body | ConvertTo-Json) -TimeoutSec 10 | Out-Null
}

# ---------------- Manufacturer driver tools (Dell / HP / Lenovo) ----------------
function Find-ProgramFile([string[]]$Relative) {
    foreach ($r in $Relative) {
        foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, 'C:\SWSetup')) {
            if (-not $base) { continue }
            $f = Join-Path $base $r
            if (Test-Path $f) { return $f }
        }
    }
    $null
}

function Invoke-OemUpdates([ValidateSet('Scan', 'Install')][string]$Mode) {
    $make = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    Log "Manufacturer: $make"
    New-Item -ItemType Directory -Path $ITK_ReportDir -Force | Out-Null
    if ($make -match 'Dell') {
        $exe = Find-ProgramFile 'Dell\CommandUpdate\dcu-cli.exe'
        if (-not $exe) { Log 'Installing Dell Command | Update...'; Invoke-WingetApps -Ids @('Dell.CommandUpdate.Universal') -Action Install; $exe = Find-ProgramFile 'Dell\CommandUpdate\dcu-cli.exe' }
        if (-not $exe) { Log 'Dell Command | Update could not be installed. Try Windows Update drivers instead.' 'ERROR'; return }
        if ($Mode -eq 'Scan') { & $exe /scan -silent } else { & $exe /applyUpdates -reboot=disable -silent }
        $code = $LASTEXITCODE
        $msg = switch ($code) { 0 { 'done' } 1 { 'done - restart required' } 5 { 'done - restart required' } 500 { 'no updates found' } default { "exit code $code" } }
        Log "Dell Command | Update: $msg" $(if ($code -in 0, 1, 5, 500) { 'OK' } else { 'WARN' })
    }
    elseif ($make -match 'HP|Hewlett') {
        $exe = Get-ChildItem 'C:\SWSetup', "$env:ProgramFiles\HP", "${env:ProgramFiles(x86)}\HP" -Filter HPImageAssistant.exe -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if (-not $exe) {
            Log 'Installing HP Image Assistant...'
            Invoke-WingetApps -Ids @('HP.ImageAssistant') -Action Install
            $exe = Get-ChildItem 'C:\SWSetup', "$env:ProgramFiles\HP", "${env:ProgramFiles(x86)}\HP", "$env:ProgramData\Microsoft\WinGet" -Filter HPImageAssistant.exe -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        }
        if (-not $exe) { Log 'HP Image Assistant could not be found after install. Try Windows Update drivers instead.' 'ERROR'; return }
        $report = Join-Path $ITK_ReportDir "HPIA_$(Get-Date -Format yyyyMMdd_HHmm)"
        $action = if ($Mode -eq 'Scan') { 'List' } else { 'Install' }
        $p = Start-Process -FilePath $exe -ArgumentList "/Operation:Analyze", "/Category:Drivers,Firmware,BIOS", "/Selection:All", "/Action:$action", "/Silent", "/Noninteractive", "/ReportFolder:`"$report`"" -Wait -PassThru
        Log "HP Image Assistant finished (exit code $($p.ExitCode)). Report: $report" $(if ($p.ExitCode -in 0, 256, 3010) { 'OK' } else { 'WARN' })
        Get-ChildItem $report -Filter *.json -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object {
            try { (Get-Content $_.FullName -Raw | ConvertFrom-Json).HPIA.Recommendations | Select-Object Name, TargetVersion, ReferenceVersion, Comments | Format-Table -AutoSize } catch {}
        }
    }
    elseif ($make -match 'Lenovo') {
        $exe = Find-ProgramFile 'Lenovo\System Update\tvsu.exe'
        if (-not $exe) { Log 'Installing Lenovo System Update...'; Invoke-WingetApps -Ids @('Lenovo.SystemUpdate') -Action Install; $exe = Find-ProgramFile 'Lenovo\System Update\tvsu.exe' }
        if (-not $exe) { Log 'Lenovo System Update could not be installed. Try Windows Update drivers instead.' 'ERROR'; return }
        $action = if ($Mode -eq 'Scan') { 'LIST' } else { 'INSTALL' }
        $cmd = "/CM -search A -action $action -includerebootpackages 1,3,4 -noicon -noreboot -nolicense"
        # System Update only accepts command-line mode when the same arguments are set as AdminCommandLine
        foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Lenovo\System Update\Preferences\UserSettings\General', 'HKLM:\SOFTWARE\Lenovo\System Update\Preferences\UserSettings\General') {
            if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
            Set-ItemProperty -Path $k -Name AdminCommandLine -Value $cmd
        }
        $p = Start-Process -FilePath $exe -ArgumentList $cmd -Wait -PassThru
        Log "Lenovo System Update finished (exit code $($p.ExitCode)). Its log is under C:\ProgramData\Lenovo\SystemUpdate." 'OK'
    }
    else {
        Log "No manufacturer tool for '$make'. Use 'Windows Update drivers' instead." 'WARN'
    }
}

# ---------------- Blue screen stop codes ----------------
$ITK_StopCodes = @{
    '0x0000000a' = 'IRQL_NOT_LESS_OR_EQUAL|A driver or faulty RAM. Update drivers, then test memory.'
    '0x00000019' = 'BAD_POOL_HEADER|A driver corrupting memory, or faulty RAM.'
    '0x0000001a' = 'MEMORY_MANAGEMENT|Usually faulty RAM. Run a memory test.'
    '0x0000001e' = 'KMODE_EXCEPTION_NOT_HANDLED|A driver crashed. Update or roll back recent drivers.'
    '0x0000003b' = 'SYSTEM_SERVICE_EXCEPTION|A driver or system file. Update drivers and run SFC / DISM.'
    '0x0000004e' = 'PFN_LIST_CORRUPT|Faulty RAM or a driver.'
    '0x00000050' = 'PAGE_FAULT_IN_NONPAGED_AREA|Faulty RAM, a driver or antivirus. Test memory, update drivers.'
    '0x00000077' = 'KERNEL_STACK_INPAGE_ERROR|Disk or cable problem. Check disk health.'
    '0x0000007a' = 'KERNEL_DATA_INPAGE_ERROR|Disk, cable or RAM problem. Check disk health.'
    '0x0000007e' = 'SYSTEM_THREAD_EXCEPTION_NOT_HANDLED|A driver crashed (often graphics). Update drivers.'
    '0x0000007f' = 'UNEXPECTED_KERNEL_MODE_TRAP|Hardware fault, overheating or overclocking.'
    '0x0000009c' = 'MACHINE_CHECK_EXCEPTION|CPU or motherboard hardware error.'
    '0x0000009f' = 'DRIVER_POWER_STATE_FAILURE|A driver failed on sleep / wake. Update drivers, check BIOS.'
    '0x000000be' = 'ATTEMPTED_WRITE_TO_READONLY_MEMORY|A faulty driver.'
    '0x000000c2' = 'BAD_POOL_CALLER|A faulty driver.'
    '0x000000c5' = 'DRIVER_CORRUPTED_EXPOOL|A faulty driver.'
    '0x000000d1' = 'DRIVER_IRQL_NOT_LESS_OR_EQUAL|A faulty driver (often network or graphics).'
    '0x000000ea' = 'THREAD_STUCK_IN_DEVICE_DRIVER|Graphics driver or graphics card.'
    '0x000000ef' = 'CRITICAL_PROCESS_DIED|Corrupt system files or a failing disk. Run SFC / DISM, check disk.'
    '0x000000f4' = 'CRITICAL_OBJECT_TERMINATION|Failing disk or storage driver.'
    '0x000000fc' = 'ATTEMPTED_EXECUTE_OF_NOEXECUTE_MEMORY|A faulty driver or RAM.'
    '0x00000101' = 'CLOCK_WATCHDOG_TIMEOUT|CPU problem, overclocking or BIOS. Update BIOS.'
    '0x00000109' = 'CRITICAL_STRUCTURE_CORRUPTION|A driver, RAM or malware.'
    '0x0000010e' = 'VIDEO_MEMORY_MANAGEMENT_INTERNAL|Graphics driver.'
    '0x00000116' = 'VIDEO_TDR_FAILURE|Graphics driver or graphics card. Clean-install the graphics driver.'
    '0x00000117' = 'VIDEO_TDR_TIMEOUT_DETECTED|Graphics driver or graphics card.'
    '0x00000119' = 'VIDEO_SCHEDULER_INTERNAL_ERROR|Graphics driver.'
    '0x00000124' = 'WHEA_UNCORRECTABLE_ERROR|Hardware error: CPU, RAM, overheating, overclocking or power.'
    '0x0000012b' = 'FAULTY_HARDWARE_CORRUPTED_PAGE|Faulty RAM.'
    '0x00000133' = 'DPC_WATCHDOG_VIOLATION|Storage driver or SSD firmware. Update chipset / storage drivers and SSD firmware.'
    '0x00000139' = 'KERNEL_SECURITY_CHECK_FAILURE|A driver, RAM or corrupt system files.'
    '0x00000144' = 'BUGCODE_USB3_DRIVER|USB 3 driver or a USB device.'
    '0x00000154' = 'UNEXPECTED_STORE_EXCEPTION|Disk or storage driver problem.'
    '0x000001a5' = 'USB_DRIPS_BLOCKER_SURPRISE_REMOVAL_LIVEDUMP|USB device or dock problem.'
}
function Get-StopCodeInfo([string]$Code) {
    $c = '0x{0:x8}' -f [Convert]::ToUInt32(($Code -replace '^0x', ''), 16)
    if ($ITK_StopCodes.ContainsKey($c)) { $p = $ITK_StopCodes[$c] -split '\|', 2; return [pscustomobject]@{ Code = $c; Name = $p[0]; Advice = $p[1] } }
    [pscustomobject]@{ Code = $c; Name = 'Unknown'; Advice = 'Look up the stop code, or analyse the dump file.' }
}

# ---------------- Before / after snapshots ----------------
function Get-SystemSnapshot {
    $s = [ordered]@{}
    $apps = [ordered]@{}
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } | Sort-Object DisplayName | ForEach-Object { $apps[$_.DisplayName] = "$($_.DisplayVersion)" }
    $s['Installed apps'] = $apps
    $svc = [ordered]@{}; Get-Service | Sort-Object Name | ForEach-Object { $svc[$_.Name] = "$($_.StartType), $($_.Status)" }; $s['Services'] = $svc
    $st = [ordered]@{}; Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | ForEach-Object { $st["$($_.Name) ($($_.User))"] = $_.Command }; $s['Startup items'] = $st
    $tk = [ordered]@{}; Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.TaskName -notlike 'ITToolkit_*' } | ForEach-Object { $tk["$($_.TaskPath)$($_.TaskName)"] = "$($_.State)" }; $s['Scheduled tasks'] = $tk
    $pr = [ordered]@{}; Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { $pr[$_.Name] = "$($_.DriverName) on $($_.PortName)" }; $s['Printers'] = $pr
    $nw = [ordered]@{}; Get-NetIPConfiguration -ErrorAction SilentlyContinue | ForEach-Object { $nw[$_.InterfaceAlias] = "IP $($_.IPv4Address.IPAddress -join ',') GW $($_.IPv4DefaultGateway.NextHop -join ',') DNS $((($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses) -join ',')" }; $s['Network'] = $nw
    $dr = [ordered]@{}; Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_.DriverProviderName -and $_.DriverProviderName -notmatch '^Microsoft' -and $_.DeviceName } | ForEach-Object { $dr[$_.DeviceName] = "$($_.DriverVersion)" }; $s['Drivers (third-party)'] = $dr
    $ad = [ordered]@{}; try { Get-LocalGroupMember -Group Administrators -ErrorAction Stop | ForEach-Object { $ad[$_.Name] = $_.ObjectClass } } catch {}; $s['Local administrators'] = $ad
    $fw = [ordered]@{}; Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object { $fw[$_.Name] = "Enabled: $($_.Enabled)" }; $s['Firewall'] = $fw
    $ot = [ordered]@{}
    $ot['Pending reboot'] = "$(Test-PendingReboot)"
    $ot['Power plan'] = "$((powercfg /getactivescheme) -replace '^.*\(|\)$', '')"
    $h = "$env:windir\System32\drivers\etc\hosts"; if (Test-Path $h) { $ot['Hosts file (hash)'] = (Get-FileHash $h -Algorithm SHA256).Hash.Substring(0, 16) }
    try { $mp = Get-MpComputerStatus -ErrorAction Stop; $ot['Defender real-time'] = "$($mp.RealTimeProtectionEnabled)" } catch {}
    $sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"; $ot['System drive free'] = Format-Size $sys.FreeSpace
    $s['Other'] = $ot
    [pscustomobject]@{ Computer = $env:COMPUTERNAME; Taken = (Get-Date -Format 's'); Sections = $s }
}
