# Software (winget). The Install tab has the full app checklist.
Register-Tool 'Software' 'Installed software' 'List installed programs (optional filter)' -Inputs 'Filter|Name contains (leave blank for all)|' {
    param($P)
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $f = $P.Filter
    $apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent -and (-not $f -or $_.DisplayName -like "*$f*") } |
        Sort-Object DisplayName -Unique
    Log "$(@($apps).Count) programs found"
    $apps | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table -AutoSize
}
Register-Tool 'Software' 'Available app upgrades' 'Apps winget can update' {
    $wg = Get-WingetPath
    if (-not $wg) { Log 'winget was not found. Run "Install / repair winget" first.' 'ERROR'; return }
    [void](Invoke-Winget $wg @('upgrade', '--include-unknown', '--accept-source-agreements', '--source', 'winget'))
}
Register-Tool 'Software' 'Upgrade all apps' 'winget upgrade --all (silent)' -Confirm 'Every app winget can update will be upgraded silently. Open apps may be closed. Continue?' {
    $wg = Get-WingetPath
    if (-not $wg) { Log 'winget was not found. Run "Install / repair winget" first.' 'ERROR'; return }
    $code = Invoke-Winget $wg @('upgrade', '--all', '--silent', '--include-unknown', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity', '--source', 'winget')
    Log "Upgrade all: $(Get-WingetResultText $code)" $(if ($ITK_WingetOkCodes -contains $code) { 'OK' } else { 'WARN' })
}
Register-Tool 'Software' 'Search winget' 'Find a package ID to install' -Inputs 'Query|App name to search for|' {
    param($P)
    $wg = Get-WingetPath
    if (-not $wg) { Log 'winget was not found. Run "Install / repair winget" first.' 'ERROR'; return }
    [void](Invoke-Winget $wg @('search', $P.Query, '--accept-source-agreements', '--source', 'winget'))
}
Register-Tool 'Software' 'Install by winget ID' 'Install any package by its exact ID' -Inputs 'Id|winget package ID (e.g. Google.Chrome)|' {
    param($P) Invoke-WingetApps -Ids @($P.Id) -Action Install
}
Register-Tool 'Software' 'Install / repair winget' 'Installs the official WinGet module and repairs winget' {
    $wg = Get-WingetPath
    if ($wg) { Log "winget found: $wg" 'OK' }
    Log 'Installing NuGet provider and the Microsoft.WinGet.Client module...'
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ErrorAction Stop | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Scope AllUsers -Repository PSGallery -AllowClobber -ErrorAction Stop
    Import-Module Microsoft.WinGet.Client -ErrorAction Stop
    Log 'Repairing winget (this can take a few minutes)...'
    Repair-WinGetPackageManager -AllUsers -Latest -ErrorAction Stop
    $wg = Get-WingetPath
    if ($wg) { Log "winget ready: $wg" 'OK'; & $wg --version } else { Log 'winget still not found. A restart may be needed.' 'WARN' }
}
Register-Tool 'Software' 'O&O ShutUp10++' 'Download and open the free privacy settings tool (portable, nothing installed)' {
    $dir = Join-Path $ITK_DataDir 'Apps'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $exe = Join-Path $dir 'OOSU10.exe'
    Log 'Downloading O&O ShutUp10++ from oo-software.com...'
    Invoke-WebRequest -Uri 'https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe' -OutFile $exe -UseBasicParsing -ErrorAction Stop
    Start-Process -FilePath $exe
    Log 'O&O ShutUp10++ opened.' 'OK'
}
