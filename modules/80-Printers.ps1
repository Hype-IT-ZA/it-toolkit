# Printers
Register-Tool 'Printers' 'List printers' 'Installed printers, drivers, ports' { Get-Printer | Select-Object Name, DriverName, PortName, PrinterStatus, Shared | Format-Table -AutoSize }
Register-Tool 'Printers' 'Print queue' 'Jobs waiting on every printer' {
    $jobs = Get-Printer | ForEach-Object { Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue }
    if (-not $jobs) { Log 'No print jobs waiting.' 'OK'; return }
    $jobs | Select-Object PrinterName, DocumentName, UserName, JobStatus, SubmittedTime | Format-Table -AutoSize
}
Register-Tool 'Printers' 'Add network printer (IP)' 'TCP/IP printer for everyone on the PC' -Inputs 'Ip|Printer IP address|192.168.1.', 'Name|Printer name|Office Printer', 'Driver|Driver name (must already be installed or built in)|Microsoft PCL6 Class Driver' {
    param($P)
    $port = "IP_$($P.Ip)"
    if (-not (Get-PrinterPort -Name $port -ErrorAction SilentlyContinue)) { Add-PrinterPort -Name $port -PrinterHostAddress $P.Ip -ErrorAction Stop; Log "Port $port created" }
    if (-not (Get-PrinterDriver -Name $P.Driver -ErrorAction SilentlyContinue)) {
        try { Add-PrinterDriver -Name $P.Driver -ErrorAction Stop; Log "Driver '$($P.Driver)' added" }
        catch { Log "Driver '$($P.Driver)' is not installed. Install the manufacturer's driver first, then use its exact name. Installed drivers:" 'ERROR'; Get-PrinterDriver | Select-Object Name | Format-Table -AutoSize; return }
    }
    Add-Printer -Name $P.Name -DriverName $P.Driver -PortName $port -ErrorAction Stop
    Log "Printer '$($P.Name)' added on $($P.Ip)." 'OK'
}
Register-Tool 'Printers' 'Printer drivers' 'Installed printer drivers' { Get-PrinterDriver | Select-Object Name, Manufacturer, MajorVersion | Sort-Object Name | Format-Table -AutoSize }
Register-Tool 'Printers' 'Restart print spooler' 'Restarts the spooler, keeps jobs' { Restart-Service Spooler -Force; Get-Service Spooler | Select-Object Name, Status | Format-Table -AutoSize }
Register-Tool 'Printers' 'Clear stuck print jobs' 'Stops spooler, clears queue, restarts' -Confirm 'All waiting print jobs will be cancelled. Continue?' {
    Stop-Service Spooler -Force
    Get-ChildItem "$env:windir\System32\spool\PRINTERS" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    Log 'Print queue cleared and spooler restarted.' 'OK'
}
