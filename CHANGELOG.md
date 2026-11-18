# Changelog

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
