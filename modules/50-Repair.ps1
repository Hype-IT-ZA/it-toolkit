# Repair
Register-Tool 'Repair' 'Create restore point' 'System Restore checkpoint before you change things' { [void](New-ToolkitRestorePoint 'IT Toolkit - manual') }
Register-Tool 'Repair' 'SFC scan' 'System File Checker (sfc /scannow)' { sfc.exe /scannow }
Register-Tool 'Repair' 'DISM check health' 'Quick component store check' { dism.exe /Online /Cleanup-Image /CheckHealth }
Register-Tool 'Repair' 'DISM restore health' 'Repair Windows image (10-30 min)' { dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart }
Register-Tool 'Repair' 'Sync time' 'Force a Windows time resync' {
    Start-Service w32time -ErrorAction SilentlyContinue
    w32tm /resync /force
    w32tm /query /status
}
Register-Tool 'Repair' 'Group Policy update' 'gpupdate /force (computer)' { 'N' | gpupdate.exe /target:computer /force }
Register-Tool 'Repair' 'Re-register Start menu & Search' 'Fixes a Start menu that will not open (all users)' -Confirm 'Explorer will restart for the signed-in user. Continue?' {
    Get-AppxPackage -AllUsers Microsoft.Windows.ShellExperienceHost, Microsoft.Windows.StartMenuExperienceHost, MicrosoftWindows.Client.CBS -ErrorAction SilentlyContinue | ForEach-Object {
        $manifest = Join-Path $_.InstallLocation 'AppxManifest.xml'
        if (Test-Path $manifest) { try { Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop; Log "Re-registered $($_.Name)" 'OK' } catch { Log "$($_.Name): $($_.Exception.Message)" 'WARN' } }
    }
    Stop-Process -Name StartMenuExperienceHost, SearchHost, explorer -Force -ErrorAction SilentlyContinue
    Log 'Done. Explorer and Start will restart by themselves.' 'OK'
}
Register-Tool 'Repair' 'Full system corruption scan' 'chkdsk scan, SFC, DISM restore health, then SFC again (30-60 min)' {
    Log 'Step 1/4: chkdsk online scan'; chkdsk.exe "$env:SystemDrive" /scan
    Log 'Step 2/4: SFC'; sfc.exe /scannow
    Log 'Step 3/4: DISM restore health'; dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart
    Log 'Step 4/4: SFC again (fixes files DISM made repairable)'; sfc.exe /scannow
    Log 'Corruption scan finished. Restart if anything was repaired.' 'OK'
}
