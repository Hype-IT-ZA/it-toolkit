# Updates tab - Windows Update policies and actions
# Policy tools only touch the values listed in $ITK_WUValues, so other company policies are left alone.

Register-Tool 'Update policy' 'Show update policy' 'Current Windows Update policy values' -Tab Updates {
    foreach ($k in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate', 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU') {
        if (Test-Path $k) {
            Log $k
            (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object { Log ('   {0} = {1}' -f $_.Name, $_.Value) }
        } else { Log "$k - not set (Windows defaults)" }
    }
    $dv = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    Log "This PC is on version $dv." 'OK'
}
Register-Tool 'Update policy' 'Default (let Windows manage)' 'Removes the policy values this toolkit sets' -Tab Updates -Confirm 'The update policies set by this toolkit will be removed and Windows goes back to its defaults. Continue?' {
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    foreach ($n in 'DeferFeatureUpdates', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdates', 'DeferQualityUpdatesPeriodInDays', 'TargetReleaseVersion', 'TargetReleaseVersionInfo', 'ProductVersion', 'ExcludeWUDriversInQualityUpdate') {
        Remove-ItemProperty -Path $wu -Name $n -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path "$wu\AU" -Name NoAutoRebootWithLoggedOnUsers -ErrorAction SilentlyContinue
    Log 'Update policies reset to Windows defaults.' 'OK'
}
Register-Tool 'Update policy' 'Security-focused updates' 'Security updates after 4 days, feature updates after 365' -Tab Updates -Confirm 'Feature updates will be held back for a year and quality updates delayed 4 days. Continue?' {
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    New-Item -Path "$wu\AU" -Force | Out-Null
    Set-ItemProperty $wu DeferFeatureUpdates 1 -Type DWord
    Set-ItemProperty $wu DeferFeatureUpdatesPeriodInDays 365 -Type DWord
    Set-ItemProperty $wu DeferQualityUpdates 1 -Type DWord
    Set-ItemProperty $wu DeferQualityUpdatesPeriodInDays 4 -Type DWord
    Set-ItemProperty "$wu\AU" NoAutoRebootWithLoggedOnUsers 1 -Type DWord
    Log 'Security-focused update policy applied.' 'OK'
}
Register-Tool 'Update policy' 'Stay on current Windows version' 'Blocks the next feature upgrade (e.g. 24H2 -> 25H2)' -Tab Updates -Confirm 'This PC will stay on its current Windows version until you choose Default again. Continue?' {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $product = if ([int]$cv.CurrentBuild -ge 22000) { 'Windows 11' } else { 'Windows 10' }
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    New-Item -Path $wu -Force | Out-Null
    Set-ItemProperty $wu TargetReleaseVersion 1 -Type DWord
    Set-ItemProperty $wu ProductVersion $product -Type String
    Set-ItemProperty $wu TargetReleaseVersionInfo $cv.DisplayVersion -Type String
    Log "Pinned to $product $($cv.DisplayVersion)." 'OK'
}
Register-Tool 'Update policy' 'Exclude driver updates' 'Stop Windows Update installing drivers' -Tab Updates {
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    New-Item -Path $wu -Force | Out-Null
    Set-ItemProperty $wu ExcludeWUDriversInQualityUpdate 1 -Type DWord
    Log 'Driver updates excluded from Windows Update.' 'OK'
}
Register-Tool 'Update policy' 'Allow driver updates' 'Let Windows Update install drivers again' -Tab Updates {
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name ExcludeWUDriversInQualityUpdate -ErrorAction SilentlyContinue
    Log 'Driver updates allowed.' 'OK'
}
Register-Tool 'Update policy' 'No restart while signed in' 'Never auto-restart while a user is signed in' -Tab Updates {
    $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    New-Item -Path $au -Force | Out-Null
    Set-ItemProperty $au NoAutoRebootWithLoggedOnUsers 1 -Type DWord
    Log 'Automatic restarts are blocked while someone is signed in.' 'OK'
}

Register-Tool 'Update actions' 'Check for updates' 'List available updates (can take minutes)' -Tab Updates {
    Log 'Searching for updates...'
    $r = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0')
    if ($r.Updates.Count -eq 0) { Log 'No updates available.' 'OK'; return }
    Log "$($r.Updates.Count) update(s) available" 'WARN'
    $r.Updates | ForEach-Object { [pscustomobject]@{ Title = $_.Title; 'Size (MB)' = [math]::Round($_.MaxDownloadSize / 1MB) } } | Format-Table -AutoSize
}
Register-Tool 'Update actions' 'Install updates now' 'Download and install everything available' -Tab Updates -Confirm 'All available updates will be downloaded and installed now. The PC may need a restart afterwards. Continue?' {
    $session = New-Object -ComObject Microsoft.Update.Session
    Log 'Searching...'
    $found = $session.CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0 and Type=''Software''').Updates
    if ($found.Count -eq 0) { Log 'Nothing to install.' 'OK'; return }
    $list = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in $found) { if (-not $u.EulaAccepted) { $u.AcceptEula() }; [void]$list.Add($u); Log "Queued: $($u.Title)" }
    Log 'Downloading...'
    $dl = $session.CreateUpdateDownloader(); $dl.Updates = $list; [void]$dl.Download()
    Log 'Installing...'
    $inst = $session.CreateUpdateInstaller(); $inst.Updates = $list
    $res = $inst.Install()
    for ($i = 0; $i -lt $list.Count; $i++) {
        $rc = $res.GetUpdateResult($i).ResultCode
        Log ('{0} - {1}' -f $list.Item($i).Title, @{2 = 'installed'; 3 = 'installed with errors'; 4 = 'FAILED'; 5 = 'aborted' }[[int]$rc]) $(if ($rc -eq 2) { 'OK' } else { 'WARN' })
    }
    if ($res.RebootRequired) { Log 'A restart is required to finish.' 'WARN' }
}
Register-Tool 'Update actions' 'Update history' 'Last 25 Windows Update results' -Tab Updates {
    $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
    $n = $searcher.GetTotalHistoryCount()
    if ($n -eq 0) { Log 'No update history.'; return }
    $searcher.QueryHistory(0, [math]::Min($n, 25)) | Where-Object { $_.Title } | ForEach-Object {
        [pscustomobject]@{ Date = $_.Date; Result = @{1 = 'In progress'; 2 = 'Succeeded'; 3 = 'Succeeded w/ errors'; 4 = 'FAILED'; 5 = 'Aborted' }[[int]$_.ResultCode]; Title = $_.Title }
    } | Format-Table -AutoSize
}
Register-Tool 'Update actions' 'Installed hotfixes' 'Latest 20 installed KBs' -Tab Updates { Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 HotFixID, Description, InstalledOn | Format-Table -AutoSize }
Register-Tool 'Update actions' 'Clear update download cache' 'Empties SoftwareDistribution\Download' -Tab Updates -Confirm 'Windows Update services will be stopped briefly and downloaded update files removed (they re-download if needed). Continue?' {
    if ((Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or (Get-Process TiWorker -ErrorAction SilentlyContinue)) {
        Log 'Updates are installing or a reboot is pending - skipped for safety. Reboot first.' 'WARN'; return
    }
    $dl = "$env:windir\SoftwareDistribution\Download"
    $size = (Get-ChildItem $dl -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Get-ChildItem $dl -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv, bits -ErrorAction SilentlyContinue
    Log "Cleared about $(Format-Size $size) of update downloads." 'OK'
}
Register-Tool 'Update actions' 'Reset Windows Update' 'Renames update caches (kept as backup)' -Tab Updates -Confirm 'This stops update services and renames SoftwareDistribution and catroot2 (backups are kept). Continue?' {
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
