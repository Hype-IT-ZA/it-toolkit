# =====================================================================
#  Windows features (WinUtil "Config" tab). Shown on the Tweaks tab so each one
#  has a status, can be ticked together, and can be turned off again (Undo).
#  Most need a restart. Some are not available on Windows Home.
# =====================================================================

Register-Tweak 'Windows features' '.NET Framework 3.5 and 4.x extras' 'Older apps that need .NET 2.0 / 3.5, plus .NET 4 advanced services' `
    -Apply { Enable-WindowsOptionalFeature -Online -FeatureName NetFx3, NetFx4-AdvSrvs -All -NoRestart -ErrorAction Stop | Out-Null } `
    -Revert { Disable-WindowsOptionalFeature -Online -FeatureName NetFx3 -NoRestart -ErrorAction Stop | Out-Null } `
    -Test { (Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -eq 'Enabled' }
Register-Tweak 'Windows features' 'Hyper-V' 'Run virtual machines (Pro / Enterprise only, restart needed)' `
    -Warning 'Hyper-V can conflict with VirtualBox / VMware and some anti-cheat games. A restart is needed.' `
    -Apply { Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart -ErrorAction Stop | Out-Null } `
    -Revert { Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -ErrorAction Stop | Out-Null } `
    -Test { (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -eq 'Enabled' }
Register-Tweak 'Windows features' 'Windows Subsystem for Linux (WSL)' 'Run Linux on Windows - install a distro afterwards with: wsl --install' `
    -Apply { Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform, Microsoft-Windows-Subsystem-Linux -All -NoRestart -ErrorAction Stop | Out-Null } `
    -Revert { Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux, VirtualMachinePlatform -NoRestart -ErrorAction Stop | Out-Null } `
    -Test { (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 'Enabled' }
Register-Tweak 'Windows features' 'Windows Sandbox' 'Throw-away desktop for testing suspicious files (Pro / Enterprise)' `
    -Apply { Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All -NoRestart -ErrorAction Stop | Out-Null } `
    -Revert { Disable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -NoRestart -ErrorAction Stop | Out-Null } `
    -Test { (Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM).State -eq 'Enabled' }
Register-Tweak 'Windows features' 'Legacy media components' 'Windows Media Player, DirectPlay and older media playback (old games / apps)' `
    -Apply { Enable-WindowsOptionalFeature -Online -FeatureName WindowsMediaPlayer, MediaPlayback, DirectPlay, LegacyComponents -All -NoRestart -ErrorAction SilentlyContinue | Out-Null } `
    -Revert { Disable-WindowsOptionalFeature -Online -FeatureName DirectPlay -NoRestart -ErrorAction SilentlyContinue | Out-Null } `
    -Test { (Get-WindowsOptionalFeature -Online -FeatureName DirectPlay).State -eq 'Enabled' }
Register-Tweak 'Windows features' 'NFS client' 'Connect to Linux / NAS NFS shares (Pro / Enterprise)' `
    -Apply {
        Enable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly, ClientForNFS-Infrastructure, NFS-Administration -All -NoRestart -ErrorAction Stop | Out-Null
        $k = 'HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default'
        New-Item -Path $k -Force | Out-Null
        Set-ItemProperty -Path $k -Name AnonymousUID -Value 0 -Type DWord
        Set-ItemProperty -Path $k -Name AnonymousGID -Value 0 -Type DWord
        nfsadmin.exe client stop 2>&1 | Out-Null; nfsadmin.exe client start 2>&1 | Out-Null
        nfsadmin.exe client localhost config fileaccess=755 SecFlavors=+sys -krb5 -krb5i 2>&1 | Out-Null
    } `
    -Revert { Disable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly, ClientForNFS-Infrastructure, NFS-Administration -NoRestart -ErrorAction Stop | Out-Null } `
    -Test { (Get-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly).State -eq 'Enabled' }
Register-Tweak 'Windows features' 'OpenSSH Server' 'Connect to this PC over SSH (port 22)' `
    -Warning 'Opens port 22 on this PC. Only allow it on trusted networks and use strong passwords or keys.' `
    -Apply {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null
        Set-Service sshd -StartupType Automatic; Start-Service sshd
        if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null }
    } `
    -Revert { Stop-Service sshd -Force -ErrorAction SilentlyContinue; Set-Service sshd -StartupType Disabled -ErrorAction SilentlyContinue; Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue | Out-Null } `
    -Test { (Get-Service sshd -ErrorAction SilentlyContinue).Status -eq 'Running' }
Register-Tweak 'Windows features' 'Daily registry backup' 'Windows keeps a daily copy of the registry in System32\config\RegBack' `
    -Apply {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager' -Name EnablePeriodicBackup -Value 1 -Type DWord
        $action = New-ScheduledTaskAction -Execute 'schtasks.exe' -Argument '/run /i /tn "\Microsoft\Windows\Registry\RegIdleBackup"'
        $trigger = New-ScheduledTaskTrigger -Daily -At '00:30'
        Register-ScheduledTask -TaskName 'IT Toolkit - Registry backup' -Action $action -Trigger $trigger -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    } `
    -Revert {
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager' -Name EnablePeriodicBackup -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName 'IT Toolkit - Registry backup' -Confirm:$false -ErrorAction SilentlyContinue
    } `
    -Test { [bool](Get-ScheduledTask -TaskName 'IT Toolkit - Registry backup' -ErrorAction SilentlyContinue) }
Register-Tweak 'Windows features' 'F8 boot recovery menu' 'Press F8 at start-up for Safe Mode and recovery options (slows boot slightly)' `
    -Apply { bcdedit.exe /set '{current}' bootmenupolicy legacy | Out-Null } -Revert { bcdedit.exe /set '{current}' bootmenupolicy standard | Out-Null } `
    -Test { "$(bcdedit.exe /enum '{current}')" -match 'bootmenupolicy\s+Legacy' }
Register-Tweak 'Windows features' 'Use pool.ntp.org for time' 'Fixes a clock that keeps drifting (not for domain PCs - they sync with the domain)' `
    -Apply {
        Start-Service w32time -ErrorAction SilentlyContinue
        w32tm /config /manualpeerlist:'pool.ntp.org,0x8' /syncfromflags:manual /update | Out-Null
        Restart-Service w32time -Force; w32tm /resync /force | Out-Null
    } `
    -Revert {
        if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) { w32tm /config /syncfromflags:domhier /update | Out-Null }
        else { w32tm /config /manualpeerlist:'time.windows.com,0x8' /syncfromflags:manual /update | Out-Null }
        Restart-Service w32time -Force
    } `
    -Test { "$(w32tm /query /source)" -match 'pool\.ntp\.org' }
