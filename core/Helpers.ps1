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
