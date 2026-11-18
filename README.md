# IT Toolkit

A dark / light GUI toolbox of 80+ everyday IT tools for Windows, written in plain PowerShell (WinForms, no installs).
It's built to run inside a **ScreenConnect Backstage** session (as SYSTEM, without Explorer) and works just as well on your own PC.

## Quick start

Open an elevated PowerShell window, or the PowerShell console in ScreenConnect Backstage, and run:

```powershell
irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex
```

This downloads the latest version to `C:\ProgramData\ITToolkit` and starts it. Run the same line again to update.

On an older machine (Windows 10 before 1809 or Server 2016) where the download fails with a TLS or SSL error, use this instead:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex
```

> **Tip:** `irm | iex` runs code straight from the internet. Read [`install.ps1`](install.ps1) and [`ITToolkit.ps1`](ITToolkit.ps1) first if you're not the one maintaining this repo.

## Features

- **80+ tools in 11 categories.** Click a card to run it.
- **Never freezes.** Tools run in the background, several can run at once, and the **Stop** button cancels them.
- **Safe by default.** Anything risky asks for confirmation first. The cleanup tools only remove temp and cache files that Windows rebuilds.
- **Dark and light themes** with a switch in the header. Your choice is remembered.
- **Search** with `Ctrl+F`, plus a **PS>** line for running any PowerShell command.
- **Colour-coded output** you can copy or save. A session log is written to disk when you close the window.
- **Plugins.** Drop a `.ps1` file into the `Tools` folder to add your own tools.

| Category | Examples |
|---|---|
| Quick Launch | Task Manager, cmd, PowerShell, regedit, Services, Event Viewer, Device Manager, Disk Management, hosts file |
| System | System summary (model, serial, OS, CPU, RAM, uptime), performance snapshot, installed software, pending reboot check, startup apps, activation, problem devices, battery health, BitLocker |
| Network | IP config, adapters, public IP, ping, traceroute, port test, DNS lookup, flush DNS, renew DHCP, network stack reset, Wi-Fi status, active connections |
| Disk & Cleanup | Disk space, safe cleanup (temp files and browser caches for all users), Windows Update cache, Recycle Bins, largest folders, disk health, DISM component cleanup, chkdsk scan |
| Repair | SFC, DISM check and restore health, Windows Update reset (old folders kept as backup), time sync, gpupdate |
| Services & Processes | Top processes, stopped automatic services, restart a service, end a process |
| Security & Users | Antivirus status, Defender update and quick scan, firewall, local users and admins, logged-on users, failed logons, recent errors, shutdown history |
| Updates | Update history, check for updates, installed hotfixes, start update install |
| Printers | List printers, print queue, restart spooler, clear stuck jobs |
| Power | Power plans, restart in 5 minutes (warns the user), cancel restart, restart now, turn off hibernation |
| Custom | Example plugin tools from `Tools/Example-Tools.ps1` |

Cards are tagged **CONFIRM** (asks "are you sure?"), **INPUT** (asks for a value) or **LAUNCH** (opens an app).

## Other ways to run it

From a local copy, for example after copying the folder over with ScreenConnect's file transfer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "C:\ProgramData\ITToolkit\ITToolkit.ps1"
```

As a desktop shortcut, with **Run as administrator** ticked under Properties → Advanced:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "C:\Path\To\ITToolkit\ITToolkit.ps1"
```

## Adding your own tools

Every `.ps1` file in the `Tools` folder next to `ITToolkit.ps1` is loaded at startup. Each file calls `Register-Tool`:

```powershell
# Plain tool: anything it outputs is shown in the console
Register-Tool -Category 'My Tools' -Name 'Hello' -Description 'Says hi' -Action {
    Log 'Hello!' 'OK'      # levels: INFO, OK, WARN, ERROR
    Get-Date
}

# Asks for a value first ('Key|Prompt|Default'); read it with param($P)
Register-Tool -Category 'My Tools' -Name 'Ping a host' -Description 'Ping 4 times' `
    -Inputs 'Target|Hostname or IP|8.8.8.8' -Action { param($P) ping.exe -n 4 $P.Target }

# Shows a Yes/No warning first
Register-Tool -Category 'My Tools' -Name 'Restart spooler' -Description 'Restarts printing' `
    -Confirm 'Restart the print spooler?' -Action { Restart-Service Spooler -Force }

# Opens an app straight away, without the background runner
Register-Tool -Category 'My Tools' -Name 'Notepad' -Description 'Open Notepad' -Launch -Action { Start-Process notepad.exe }
```

Tools added to the `Tools` folder in this repo are installed by the one-liner. Files you add yourself on a PC in `C:\ProgramData\ITToolkit\Tools` are kept when you update.

The built-in tools are defined near the top of `ITToolkit.ps1` with the same `Register-Tool` calls, so you can edit or remove them there.

## Files and settings

| Path | What's in it |
|---|---|
| `C:\ProgramData\ITToolkit\ITToolkit.ps1` | The toolkit |
| `C:\ProgramData\ITToolkit\Tools\` | Plugin tools |
| `C:\ProgramData\ITToolkit\settings.json` | Saved theme |
| `C:\ProgramData\ITToolkit\Logs\` | Saved logs and session logs |

## Requirements and notes

- Windows 10 or 11, or Windows Server 2016 and later, with Windows PowerShell 5.1 (built in). Run it elevated.
- The script restarts itself in STA mode if it needs to, which WinForms requires.
- **In Backstage it runs as SYSTEM,** so anything tied to a user's own account (HKCU, mapped drives) shows SYSTEM's. The cleanup tools go through every user profile to get around this.
- Some tools only work on certain editions or hardware, for example `lusrmgr.msc` on Pro and Enterprise, battery health on laptops, and BitLocker where it's available.
- Scroll bars stay light in dark mode because of a WinForms limitation.

## License

[MIT](LICENSE)
