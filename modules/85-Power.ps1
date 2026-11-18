# Power
Register-Tool 'Power' 'Power plans' 'Active and available plans' { powercfg /list }
Register-Tool 'Power' 'Restart in 5 minutes' 'Warns the user, then restarts' -Confirm 'The user will see a 5-minute warning, then the PC restarts. Continue?' {
    shutdown.exe /r /t 300 /d p:4:1 /c 'IT Support: this PC will restart in 5 minutes. Please save your work.'
    Log 'Restart scheduled in 5 minutes. Use "Cancel scheduled restart" to abort.' 'WARN'
}
Register-Tool 'Power' 'Cancel scheduled restart' 'shutdown /a' { shutdown.exe /a; Log 'Scheduled restart cancelled (if one was pending).' 'OK' }
Register-Tool 'Power' 'Restart now' 'Immediate restart' -Confirm 'The PC will restart NOW. Unsaved work will be lost. Continue?' { shutdown.exe /r /t 5 /d p:4:1 /c 'IT Support restart'; Log 'Restarting in 5 seconds...' 'WARN' }
Register-Tool 'Power' 'Sleep / wake report' 'What is keeping the PC awake (powercfg)' {
    Log 'Active requests (apps preventing sleep):'; powercfg /requests
    Log 'Last wake source:'; powercfg /lastwake
    Log 'Devices allowed to wake the PC:'; powercfg /devicequery wake_armed
}
