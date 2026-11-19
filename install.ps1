<#
    IT Toolkit - one-line installer and launcher
    https://github.com/Hype-IT-ZA/it-toolkit

    Open the GUI (elevated PowerShell or a ScreenConnect Backstage PowerShell console):

        irm hype-it-za.github.io/it-toolkit | iex
        (long form: irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex)

    Headless (no window) - pass the same options as ITToolkit.ps1:

        & ([scriptblock]::Create((irm hype-it-za.github.io/it-toolkit))) -Run 'Safe cleanup'
        & ([scriptblock]::Create((irm hype-it-za.github.io/it-toolkit))) -HealthCheck

    A specific version (if a new release ever causes problems):

        & ([scriptblock]::Create((irm hype-it-za.github.io/it-toolkit))) -Version 2.2.0

    What it does:
      1. Downloads the latest release from GitHub (or the version you ask for)
      2. Copies it to C:\ProgramData\ITToolkit (your own files in the Tools folder are kept)
      3. Starts the toolkit
    Run it again any time to update.
#>
param(
    [string[]]$Run, [string[]]$Install, [string[]]$Uninstall, [string[]]$Tweak, [switch]$Undo,
    [switch]$HealthCheck, [switch]$Inventory, [switch]$List, [switch]$Force, [hashtable]$Inputs, [string]$Setup,
    [string]$Version   # install a specific release, e.g. 2.1.0 (default: latest)
)
$ITK_PassThru = @{}
foreach ($k in $PSBoundParameters.Keys) { if ($k -ne 'Version') { $ITK_PassThru[$k] = $PSBoundParameters[$k] } }
$ITK_Version = $Version

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'SilentlyContinue'

    $Repo   = 'Hype-IT-ZA/it-toolkit'
    $Branch = 'main'
    $Dest   = Join-Path $env:ProgramData 'ITToolkit'
    $Parts  = 'ITToolkit.ps1', 'version.txt', 'core', 'modules', 'data', 'Tools'

    # Older Windows builds default to TLS 1.0 - GitHub needs TLS 1.2
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Write-Host 'Warning: not running elevated - many tools need admin rights.' -ForegroundColor Yellow }

    # Latest release asset first (signed when a certificate is configured), then the branch / tag archive
    $sources = if ($ITK_Version) {
        $v = $ITK_Version.TrimStart('v')
        "https://github.com/$Repo/releases/download/v$v/ITToolkit.zip", "https://github.com/$Repo/archive/refs/tags/v$v.zip"
    } else {
        "https://github.com/$Repo/releases/latest/download/ITToolkit.zip", "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
    }
    $what = if ($ITK_Version) { "version $ITK_Version" } else { 'the latest version' }
    Write-Host "IT Toolkit: downloading $what from github.com/$Repo ..." -ForegroundColor Cyan
    $tmp = Join-Path $env:TEMP ('ittoolkit_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'repo.zip'
        $got = $null
        foreach ($u in $sources) {
            try { Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing; $got = $u; break } catch { }
        }
        if (-not $got) { throw "IT Toolkit $what was not found on GitHub." }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
        foreach ($p in $Parts) {
            $from = Join-Path $src.FullName $p
            if (-not (Test-Path $from)) { continue }
            if ((Get-Item $from).PSIsContainer) {
                $to = Join-Path $Dest $p
                New-Item -ItemType Directory -Path $to -Force | Out-Null
                # core / modules / data are replaced so removed files do not linger; Tools keeps your own files
                if ($p -ne 'Tools') { Get-ChildItem $to -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
                Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force
            } else {
                Copy-Item -Path $from -Destination $Dest -Force
            }
        }
    }
    catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path (Join-Path $Dest 'ITToolkit.ps1')) { Write-Host 'Starting the copy that is already installed instead.' -ForegroundColor Yellow }
        else { return }
    }
    finally {
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    $ver = Get-Content (Join-Path $Dest 'version.txt') -ErrorAction SilentlyContinue
    Write-Host "IT Toolkit $ver installed to $Dest - starting..." -ForegroundColor Green
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    & (Join-Path $Dest 'ITToolkit.ps1') @ITK_PassThru
}
