# =====================================================================
#  IT Toolkit - headless mode (no window)
#  Used when ITToolkit.ps1 is started with -Run, -Install, -Uninstall,
#  -Tweak, -HealthCheck, -Inventory or -List. Good for ScreenConnect's
#  Commands tab, RMM scripts and running the same fix on many PCs.
# =====================================================================

$script:HeadlessErrors = 0
$script:HeadlessExitCode = 0

function Write-HeadlessLine([string]$Level, [string]$Text) {
    $color = switch ($Level) { 'OK' { 'Green' } 'WARN' { 'Yellow' } 'ERROR' { 'Red' } 'HEAD' { 'Cyan' } default { 'Gray' } }
    $first = $true
    foreach ($line in (($Text -replace "`r", '') -split "`n")) {
        if ($first) { Write-Host ('[{0:HH:mm:ss}] {1}' -f (Get-Date), $line) -ForegroundColor $color; $first = $false }
        else { Write-Host ('           ' + $line) -ForegroundColor $color }
    }
}
function Log { param([string]$Message, [string]$Level = 'INFO') Write-HeadlessLine $Level $Message }
function Send-ToolkitEvent { param([string]$Type, $Data) }

function Write-HeadlessItem($Item) {
    if ($Item.Level -eq 'EVENT') {
        if ($Item.Type -eq 'TweakStatus') {
            $state = if ($Item.Data.Applied -eq $true) { 'applied' } elseif ($Item.Data.Applied -eq $false) { 'not applied' } else { 'unknown' }
            Write-HeadlessLine 'INFO' "$($Item.Data.Name): $state"
        }
        return
    }
    if ($Item.Level -eq 'ERROR') { $script:HeadlessErrors++ }
    Write-HeadlessLine $Item.Level $Item.Text
}

function Invoke-HeadlessTask([string]$Name, [string]$Code, [hashtable]$Params = @{}) {
    Write-HeadlessLine 'HEAD' ">> $Name"
    $job = Start-ToolkitTask $Name $Code $Params
    $item = $null
    while (-not $job.Handle.IsCompleted) {
        while ($Queue.TryDequeue([ref]$item)) { Write-HeadlessItem $item }
        Start-Sleep -Milliseconds 150
    }
    while ($Queue.TryDequeue([ref]$item)) { Write-HeadlessItem $item }
    try { [void]$job.PS.EndInvoke($job.Handle) } catch { Write-HeadlessLine 'ERROR' $_.Exception.Message; $script:HeadlessErrors++ }
    $job.PS.Dispose()
    Write-HeadlessLine 'OK' ('Done: {0} ({1:N1} s)' -f $Name, ((Get-Date) - $job.Start).TotalSeconds)
}

function Resolve-AppIds([string[]]$Names) {
    foreach ($n in $Names) {
        $app = $script:Apps | Where-Object { $_.id -eq $n -or $_.name -eq $n } | Select-Object -First 1
        if ($app) { $app.id } else { $n }   # unknown names are passed to winget as an ID
    }
}

Write-HeadlessLine 'HEAD' "$($Config.AppName) $($Config.Version) - headless mode on $env:COMPUTERNAME"
foreach ($e in $script:LoadErrors) { Write-HeadlessLine 'ERROR' "Failed to load $e" }

if ($List) {
    Write-Host "`nTOOLS  (use: -Run 'Name')" -ForegroundColor Cyan
    $script:Tools | Where-Object { -not $_.Launch } | Sort-Object Tab, Category, Name |
        Format-Table @{ n = 'Tab'; e = { $_.Tab } }, Category, Name, @{ n = 'Inputs'; e = { ($_.Inputs | ForEach-Object { ($_ -split '\|')[0] }) -join ', ' } }, @{ n = 'Needs -Force'; e = { [bool]$_.Confirm } } -AutoSize | Out-String -Width 220 | Write-Host
    Write-Host "TWEAKS  (use: -Tweak 'Name'  and -Undo to revert)" -ForegroundColor Cyan
    $script:Tweaks | Sort-Object Category, Name | Format-Table Category, Name, Recommended, @{ n = 'Needs -Force'; e = { [bool]$_.Warning } } -AutoSize | Out-String -Width 220 | Write-Host
    Write-Host "APPS  (use: -Install id, id)" -ForegroundColor Cyan
    $script:Apps | Sort-Object category, name | Format-Table category, name, id -AutoSize | Out-String -Width 220 | Write-Host
}

if ($Setup) {
    try {
        $setupData = if ($Setup -match '^https?://') { Invoke-RestMethod -Uri $Setup -TimeoutSec 20 } else { Get-Content -Path $Setup -Raw | ConvertFrom-Json }
        if ($setupData -is [string]) { $setupData = $setupData | ConvertFrom-Json }
        $setupApps = @($setupData.apps | Where-Object { $_ }); $setupTweaks = @($setupData.tweaks | Where-Object { $_ })
        Write-HeadlessLine 'INFO' "Setup '$($setupData.name)': $($setupApps.Count) apps, $($setupTweaks.Count) tweaks"
        $Install = @(@($Install) + $setupApps | Where-Object { $_ })
        $Tweak = @(@($Tweak) + $setupTweaks | Where-Object { $_ })
    } catch { Write-HeadlessLine 'ERROR' "Could not read setup '$Setup': $($_.Exception.Message)"; $script:HeadlessErrors++ }
}

foreach ($n in @($Run)) {
    if (-not $n) { continue }
    $tool = $script:Tools | Where-Object { $_.Name -eq $n -or "$($_.Category)/$($_.Name)" -eq $n } | Select-Object -First 1
    if (-not $tool) { Write-HeadlessLine 'ERROR' "No tool named '$n'. Use -List to see them."; $script:HeadlessErrors++; continue }
    if ($tool.Launch) { Write-HeadlessLine 'WARN' "'$n' opens a window - skipped in headless mode."; continue }
    if ($tool.Confirm -and -not $Force) { Write-HeadlessLine 'WARN' "'$n' needs confirmation: $($tool.Confirm)  Add -Force to run it."; continue }
    $params = @{}
    foreach ($spec in $tool.Inputs) {
        $parts = $spec -split '\|', 3
        $params[$parts[0]] = if ($Inputs.ContainsKey($parts[0])) { [string]$Inputs[$parts[0]] } elseif ($parts.Count -gt 2) { $parts[2] } else { '' }
    }
    Invoke-HeadlessTask $tool.Name $tool.Code $params
}

if ($Install) {
    $ids = @(Resolve-AppIds $Install)
    Invoke-HeadlessTask "Install apps: $($ids -join ', ')" 'param($P) Invoke-WingetApps -Ids $P.Ids -Action Install' @{ Ids = $ids }
}
if ($Uninstall) {
    $ids = @(Resolve-AppIds $Uninstall)
    Invoke-HeadlessTask "Uninstall apps: $($ids -join ', ')" 'param($P) Invoke-WingetApps -Ids $P.Ids -Action Uninstall' @{ Ids = $ids }
}

if ($Tweak) {
    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($n in $Tweak) {
        $t = $script:Tweaks | Where-Object Name -eq $n | Select-Object -First 1
        if (-not $t) { Write-HeadlessLine 'ERROR' "No tweak named '$n'. Use -List to see them."; $script:HeadlessErrors++; continue }
        if ($Undo -and $t.NoUndo) { Write-HeadlessLine 'WARN' "'$n' cannot be undone automatically - skipped."; continue }
        if (-not $Undo -and $t.Warning -and -not $Force) { Write-HeadlessLine 'WARN' "'$n': $($t.Warning)  Add -Force to apply it."; continue }
        $selected.Add($t)
    }
    if ($selected.Count) {
        $mode = if ($Undo) { 'Revert' } else { 'Apply' }
        $code = {
            param($P)
            if ($P.Mode -eq 'Apply') { [void](New-ToolkitRestorePoint 'IT Toolkit - before tweaks') }
            foreach ($t in $P.Tweaks) {
                try { Invoke-Tweak -Tweak $t -Mode $P.Mode; Log "$($P.Mode): $($t.Name)" 'OK' } catch { Log "$($t.Name): $($_.Exception.Message)" 'ERROR' }
                Send-ToolkitEvent 'TweakStatus' @{ Name = $t.Name; Applied = (Invoke-Tweak -Tweak $t -Mode Test) }
            }
            Log 'Some changes take effect after Explorer restarts or the user signs out again.'
        }.ToString()
        Invoke-HeadlessTask "$mode tweaks" $code @{ Tweaks = $selected.ToArray(); Mode = $mode }
    }
}

if ($SelfTest) {
    $t = $script:Tools | Where-Object Name -eq 'Toolkit self-test' | Select-Object -First 1
    if ($t) { Invoke-HeadlessTask $t.Name $t.Code @{} }
}
if ($TweakStatus) {
    $code = {
        param($P)
        $on = 0
        foreach ($t in $P.Tweaks) {
            $state = $null; try { $state = Invoke-Tweak -Tweak $t -Mode Test } catch { Log "$($t.Name): $($_.Exception.Message)" 'ERROR' }
            if ($state -eq $true) { $on++ }
            Log ('{0,-12} {1,-22} {2}' -f $(if ($state -eq $true) { 'APPLIED' } elseif ($state -eq $false) { 'not applied' } else { 'unknown' }), $t.Category, $t.Name) $(if ($state -eq $true) { 'OK' } else { 'INFO' })
        }
        Log "$on of $($P.Tweaks.Count) tweaks are applied." 'OK'
    }.ToString()
    Invoke-HeadlessTask 'Tweak status' $code @{ Tweaks = $script:Tweaks.ToArray() }
}

if ($HealthCheck) {
    $t = $script:Tools | Where-Object Name -eq 'Health check report' | Select-Object -First 1
    if ($t) { Invoke-HeadlessTask $t.Name $t.Code @{} }
}
if ($Inventory) {
    $t = $script:Tools | Where-Object Name -eq 'Inventory export' | Select-Object -First 1
    if ($t) { Invoke-HeadlessTask $t.Name $t.Code @{} }
}

if ($script:HeadlessErrors) {
    Write-HeadlessLine 'WARN' "Finished with $($script:HeadlessErrors) error line(s)."
    $script:HeadlessExitCode = 1
} else {
    Write-HeadlessLine 'OK' 'Finished.'
}
