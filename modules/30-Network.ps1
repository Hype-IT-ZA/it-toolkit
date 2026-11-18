# Network
Register-Tool 'Network' 'IP configuration' 'Adapters, IPs, gateways, DNS' {
    Get-NetIPConfiguration | ForEach-Object {
        [pscustomobject]@{
            Adapter = $_.InterfaceAlias; Status = $_.NetAdapter.Status
            IPv4 = ($_.IPv4Address.IPAddress -join ', '); Gateway = ($_.IPv4DefaultGateway.NextHop -join ', ')
            DNS = (($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ', ')
        }
    } | Format-Table -AutoSize
}
Register-Tool 'Network' 'Network adapters' 'Link speed, MAC, status' {
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress | Format-Table -AutoSize
}
Register-Tool 'Network' 'Public IP' 'Internet-facing IP address' {
    try { Log ('Public IP: ' + (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10)) 'OK' } catch { Log "Could not reach the internet: $($_.Exception.Message)" 'ERROR' }
}
Register-Tool 'Network' 'Speed test' 'Download speed and latency (Cloudflare)' {
    $ping = Test-Connection -ComputerName 1.1.1.1 -Count 4 -ErrorAction SilentlyContinue
    if ($ping) { Log ('Latency to 1.1.1.1: {0:N0} ms average' -f ($ping | Measure-Object ResponseTime -Average).Average) }
    $bytes = 25MB
    Log 'Downloading 25 MB test file...'
    $wc = New-Object Net.WebClient
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $data = $wc.DownloadData("https://speed.cloudflare.com/__down?bytes=$bytes")
        $sw.Stop()
        $mbps = ($data.Length * 8 / 1MB) / $sw.Elapsed.TotalSeconds
        Log ('Download: {0:N1} Mbps ({1:N1} s)' -f $mbps, $sw.Elapsed.TotalSeconds) 'OK'
    } catch { Log "Speed test failed: $($_.Exception.Message)" 'ERROR' } finally { $wc.Dispose() }
}
Register-Tool 'Network' 'Ping' 'Ping a host 4 times' -Inputs 'Target|Hostname or IP|8.8.8.8' { param($P) ping.exe -n 4 $P.Target }
Register-Tool 'Network' 'Traceroute' 'Trace the route to a host' -Inputs 'Target|Hostname or IP|8.8.8.8' { param($P) tracert.exe -d -h 20 -w 800 $P.Target }
Register-Tool 'Network' 'Test port' 'Check if a TCP port is reachable' -Inputs 'Target|Hostname or IP|google.com', 'Port|Port number|443' {
    param($P)
    $r = Test-NetConnection -ComputerName $P.Target -Port ([int]$P.Port) -WarningAction SilentlyContinue
    Log ('{0}:{1} ({2}) -> {3}' -f $P.Target, $P.Port, $r.RemoteAddress, $(if ($r.TcpTestSucceeded) { 'OPEN' } else { 'CLOSED / filtered' })) $(if ($r.TcpTestSucceeded) { 'OK' } else { 'WARN' })
}
Register-Tool 'Network' 'DNS lookup' 'Resolve a name' -Inputs 'Name|Hostname to resolve|google.com' {
    param($P) Resolve-DnsName -Name $P.Name -ErrorAction Stop | Select-Object Name, Type, TTL, IPAddress, NameHost | Format-Table -AutoSize
}
Register-Tool 'Network' 'Flush DNS cache' 'ipconfig /flushdns' { ipconfig /flushdns }
Register-Tool 'Network' 'Set DNS servers' 'Cloudflare, Google, Quad9, OpenDNS, AdGuard or back to DHCP' -Inputs 'Provider|Cloudflare, CloudflareMalware, CloudflareFamily, Google, Quad9, OpenDNS, AdGuard, AdGuardFamily or DHCP|Cloudflare' `
    -Confirm 'This changes DNS on every connected adapter. On a company domain network this can break sign-ins and file shares. Continue?' {
    param($P)
    $sets = @{
        cloudflare = @('1.1.1.1', '1.0.0.1'); cloudflaremalware = @('1.1.1.2', '1.0.0.2'); cloudflarefamily = @('1.1.1.3', '1.0.0.3')
        google = @('8.8.8.8', '8.8.4.4'); quad9 = @('9.9.9.9', '149.112.112.112'); opendns = @('208.67.222.222', '208.67.220.220')
        adguard = @('94.140.14.14', '94.140.15.15'); adguardfamily = @('94.140.14.15', '94.140.15.16')
    }
    $choice = ($P.Provider -replace '[^A-Za-z0-9]', '').ToLower()
    if ($choice -ne 'dhcp' -and -not $sets.ContainsKey($choice)) { Log "Unknown provider '$($P.Provider)'. Use one of: $(($sets.Keys | Sort-Object) -join ', '), dhcp" 'ERROR'; return }
    foreach ($a in (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' })) {
        if ($choice -eq 'dhcp') { Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ResetServerAddresses; Log "$($a.InterfaceAlias): DNS reset to automatic (DHCP)" 'OK' }
        else { Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $sets[$choice]; Log "$($a.InterfaceAlias): DNS set to $($sets[$choice] -join ', ')" 'OK' }
    }
    ipconfig /flushdns | Out-Null
}
Register-Tool 'Network' 'Renew DHCP lease' 'ipconfig /renew (no release)' -Confirm 'Renewing the IP can briefly drop the remote session. It should reconnect by itself. Continue?' { ipconfig /renew }
Register-Tool 'Network' 'Reset network stack' 'Winsock + TCP/IP reset (needs reboot)' -Confirm 'This resets Winsock and TCP/IP settings. Static IPs may need re-entering and a reboot is required. Continue?' {
    netsh winsock reset; netsh int ip reset
    Log 'Done. Restart the PC to finish.' 'WARN'
}
Register-Tool 'Network' 'Reset hosts file' 'Back up and restore the default hosts file' -Confirm 'The current hosts file will be backed up and replaced with the Windows default. Continue?' {
    $h = "$env:windir\System32\drivers\etc\hosts"
    $bak = "$h.bak_$(Get-Date -Format yyyyMMddHHmmss)"
    if (Test-Path $h) { Copy-Item $h $bak -Force; Log "Backup saved: $bak" }
    $default = "# Copyright (c) 1993-2009 Microsoft Corp.`r`n#`r`n# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.`r`n#`r`n# localhost name resolution is handled within DNS itself.`r`n#`t127.0.0.1       localhost`r`n#`t::1             localhost`r`n"
    Set-Content -Path $h -Value $default -Encoding ASCII
    ipconfig /flushdns | Out-Null
    Log 'Hosts file reset to default.' 'OK'
}
Register-Tool 'Network' 'Wi-Fi status' 'SSID, signal, speed of the Wi-Fi adapter' { netsh wlan show interfaces }
Register-Tool 'Network' 'Active connections' 'Established TCP connections by process' {
    $names = @{}; Get-Process | ForEach-Object { $names[$_.Id] = $_.Name }
    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -notin '127.0.0.1', '::1' } |
        Select-Object @{ n = 'Process'; e = { $names[[int]$_.OwningProcess] } }, OwningProcess, LocalPort, RemoteAddress, RemotePort |
        Sort-Object Process | Format-Table -AutoSize
}
Register-Tool 'Network' 'Proxy settings' 'WinHTTP proxy configuration' { netsh winhttp show proxy }
