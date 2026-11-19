# Quick Launch - opens apps on the Backstage / local desktop (runs instantly on the UI thread)
Register-Tool 'Quick Launch' 'Task Manager'         'Processes, performance, startup apps'  { Start-Process taskmgr.exe } -Launch
Register-Tool 'Quick Launch' 'Command Prompt'       'New cmd.exe window'                     { Start-Process cmd.exe } -Launch
Register-Tool 'Quick Launch' 'PowerShell'           'New PowerShell window'                  { Start-Process powershell.exe -ArgumentList '-NoExit', '-NoProfile' } -Launch
Register-Tool 'Quick Launch' 'Registry Editor'      'regedit'                                { Start-Process regedit.exe } -Launch
Register-Tool 'Quick Launch' 'Services'             'services.msc'                           { Start-Process mmc.exe 'services.msc' } -Launch
Register-Tool 'Quick Launch' 'Event Viewer'         'eventvwr.msc'                           { Start-Process mmc.exe 'eventvwr.msc' } -Launch
Register-Tool 'Quick Launch' 'Device Manager'       'devmgmt.msc'                            { Start-Process mmc.exe 'devmgmt.msc' } -Launch
Register-Tool 'Quick Launch' 'Computer Management'  'compmgmt.msc'                           { Start-Process mmc.exe 'compmgmt.msc' } -Launch
Register-Tool 'Quick Launch' 'Disk Management'      'diskmgmt.msc'                           { Start-Process mmc.exe 'diskmgmt.msc' } -Launch
Register-Tool 'Quick Launch' 'Local Users & Groups' 'lusrmgr.msc (Pro / Enterprise only)'    { Start-Process mmc.exe 'lusrmgr.msc' } -Launch
Register-Tool 'Quick Launch' 'Task Scheduler'       'taskschd.msc'                           { Start-Process mmc.exe 'taskschd.msc' } -Launch
Register-Tool 'Quick Launch' 'System Information'   'msinfo32'                               { Start-Process msinfo32.exe } -Launch
Register-Tool 'Quick Launch' 'System Properties'    'Computer name, domain, advanced settings' { Start-Process SystemPropertiesAdvanced.exe } -Launch
Register-Tool 'Quick Launch' 'Network Connections'  'ncpa.cpl adapter list'                  { Start-Process control.exe 'ncpa.cpl' } -Launch
Register-Tool 'Quick Launch' 'Programs & Features'  'appwiz.cpl uninstall list'              { Start-Process control.exe 'appwiz.cpl' } -Launch
Register-Tool 'Quick Launch' 'Edit hosts file'      'Opens the hosts file in Notepad'        { Start-Process notepad.exe "$env:windir\System32\drivers\etc\hosts" } -Launch
Register-Tool 'Quick Launch' 'Control Panel'         'Classic Control Panel'                  { Start-Process control.exe } -Launch
Register-Tool 'Quick Launch' 'Devices and Printers'  'Classic printers window'                { Start-Process control.exe 'printers' } -Launch
Register-Tool 'Quick Launch' 'Power Options'         'powercfg.cpl'                           { Start-Process control.exe 'powercfg.cpl' } -Launch
Register-Tool 'Quick Launch' 'Sound'                 'mmsys.cpl playback / recording devices' { Start-Process control.exe 'mmsys.cpl' } -Launch
Register-Tool 'Quick Launch' 'Mouse'                 'main.cpl'                               { Start-Process control.exe 'main.cpl' } -Launch
Register-Tool 'Quick Launch' 'Region'                'intl.cpl date, number and keyboard formats' { Start-Process control.exe 'intl.cpl' } -Launch
Register-Tool 'Quick Launch' 'Date and Time'         'timedate.cpl'                           { Start-Process control.exe 'timedate.cpl' } -Launch
Register-Tool 'Quick Launch' 'Windows Firewall'      'firewall.cpl'                           { Start-Process control.exe 'firewall.cpl' } -Launch
Register-Tool 'Quick Launch' 'Security and Maintenance' 'wscui.cpl'                           { Start-Process control.exe 'wscui.cpl' } -Launch
Register-Tool 'Quick Launch' 'System Restore'        'rstrui - roll back to a restore point'  { Start-Process rstrui.exe } -Launch
Register-Tool 'Quick Launch' 'User Accounts (netplwiz)' 'Users, passwords and automatic sign-in' { Start-Process netplwiz.exe } -Launch
