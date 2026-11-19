# IT Toolkit

[![Tests](https://github.com/Hype-IT-ZA/it-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/Hype-IT-ZA/it-toolkit/actions/workflows/ci.yml)

A free, open-source Windows support toolbox with a modern dark / light window: colour-coded categories with Windows' own Fluent icons, cards that reflow to the window size, and a live output console. It has everything in Chris Titus Tech's WinUtil (all its apps and tweaks), plus a large set of tools built for **remote support**. It runs inside a **ScreenConnect Backstage** session (as SYSTEM, without Explorer) and on any Windows PC.

- **Tools tab.** 150+ everyday IT tools: system, drivers, blue screens, network, disk and cleanup, repair, software, Office and Teams, the signed-in user's session, Domain & Entra, security, printers, power and reports.
- **Install tab.** Tick apps from about 250 programs (every app in WinUtil, plus more) and install, upgrade or uninstall them silently with winget. Includes presets.
- **Tweaks tab.** 85 tweaks and Windows features covering every WinUtil tweak, preference toggle and Config-tab feature. A restore point is made first, every tweak shows whether it's applied, and almost all of them can be undone.
- **Updates tab.** Windows Update policies (security-focused, stay on the current version, no driver updates) and update actions.
- **Headless mode.** Run any tool, install or tweak without the window. Useful for ScreenConnect's **Commands** tab or for fixing many PCs at once.

## Quick start

Open an elevated PowerShell window, or the PowerShell console in ScreenConnect Backstage, and run:

```powershell
irm hype-it-za.github.io/it-toolkit | iex
```

The long form also works: `irm https://raw.githubusercontent.com/Hype-IT-ZA/it-toolkit/main/install.ps1 | iex`

This downloads the latest version to `C:\ProgramData\ITToolkit` and opens the GUI. Run it again to update. The toolkit also tells you when a new version is out.

On an older machine (Windows 10 before 1809, or Server 2016) where the download fails with a TLS or SSL error, use this instead:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://hype-it-za.github.io/it-toolkit | iex
```

> `irm | iex` runs code straight from the internet. Read [`install.ps1`](install.ps1) first if you don't maintain this repo.

## The tabs

### Tools

| Category | Highlights |
|---|---|
| Quick Launch | Task Manager, cmd, PowerShell, regedit, the main `.msc` consoles, Control Panel and its classic applets (printers, power, sound, region, firewall...), System Restore, netplwiz, hosts file |
| System | System summary, performance snapshot, pending reboot check, **Windows 11 readiness**, startup apps, scheduled tasks, activation, problem devices, battery health, third-party drivers |
| Drivers | Dell / HP / Lenovo updates with the maker's own tool (scan or install), Windows Update drivers, driver backup |
| Blue screens | Recent stop codes and what they usually mean, crash dump analysis showing the driver involved, memory test and results |
| Network | **Network scan**, Wi-Fi report, saved Wi-Fi networks, IP config, adapters, public IP, **speed test**, ping, traceroute, port test, DNS lookup, **set DNS** (Cloudflare, Google, Quad9 or DHCP), flush DNS, renew DHCP, network stack reset, **reset hosts file**, Wi-Fi, connections, proxy |
| Disk & Cleanup | Disk space, safe cleanup (temp files and browser caches for all users, older than 2 days), Recycle Bins, largest folders, disk health, DISM cleanup, chkdsk scan |
| Repair | Restore point, SFC, DISM check and restore health, time sync, gpupdate, re-register Start and Search |
| Software | Installed software, available upgrades, upgrade all apps, winget search, install by ID, **install or repair winget** |
| Services & Processes | Top processes, stopped automatic services, restart a service, end a process |
| **User Session** | Runs as the *signed-in user*, not SYSTEM: who's signed in, message the user, their mapped drives and printers, restart Explorer, reset OneDrive, user gpupdate, open a website for them, user environment |
| **Domain & Entra** | Join status (domain / Entra / Intune), the user's Entra sign-in state, domain connection test, Group Policy results (HTML), Intune sync, Intune diagnostics, Intune app errors. Runs on the PC, no domain controller access needed |
| **Office & Teams** | Office info and channel, quick repair, online repair, update now, activation status, clear Teams cache (new and classic), reset Outlook cache, Outlook safe mode, reset the navigation pane |
| Security & Users | Antivirus status, Defender update and quick scan, **Microsoft Safety Scanner** (detect only), firewall, **BitLocker recovery key**, BitLocker status, enable or disable RDP, local users and admins, failed logons, recent errors, shutdown history |
| Printers | List printers, queue, **add network printer by IP**, drivers, restart spooler, clear stuck jobs |
| Power | Power plans, restart in 5 minutes (warns the user), cancel restart, restart now, sleep and wake report |
| **Toolkit** | **Toolkit self-test** (checks permissions, PowerShell, .NET, TLS, GitHub, winget, Task Scheduler, run-as-user and more, and says what to fix), **Report a problem** (opens the GitHub bug form) |
| **Reports** | **Health check report** (HTML with 15+ pass/warn/fail checks), **log bundle** (one zip for escalation), **before / after snapshots**, **inventory export** (hardware and software CSVs), **ticket notes**, open latest report |

Right-click any card to **add it to your favourites**. **Favourites** and **Recent** sit at the top of the sidebar.

### Install

Tick apps from 16 categories (or add a **preset**: Basic office PC, Technician toolkit, Developer or Gaming PC) and click **Install / upgrade selected**. You can also **Uninstall selected**, **Upgrade all apps**, or **Check installed** to see which apps are already on the PC. **Save selection as my preset** keeps your own list.

As SYSTEM, the toolkit finds winget on its own and installs machine-wide where possible. If winget is missing or broken, use **Tools → Software → Install / repair winget**.

### Tweaks

Each tweak shows **Applied** or **Not applied**, and recommended ones are marked. **Apply selected** creates a restore point first, and **Undo selected** reverses tweaks. Tweaks marked **Caution** explain the risk before you apply them. The few that can't be undone automatically say so.

Tweaks that change per-user settings (HKCU) are applied to **every signed-in user**, so they work from Backstage too.

| Category | Tweaks |
|---|---|
| Essential | Telemetry, activity history, consumer features, location, Delivery Optimization, hibernation, common services to Manual, Store results in search, WPBT, device companion apps, End task, Explorer folder type detection |
| Privacy | Advertising ID, tips and suggestions, Bing in Start, Copilot and Recall (policies), widgets, background apps, notifications and calendar |
| Browsers | Debloat Edge, debloat Brave |
| Performance | Ultimate Performance plan, visual effects for best performance, Game DVR, Game Mode, Fast Startup, search indexing, svchost splitting, reserved storage, Multiplane Overlay |
| Explorer & Taskbar | File extensions, hidden files, open to This PC, remove Home and Gallery, classic right-click menu, previous Start layout, hide Start recommendations, taskbar left, hide search, hide Task View, battery percentage, dark mode |
| Preferences | Detailed BSOD, verbose sign-in, Sticky Keys, NumLock, mouse acceleration, scrollbars always visible, window snapping, Settings home page, sign-in blur, lock screen, lock screen ads, classic Outlook, long paths, Storage Sense, network in Modern Standby, S3 sleep, UTC clock |
| Network | Prefer IPv4, disable IPv6, Teredo, unsigned RDP warnings, SMBv1, Adobe block list |
| Drivers & vendor apps | Block Razer and Logitech auto-installs |
| Cleanup | Disk Cleanup + remove old updates, delete temporary files |
| Remove apps | Promoted bloat apps, Widgets, Copilot and AI apps, OneDrive, Edge, turn off BitLocker |
| Windows features | .NET 3.5, Hyper-V, WSL, Windows Sandbox, legacy media, NFS client, OpenSSH Server, daily registry backup, F8 recovery menu, pool.ntp.org time |

WinUtil's buttons are here too. **O&O ShutUp10++** is under Tools → Software, **Set DNS** (all of WinUtil's DNS providers) is under Tools → Network, and **Ultimate Performance** is a tweak you can apply or undo.

### Updates

- **Policies:** default (let Windows manage), security-focused (quality updates after 4 days, feature updates after 365), stay on the current Windows version, exclude or allow driver updates, no restart while someone is signed in, and show the current policy. They only change the values this toolkit sets.
- **Actions:** check for updates, install updates now, update history, installed hotfixes, clear the update cache, reset Windows Update.

## Output, ticket notes and reports

- Every tool writes colour-coded output to the console. **Stop** cancels running tasks.
- The **PS>** line runs any PowerShell command in the background.
- **Ticket notes** builds a summary of the session ("Disk space: done. C: is low on space…") ready to paste into a ticket.
- **Settings** has an optional *report title* (your company or client name on reports) and an optional *webhook* (Discord, Slack or a Teams incoming webhook). The webhook can receive the ticket notes when you close the toolkit.
- Reports, logs and settings are saved in `C:\ProgramData\ITToolkit`.

## Headless mode

Pass options to run without the GUI. For ScreenConnect's **Commands** tab, start the command with `#!ps` and set a timeout, for example `#timeout=900000`.

```powershell
$itk = [scriptblock]::Create((irm hype-it-za.github.io/it-toolkit))

& $itk -List                                           # everything you can run
& $itk -Run 'Disk space', 'Safe cleanup'               # run tools
& $itk -Run 'Ping' -Inputs @{ Target = '1.1.1.1' }     # tools that ask for input
& $itk -Run 'Restart now' -Force                       # tools that normally ask "are you sure?"
& $itk -Install Google.Chrome, 7zip.7zip               # winget IDs or app names
& $itk -Uninstall 'Zoom'
& $itk -Tweak 'Show file extensions', 'Disable telemetry'
& $itk -Tweak 'Show file extensions' -Undo
& $itk -Setup 'https://example.com/office-pc.json'    # apps + tweaks from a saved setup
& $itk -HealthCheck                                    # HTML report in C:\ProgramData\ITToolkit\Reports
& $itk -Inventory                                      # hardware + software CSVs
& $itk -TweakStatus                                    # which tweaks are applied (changes nothing)
& $itk -SelfTest                                       # check the toolkit works on this PC
```

If the toolkit is already installed:

```powershell
& 'C:\ProgramData\ITToolkit\ITToolkit.ps1' -Run 'Safe cleanup'
```

The exit code is `1` if anything logged an error.

## Saved setups

On the Install or Tweaks tab, tick the apps and tweaks you want and click **Export setup**. That saves a small `.json` file (by default in `C:\ProgramData\ITToolkit\Setups`):

```json
{ "name": "office-pc", "apps": ["Google.Chrome", "7zip.7zip"], "tweaks": ["Disable telemetry", "Show file extensions"] }
```

On another PC, click **Import setup** to tick the same items, then review them and install / apply. Headless, `-Setup <file or URL>` installs and applies everything in one go. You can host your setups anywhere, for example a gist or your own repo.

## Problems and bug reports

1. Run **Tools → Toolkit → Toolkit self-test** (or `-SelfTest` headless). It checks everything the toolkit depends on and tells you what to fix.
2. Still stuck? [Open a bug report](https://github.com/Hype-IT-ZA/it-toolkit/issues/new/choose). The form asks for the version, Windows version, how you started it and the self-test output.

## Tests

Every push runs [`ci.yml`](.github/workflows/ci.yml) on a real Windows machine with Windows PowerShell 5.1: it parses every script and the Pages installer, runs PSScriptAnalyzer, runs the read-only tools, the health check, inventory and tweak status headless, and opens the whole window off-screen (`-UiTest`) to draw every tab, category and theme.

## Versions, releases and code signing

- Every change to `version.txt` on `main` creates a GitHub release with `ITToolkit.zip` (see `.github/workflows/release.yml`).
- The one-liner installs the **latest release**. To pin a version, for example if a new release causes problems: `& ([scriptblock]::Create((irm hype-it-za.github.io/it-toolkit))) -Version 2.2.0`
- **Code signing (optional):** add the repository secrets `CODE_SIGNING_PFX` (base64 of your `.pfx`) and `CODE_SIGNING_PASSWORD`, and every `.ps1` in the release zip is Authenticode-signed with a timestamp. This helps on PCs that only allow signed scripts and with antivirus reputation. It needs a code signing certificate from a CA such as Sectigo, DigiCert or Certum, or Azure Trusted Signing.

## Adding your own tools and tweaks

Drop a `.ps1` file in the `Tools` folder (see [`Tools/Example-Tools.ps1`](Tools/Example-Tools.ps1)):

```powershell
Register-Tool -Category 'My Tools' -Name 'Hello' -Description 'Says hi' -Action {
    Log 'Hello!' 'OK'          # INFO, OK, WARN, ERROR
}

Register-Tool -Category 'My Tools' -Name 'Ping a host' -Description 'Ping 4 times' `
    -Inputs 'Target|Hostname or IP|8.8.8.8' -Action { param($P) ping.exe -n 4 $P.Target }

Register-Tool -Category 'My Tools' -Name 'Risky thing' -Description '...' -Confirm 'Are you sure?' -Action { ... }

Register-Tool -Category 'My Tools' -Name 'Notepad' -Description 'Open Notepad' -Launch -Action { Start-Process notepad.exe }

Register-Tweak -Category 'My Tweaks' -Name 'Seconds on the clock' -Description '...' -Registry @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSecondsInSystemClock'; Value = 1; Revert = 0 }
)
```

Actions run in the background and can use the helpers in [`core/Helpers.ps1`](core/Helpers.ps1), such as `Invoke-AsUser`, `Set-RegValue` (where `HKCU:\` means every signed-in user), `Invoke-WingetApps`, `Get-ConsoleUser`, `Format-Size` and `New-HtmlReport`.

- Files in this repo's `Tools` folder go to every PC that runs the one-liner.
- Files you add yourself in `C:\ProgramData\ITToolkit\Tools` on a PC are kept when you update.
- To add apps to the Install tab, edit [`data/apps.json`](data/apps.json). It also holds the presets.

## Project layout

```text
ITToolkit.ps1        entry point: options, registries, background runner
install.ps1          one-line installer / updater
version.txt          latest version (used for the "update available" banner)
core/Helpers.ps1     shared helpers, loaded in the GUI and in every background task
core/UI.ps1          the window (owner-drawn cards, sidebar and buttons; -UiTest self-check)
core/Headless.ps1    command-line mode
modules/*.ps1        built-in tools, tweaks and update policies
data/apps.json       Install tab catalog and presets
Tools/*.ps1          your own plugins
```

## Requirements and notes

- Windows 10 or 11, or Windows Server 2016 and later, with Windows PowerShell 5.1 (built in). Run it elevated.
- **Backstage runs as SYSTEM.** The *User Session* tools and per-user tweaks get around this by working with the signed-in user's own session and registry.
- Some tools only work on certain editions or hardware, for example `lusrmgr.msc` on Pro and Enterprise, battery health on laptops, and Office tools with Microsoft 365 / Click-to-Run.
- Icons use Segoe Fluent Icons (Windows 11) or Segoe MDL2 Assets (Windows 10), which ship with Windows. On Server Core-style systems without them, the tiles show letters instead.

## Licence

[MIT](LICENSE). The app catalog and tweak list are based on Chris Titus Tech's [WinUtil](https://github.com/ChrisTitusTech/winutil) (MIT); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Not affiliated with Chris Titus Tech, ConnectWise or Microsoft.
