# Disk & Cleanup
Register-Tool 'Disk & Cleanup' 'Disk space' 'Free space per drive' {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $pct = if ($_.Size) { [math]::Round($_.FreeSpace / $_.Size * 100, 1) } else { 0 }
        if ($pct -lt 10) { Log "$($_.DeviceID) is low on space ($pct% free)" 'WARN' }
        [pscustomobject]@{ Drive = $_.DeviceID; Label = $_.VolumeName; 'Size (GB)' = [math]::Round($_.Size / 1GB, 1); 'Free (GB)' = [math]::Round($_.FreeSpace / 1GB, 1); 'Free %' = $pct }
    } | Format-Table -AutoSize
}
Register-Tool 'Disk & Cleanup' 'Safe cleanup' 'Temp files + browser caches older than 2 days (all users)' {
    $cutoff = (Get-Date).AddDays(-2); $freed = 0; $count = 0; $skipped = 0
    $paths = @("$env:windir\Temp", "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue")
    Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath } | ForEach-Object {
        $u = $_.LocalPath
        $paths += "$u\AppData\Local\Temp", "$u\AppData\Local\Microsoft\Windows\INetCache", "$u\AppData\Local\CrashDumps"
        foreach ($b in 'Google\Chrome', 'Microsoft\Edge', 'BraveSoftware\Brave-Browser') {
            foreach ($c in 'Cache', 'Code Cache', 'GPUCache') { $paths += "$u\AppData\Local\$b\User Data\*\$c" }
        }
        $paths += "$u\AppData\Local\Mozilla\Firefox\Profiles\*\cache2"
    }
    $before = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    foreach ($path in $paths) {
        foreach ($dir in @(Get-Item -Path $path -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })) {
            $stack = New-Object System.Collections.Stack; $stack.Push($dir.FullName)
            while ($stack.Count) {
                foreach ($i in Get-ChildItem -LiteralPath $stack.Pop() -Force -ErrorAction SilentlyContinue) {
                    if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }   # never follow junctions
                    if ($i.PSIsContainer) { $stack.Push($i.FullName); continue }
                    if ($i.LastWriteTime -ge $cutoff) { continue }
                    try { $len = $i.Length; Remove-Item -LiteralPath $i.FullName -Force -ErrorAction Stop; $freed += $len; $count++ } catch { $skipped++ }
                }
            }
        }
    }
    $after = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    Log ('Removed {0:N0} files ({1}). Skipped {2:N0} in-use files.' -f $count, (Format-Size $freed), $skipped) 'OK'
    Log ('Free space: {0} -> {1}' -f (Format-Size $before), (Format-Size $after)) 'OK'
}
Register-Tool 'Disk & Cleanup' 'Empty Recycle Bins' 'All users, system drive' -Confirm 'This permanently deletes everything in every user''s Recycle Bin on the system drive. Continue?' {
    $rb = "$env:SystemDrive\`$Recycle.Bin"
    $size = (Get-ChildItem $rb -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Get-ChildItem $rb -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Log "Emptied about $(Format-Size $size)." 'OK'
}
Register-Tool 'Disk & Cleanup' 'Largest folders' 'Top 20 sub-folders by size' -Inputs 'Path|Folder to analyse|C:\Users' {
    param($P)
    if (-not (Test-Path $P.Path)) { Log "Path not found: $($P.Path)" 'ERROR'; return }
    Log "Measuring folders under $($P.Path) - this can take a minute..."
    Get-ChildItem -LiteralPath $P.Path -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object {
        $sum = (Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        [pscustomobject]@{ Folder = $_.FullName; 'Size (GB)' = [math]::Round($sum / 1GB, 2) }
    } | Sort-Object 'Size (GB)' -Descending | Select-Object -First 20 | Format-Table -AutoSize
}
Register-Tool 'Disk & Cleanup' 'Disk health' 'Physical disk status, wear and temperature' {
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus, @{ n = 'Size (GB)'; e = { [math]::Round($_.Size / 1GB) } } | Format-Table -AutoSize
    try { Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours | Format-Table -AutoSize }
    catch { Log 'Reliability counters not available for this disk/driver.' 'WARN' }
}
Register-Tool 'Disk & Cleanup' 'Component store cleanup' 'DISM StartComponentCleanup (safe, 5-15 min)' { dism.exe /Online /Cleanup-Image /StartComponentCleanup /NoRestart }
Register-Tool 'Disk & Cleanup' 'Check disk (online scan)' 'chkdsk /scan - read-only check, no reboot' { chkdsk.exe "$env:SystemDrive" /scan }
