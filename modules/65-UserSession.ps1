# User Session - things that must run as the person signed in to the PC.
# Backstage runs as SYSTEM; Invoke-AsUser (core\Helpers.ps1) runs code in the user's own session.
Register-Tool 'User Session' 'Who is signed in' 'Console user and all sessions (quser)' {
    $u = Get-ConsoleUser
    if ($u) { Log "Signed in at the console: $u" 'OK' } else { Log 'Nobody is signed in at the console.' 'WARN' }
    quser.exe 2>&1
}
Register-Tool 'User Session' 'Message the user' 'Pop-up message on the user''s screen' -Inputs 'Text|Message to show|IT Support is working on your PC. Please save your work.' {
    param($P)
    msg.exe * /TIME:600 $P.Text
    Log 'Message sent to all sessions.' 'OK'
}
Register-Tool 'User Session' 'Mapped drives (user)' 'Network drives the signed-in user has' {
    Invoke-AsUser -Script 'Get-PSDrive -PSProvider FileSystem | Where-Object DisplayRoot | Select-Object Name, DisplayRoot | Format-Table -AutoSize; net use'
}
Register-Tool 'User Session' 'Printers (user)' 'Printers as the signed-in user sees them' {
    Invoke-AsUser -Script 'Get-Printer | Select-Object Name, Type, DriverName, PortName | Format-Table -AutoSize; "Default: " + (Get-CimInstance Win32_Printer -Filter "Default=True").Name'
}
Register-Tool 'User Session' 'Restart Explorer' 'Fixes a frozen taskbar or desktop' -Confirm 'The user''s taskbar and open File Explorer windows will close and come back. Continue?' {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Invoke-AsUser -Script 'Start-Process explorer.exe' -NoWait | Out-Null }
    Log 'Explorer restarted.' 'OK'
}
Register-Tool 'User Session' 'Reset OneDrive (user)' 'Fixes sync problems - files are not deleted' -Confirm 'OneDrive will reset and resync for the signed-in user. Files stay where they are. Continue?' {
    Invoke-AsUser -TimeoutSec 180 -Script @'
$paths = "$env:LOCALAPPDATA\Microsoft\OneDrive\onedrive.exe", "$env:ProgramFiles\Microsoft OneDrive\onedrive.exe", "${env:ProgramFiles(x86)}\Microsoft OneDrive\onedrive.exe"
$exe = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) { 'OneDrive is not installed for this user.'; return }
& $exe /reset
Start-Sleep -Seconds 20
if (-not (Get-Process OneDrive -ErrorAction SilentlyContinue)) { Start-Process $exe }
'OneDrive reset and restarted.'
'@
}
Register-Tool 'User Session' 'User Group Policy update' 'gpupdate /target:user as the signed-in user' {
    Invoke-AsUser -TimeoutSec 180 -Script "'N' | gpupdate.exe /target:user /force"
}
Register-Tool 'User Session' 'Open a website for the user' 'Opens a link in the user''s browser' -Inputs 'Url|Website address|https://' {
    param($P)
    $url = $P.Url -replace "'", ''
    Invoke-AsUser -NoWait -Script "Start-Process '$url'" | Out-Null
    Log "Opened $url for $(Get-ConsoleUser)" 'OK'
}
Register-Tool 'User Session' 'User environment' 'Profile path, OneDrive folders, signed-in account' {
    Invoke-AsUser -Script '[pscustomobject]@{ User = "$env:USERDOMAIN\$env:USERNAME"; Profile = $env:USERPROFILE; Desktop = [Environment]::GetFolderPath("Desktop"); Documents = [Environment]::GetFolderPath("MyDocuments"); OneDrive = $env:OneDrive; OneDriveBusiness = $env:OneDriveCommercial; LogonServer = $env:LOGONSERVER } | Format-List'
}
