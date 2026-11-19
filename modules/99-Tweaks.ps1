# =====================================================================
#  Tweaks tab. Covers everything in Chris Titus Tech's WinUtil tweak list
#  (MIT licence, see THIRD_PARTY_NOTICES.md), rewritten for this toolkit:
#  HKCU:\ paths go to every signed-in user, so tweaks work as SYSTEM in Backstage.
#
#  Registry item: @{ Path; Name; Value; Type = 'DWord'; Revert = <value> }  (no Revert = value deleted on undo)
#  Service item:  @{ Name; Startup; Revert }
#  -Warning marks a tweak CAUTION and is shown before applying. -NoUndo = cannot be undone automatically.
# =====================================================================
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$brave = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'
$tcp6 = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'

# =====================================================================
#  ESSENTIAL
# =====================================================================
Register-Tweak 'Essential' 'Disable telemetry' 'Minimum diagnostic data, no tailored experiences, no inking/typing collection, telemetry and error-report services off' -Recommended `
    -Registry @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; Name = 'HasAccepted'; Value = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\Input\TIPC'; Name = 'Enabled'; Value = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Value = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Value = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Value = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Value = 0 }
        @{ Path = $adv; Name = 'Start_TrackProgs'; Value = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0 }
    ) -Services @(
        @{ Name = 'DiagTrack'; Startup = 'Disabled'; Revert = 'Automatic' }
        @{ Name = 'WerSvc'; Startup = 'Disabled'; Revert = 'Manual' }
    ) -Apply {
        Remove-RegValue 'HKCU:\Software\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds'
        try { Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop } catch { Log 'Defender sample submission not changed (Defender may be off).' 'WARN' }
        [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
    } -Revert {
        try { Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction Stop } catch {}
        [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', $null, 'Machine')
    }
Register-Tweak 'Essential' 'Disable activity history' 'Stops Windows publishing or uploading your activity timeline (clipboard history keeps working)' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 }
)
Register-Tweak 'Essential' 'Disable consumer features' 'Stops Windows installing promoted apps and games by itself' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1 }
)
Register-Tweak 'Essential' 'Disable location tracking' 'Location off for Windows and apps, location service and offline map updates disabled' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Name = 'Value'; Value = 'Deny'; Type = 'String'; Revert = 'Allow' }
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}'; Name = 'SensorPermissionState'; Value = 0; Revert = 1 }
    @{ Path = 'HKLM:\SYSTEM\Maps'; Name = 'AutoUpdateEnabled'; Value = 0; Revert = 1 }
) -Services @(@{ Name = 'lfsvc'; Startup = 'Disabled'; Revert = 'Manual' })
Register-Tweak 'Essential' 'Disable Delivery Optimization' 'Windows Update no longer uploads updates to other PCs on the internet or local network' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0 }
)
Register-Tweak 'Essential' 'Disable hibernation' 'Turns off hibernation and frees hiberfil.sys (also turns off Fast Startup)' -Registry @(
    @{ Path = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Power'; Name = 'HibernateEnabled'; Value = 0; Revert = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name = 'ShowHibernateOption'; Value = 0; Revert = 1 }
) -Apply { powercfg.exe /hibernate off } -Revert { powercfg.exe /hibernate on }
Register-Tweak 'Essential' 'Set common services to Manual' 'Offline Files, Telemetry and Internet Connection Sharing disabled; Maps Broker and Storage Service set to Manual' `
    -Warning 'Mobile Hotspot (Internet Connection Sharing) and Offline Files stop working while this is applied.' -Services @(
        @{ Name = 'CscService'; Startup = 'Disabled'; Revert = 'Manual' }
        @{ Name = 'DiagTrack'; Startup = 'Disabled'; Revert = 'Automatic' }
        @{ Name = 'MapsBroker'; Startup = 'Manual'; Revert = 'Automatic' }
        @{ Name = 'StorSvc'; Startup = 'Manual'; Revert = 'Automatic' }
        @{ Name = 'SharedAccess'; Startup = 'Disabled'; Revert = 'Manual' }
    )
Register-Tweak 'Essential' 'Hide Store results in Start search' 'Start menu search no longer suggests Microsoft Store apps (all users)' -Apply {
    foreach ($p in Get-UserProfilePaths) {
        $db = "$p\AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
        if (Test-Path $db) { icacls.exe $db /deny '*S-1-1-0:F' | Out-Null; Log "Blocked $db" }
    }
} -Revert {
    foreach ($p in Get-UserProfilePaths) {
        $db = "$p\AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
        if (Test-Path $db) { icacls.exe $db /remove:d '*S-1-1-0' | Out-Null }
    }
} -Test {
    $db = Get-UserProfilePaths | ForEach-Object { "$_\AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db" } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $db) { return $false }
    [bool]((Get-Acl $db).Access | Where-Object { $_.AccessControlType -eq 'Deny' -and $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -eq 'S-1-1-0' })
}
Register-Tweak 'Essential' 'Disable WPBT' 'Stops the PC maker running software from firmware at boot (Windows Platform Binary Table)' `
    -Warning 'Business anti-theft tools that live in the BIOS (for example Absolute / Computrace) rely on this and will stop working.' -Registry @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'DisableWpbtExecution'; Value = 1 }
    )
Register-Tweak 'Essential' 'Block device companion apps' 'No extra software or ads when you plug in a device (monitor, printer, mouse)' -Recommended -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata'; Name = 'PreventDeviceMetadataFromNetwork'; Value = 1 }
)
Register-Tweak 'Essential' 'End task in taskbar menu' 'Right-click a taskbar app to force-close it (Windows 11 23H2+)' -Recommended -Registry @(
    @{ Path = "$adv\TaskbarDeveloperSettings"; Name = 'TaskbarEndTask'; Value = 1; Revert = 0 }
)
Register-Tweak 'Essential' 'Disable Explorer folder type detection' 'Explorer stops guessing folder types (Music, Pictures...) which slows browsing. Resets saved folder views.' `
    -Warning 'Saved folder views (sort order, columns, grouping) are reset for every user, and Explorer grouping is turned off.' -Apply {
        foreach ($r in Get-UserHiveRoots) {
            $base = "$r\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell"
            Remove-Item "$base\Bags", "$base\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -Path "$base\Bags\AllFolders\Shell" -Force | Out-Null
            New-ItemProperty -Path "$base\Bags\AllFolders\Shell" -Name FolderType -Value 'NotSpecified' -PropertyType String -Force | Out-Null
        }
    } -Revert {
        foreach ($r in Get-UserHiveRoots) {
            $base = "$r\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell"
            Remove-Item "$base\Bags", "$base\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
        }
    } -Test { $r = Get-UserHiveRoots | Select-Object -First 1; $r -and ((Get-ItemProperty "$r\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" -ErrorAction SilentlyContinue).FolderType -eq 'NotSpecified') }

# =====================================================================
#  PRIVACY
# =====================================================================
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
Register-Tweak 'Privacy' 'Disable Bing in Start search' 'Start menu searches only this PC, not the web' -Registry @(
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Privacy' 'Disable Copilot and Recall' 'Turns off Copilot, Recall snapshots and AI in Notepad (policies only)' -Registry @(
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\WindowsNotepad'; Name = 'DisableAIFeatures'; Value = 1 }
)
Register-Tweak 'Privacy' 'Disable widgets / news' 'Removes the news and weather widgets board (policy - Widgets can come back on undo)' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0 }
)
Register-Tweak 'Privacy' 'Disable background apps' 'Store apps no longer run in the background' `
    -Warning 'Apps like Phone Link, Mail or Teams (Store version) may stop showing notifications until opened.' -Registry @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name = 'GlobalUserDisabled'; Value = 1; Revert = 0 }
    )
Register-Tweak 'Privacy' 'Disable notifications and calendar' 'Turns off the notification centre, calendar flyout and toast pop-ups' `
    -Warning 'All app notifications (Teams, Outlook, Windows Security) are hidden while this is applied.' -Registry @(
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableNotificationCenter'; Value = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name = 'ToastEnabled'; Value = 0; Revert = 1 }
    )

# =====================================================================
#  BROWSERS
# =====================================================================
Register-Tweak 'Browsers' 'Debloat Microsoft Edge' 'No first-run wizard, shopping, rewards, collections, Copilot sidebar, telemetry or "make Edge default" nags' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'CreateDesktopShortcutDefault'; Value = 0 }
    @{ Path = $edge; Name = 'PersonalizationReportingEnabled'; Value = 0 }
    @{ Path = "$edge\ExtensionInstallBlocklist"; Name = '1'; Value = 'ofefcgjbeghpigppfmkologfjadafddi'; Type = 'String' }
    @{ Path = $edge; Name = 'ShowRecommendationsEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'HideFirstRunExperience'; Value = 1 }
    @{ Path = $edge; Name = 'UserFeedbackAllowed'; Value = 0 }
    @{ Path = $edge; Name = 'ConfigureDoNotTrack'; Value = 1 }
    @{ Path = $edge; Name = 'AlternateErrorPagesEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'EdgeCollectionsEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'EdgeShoppingAssistantEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'MicrosoftEdgeInsiderPromotionEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'ShowMicrosoftRewards'; Value = 0 }
    @{ Path = $edge; Name = 'WebWidgetAllowed'; Value = 0 }
    @{ Path = $edge; Name = 'DiagnosticData'; Value = 0 }
    @{ Path = $edge; Name = 'EdgeAssetDeliveryServiceEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'WalletDonationEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'DefaultBrowserSettingsCampaignEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'StartupBoostEnabled'; Value = 0 }
    @{ Path = $edge; Name = 'BackgroundModeEnabled'; Value = 0 }
)
Register-Tweak 'Browsers' 'Debloat Brave' 'Turns off Brave Rewards, Wallet, VPN, Leo AI, News, Talk, Tor windows and usage pings' -Registry @(
    @{ Path = $brave; Name = 'BraveRewardsDisabled'; Value = 1 }
    @{ Path = $brave; Name = 'BraveWalletDisabled'; Value = 1 }
    @{ Path = $brave; Name = 'BraveVPNDisabled'; Value = 1 }
    @{ Path = $brave; Name = 'BraveAIChatEnabled'; Value = 0 }
    @{ Path = $brave; Name = 'BraveStatsPingEnabled'; Value = 0 }
    @{ Path = $brave; Name = 'BraveNewsDisabled'; Value = 1 }
    @{ Path = $brave; Name = 'BraveTalkDisabled'; Value = 1 }
    @{ Path = $brave; Name = 'TorDisabled'; Value = 1 }
    @{ Path = $brave; Name = 'BraveP3AEnabled'; Value = 0 }
    @{ Path = $brave; Name = 'UrlKeyedAnonymizedDataCollectionEnabled'; Value = 0 }
    @{ Path = $brave; Name = 'SafeBrowsingExtendedReportingEnabled'; Value = 0 }
    @{ Path = $brave; Name = 'MetricsReportingEnabled'; Value = 0 }
)

# =====================================================================
#  PERFORMANCE
# =====================================================================
Register-Tweak 'Performance' 'Ultimate Performance power plan' 'Adds and activates the hidden Ultimate Performance plan (desktops, not laptops)' `
    -Apply {
        $out = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
        if ("$out" -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { powercfg /setactive $Matches[1] }
    } -Revert {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
        foreach ($line in (powercfg /list) -match 'Ultimate') { if ($line -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { powercfg /delete $Matches[1] } }
    } -Test { "$(powercfg /getactivescheme)" -match 'Ultimate' }
Register-Tweak 'Performance' 'Visual effects for best performance' 'Turns off animations, shadows, Aero Peek and the Chat button; menus open faster' -Registry @(
    @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'DragFullWindows'; Value = '0'; Type = 'String'; Revert = '1' }
    @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'MenuShowDelay'; Value = '200'; Type = 'String'; Revert = '400' }
    @{ Path = 'HKCU:\Control Panel\Desktop\WindowMetrics'; Name = 'MinAnimate'; Value = '0'; Type = 'String'; Revert = '1' }
    @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardDelay'; Value = '0'; Type = 'String'; Revert = '1' }
    @{ Path = $adv; Name = 'ListviewAlphaSelect'; Value = 0; Revert = 1 }
    @{ Path = $adv; Name = 'ListviewShadow'; Value = 0; Revert = 1 }
    @{ Path = $adv; Name = 'TaskbarAnimations'; Value = 0; Revert = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Value = 3; Revert = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'EnableAeroPeek'; Value = 0; Revert = 1 }
    @{ Path = $adv; Name = 'TaskbarMn'; Value = 0; Revert = 1 }
    @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'UserPreferencesMask'; Value = ([byte[]](144, 18, 3, 128, 16, 0, 0, 0)); Type = 'Binary'; Revert = ([byte[]](158, 30, 7, 128, 18, 0, 0, 0)) }
)
Register-Tweak 'Performance' 'Disable Game DVR background recording' 'Stops Xbox Game Bar recording in the background' -Recommended -Registry @(
    @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Revert = 1 }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Value = 0 }
)
Register-Tweak 'Performance' 'Disable Game Mode' 'Windows stops re-prioritising resources when a game runs' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AllowAutoGameMode'; Value = 0; Revert = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AutoGameModeEnabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Performance' 'Disable Fast Startup' 'Shutdown really shuts down - fixes many driver and update issues' -Registry @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Performance' 'Disable search indexing' 'Stops the Windows Search service to cut disk activity (mainly for hard drives)' `
    -Warning 'File searches in Explorer, Start and Outlook become much slower without the index.' `
    -Services @(@{ Name = 'WSearch'; Startup = 'Disabled'; Revert = 'Automatic' }) `
    -Revert { Start-Service WSearch -ErrorAction SilentlyContinue }
Register-Tweak 'Performance' 'Disable svchost splitting' 'Fewer svchost.exe processes and less memory use on PCs with 12 GB RAM or less (restart needed)' `
    -Warning 'Can interfere with Xbox services. A restart is needed.' -Apply {
        $kb = [int64]((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB)
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name SvcHostSplitThresholdInKB -Value $kb -Type DWord
    } -Revert { Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name SvcHostSplitThresholdInKB -Value 3670016 -Type DWord } `
    -Test { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control').SvcHostSplitThresholdInKB -gt 3670016 }
Register-Tweak 'Performance' 'Disable reserved storage' 'Frees the 7-10 GB Windows keeps for updates (small drives only)' `
    -Warning 'Turn this back on before big Windows feature updates or they may fail to install.' `
    -Apply { DISM.exe /Online /Set-ReservedStorageState /State:Disabled } -Revert { DISM.exe /Online /Set-ReservedStorageState /State:Enabled } `
    -Test { "$(DISM.exe /Online /Get-ReservedStorageState)" -match 'Disabled' }
Register-Tweak 'Performance' 'Disable Multiplane Overlay' 'Fixes flickering, black screens and stutter with some graphics cards and multi-monitor setups' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'; Name = 'OverlayTestMode'; Value = 5 }
)

# =====================================================================
#  EXPLORER & TASKBAR
# =====================================================================
Register-Tweak 'Explorer & Taskbar' 'Show file extensions' 'Shows .exe, .pdf, .docx at the end of file names' -Recommended -Registry @(
    @{ Path = $adv; Name = 'HideFileExt'; Value = 0; Revert = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'Show hidden files' 'Shows hidden files and folders in File Explorer' -Registry @(
    @{ Path = $adv; Name = 'Hidden'; Value = 1; Revert = 2 }
)
Register-Tweak 'Explorer & Taskbar' 'Open File Explorer to This PC' 'Instead of Home / Quick access' -Registry @(
    @{ Path = $adv; Name = 'LaunchTo'; Value = 1; Revert = 2 }
)
Register-Tweak 'Explorer & Taskbar' 'Remove Home and Gallery from Explorer' 'Hides Home and Gallery in the navigation pane and opens Explorer to This PC' -Registry @(
    @{ Path = 'HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}'; Name = 'System.IsPinnedToNameSpaceTree'; Value = 0 }
    @{ Path = 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Name = 'System.IsPinnedToNameSpaceTree'; Value = 0 }
    @{ Path = $adv; Name = 'LaunchTo'; Value = 1; Revert = 2 }
)
Register-Tweak 'Explorer & Taskbar' 'Classic right-click menu' 'Windows 11: full right-click menu without "Show more options"' `
    -Apply { foreach ($r in Get-UserHiveRoots) { New-Item -Path "$r\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Value '' -Force | Out-Null } } `
    -Revert { foreach ($r in Get-UserHiveRoots) { Remove-Item -Path "$r\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue } } `
    -Test { $r = Get-UserHiveRoots | Select-Object -First 1; $r -and (Test-Path "$r\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32") }
Register-Tweak 'Explorer & Taskbar' 'Previous Start menu layout' 'Brings back the Start menu from before the 25H2 redesign (does nothing on newer builds)' `
    -Warning 'Uses a hidden Windows feature switch. It only works on some builds and may stop working after an update.' -Registry @(
        @{ Path = 'HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\3036241548'; Name = 'EnabledState'; Value = 1 }
    )
Register-Tweak 'Explorer & Taskbar' 'Hide Start menu recommendations' 'Removes the Recommended section from Start' `
    -Warning 'This also turns off Windows Spotlight on the lock screen (it marks the PC as an education device).' -Registry @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start'; Name = 'HideRecommendedSection'; Value = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education'; Name = 'IsEducationEnvironment'; Value = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'HideRecommendedSection'; Value = 1 }
    )
Register-Tweak 'Explorer & Taskbar' 'Taskbar aligned left' 'Windows 11: Start button on the left like Windows 10' -Registry @(
    @{ Path = $adv; Name = 'TaskbarAl'; Value = 0; Revert = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'Hide taskbar search' 'Removes the search box / icon from the taskbar (Start search still works)' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0 }
)
Register-Tweak 'Explorer & Taskbar' 'Hide Task View button' 'Removes the Task View button from the taskbar' -Registry @(
    @{ Path = $adv; Name = 'ShowTaskViewButton'; Value = 0; Revert = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'Show battery percentage' 'Shows the battery % next to the tray icon (laptops)' -Registry @(
    @{ Path = $adv; Name = 'IsBatteryPercentageEnabled'; Value = 1 }
)
Register-Tweak 'Explorer & Taskbar' 'Dark mode' 'Dark theme for Windows and apps' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Revert = 1 }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Revert = 1 }
)

# =====================================================================
#  PREFERENCES
# =====================================================================
Register-Tweak 'Preferences' 'Detailed blue screen info' 'Shows the stop code details (no sad face) on a BSOD' -Recommended -Registry @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'; Name = 'DisplayParameters'; Value = 1; Revert = 0 }
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'; Name = 'DisableEmoticon'; Value = 1; Revert = 0 }
)
Register-Tweak 'Preferences' 'Verbose sign-in messages' 'Shows what Windows is doing during start-up, sign-in and shutdown' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'VerboseStatus'; Value = 1 }
)
Register-Tweak 'Preferences' 'Disable Sticky Keys prompt' 'No pop-up after pressing Shift five times' -Recommended -Registry @(
    @{ Path = 'HKCU:\Control Panel\Accessibility\StickyKeys'; Name = 'Flags'; Value = '506'; Type = 'String'; Revert = '510' }
)
Register-Tweak 'Preferences' 'NumLock on at startup' 'Number pad works straight away on the sign-in screen' -Registry @(
    @{ Path = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Value = '2'; Type = 'String'; Revert = '0' }
    @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Value = '2'; Type = 'String'; Revert = '0' }
)
Register-Tweak 'Preferences' 'Disable mouse acceleration' 'Cursor moves the same distance however fast you move the mouse ("enhance pointer precision" off)' -Registry @(
    @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseSpeed'; Value = '0'; Type = 'String'; Revert = '1' }
    @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold1'; Value = '0'; Type = 'String'; Revert = '6' }
    @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold2'; Value = '0'; Type = 'String'; Revert = '10' }
)
Register-Tweak 'Preferences' 'Scrollbars always visible' 'Scrollbars stay visible instead of hiding when not in use' -Registry @(
    @{ Path = 'HKCU:\Control Panel\Accessibility'; Name = 'DynamicScrollbars'; Value = 0; Revert = 1 }
)
Register-Tweak 'Preferences' 'Disable window snapping' 'Dragging a window to the edge no longer snaps or resizes it' -Registry @(
    @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'WindowArrangementActive'; Value = '0'; Type = 'String'; Revert = '1' }
)
Register-Tweak 'Preferences' 'Hide Settings home page' 'Settings opens on System instead of the Home page' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'SettingsPageVisibility'; Value = 'hide:home'; Type = 'String' }
)
Register-Tweak 'Preferences' 'Disable sign-in screen blur' 'Shows the sign-in background picture without the frosted blur' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'DisableAcrylicBackgroundOnLogon'; Value = 1 }
)
Register-Tweak 'Preferences' 'Disable lock screen' 'Goes straight to the sign-in screen on boot and wake' -Registry @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; Name = 'NoLockScreen'; Value = 1 }
)
Register-Tweak 'Preferences' 'Disable lock screen tips and ads' 'No Windows Spotlight "fun facts" and ads on the lock screen' -Registry @(
    @{ Path = $cdm; Name = 'RotatingLockScreenOverlayEnabled'; Value = 0; Revert = 1 }
    @{ Path = $cdm; Name = 'SubscribedContent-338387Enabled'; Value = 0; Revert = 1 }
)
Register-Tweak 'Preferences' 'Use classic Outlook' 'Hides the "Try the new Outlook" toggle and stops automatic migration' -Registry @(
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences'; Name = 'UseNewOutlook'; Value = 0 }
    @{ Path = 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General'; Name = 'HideNewOutlookToggle'; Value = 1 }
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Options\General'; Name = 'DoNewOutlookAutoMigration'; Value = 0 }
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences'; Name = 'NewOutlookMigrationUserSetting'; Value = 0 }
)
Register-Tweak 'Preferences' 'Enable long file paths' 'Allows paths longer than 260 characters' -Registry @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name = 'LongPathsEnabled'; Value = 1; Revert = 0 }
)
Register-Tweak 'Preferences' 'Disable Storage Sense' 'Stops Windows deleting old Downloads and Recycle Bin files by itself' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name = '01'; Value = 0; Revert = 1 }
)
Register-Tweak 'Preferences' 'No network in Modern Standby' 'Laptop stays offline while asleep (S0 low-power idle) - saves battery' -Registry @(
    @{ Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9'; Name = 'ACSettingIndex'; Value = 0 }
)
Register-Tweak 'Preferences' 'Use S3 sleep instead of Modern Standby' 'Classic sleep that cuts CPU power (fixes hot bags and drained batteries)' `
    -Warning 'Only works if the BIOS supports S3. If not, sleep may disappear from the power menu until you undo this. Restart needed.' -Registry @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name = 'PlatformAoAcOverride'; Value = 0 }
    )
Register-Tweak 'Preferences' 'Set hardware clock to UTC' 'For PCs that dual-boot Linux - stops the clock jumping between systems' `
    -Warning 'Only for dual-boot PCs. On a normal PC the clock will be wrong until Windows resyncs.' -Registry @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; Name = 'RealTimeIsUniversal'; Value = 1; Type = 'QWord'; Revert = 0 }
    )

# =====================================================================
#  NETWORK
# =====================================================================
Register-Tweak 'Network' 'Prefer IPv4 over IPv6' 'Uses IPv4 first on networks where IPv6 is not set up properly' -Registry @(
    @{ Path = $tcp6; Name = 'DisabledComponents'; Value = 32; Revert = 0 }
)
Register-Tweak 'Network' 'Disable IPv6' 'Turns IPv6 off on every adapter' `
    -Warning 'Some ISPs, Xbox Live, DirectAccess and Windows features expect IPv6. Restart needed. Do not combine with "Prefer IPv4".' -Registry @(
        @{ Path = $tcp6; Name = 'DisabledComponents'; Value = 255; Revert = 0 }
    ) -Apply { Disable-NetAdapterBinding -Name * -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue } -Revert { Enable-NetAdapterBinding -Name * -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue }
Register-Tweak 'Network' 'Disable Teredo' 'Turns off the Teredo IPv6 tunnel (can lower latency; some games need it)' `
    -Apply { netsh interface teredo set state disabled } -Revert { netsh interface teredo set state default } `
    -Test { "$(netsh interface teredo show state)" -match 'disabled' }
Register-Tweak 'Network' 'Disable unsigned RDP file warnings' 'No security warning when opening .rdp files that are not signed' `
    -Warning 'Lowers protection against malicious .rdp files sent by email.' -Registry @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client'; Name = 'RedirectionWarningDialogVersion'; Value = 1 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client'; Name = 'RdpLaunchConsentAccepted'; Value = 1 }
    )
Register-Tweak 'Network' 'Disable SMBv1' 'Turns off the old, insecure file sharing protocol' -Recommended `
    -Warning 'Very old NAS boxes, printers or scanners that only speak SMBv1 will stop working with this PC.' `
    -Apply { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force; Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null } `
    -Revert { Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force } `
    -Test { -not (Get-SmbServerConfiguration).EnableSMB1Protocol }
Register-Tweak 'Network' 'Block Adobe activation servers' 'Adds a community block list of Adobe telemetry / activation hosts to the hosts file' `
    -Warning 'Downloads a community-maintained list (github.com/Ruddernation-Designs) and may stop licensed Adobe apps from activating.' -Apply {
        $h = "$env:windir\System32\drivers\etc\hosts"
        Copy-Item $h "$h.bak_$(Get-Date -Format yyyyMMddHHmmss)" -Force
        $list = Invoke-RestMethod -Uri 'https://github.com/Ruddernation-Designs/Adobe-URL-Block-List/raw/refs/heads/master/hosts' -TimeoutSec 20
        Add-Content -Path $h -Value "`r`n# IT Toolkit Adobe block - start`r`n$list`r`n# IT Toolkit Adobe block - end"
        ipconfig /flushdns | Out-Null
    } -Revert {
        $h = "$env:windir\System32\drivers\etc\hosts"
        $text = (Get-Content $h -Raw) -replace '(?s)\r?\n# IT Toolkit Adobe block - start.*?# IT Toolkit Adobe block - end', ''
        Set-Content -Path $h -Value $text -NoNewline -Encoding ASCII
        ipconfig /flushdns | Out-Null
    } -Test { (Get-Content "$env:windir\System32\drivers\etc\hosts" -Raw) -match 'IT Toolkit Adobe block - start' }

# =====================================================================
#  DRIVERS & VENDOR SOFTWARE
# =====================================================================
Register-Tweak 'Drivers & vendor apps' 'Block Razer software auto-install' 'Stops Windows installing Razer Synapse when a Razer device is plugged in' `
    -Warning 'Also stops Windows downloading drivers and companion apps automatically for ALL new devices.' -Registry @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Value = 0; Revert = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer'; Name = 'DisableCoInstallers'; Value = 1; Revert = 0 }
    ) -Apply {
        $p = "$env:windir\Installer\Razer"
        if (Test-Path $p) { Get-ChildItem $p -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } else { New-Item -Path $p -ItemType Directory -Force | Out-Null }
        icacls.exe $p /deny '*S-1-1-0:(W)' | Out-Null
    } -Revert { if (Test-Path "$env:windir\Installer\Razer") { icacls.exe "$env:windir\Installer\Razer" /remove:d '*S-1-1-0' | Out-Null } }
Register-Tweak 'Drivers & vendor apps' 'Block Logitech Download Assistant' 'Stops Windows Update reinstalling the Logi Download Assistant pop-up' -Apply {
    Stop-Process -Name 'logi_download_assistant' -Force -ErrorAction SilentlyContinue
    $p = Join-Path $(if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }) 'LogiDownloadAssistant'
    if (Test-Path $p) { Get-ChildItem $p -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } else { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    icacls.exe $p /deny '*S-1-1-0:(W)' | Out-Null
} -Revert {
    $p = Join-Path $(if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }) 'LogiDownloadAssistant'
    if (Test-Path $p) { icacls.exe $p /remove:d '*S-1-1-0' | Out-Null }
} -Test {
    $p = Join-Path $(if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }) 'LogiDownloadAssistant'
    (Test-Path $p) -and [bool]((Get-Acl $p).Access | Where-Object { $_.AccessControlType -eq 'Deny' })
}

# =====================================================================
#  CLEANUP (one-off actions, nothing to undo)
# =====================================================================
Register-Tweak 'Cleanup' 'Run Disk Cleanup + remove old updates' 'cleanmgr on C: plus DISM /ResetBase to delete superseded updates' -NoUndo `
    -Warning 'After /ResetBase, already-installed updates can no longer be uninstalled.' -Apply {
        Start-Process cleanmgr.exe -ArgumentList "/d $env:SystemDrive /VERYLOWDISK" -Wait
        DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
    }
Register-Tweak 'Cleanup' 'Delete temporary files' 'Empties the Windows and every user''s Temp folder (files in use are skipped)' -NoUndo -Apply {
    $paths = @("$env:windir\Temp") + @(Get-UserProfilePaths | ForEach-Object { "$_\AppData\Local\Temp" })
    foreach ($p in $paths) { if (Test-Path $p) { Get-ChildItem $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Log "Emptied $p" } }
}

# =====================================================================
#  REMOVE APPS (caution - reinstall to undo)
# =====================================================================
Register-Tweak 'Remove apps' 'Remove promoted bloat apps' 'Removes Candy Crush, TikTok, Spotify promo, Disney+, Clipchamp and similar for all users' -NoUndo `
    -Warning 'Removed for every user. They can be installed again from the Microsoft Store.' -Apply {
        $names = '*CandyCrush*', '*BubbleWitch*', '*TikTok*', '*Disney*', '*Facebook*', '*Instagram*', '*Twitter*', '*SpotifyAB.SpotifyMusic*',
                 '*king.com*', '*Clipchamp*', '*Microsoft.BingNews*', '*Microsoft.GamingApp*', '*Microsoft.MicrosoftSolitaireCollection*', '*Microsoft.ZuneVideo*'
        foreach ($n in $names) {
            Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; Log "Removed $($_.Name)" } catch { Log "$($_.Name): $($_.Exception.Message)" 'WARN' } }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -like $n | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        }
    } -Test { -not ('*CandyCrush*', '*TikTok*', '*Disney*' | ForEach-Object { Get-AppxPackage -AllUsers -Name $_ -ErrorAction SilentlyContinue }) }
Register-Tweak 'Remove apps' 'Remove Widgets' 'Uninstalls the Widgets board and its web experience pack for all users' -NoUndo `
    -Warning 'Reinstall "Windows Web Experience Pack" from the Microsoft Store to get Widgets back.' -Apply {
        Get-Process *Widget* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        foreach ($n in 'Microsoft.WidgetsPlatformRuntime', 'MicrosoftWindows.Client.WebExperience') {
            Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; Log "Removed $($_.Name)" } catch { Log "$($_.Name): $($_.Exception.Message)" 'WARN' } }
        }
    } -Test { -not (Get-AppxPackage -AllUsers -Name 'MicrosoftWindows.Client.WebExperience' -ErrorAction SilentlyContinue) }
Register-Tweak 'Remove apps' 'Remove Copilot and AI apps' 'Uninstalls Copilot and the Microsoft 365 Copilot app, disables the AI service and the Recall feature' -NoUndo `
    -Warning 'Copilot and Recall are removed for every user. Reinstall Copilot from the Store to undo.' -Apply {
        foreach ($n in '*Copilot*', 'Microsoft.MicrosoftOfficeHub', 'MicrosoftWindows.Client.CoreAI') {
            Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; Log "Removed $($_.Name)" } catch { Log "$($_.Name): $($_.Exception.Message)" 'WARN' } }
        }
        if (Get-Service -Name WSAIFabricSvc -ErrorAction SilentlyContinue) { Set-Service -Name WSAIFabricSvc -StartupType Disabled; Stop-Service WSAIFabricSvc -Force -ErrorAction SilentlyContinue }
        try { Disable-WindowsOptionalFeature -Online -FeatureName Recall -NoRestart -ErrorAction Stop | Out-Null; Log 'Recall feature disabled.' 'OK' } catch { Log 'Recall is not on this PC.' }
    } -Test { -not (Get-AppxPackage -AllUsers -Name '*Copilot*' -ErrorAction SilentlyContinue) }
Register-Tweak 'Remove apps' 'Remove OneDrive' 'Uninstalls OneDrive for the signed-in user and stops it coming back. Local files stay where they are.' `
    -Warning 'Files that are "online-only" in OneDrive will no longer open from this PC. Make sure everything needed is downloaded first.' -Apply {
        Invoke-AsUser -TimeoutSec 300 -Script @'
Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
$setup = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") + @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($setup) { Start-Process $setup -ArgumentList '/uninstall' -Wait; 'OneDrive uninstalled.' } else { 'OneDrive setup not found - it may already be removed.' }
'@
        if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc') { Set-Service -Name OneSyncSvc -StartupType Disabled -ErrorAction SilentlyContinue }
    } -Revert {
        Invoke-WingetApps -Ids @('Microsoft.OneDrive') -Action Install
        if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc') { Set-Service -Name OneSyncSvc -StartupType Automatic -ErrorAction SilentlyContinue }
    } -Test { -not (Get-UserProfilePaths | Where-Object { Test-Path "$_\AppData\Local\Microsoft\OneDrive\OneDrive.exe" }) }
Register-Tweak 'Remove apps' 'Remove Microsoft Edge' 'Uninstalls Edge with its own uninstaller (WebView2 stays, apps that need it keep working)' `
    -Warning 'Edge is removed system-wide. Some Windows links and widgets open nothing until another browser is set as default. Undo reinstalls Edge with winget.' -Apply {
        $dir = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"
        $setup = Get-ChildItem "$dir\*\Installer\setup.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        if (-not $setup) { Log 'Microsoft Edge is not installed.'; return }
        New-Item -Path "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe" -ItemType File -Force | Out-Null
        Start-Process -FilePath $setup.FullName -ArgumentList '--uninstall --system-level --force-uninstall' -Wait
        Log 'Microsoft Edge removed.' 'OK'
    } -Revert { Invoke-WingetApps -Ids @('Microsoft.Edge') -Action Install } `
    -Test { -not (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") }
Register-Tweak 'Remove apps' 'Turn off BitLocker' 'Decrypts the system drive (takes a while, the PC stays usable)' -NoUndo `
    -Warning 'The drive is no longer encrypted - anyone with the laptop can read it. Company devices often REQUIRE BitLocker. Re-enable it from Control Panel.' -Apply {
        $v = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        if ($v.VolumeStatus -eq 'FullyDecrypted') { Log "BitLocker is already off on $env:SystemDrive." 'OK' }
        else { Disable-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop | Out-Null; Log 'Decryption started. Check progress with Tools > Security > BitLocker status.' 'OK' }
    } -Test { (Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).VolumeStatus -eq 'FullyDecrypted' }

Remove-Variable adv, cdm, edge, brave, tcp6 -ErrorAction SilentlyContinue
