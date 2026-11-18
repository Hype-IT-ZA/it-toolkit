# Office & Teams (Microsoft 365 Click-to-Run)
Register-Tool 'Office & Teams' 'Office info' 'Version, channel, products, platform' {
    $o = Get-OfficeC2R
    if (-not $o) { Log 'Microsoft 365 / Click-to-Run Office was not found.' 'WARN'; return }
    $o | Select-Object Version, Channel, Platform, Culture, Products | Format-List
}
Register-Tool 'Office & Teams' 'Office quick repair' 'Offline repair, about 5 minutes' -Confirm 'All Office apps will be closed while Office repairs itself. Continue?' {
    $o = Get-OfficeC2R
    if (-not $o -or -not (Test-Path $o.RepairExe)) { Log 'Click-to-Run Office was not found.' 'ERROR'; return }
    & $o.RepairExe scenario=Repair platform=$($o.Platform) culture=$($o.Culture) forceappshutdown=True RepairType=QuickRepair DisplayLevel=False
    Log 'Quick repair started in the background. It takes a few minutes.' 'OK'
}
Register-Tool 'Office & Teams' 'Office online repair' 'Full reinstall from the internet (30+ min)' -Confirm 'Office apps will close and Office will be reinstalled from the internet. This can take 30 minutes or more. Continue?' {
    $o = Get-OfficeC2R
    if (-not $o -or -not (Test-Path $o.RepairExe)) { Log 'Click-to-Run Office was not found.' 'ERROR'; return }
    & $o.RepairExe scenario=Repair platform=$($o.Platform) culture=$($o.Culture) forceappshutdown=True RepairType=FullRepair DisplayLevel=False
    Log 'Online repair started in the background.' 'OK'
}
Register-Tool 'Office & Teams' 'Update Office now' 'Download and install the latest Office build' -Confirm 'Office apps will close to install updates. Continue?' {
    $o = Get-OfficeC2R
    if (-not $o -or -not (Test-Path $o.ClientExe)) { Log 'Click-to-Run Office was not found.' 'ERROR'; return }
    & $o.ClientExe /update user updatepromptuser=false forceappshutdown=true displaylevel=false
    Log "Office update started (current version $($o.Version))." 'OK'
}
Register-Tool 'Office & Teams' 'Office activation status' 'License details (ospp / vnextdiag)' {
    $dirs = "$env:ProgramFiles\Microsoft Office\Office16", "${env:ProgramFiles(x86)}\Microsoft Office\Office16"
    $vnext = $dirs | ForEach-Object { Join-Path $_ 'vnextdiag.ps1' } | Where-Object { Test-Path $_ } | Select-Object -First 1
    $ospp = $dirs | ForEach-Object { Join-Path $_ 'OSPP.VBS' } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($vnext) { Log 'Microsoft 365 licenses (vnextdiag):'; & $vnext -action list }
    if ($ospp) { Log 'Volume / retail licenses (ospp):'; cscript.exe //nologo $ospp /dstatus }
    if (-not $vnext -and -not $ospp) { Log 'No Office licensing tools found.' 'WARN' }
}
Register-Tool 'Office & Teams' 'Clear Teams cache' 'New + classic Teams, all users (Teams is closed)' -Confirm 'Teams will be closed for everyone on this PC and its cache cleared. Chats and files are not affected. Continue?' {
    Stop-Process -Name ms-teams, Teams -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath } | ForEach-Object {
        $paths = @("$($_.LocalPath)\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams")
        $paths += foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'blob_storage', 'IndexedDB', 'Service Worker\CacheStorage') { "$($_.LocalPath)\AppData\Roaming\Microsoft\Teams\$c" }
        foreach ($p in $paths) { if (Test-Path $p) { Get-ChildItem $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Log "Cleared $p" } }
    }
    Log 'Teams cache cleared. Teams can be opened again.' 'OK'
}
Register-Tool 'Office & Teams' 'Reset Outlook cache' 'Renames RoamCache (autocomplete backup kept)' -Confirm 'Outlook will be closed for everyone on this PC. The old cache folder is kept as a backup. Continue?' {
    Stop-Process -Name OUTLOOK -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $stamp = Get-Date -Format yyyyMMddHHmmss
    Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath } | ForEach-Object {
        $p = "$($_.LocalPath)\AppData\Local\Microsoft\Outlook\RoamCache"
        if (Test-Path $p) { Rename-Item $p "RoamCache.old_$stamp" -ErrorAction SilentlyContinue; Log "Reset $p (backup kept)" 'OK' }
    }
}
Register-Tool 'Office & Teams' 'Outlook safe mode (user)' 'Starts Outlook without add-ins for the user' {
    Invoke-AsUser -NoWait -Script 'Start-Process outlook.exe -ArgumentList "/safe"' | Out-Null
    Log 'Outlook started in safe mode for the signed-in user.' 'OK'
}
Register-Tool 'Office & Teams' 'Reset Outlook navigation pane' 'Fixes a broken folder pane (user)' -Confirm 'Outlook will be closed and reopened for the signed-in user. Continue?' {
    Stop-Process -Name OUTLOOK -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Invoke-AsUser -NoWait -Script 'Start-Process outlook.exe -ArgumentList "/resetnavpane"' | Out-Null
    Log 'Outlook reopened with a reset navigation pane.' 'OK'
}
