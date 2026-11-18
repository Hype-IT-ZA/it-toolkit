<#
    IT Toolkit - one-line installer and launcher
    https://github.com/Hype-IT-ZA/it-toolkit

    Run in an elevated PowerShell window or a ScreenConnect Backstage PowerShell console:

        irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex

    What it does:
      1. Downloads the latest version of the repo from GitHub
      2. Copies ITToolkit.ps1 and the Tools folder to C:\ProgramData\ITToolkit
         (your own extra files in the Tools folder are kept)
      3. Starts the toolkit

    Run it again any time to update.
#>
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'SilentlyContinue'

    $Repo   = 'Hype-IT-ZA/it-toolkit'
    $Branch = 'main'
    $Dest   = Join-Path $env:ProgramData 'ITToolkit'

    # Older Windows builds default to TLS 1.0 - GitHub needs TLS 1.2
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Write-Host 'Warning: not running elevated - many tools need admin rights.' -ForegroundColor Yellow }

    Write-Host "IT Toolkit: downloading the latest version from github.com/$Repo ..." -ForegroundColor Cyan
    $tmp = Join-Path $env:TEMP ('ittoolkit_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'repo.zip'
        Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1

        New-Item -ItemType Directory -Path (Join-Path $Dest 'Tools') -Force | Out-Null
        Copy-Item -Path (Join-Path $src.FullName 'ITToolkit.ps1') -Destination $Dest -Force
        $srcTools = Join-Path $src.FullName 'Tools'
        if (Test-Path $srcTools) { Copy-Item -Path (Join-Path $srcTools '*') -Destination (Join-Path $Dest 'Tools') -Recurse -Force }
    }
    catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path (Join-Path $Dest 'ITToolkit.ps1')) { Write-Host 'Starting the copy that is already installed instead.' -ForegroundColor Yellow }
        else { return }
    }
    finally {
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Installed to $Dest - starting IT Toolkit..." -ForegroundColor Green
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    & (Join-Path $Dest 'ITToolkit.ps1')
}
