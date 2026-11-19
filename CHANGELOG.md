# Changelog

## 2.3.1

- Install tab: presets open from an **Add a preset** button and menu (shows how many apps each adds) instead of a drop-down.
- Sidebar items no longer slide under the scroll bar; tool and tweak cards are a little more compact.
- Health check report: fixed "Argument types do not match", which stopped the HTML report being saved.
- "Remove promoted bloat apps" now shows whether it is applied (the status check errored before).
- Problem devices with no name show their device ID in the health check.
- Task errors now include the line that failed, which makes bug reports easier to act on.

## 2.3.0

- **New look.** The window is redrawn from scratch: every category has its own colour and a Windows Fluent icon, cards have rounded corners and reflow to fill the window, and the sidebar, tabs and buttons have icons. Pills read "Asks first", "Needs input", "Applied", "Recommended" and so on instead of capitals. Dark mode now also darkens the title bar and scroll bars, and a blue bar moves under Output while a task runs.
- Ticking apps or tweaks, favouriting a tool and tweak status updates no longer rebuild the list, so they are instant.
- **Toolkit self-test** (Tools → Toolkit, or `-SelfTest`): checks elevation, PowerShell, .NET, TLS, GitHub, winget, Task Scheduler, run-as-user, Windows Update, Defender, free space and pending reboot, and says what to fix.
- `-TweakStatus` lists which tweaks are applied without changing anything.
- **Report a problem** opens a GitHub bug form that asks for the details needed to fix it.
- **Tests on real Windows:** every push parses all scripts, runs PSScriptAnalyzer, runs read-only tools and reports headless, and draws every part of the window off-screen (`-UiTest`).
- New landing page with a preview of the window.

## 2.2.1

- Tweaks tab: the list no longer redraws several times while tweak status is being checked. It now redraws once, when all results are in.

## 2.2.0

- **Domain & Entra** (checks on the PC itself, no domain controller access needed): join status, the user's Entra sign-in (PRT) state, domain connection test, Group Policy results with an HTML report, Intune sync, Intune diagnostics bundle and Intune app errors.
- **Drivers:** scan for or install Dell / HP / Lenovo updates using each maker's own tool, Windows Update drivers, and a driver backup export.
- **Blue screens:** recent stop codes with what they usually mean, crash dump analysis that shows the driver involved (NirSoft BlueScreenView), and a memory test with its results.
- **Network:** network scan (devices, names, MACs, likely type), Wi-Fi report and saved Wi-Fi networks.
- **Reports:** log bundle zip for escalation, and before / after snapshots that list everything that changed.
- **Saved setups:** export ticked apps and tweaks to a file and import them on another PC, or run `-Setup <file or URL>` headless.
- **Windows features** (WinUtil Config tab): .NET 3.5, Hyper-V, WSL, Sandbox, legacy media, NFS, OpenSSH Server, daily registry backup, F8 recovery menu and pool.ntp.org time. Each can be undone.
- Full system corruption scan, Autologon (Sysinternals) and 11 more Control Panel shortcuts.
- **Releases:** each version bump creates a GitHub release with `ITToolkit.zip`. The installer uses the latest release, and `-Version 2.2.0` installs a specific one. Scripts are signed automatically when a code signing certificate is added as a repository secret.

## 2.1.0

- **Install tab:** added every app from Chris Titus Tech's WinUtil (172 new, 249 in total). Fixed the IDs for KeePassXC (`KeePassXCTeam.KeePassXC`) and GIMP (`GIMP.GIMP.3`).
- **Tweaks tab:** now covers every WinUtil tweak and preference toggle (75 tweaks, up from 33), in new groups: Essential, Browsers, Network, Drivers & vendor apps, Cleanup and Remove apps.
- Expanded the telemetry, location, visual effects, Edge debloat, BSOD and Copilot tweaks to match WinUtil.
- **Set DNS** now has all of WinUtil's providers (Cloudflare malware/family, OpenDNS, AdGuard and AdGuard family).
- Added **O&O ShutUp10++** under Tools → Software.
- Added THIRD_PARTY_NOTICES.md (WinUtil MIT licence).

## 2.0.0

- Rebuilt as a tabbed app: **Tools**, **Install**, **Tweaks** and **Updates**.
- **Install tab:** winget app checklist (75+ apps) with presets, install, upgrade or uninstall selected, upgrade all, check installed, and your own saved preset.
- **Tweaks tab:** about 35 privacy, performance and UI tweaks with live applied / not applied status, a restore point before applying, and undo.
- **Updates tab:** Windows Update policies (security-focused, stay on version, drivers, no restart while signed in) and update actions, including install now.
- **Headless mode:** `-Run`, `-Install`, `-Uninstall`, `-Tweak` / `-Undo`, `-HealthCheck`, `-Inventory`, `-List`, `-Force` and `-Inputs`. The installer passes them through.
- New tool groups: **User Session** (runs as the signed-in user), **Office & Teams**, **Reports** (HTML health check, inventory CSV, ticket notes) and **Software**.
- New tools: Windows 11 readiness, speed test, set DNS, reset hosts file, add network printer by IP, BitLocker recovery key, enable or disable RDP, Microsoft Safety Scanner, sleep and wake report, third-party drivers, re-register Start and Search.
- Favourites (right-click a card) and Recent tools.
- "Update available" banner that checks `version.txt` on GitHub.
- Settings: report title and webhook (Discord, Slack or Teams), with ticket notes sent on close.
- HKCU changes are applied to every signed-in user, so they work as SYSTEM in Backstage.
- Split into `core/`, `modules/` and `data/`.

## 1.0.0

- First release: single-file GUI with about 80 tools, dark / light theme, a `Tools` plugin folder and the `irm | iex` installer.
