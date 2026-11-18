<#
.SYNOPSIS
    IT Toolkit - a dark / light GUI toolbox for Windows support: tools, app installs, tweaks and update policies.
    Built to run inside ScreenConnect Backstage (as SYSTEM, without Explorer) or on any Windows PC.

.DESCRIPTION
    Tabs:
      Tools    - 100+ everyday IT tools (system, network, disk, repair, Office, user session, security, reports...)
      Install  - tick apps and install / upgrade / uninstall them with winget, with presets
      Tweaks   - privacy, performance and UI tweaks; every tweak can be undone, restore point first
      Updates  - Windows Update policies (security-focused, stay on version, drivers) and update actions

.EXAMPLE
    # GUI (latest version, from GitHub)
    irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex

.EXAMPLE
    # Headless - no window, for ScreenConnect "Commands" or scripts
    .\ITToolkit.ps1 -List
    .\ITToolkit.ps1 -Run 'Disk space', 'Safe cleanup'
    .\ITToolkit.ps1 -Run 'Ping' -Inputs @{ Target = '1.1.1.1' }
    .\ITToolkit.ps1 -Install Google.Chrome, 7zip.7zip
    .\ITToolkit.ps1 -Tweak 'Show file extensions' -Undo
    .\ITToolkit.ps1 -HealthCheck

.LINK
    https://github.com/Hype-IT-ZA/it-toolkit
#>
[CmdletBinding()]
param(
    [string[]]$Run,          # tool names to run without the GUI
    [string[]]$Install,      # winget IDs or app names to install
    [string[]]$Uninstall,    # winget IDs or app names to uninstall
    [string[]]$Tweak,        # tweak names to apply (or revert with -Undo)
    [switch]$Undo,
    [switch]$HealthCheck,    # save a health check report
    [switch]$Inventory,      # save an inventory CSV
    [switch]$List,           # list everything that can be run
    [switch]$Force,          # allow tools / tweaks that normally ask "are you sure?"
    [hashtable]$Inputs = @{},
    [switch]$NoRelaunch
)

$Headless = [bool]($Run -or $Install -or $Uninstall -or $Tweak -or $HealthCheck -or $Inventory -or $List)

# The GUI needs an STA thread - relaunch if needed
if (-not $Headless -and [Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA' -and -not $NoRelaunch -and $PSCommandPath) {
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"", '-NoRelaunch')
    return
}

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# =====================================================================
#  CONFIG
# =====================================================================
$Root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Config = @{
    AppName     = 'IT Toolkit'
    Version     = '2.0.0'
    Repo        = 'Hype-IT-ZA/it-toolkit'
    Branch      = 'main'
    Root        = $Root
    DataDir     = Join-Path $env:ProgramData 'ITToolkit'
    HelpersPath = Join-Path $Root 'core\Helpers.ps1'
    ModulesDir  = Join-Path $Root 'modules'
    ToolsDir    = Join-Path $Root 'Tools'
    AppsFile    = Join-Path $Root 'data\apps.json'
}
$Config.LogDir     = Join-Path $Config.DataDir 'Logs'
$Config.ReportDir  = Join-Path $Config.DataDir 'Reports'
$Config.InstallUrl = "https://raw.githubusercontent.com/$($Config.Repo)/$($Config.Branch)/install.ps1"
$Config.VersionUrl = "https://raw.githubusercontent.com/$($Config.Repo)/$($Config.Branch)/version.txt"
foreach ($d in $Config.DataDir, $Config.LogDir, $Config.ReportDir) { New-Item -ItemType Directory -Path $d -Force -ErrorAction SilentlyContinue | Out-Null }

if (-not (Test-Path $Config.HelpersPath)) {
    Write-Host "core\Helpers.ps1 is missing next to ITToolkit.ps1. Re-download the full toolkit:" -ForegroundColor Red
    Write-Host "  irm $($Config.InstallUrl) | iex" -ForegroundColor Yellow
    return
}
. $Config.HelpersPath
$Settings = Get-ToolkitSettings

# =====================================================================
#  REGISTRIES (tools, tweaks, apps)
# =====================================================================
$script:Tools  = New-Object System.Collections.Generic.List[object]
$script:Tweaks = New-Object System.Collections.Generic.List[object]
$script:Apps   = @()
$script:Presets = [ordered]@{}

function Register-Tool {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Name,
        [string]$Description = '',
        [Parameter(Mandatory)][scriptblock]$Action,
        [string[]]$Inputs = @(),
        [string]$Confirm,
        [switch]$Launch,
        [ValidateSet('Tools', 'Updates')][string]$Tab = 'Tools'
    )
    $script:Tools.Add([pscustomobject]@{
        Tab = $Tab; Category = $Category; Name = $Name; Description = $Description
        Action = $Action; Code = $Action.ToString(); Inputs = @($Inputs | Where-Object { $_ })
        Confirm = $Confirm; Launch = [bool]$Launch
    })
}

function Register-Tweak {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Name,
        [string]$Description = '',
        [hashtable[]]$Registry = @(),     # @{ Path; Name; Value; Type='DWord'; Revert=<value> (omit = delete on undo) }  HKCU:\ = every signed-in user
        [hashtable[]]$Services = @(),     # @{ Name; Startup='Disabled'; Revert='Automatic' }
        [scriptblock]$Apply,
        [scriptblock]$Revert,
        [scriptblock]$Test,               # return $true when the tweak is applied
        [switch]$Recommended,
        [string]$Warning,                 # shown before applying; marks the tweak as CAUTION
        [switch]$NoUndo
    )
    $script:Tweaks.Add([pscustomobject]@{
        Category = $Category; Name = $Name; Description = $Description
        Registry = $Registry; Services = $Services
        ApplyCode = $(if ($Apply) { $Apply.ToString() } else { '' })
        RevertCode = $(if ($Revert) { $Revert.ToString() } else { '' })
        TestCode = $(if ($Test) { $Test.ToString() } else { '' })
        Recommended = [bool]$Recommended; Warning = $Warning; NoUndo = [bool]$NoUndo
    })
}

$script:LoadErrors = New-Object System.Collections.Generic.List[string]
if (Test-Path $Config.ModulesDir) {
    foreach ($file in Get-ChildItem -Path $Config.ModulesDir -Filter '*.ps1' -File | Sort-Object Name) {
        try { . $file.FullName } catch { $script:LoadErrors.Add("$($file.Name): $($_.Exception.Message)") }
    }
}
$builtInToolCount = $script:Tools.Count
if (Test-Path $Config.ToolsDir) {
    foreach ($file in Get-ChildItem -Path $Config.ToolsDir -Filter '*.ps1' -File | Sort-Object Name) {
        try { . $file.FullName } catch { $script:LoadErrors.Add("Tools\$($file.Name): $($_.Exception.Message)") }
    }
}
$PluginToolCount = $script:Tools.Count - $builtInToolCount

if (Test-Path $Config.AppsFile) {
    try {
        $catalog = Get-Content $Config.AppsFile -Raw | ConvertFrom-Json
        $script:Apps = @($catalog.apps)
        foreach ($p in $catalog.presets.PSObject.Properties) { $script:Presets[$p.Name] = @($p.Value) }
    } catch { $script:LoadErrors.Add("data\apps.json: $($_.Exception.Message)") }
}

# =====================================================================
#  BACKGROUND RUNNER (shared by the GUI and headless mode)
# =====================================================================
$Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
$Pool = [runspacefactory]::CreateRunspacePool(1, 4)
$Pool.ApartmentState = 'STA'
$Pool.Open()
$script:JobCounter = 0

$Wrapper = {
    param($Queue, $Code, $Params, $HelpersPath, $JobId)
    function Log { param([string]$Message, [string]$Level = 'INFO') $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = $Level; Text = $Message; JobId = $JobId; Type = $null; Data = $null }) }
    function Send-ToolkitEvent { param([string]$Type, $Data) $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = 'EVENT'; Text = ''; JobId = $JobId; Type = $Type; Data = $Data }) }
    $ProgressPreference = 'SilentlyContinue'; $ErrorActionPreference = 'Continue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    try { . $HelpersPath } catch { Log "Could not load helpers: $($_.Exception.Message)" 'ERROR' }
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
                $t = (($o -replace "`0", '') -split "`r")[-1]              # UTF-16 nulls (sfc) and progress redraws (dism)
                $t = $t -replace '\x1b\[[0-9;?]*[A-Za-z]', ''               # ANSI colour codes
                if ($t.Trim() -and $t -notmatch '[\u2580-\u259F]' -and $t -notmatch '^\s*[-\\|/]\s*$') { Log $t }
            }
            else { $buffer.Add($o) }
        }
        & $flush
    } catch { & $flush; Log $_.Exception.Message 'ERROR' }
}

function Start-ToolkitTask([string]$Name, [string]$Code, [hashtable]$Params = @{}) {
    $script:JobCounter++
    $ps = [powershell]::Create(); $ps.RunspacePool = $Pool
    [void]$ps.AddScript($Wrapper.ToString()).AddArgument($Queue).AddArgument($Code).AddArgument($Params).AddArgument($Config.HelpersPath).AddArgument($script:JobCounter)
    $handle = $ps.BeginInvoke()
    [pscustomobject]@{
        Id = $script:JobCounter; Name = $Name; PS = $ps; Handle = $handle; Start = (Get-Date); End = $null
        Stopped = $false; Quiet = $false; Status = 'Running'; LastOk = ''
        Warnings = (New-Object System.Collections.Generic.List[string]); Errors = (New-Object System.Collections.Generic.List[string])
    }
}

# =====================================================================
#  GO
# =====================================================================
try {
    if ($Headless) { . (Join-Path $Root 'core\Headless.ps1') }
    else { . (Join-Path $Root 'core\UI.ps1') }
}
finally {
    try { $Pool.Close(); $Pool.Dispose() } catch {}
}
if ($Headless) { exit $script:HeadlessExitCode }
