# =====================================================================
#  Tweaks tab. Every tweak can be undone unless marked -NoUndo.
#  HKCU:\ paths are applied to every signed-in user (works as SYSTEM in Backstage).
#  Registry item: @{ Path; Name; Value; Type = 'DWord'; Revert = <value> }  (no Revert = value deleted on undo)
# =====================================================================
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

# ---------------- Privacy ----------------
Register-Tweak 'Privacy' 'Disable telemetry' 'Sets diagnostic data to the minimum and disables the telemetry service' -Recommended `
    -Registry @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1 }
    ) -Services @(@{ Name = 'DiagTrack'; Startup = 'Disabled'; Revert = 'Automatic' })
Register-Tweak 'Privacy' 'Disable activity history' 'Stops Windows collecting and uploading your activity timeline' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 }
)
Register-Tweak 'Privacy' 'Disable advertising ID' 'Apps can no longer use an ID to show you targeted ads' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Privacy' 'Disable tips and suggestions' 'No "suggested" apps, tips or ads in Start, Settings and the lock screen' -Recommended -Registry @(
    @{ Path = $cdm; Name = 'SubscribedContent-338388Enabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SubscribedContent-338389Enabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SubscribedContent-353694Enabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SubscribedContent-353696Enabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SystemPaneSuggestionsEnabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SoftLandingEnabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SilentInstalledAppsEnabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Privacy' 'Disable consumer features' 'Stops Windows installing promoted apps and games by itself' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1 }
)
Register-Tweak 'Privacy' 'Disable Bing in Start search' 'Start menu searches only this PC, not the web' -Registry @(
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Privacy' 'Disable Copilot and Recall' 'Turns off the Copilot button and Recall snapshots' -Registry @(
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1 }
)
Register-Tweak 'Privacy' 'Disable widgets / news' 'Removes the news and weather widgets board' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0 }
)
Register-Tweak 'Privacy' 'Disable location tracking' 'Apps and Windows can no longer use your location' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Name = 'Value'; Value = 'Deny'; Type = 'String'; Revert = 'Allow' }
)
Register-Tweak 'Privacy' 'Quieter Edge' 'No first-run wizard, no startup boost, no running in the background' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'HideFirstRunExperience'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Value = 0 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Value = 0 }
)

# ---------------- Performance ----------------
Register-Tweak 'Performance' 'Ultimate Performance power plan' 'Adds and activates the hidden Ultimate Performance plan (desktops)' `
    -Apply {
        $out = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
        if ("$out" -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { powercfg /setactive $Matches[1] }
    } -Revert { powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e } `
    -Test { "$(powercfg /getactivescheme)" -match 'Ultimate' }
Register-Tweak 'Performance' 'Disable Game DVR background recording' 'Stops Xbox Game Bar recording in the background' -Recommended -Registry @(
    @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Revert = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Value = 0 }
)
Register-Tweak 'Performance' 'Visual effects for performance' 'Turns off animations and shadows (needs sign-out)' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Value = 2; Revert = 0 }
)
Register-Tweak 'Performance' 'Disable Fast Startup' 'Shutdown really shuts down - fixes many driver and update issues' -Registry @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Performance' 'Disable hibernation' 'Frees the space used by hiberfil.sys (also turns off Fast Startup)' `
    -Apply { powercfg /hibernate off } -Revert { powercfg /hibernate on } `
    -Test { -not (Test-Path "$env:SystemDrive\hiberfil.sys") }
Register-Tweak 'Performance' 'Disable Teredo' 'Turns off the Teredo IPv6 tunnel (can help some games and VPNs)' `
    -Apply { netsh interface teredo set state disabled } -Revert { netsh interface teredo set state default } `
    -Test { "$(netsh interface teredo show state)" -match 'disabled' }

# ---------------- Explorer & Taskbar ----------------
Register-Tweak 'Explorer & Taskbar' 'Show file extensions' 'Shows .exe, .pdf, .docx at the end of file names' -Recommended -Registry @(
    @{ Path = $adv; Name = 'HideFileExt'; Value = 0; Revert = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'Show hidden files' 'Shows hidden files and folders in File Explorer' -Registry @(
    @{ Path = $adv; Name = 'Hidden'; Value = 1; Revert = 2 }
)
Register-Tweak 'Explorer & Taskbar' 'Open File Explorer to This PC' 'Instead of Home / Quick access' -Registry @(
    @{ Path = $adv; Name = 'LaunchTo'; Value = 1; Revert = 2 }
)
Register-Tweak 'Explorer & Taskbar' 'Classic right-click menu' 'Windows 11: full right-click menu without "Show more options"' `
    -Apply { foreach ($r in Get-UserHiveRoots) { New-Item -Path "$r\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Value '' -Force | Out-Null } } `
    -Revert { foreach ($r in Get-UserHiveRoots) { Remove-Item -Path "$r\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue } } `
    -Test { $r = Get-UserHiveRoots | Select-Object -First 1; $r -and (Test-Path "$r\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32") }
Register-Tweak 'Explorer & Taskbar' 'Taskbar aligned left' 'Windows 11: Start button on the left like Windows 10' -Registry @(
    @{ Path = $adv; Name = 'TaskbarAl'; Value = 0; Revert = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'Hide Task View button' 'Removes the Task View button from the taskbar' -Registry @(
    @{ Path = $adv; Name = 'ShowTaskViewButton'; Value = 0; Revert = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'End task in taskbar menu' 'Right-click a taskbar app to force-close it (Windows 11 23H2+)' -Registry @(
    @{ Path = "$adv\TaskbarDeveloperSettings"; Name = 'TaskbarEndTask'; Value = 1; Revert = 0 }
)
Register-Tweak 'Explorer & Taskbar' 'Dark mode' 'Dark theme for Windows and apps' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Revert = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Revert = 1 }
)

# ---------------- System ----------------
Register-Tweak 'System' 'Disable Sticky Keys prompt' 'No pop-up after pressing Shift five times' -Recommended -Registry @(
    @{ Path = 'HKCU:\Control Panel\Accessibility\StickyKeys'; Name = 'Flags'; Value = '506'; Type = 'String'; Revert = '510' }
)
Register-Tweak 'System' 'NumLock on at startup' 'Number pad works straight away on the sign-in screen' -Registry @(
    @{ Path = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Value = '2'; Type = 'String'; Revert = '0' }
    @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Value = '2'; Type = 'String'; Revert = '0' }
)
Register-Tweak 'System' 'Detailed blue screen info' 'Shows the stop code details on a BSOD' -Recommended -Registry @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'; Name = 'DisplayParameters'; Value = 1; Revert = 0 }
)
Register-Tweak 'System' 'Verbose sign-in messages' 'Shows what Windows is doing during start-up and sign-in' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'VerboseStatus'; Value = 1 }
)
Register-Tweak 'System' 'Disable web results on lock screen' 'No "Windows Spotlight" fun facts and ads on the lock screen' -Registry @(
    @{ Path = $cdm; Name = 'RotatingLockScreenOverlayEnabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SubscribedContent-338387Enabled'; Value = 0; Revert = 1 }
)

# ---------------- Advanced (caution) ----------------
Register-Tweak 'Advanced' 'Remove promoted bloat apps' 'Removes Candy Crush, TikTok, Spotify promo, Disney+ and similar for all users' -NoUndo `
    -Warning 'These apps are removed for every user. They can be installed again from the Microsoft Store, but not undone automatically.' `
    -Apply {
        $names = '*CandyCrush*', '*BubbleWitch*', '*TikTok*', '*Disney*', '*Facebook*', '*Instagram*', '*Twitter*', '*SpotifyAB.SpotifyMusic*',
                 '*king.com*', '*Clipchamp*', '*Microsoft.BingNews*', '*Microsoft.GamingApp*', '*Microsoft.MicrosoftSolitaireCollection*', '*Microsoft.ZuneVideo*'
        foreach ($n in $names) {
            Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; Log "Removed $($_.Name)" } catch { Log "$($_.Name): $($_.Exception.Message)" 'WARN' } }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -like $n | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        }
    } -Test { -not (Get-AppxPackage -AllUsers -Name '*CandyCrush*', '*TikTok*', '*Disney*' -ErrorAction SilentlyContinue) }
Register-Tweak 'Advanced' 'Disable Storage Sense' 'Stops Windows deleting old Downloads and Recycle Bin files by itself' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name = '01'; Value = 0; Revert = 1 }
)
Register-Tweak 'Advanced' 'Disable Windows Update P2P sharing' 'Updates only come from Microsoft, not other PCs on the internet' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0 }
)
Register-Tweak 'Advanced' 'Disable SMBv1' 'Turns off the old, insecure file sharing protocol' -Recommended `
    -Warning 'Very old NAS boxes, printers or scanners that only speak SMBv1 will stop working with this PC.' `
    -Apply { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force; Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null } `
    -Revert { Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force } `
    -Test { -not (Get-SmbServerConfiguration).EnableSMB1Protocol }

Remove-Variable adv, cdm -ErrorAction SilentlyContinue
