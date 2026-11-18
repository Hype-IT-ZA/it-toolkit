# =====================================================================
#  IT Toolkit - main window (WinForms)
#  Dot-sourced by ITToolkit.ps1, which provides $Config, $Settings,
#  $script:Tools / Tweaks / Apps / Presets, $Queue and Start-ToolkitTask.
# =====================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
if (-not ('ITK.Native' -as [type])) {
    Add-Type -Namespace ITK -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
'@
}

# =====================================================================
#  THEME
# =====================================================================
$Themes = @{
    Dark  = @{
        Bg = '#15171c'; Sidebar = '#1b1e24'; Surface = '#1f2229'; Card = '#252932'; CardHover = '#2e3340'
        Border = '#353b47'; Text = '#e7e9ee'; Muted = '#98a1b0'; Accent = '#2563eb'; AccentHover = '#1d4fc4'; Link = '#60a5fa'
        AccentText = '#ffffff'; Console = '#0f1115'; ConsoleText = '#d5d9e0'; Input = '#252932'
        Ok = '#4ade80'; Warn = '#fbbf24'; Err = '#f87171'
    }
    Light = @{
        Bg = '#f3f4f7'; Sidebar = '#ffffff'; Surface = '#ffffff'; Card = '#ffffff'; CardHover = '#eef3ff'
        Border = '#dde1e8'; Text = '#1d2330'; Muted = '#5d6878'; Accent = '#2563eb'; AccentHover = '#1d4fc4'; Link = '#1d4fc4'
        AccentText = '#ffffff'; Console = '#fafbfc'; ConsoleText = '#1d2330'; Input = '#ffffff'
        Ok = '#15803d'; Warn = '#b45309'; Err = '#b91c1c'
    }
}
$script:ThemeName = if ($Themes.ContainsKey([string]$Settings.Theme)) { [string]$Settings.Theme } else { 'Dark' }

function C([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
function TC([string]$key) { C $Themes[$script:ThemeName][$key] }
function Get-Role($c) { if ($c.Tag -is [hashtable]) { $c.Tag.Role } else { [string]$c.Tag } }

$FontUI    = New-Object Drawing.Font('Segoe UI', 9.5)
$FontBold  = New-Object Drawing.Font('Segoe UI Semibold', 10)
$FontH2    = New-Object Drawing.Font('Segoe UI Semibold', 13)
$FontTitle = New-Object Drawing.Font('Segoe UI Semibold', 14)
$FontTab   = New-Object Drawing.Font('Segoe UI Semibold', 10)
$FontSmall = New-Object Drawing.Font('Segoe UI', 8.5)
$FontBadge = New-Object Drawing.Font('Segoe UI Semibold', 7)
$FontMono  = New-Object Drawing.Font('Consolas', 9.5)
$ToolTip   = New-Object Windows.Forms.ToolTip

# =====================================================================
#  STATE
# =====================================================================
$script:Tabs = @('Tools', 'Install', 'Tweaks', 'Updates')
$script:CurrentTab = 'Tools'
$script:CurrentCategory = @{ Tools = 'All tools'; Install = 'All apps'; Tweaks = 'All tweaks'; Updates = 'All' }
$cmp = [StringComparer]::OrdinalIgnoreCase
$script:SelectedApps   = New-Object 'System.Collections.Generic.HashSet[string]' $cmp
$script:InstalledApps  = New-Object 'System.Collections.Generic.HashSet[string]' $cmp
$script:SelectedTweaks = New-Object 'System.Collections.Generic.HashSet[string]' $cmp
$script:TweakStatus    = @{}
$script:InstalledChecked = $false
$script:TweakChecked = $false
$script:Jobs     = New-Object System.Collections.ArrayList
$script:JobIndex = @{}
$script:History  = New-Object System.Collections.Generic.List[object]
$script:LogLines = New-Object System.Collections.Generic.List[object]
$script:Rendering = $false

$RunAs     = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$IsAdmin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$OsInfo    = Get-CimInstance Win32_OperatingSystem
$OsVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
$ConsoleUser = Get-ConsoleUser; if (-not $ConsoleUser) { $ConsoleUser = 'nobody' }
$MainIP = ''
try { $MainIP = (Get-NetIPConfiguration -ErrorAction Stop | Where-Object IPv4DefaultGateway | Select-Object -First 1).IPv4Address.IPAddress | Select-Object -First 1 } catch {}
if (-not $MainIP) { $MainIP = 'n/a' }

# =====================================================================
#  CONTROL HELPERS
# =====================================================================
function New-Label([string]$Text, [int]$X, [int]$Y, $Font, $Role) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $Text; $l.Location = New-Object Drawing.Point($X, $Y); $l.AutoSize = $true; $l.Font = $Font; $l.Tag = $Role
    $l.BackColor = [Drawing.Color]::Transparent; $l.UseMnemonic = $false
    $l
}
function New-Button([string]$Text, [int]$W = 0, $Role = 'btn') {
    $b = New-Object Windows.Forms.Button
    if ($W -le 0) { $W = [Windows.Forms.TextRenderer]::MeasureText($Text, $FontUI).Width + 26 }
    $b.Text = $Text; $b.Size = New-Object Drawing.Size($W, 30); $b.FlatStyle = 'Flat'; $b.Tag = $Role; $b.UseMnemonic = $false
    $b.Cursor = [Windows.Forms.Cursors]::Hand; $b.Margin = New-Object Windows.Forms.Padding(0, 4, 8, 4); $b.Font = $FontUI
    $b
}
function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath; $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); $p
}
function Set-CueBanner($tb, [string]$text) { try { [void][ITK.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, $text) } catch {} }

function Set-CtlTheme($c) {
    switch (Get-Role $c) {
        'bg'      { $c.BackColor = TC 'Bg'; $c.ForeColor = TC 'Text' }
        'header'  { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text' }
        'surface' { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text' }
        'sidebar' { $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Text' }
        'border'  { $c.BackColor = TC 'Border' }
        'text'    { $c.ForeColor = TC 'Text' }
        'muted'   { $c.ForeColor = TC 'Muted' }
        'check'   { $c.ForeColor = TC 'Text'; $c.BackColor = [Drawing.Color]::Transparent }
        'badge-confirm' { $c.ForeColor = TC 'Warn' }
        'badge-launch'  { $c.ForeColor = TC 'Link' }
        'badge-input'   { $c.ForeColor = TC 'Muted' }
        'badge-ok'      { $c.ForeColor = TC 'Ok' }
        'badge-muted'   { $c.ForeColor = TC 'Muted' }
        'badge-rec'     { $c.ForeColor = TC 'Link' }
        'card'    { $c.BackColor = TC 'Card'; $c.Invalidate() }
        'console' { $c.BackColor = TC 'Console'; $c.ForeColor = TC 'ConsoleText' }
        'input'   { $c.BackColor = TC 'Input'; $c.ForeColor = TC 'Text' }
        'btn'     { $c.BackColor = TC 'Card'; $c.ForeColor = TC 'Text'; $c.FlatAppearance.BorderColor = TC 'Border'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        'danger'  { $c.BackColor = TC 'Card'; $c.ForeColor = TC 'Err'; $c.FlatAppearance.BorderColor = TC 'Border'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        'primary' { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.BorderColor = TC 'Accent'; $c.FlatAppearance.MouseOverBackColor = TC 'AccentHover' }
        'banner'  { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText' }
        'bannerbtn' { $c.BackColor = TC 'AccentHover'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.BorderColor = TC 'AccentText'; $c.FlatAppearance.MouseOverBackColor = TC 'Accent' }
        'nav' {
            $c.FlatAppearance.BorderSize = 0
            if ($c.Tag.Category -eq $script:CurrentCategory[$script:CurrentTab]) { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.MouseOverBackColor = TC 'Accent' }
            else { $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Text'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        }
        'tab' {
            $c.FlatAppearance.BorderSize = 0
            if ($c.Tag.Tab -eq $script:CurrentTab) { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.MouseOverBackColor = TC 'Accent' }
            else { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        }
        'status'  { $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Muted' }
        'toggle'  { $c.BackColor = TC 'Surface'; $c.Invalidate() }
    }
}
function Update-Theme($root) { Set-CtlTheme $root; foreach ($c in $root.Controls) { Update-Theme $c } }

# =====================================================================
#  CONSOLE / LOG
# =====================================================================
function Get-LevelColor($lvl) {
    switch ($lvl) { 'OK' { TC 'Ok' } 'WARN' { TC 'Warn' } 'ERROR' { TC 'Err' } 'HEAD' { TC 'Link' } default { TC 'ConsoleText' } }
}
function Write-RtbLine($entry) {
    $lines = ($entry.Text -replace "`r", '') -split "`n"
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -eq 0) { [void]$sb.Append('[' + $entry.Time.ToString('HH:mm:ss') + '] ') } else { [void]$sb.Append('           ') }
        [void]$sb.Append($lines[$i]).Append("`n")
    }
    $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
    $rtb.SelectionColor = Get-LevelColor $entry.Level
    $rtb.AppendText($sb.ToString())
}
function Add-LogLine([string]$Level, [string]$Text, $Time = (Get-Date)) {
    $e = [pscustomobject]@{ Time = $Time; Level = $Level; Text = $Text }
    $script:LogLines.Add($e)
    if ($script:LogLines.Count -gt 10000) { $script:LogLines.RemoveRange(0, 2000) }
    Write-RtbLine $e
    $rtb.ScrollToCaret()
}
function Update-Console { $rtb.Clear(); foreach ($e in $script:LogLines) { Write-RtbLine $e }; $rtb.ScrollToCaret() }
function Save-Log([string]$Prefix = 'toolkit') {
    $file = Join-Path $Config.LogDir ('{0}_{1}_{2:yyyyMMdd_HHmmss}.txt' -f $Prefix, $env:COMPUTERNAME, (Get-Date))
    $script:LogLines | ForEach-Object { '[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}' -f $_.Time, $_.Level, $_.Text } | Set-Content -Path $file -Encoding UTF8
    $file
}
# Launch tools run on this thread and may call Log
function Log { param([string]$Message, [string]$Level = 'INFO') Add-LogLine $Level $Message }

# =====================================================================
#  DIALOGS
# =====================================================================
function New-Dialog([string]$Title, [int]$W, [int]$H) {
    $d = New-Object Windows.Forms.Form
    $d.Text = $Title; $d.Size = New-Object Drawing.Size($W, $H); $d.FormBorderStyle = 'FixedDialog'
    $d.StartPosition = 'CenterParent'; $d.MaximizeBox = $false; $d.MinimizeBox = $false; $d.ShowInTaskbar = $false
    $d.Font = $FontUI; $d.Tag = 'bg'
    $d
}
function Show-InputDialog([string]$Title, [string]$Prompt, [string]$Default) {
    $dlg = New-Dialog $Title 460 182
    $dlg.Controls.Add((New-Label $Prompt 18 16 $FontUI 'text'))
    $tb = New-Object Windows.Forms.TextBox
    $tb.Location = New-Object Drawing.Point(20, 44); $tb.Width = 404; $tb.Text = $Default; $tb.BorderStyle = 'FixedSingle'; $tb.Tag = 'input'
    $dlg.Controls.Add($tb)
    $ok = New-Button 'Run' 84 'primary'; $ok.Location = New-Object Drawing.Point(246, 90); $ok.DialogResult = 'OK'
    $cancel = New-Button 'Cancel' 84 'btn'; $cancel.Location = New-Object Drawing.Point(340, 90); $cancel.DialogResult = 'Cancel'
    $dlg.Controls.AddRange(@($ok, $cancel)); $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    Update-Theme $dlg
    $result = $dlg.ShowDialog($form); $value = $tb.Text.Trim(); $dlg.Dispose()
    if ($result -eq 'OK') { return $value } else { return $null }
}
function Show-TextDialog([string]$Title, [string]$Text) {
    $dlg = New-Dialog $Title 680 520
    $tb = New-Object Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars = 'Vertical'; $tb.Font = $FontMono; $tb.Text = $Text
    $tb.Location = New-Object Drawing.Point(16, 16); $tb.Size = New-Object Drawing.Size(632, 400); $tb.BorderStyle = 'FixedSingle'; $tb.Tag = 'input'
    $copy = New-Button 'Copy to clipboard' 0 'primary'; $copy.Location = New-Object Drawing.Point(16, 430)
    $close = New-Button 'Close' 84 'btn'; $close.Location = New-Object Drawing.Point(564, 430); $close.DialogResult = 'Cancel'
    $copy.Add_Click({ [Windows.Forms.Clipboard]::SetText($tb.Text); $this.Text = 'Copied' })
    $dlg.Controls.AddRange(@($tb, $copy, $close)); $dlg.CancelButton = $close
    Update-Theme $dlg
    [void]$dlg.ShowDialog($form); $dlg.Dispose()
}
function Show-SettingsDialog {
    $dlg = New-Dialog 'Settings' 520 340
    $dlg.Controls.Add((New-Label 'Report title (optional - your company or client name on reports)' 18 16 $FontUI 'text'))
    $tbTitle = New-Object Windows.Forms.TextBox; $tbTitle.Location = New-Object Drawing.Point(20, 40); $tbTitle.Width = 464; $tbTitle.Text = [string]$Settings.ReportTitle; $tbTitle.BorderStyle = 'FixedSingle'; $tbTitle.Tag = 'input'
    $dlg.Controls.Add((New-Label 'Webhook URL (optional - Discord, Slack or Teams incoming webhook)' 18 78 $FontUI 'text'))
    $tbHook = New-Object Windows.Forms.TextBox; $tbHook.Location = New-Object Drawing.Point(20, 102); $tbHook.Width = 464; $tbHook.Text = [string]$Settings.WebhookUrl; $tbHook.BorderStyle = 'FixedSingle'; $tbHook.Tag = 'input'
    $cbSend = New-Object Windows.Forms.CheckBox; $cbSend.Text = 'Send ticket notes to the webhook when I close the toolkit'; $cbSend.Location = New-Object Drawing.Point(20, 136); $cbSend.AutoSize = $true; $cbSend.Checked = [bool]$Settings.SendNotesOnClose; $cbSend.Tag = 'check'
    $cbUpd = New-Object Windows.Forms.CheckBox; $cbUpd.Text = 'Check GitHub for a newer version when the toolkit starts'; $cbUpd.Location = New-Object Drawing.Point(20, 164); $cbUpd.AutoSize = $true; $cbUpd.Checked = [bool]$Settings.CheckUpdates; $cbUpd.Tag = 'check'
    $test = New-Button 'Send test message' 0 'btn'; $test.Location = New-Object Drawing.Point(20, 200)
    $test.Add_Click({ try { Send-Webhook $tbHook.Text "IT Toolkit test message from $env:COMPUTERNAME"; $this.Text = 'Sent' } catch { [void][Windows.Forms.MessageBox]::Show($dlg, $_.Exception.Message, 'Webhook failed') } })
    $dlg.Controls.Add((New-Label "Settings file: $ITK_Settings" 18 240 $FontSmall 'muted'))
    $ok = New-Button 'Save' 84 'primary'; $ok.Location = New-Object Drawing.Point(306, 260); $ok.DialogResult = 'OK'
    $cancel = New-Button 'Cancel' 84 'btn'; $cancel.Location = New-Object Drawing.Point(400, 260); $cancel.DialogResult = 'Cancel'
    $dlg.Controls.AddRange(@($tbTitle, $tbHook, $cbSend, $cbUpd, $test, $ok, $cancel)); $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    Update-Theme $dlg
    if ($dlg.ShowDialog($form) -eq 'OK') {
        $Settings.ReportTitle = $tbTitle.Text.Trim(); $Settings.WebhookUrl = $tbHook.Text.Trim()
        $Settings.SendNotesOnClose = $cbSend.Checked; $Settings.CheckUpdates = $cbUpd.Checked
        Save-ToolkitSettings $Settings
        Add-LogLine 'OK' 'Settings saved.'
    }
    $dlg.Dispose()
}

# =====================================================================
#  TICKET NOTES / REPORTS (also used by Launch tools in modules\90-Reports.ps1)
# =====================================================================
function Get-TicketNotes {
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine("Remote support notes - $env:COMPUTERNAME")
    [void]$sb.AppendLine(('Date:   {0:yyyy-MM-dd HH:mm}' -f (Get-Date)))
    [void]$sb.AppendLine("System: $($OsInfo.Caption) $OsVersion")
    [void]$sb.AppendLine("User:   $ConsoleUser")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Work done:')
    $done = @($script:History | Where-Object { $_.Status -ne 'Running' })
    if (-not $done) { [void]$sb.AppendLine('- (nothing run yet)') }
    foreach ($j in $done) {
        $state = if ($j.Stopped) { 'stopped' } elseif ($j.Errors.Count) { 'finished with errors' } else { 'done' }
        $detail = if ($j.Errors.Count) { $j.Errors[0] } elseif ($j.Warnings.Count) { $j.Warnings[0] } else { $j.LastOk }
        $line = '- {0:HH:mm} {1}: {2}' -f $j.Start, $j.Name, $state
        if ($detail -and $detail -notlike 'Done:*') { $line += ". $(($detail -split "`n")[0].Trim())" }
        [void]$sb.AppendLine($line)
    }
    [void]$sb.AppendLine('')
    [void]$sb.Append("Generated by IT Toolkit $($Config.Version)")
    $sb.ToString()
}
function Show-TicketNotes { Show-TextDialog 'Ticket notes' (Get-TicketNotes) }
function Open-LatestReport {
    $f = Get-ChildItem $Config.ReportDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $f) { Add-LogLine 'WARN' 'No reports saved yet. Run "Health check report" first.'; return }
    foreach ($app in 'msedge.exe', 'chrome.exe', 'firefox.exe') {
        try { Start-Process $app -ArgumentList "`"$($f.FullName)`"" -ErrorAction Stop; Add-LogLine 'OK' "Opened $($f.Name)"; return } catch {}
    }
    try { Start-Process notepad.exe -ArgumentList "`"$($f.FullName)`""; Add-LogLine 'OK' "Opened $($f.Name) in Notepad" } catch { Add-LogLine 'ERROR' "Could not open $($f.FullName)" }
}

# =====================================================================
#  RUNNING TASKS
# =====================================================================
function Start-UiTask([string]$Name, [string]$Code, [hashtable]$Params = @{}, [switch]$Quiet) {
    if (-not $Quiet) { Add-LogLine 'HEAD' ">> $Name" }
    $job = Start-ToolkitTask $Name $Code $Params
    $job.Quiet = [bool]$Quiet
    [void]$script:Jobs.Add($job)
    $script:JobIndex[$job.Id] = $job
    if (-not $Quiet) { $script:History.Add($job) }
    Update-Status
}

function Add-Recent([string]$Name) {
    $Settings.Recent = @(@($Name) + @($Settings.Recent | Where-Object { $_ -ne $Name }) | Select-Object -First 12)
    Save-ToolkitSettings $Settings
}

function Invoke-Tool($tool) {
    if ($tool.Confirm) {
        $r = [Windows.Forms.MessageBox]::Show($form, $tool.Confirm, $tool.Name, [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -ne 'Yes') { Add-LogLine 'WARN' "Cancelled: $($tool.Name)"; return }
    }
    $params = @{}
    foreach ($spec in $tool.Inputs) {
        $parts = $spec -split '\|', 3
        $prompt = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
        $default = if ($parts.Count -gt 2) { $parts[2] } else { '' }
        $val = Show-InputDialog $tool.Name $prompt $default
        if ($null -eq $val) { Add-LogLine 'WARN' "Cancelled: $($tool.Name)"; return }
        $params[$parts[0]] = $val
    }
    if ($tool.Tab -eq 'Tools') { Add-Recent $tool.Name }
    if ($tool.Launch) {
        try { & $tool.Action $params } catch { Add-LogLine 'ERROR' "$($tool.Name): $($_.Exception.Message)" }
        return
    }
    Start-UiTask -Name $tool.Name -Code $tool.Code -Params $params
}

function Get-TweakPayload([string[]]$Names) {
    @($script:Tweaks | Where-Object { $Names -contains $_.Name })
}
$script:TweakRunner = {
    param($P)
    if ($P.Mode -eq 'Apply' -and $P.RestorePoint) { [void](New-ToolkitRestorePoint 'IT Toolkit - before tweaks') }
    foreach ($t in $P.Tweaks) {
        if ($P.Mode -ne 'Test') {
            try { Invoke-Tweak -Tweak $t -Mode $P.Mode; Log ('{0}: {1}' -f $(if ($P.Mode -eq 'Apply') { 'Applied' } else { 'Undone' }), $t.Name) 'OK' }
            catch { Log "$($t.Name): $($_.Exception.Message)" 'ERROR' }
        }
        $state = $null
        try { $state = Invoke-Tweak -Tweak $t -Mode Test } catch {}
        Send-ToolkitEvent 'TweakStatus' @{ Name = $t.Name; Applied = $state }
    }
    if ($P.Mode -ne 'Test') { Log 'Some changes show after Explorer restarts or the user signs out and in again (Tools > User Session > Restart Explorer).' }
}.ToString()

function Invoke-Tweaks([ValidateSet('Apply', 'Revert', 'Test')][string]$Mode, [string[]]$Names, [switch]$Quiet) {
    $list = Get-TweakPayload $Names
    if (-not $list) { Add-LogLine 'WARN' 'Tick at least one tweak first.'; return }
    if ($Mode -eq 'Revert') {
        $noUndo = @($list | Where-Object NoUndo)
        if ($noUndo) { Add-LogLine 'WARN' ("Cannot be undone automatically: " + ($noUndo.Name -join ', ')); $list = @($list | Where-Object { -not $_.NoUndo }) }
        if (-not $list) { return }
    }
    $restore = $false
    if ($Mode -eq 'Apply') {
        $warnings = @($list | Where-Object Warning)
        $msg = "Apply $($list.Count) tweak(s)?`n`nA restore point is created first.`nEvery tweak except those marked CAUTION can be undone from this tab."
        if ($warnings) { $msg += "`n`nCAUTION:`n" + (($warnings | ForEach-Object { "- $($_.Name): $($_.Warning)" }) -join "`n") }
        $r = [Windows.Forms.MessageBox]::Show($form, $msg, 'Apply tweaks', [Windows.Forms.MessageBoxButtons]::YesNo, $(if ($warnings) { [Windows.Forms.MessageBoxIcon]::Warning } else { [Windows.Forms.MessageBoxIcon]::Question }))
        if ($r -ne 'Yes') { Add-LogLine 'WARN' 'Cancelled: apply tweaks'; return }
        $restore = $true
    }
    $label = switch ($Mode) { 'Apply' { "Apply $($list.Count) tweak(s)" } 'Revert' { "Undo $($list.Count) tweak(s)" } 'Test' { 'Check tweak status' } }
    Start-UiTask -Name $label -Code $script:TweakRunner -Params @{ Tweaks = $list; Mode = $Mode; RestorePoint = $restore } -Quiet:$Quiet
}

function Invoke-AppAction([ValidateSet('Install', 'Uninstall', 'Check', 'UpgradeAll')][string]$Action, [switch]$Quiet) {
    switch ($Action) {
        'Check' {
            $checkCode = {
                $wg = Get-WingetPath
                if (-not $wg) { Log 'winget was not found on this PC. Use Tools > Software > "Install / repair winget".' 'WARN'; Send-ToolkitEvent 'AppsInstalled' @(); return }
                Log 'Checking which apps are installed (winget)...'
                $ids = @(Get-WingetInstalledIds)
                Send-ToolkitEvent 'AppsInstalled' $ids
                Log "$($ids.Count) winget-managed apps found." 'OK'
            }.ToString()
            Start-UiTask -Name 'Check installed apps' -Code $checkCode -Quiet:$Quiet
        }
        'UpgradeAll' {
            $tool = $script:Tools | Where-Object Name -eq 'Upgrade all apps' | Select-Object -First 1
            if ($tool) { Invoke-Tool $tool }
        }
        default {
            $ids = @($script:SelectedApps)
            if (-not $ids) { Add-LogLine 'WARN' 'Tick at least one app first.'; return }
            $verb = if ($Action -eq 'Install') { 'Install / upgrade' } else { 'Uninstall' }
            $r = [Windows.Forms.MessageBox]::Show($form, "$verb $($ids.Count) app(s)?`n`n" + ($ids -join "`n"), $verb, [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
            if ($r -ne 'Yes') { return }
            $code = {
                param($P)
                Invoke-WingetApps -Ids $P.Ids -Action $P.Action
                Send-ToolkitEvent 'AppsInstalled' @(Get-WingetInstalledIds)
            }.ToString()
            Start-UiTask -Name "$verb $($ids.Count) app(s)" -Code $code -Params @{ Ids = $ids; Action = $Action }
        }
    }
}

# =====================================================================
#  BUILD THE WINDOW
# =====================================================================
$form = New-Object Windows.Forms.Form
$form.Text = "$($Config.AppName) $($Config.Version) - $env:COMPUTERNAME"
$form.Size = New-Object Drawing.Size(1280, 840); $form.MinimumSize = New-Object Drawing.Size(1100, 680)
$form.StartPosition = 'CenterScreen'; $form.Font = $FontUI; $form.Tag = 'bg'; $form.KeyPreview = $true

# ---- Header ----
$header = New-Object Windows.Forms.Panel; $header.Dock = 'Top'; $header.Height = 64; $header.Tag = 'header'
$header.Controls.Add((New-Label $Config.AppName 18 9 $FontTitle 'text'))
$subText = if ($RunAs -match 'SYSTEM$') { "$env:COMPUTERNAME  -  SYSTEM (Backstage)" } else { "$env:COMPUTERNAME  -  $RunAs" }
if (-not $IsAdmin) { $subText += '  -  NOT ELEVATED' }
$header.Controls.Add((New-Label $subText 20 38 $FontSmall 'muted'))

$tabFlow = New-Object Windows.Forms.FlowLayoutPanel
$tabFlow.Location = New-Object Drawing.Point(300, 14); $tabFlow.AutoSize = $true; $tabFlow.WrapContents = $false; $tabFlow.Tag = 'header'
foreach ($t in $script:Tabs) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $t; $b.Font = $FontTab; $b.Size = New-Object Drawing.Size(([Windows.Forms.TextRenderer]::MeasureText($t, $FontTab).Width + 36), 36)
    $b.FlatStyle = 'Flat'; $b.Margin = New-Object Windows.Forms.Padding(0, 0, 6, 0); $b.Cursor = [Windows.Forms.Cursors]::Hand
    $b.Tag = @{ Role = 'tab'; Tab = $t }
    $b.Add_Click({ Select-Tab $this.Tag.Tab })
    $tabFlow.Controls.Add($b)
}
$header.Controls.Add($tabFlow)

$rightArea = New-Object Windows.Forms.Panel; $rightArea.Dock = 'Right'; $rightArea.Width = 250; $rightArea.Tag = 'header'
$btnSettings = New-Button 'Settings' 84 'btn'; $btnSettings.Location = New-Object Drawing.Point(10, 17)
$lblTheme = New-Label 'Dark mode' 110 23 $FontUI 'muted'; $lblTheme.Cursor = [Windows.Forms.Cursors]::Hand
$toggle = New-Object Windows.Forms.Panel
$toggle.Size = New-Object Drawing.Size(46, 24); $toggle.Location = New-Object Drawing.Point(184, 21); $toggle.Cursor = [Windows.Forms.Cursors]::Hand; $toggle.Tag = 'toggle'
$toggle.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $on = $script:ThemeName -eq 'Dark'
    $trackColor = if ($on) { TC 'Accent' } else { C '#8a93a2' }
    $path = New-RoundRect 0 0 ($s.Width - 1) ($s.Height - 1) (($s.Height - 1) / 2)
    $brush = New-Object Drawing.SolidBrush($trackColor); $g.FillPath($brush, $path); $brush.Dispose(); $path.Dispose()
    $d = $s.Height - 6; $x = if ($on) { $s.Width - $d - 4 } else { 3 }
    $g.FillEllipse([Drawing.Brushes]::White, $x, 3, $d, $d)
})
$toggleClick = { Set-Theme $(if ($script:ThemeName -eq 'Dark') { 'Light' } else { 'Dark' }) }
$toggle.Add_Click($toggleClick); $lblTheme.Add_Click($toggleClick)
$ToolTip.SetToolTip($toggle, 'Switch between dark and light theme')
$btnSettings.Add_Click({ Show-SettingsDialog })
$rightArea.Controls.AddRange(@($btnSettings, $lblTheme, $toggle))
$header.Controls.Add($rightArea)
$headerLine = New-Object Windows.Forms.Panel; $headerLine.Dock = 'Bottom'; $headerLine.Height = 1; $headerLine.Tag = 'border'
$header.Controls.Add($headerLine)

# ---- Update banner (hidden until a newer version is found) ----
$banner = New-Object Windows.Forms.Panel; $banner.Dock = 'Top'; $banner.Height = 40; $banner.Tag = 'banner'; $banner.Visible = $false
$banner.Padding = New-Object Windows.Forms.Padding(18, 5, 12, 5)
$lblBanner = New-Object Windows.Forms.Label; $lblBanner.Dock = 'Fill'; $lblBanner.TextAlign = 'MiddleLeft'; $lblBanner.Tag = 'banner'; $lblBanner.Font = $FontBold
$btnBannerLater = New-Button 'Later' 70 'bannerbtn'; $btnBannerLater.Dock = 'Right'
$btnBannerUpdate = New-Button 'Update now' 100 'bannerbtn'; $btnBannerUpdate.Dock = 'Right'
$bannerGap = New-Object Windows.Forms.Panel; $bannerGap.Dock = 'Right'; $bannerGap.Width = 8; $bannerGap.Tag = 'banner'
$banner.Controls.AddRange(@($btnBannerLater, $bannerGap, $btnBannerUpdate, $lblBanner)); $lblBanner.BringToFront()
$btnBannerLater.Add_Click({ $banner.Visible = $false })
$btnBannerUpdate.Add_Click({
    $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm '$($Config.InstallUrl)' | iex"
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd
    $form.Close()
})

# ---- Sidebar ----
$sidebar = New-Object Windows.Forms.Panel; $sidebar.Dock = 'Left'; $sidebar.Width = 220; $sidebar.Tag = 'sidebar'
$sidebar.Padding = New-Object Windows.Forms.Padding(12, 14, 12, 12)
$navFlow = New-Object Windows.Forms.FlowLayoutPanel; $navFlow.Dock = 'Fill'; $navFlow.FlowDirection = 'TopDown'
$navFlow.WrapContents = $false; $navFlow.AutoScroll = $true; $navFlow.Tag = 'sidebar'
$sideLine = New-Object Windows.Forms.Panel; $sideLine.Dock = 'Right'; $sideLine.Width = 1; $sideLine.Tag = 'border'
$sidebar.Controls.Add($navFlow); $sidebar.Controls.Add($sideLine); $navFlow.BringToFront()

# ---- Main area ----
$main = New-Object Windows.Forms.Panel; $main.Dock = 'Fill'; $main.Tag = 'bg'; $main.Padding = New-Object Windows.Forms.Padding(18, 12, 18, 14)

$topBar = New-Object Windows.Forms.Panel; $topBar.Dock = 'Top'; $topBar.Height = 54; $topBar.Tag = 'bg'
$lblCat = New-Label 'All tools' 0 2 $FontH2 'text'
$lblCount = New-Label '' 2 30 $FontSmall 'muted'
$searchWrap = New-Object Windows.Forms.Panel; $searchWrap.Dock = 'Right'; $searchWrap.Width = 300; $searchWrap.Tag = 'bg'
$txtSearch = New-Object Windows.Forms.TextBox
$txtSearch.Location = New-Object Drawing.Point(0, 12); $txtSearch.Width = 300; $txtSearch.BorderStyle = 'FixedSingle'; $txtSearch.Tag = 'input'
$txtSearch.Font = New-Object Drawing.Font('Segoe UI', 10.5)
$searchWrap.Controls.Add($txtSearch)
$topBar.Controls.AddRange(@($lblCat, $lblCount, $searchWrap))

$actionBar = New-Object Windows.Forms.FlowLayoutPanel
$actionBar.Dock = 'Top'; $actionBar.AutoSize = $true; $actionBar.AutoSizeMode = 'GrowAndShrink'; $actionBar.Tag = 'bg'
$actionBar.Padding = New-Object Windows.Forms.Padding(0, 0, 0, 8); $actionBar.Visible = $false

$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'; $split.Orientation = 'Horizontal'; $split.SplitterWidth = 8; $split.Tag = 'bg'
$split.Panel1.Tag = 'bg'; $split.Panel2.Tag = 'bg'

$flow = New-Object Windows.Forms.FlowLayoutPanel; $flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.Tag = 'bg'
$split.Panel1.Controls.Add($flow)

# Console
$conBorder = New-Object Windows.Forms.Panel; $conBorder.Dock = 'Fill'; $conBorder.Tag = 'border'; $conBorder.Padding = New-Object Windows.Forms.Padding(1)
$conInner = New-Object Windows.Forms.Panel; $conInner.Dock = 'Fill'; $conInner.Tag = 'surface'
$conBar = New-Object Windows.Forms.Panel; $conBar.Dock = 'Top'; $conBar.Height = 40; $conBar.Tag = 'surface'
$conBar.Controls.Add((New-Label 'Output' 12 11 $FontBold 'text'))
$conButtons = New-Object Windows.Forms.FlowLayoutPanel; $conButtons.Dock = 'Right'; $conButtons.Width = 480; $conButtons.FlowDirection = 'RightToLeft'; $conButtons.Tag = 'surface'
$btnStop  = New-Button 'Stop' 64 'danger'
$btnClear = New-Button 'Clear' 64
$btnSave  = New-Button 'Save log' 80
$btnCopy  = New-Button 'Copy' 64
$btnNotes = New-Button 'Ticket notes' 104
$conButtons.Controls.AddRange(@($btnStop, $btnClear, $btnSave, $btnCopy, $btnNotes))
$conBar.Controls.Add($conButtons)

$rtb = New-Object Windows.Forms.RichTextBox
$rtb.Dock = 'Fill'; $rtb.ReadOnly = $true; $rtb.BorderStyle = 'None'; $rtb.Font = $FontMono; $rtb.WordWrap = $false
$rtb.DetectUrls = $false; $rtb.Tag = 'console'

$cmdBar = New-Object Windows.Forms.Panel; $cmdBar.Dock = 'Bottom'; $cmdBar.Height = 42; $cmdBar.Tag = 'surface'
$cmdBar.Padding = New-Object Windows.Forms.Padding(10, 6, 10, 6)
$lblPrompt = New-Object Windows.Forms.Label; $lblPrompt.Text = 'PS>'; $lblPrompt.Dock = 'Left'; $lblPrompt.Width = 36; $lblPrompt.Font = $FontMono
$lblPrompt.TextAlign = 'MiddleLeft'; $lblPrompt.Tag = 'muted'
$txtCmd = New-Object Windows.Forms.TextBox; $txtCmd.Dock = 'Fill'; $txtCmd.Font = $FontMono; $txtCmd.BorderStyle = 'FixedSingle'; $txtCmd.Tag = 'input'
$btnRun = New-Button 'Run' 70 'primary'; $btnRun.Dock = 'Right'; $btnRun.Margin = New-Object Windows.Forms.Padding(0)
$cmdBar.Controls.AddRange(@($lblPrompt, $btnRun, $txtCmd)); $txtCmd.BringToFront()

$conInner.Controls.AddRange(@($conBar, $cmdBar, $rtb)); $rtb.BringToFront()
$conBorder.Controls.Add($conInner)
$split.Panel2.Controls.Add($conBorder)

$main.Controls.AddRange(@($actionBar, $topBar, $split)); $split.BringToFront()

# ---- Status bar ----
$status = New-Object Windows.Forms.Panel; $status.Dock = 'Bottom'; $status.Height = 26; $status.Tag = 'status'
$lblStatus = New-Object Windows.Forms.Label; $lblStatus.Dock = 'Fill'; $lblStatus.TextAlign = 'MiddleLeft'; $lblStatus.Font = $FontSmall; $lblStatus.Tag = 'status'
$lblStatus.Padding = New-Object Windows.Forms.Padding(10, 0, 0, 0); $lblStatus.UseMnemonic = $false
$statusLine = New-Object Windows.Forms.Panel; $statusLine.Dock = 'Top'; $statusLine.Height = 1; $statusLine.Tag = 'border'
$status.Controls.Add($lblStatus); $status.Controls.Add($statusLine); $lblStatus.BringToFront()

$form.Controls.AddRange(@($main, $sidebar, $banner, $header, $status)); $main.BringToFront()

# =====================================================================
#  VIEWS
# =====================================================================
function Update-Status {
    $up = (Get-Date) - $OsInfo.LastBootUpTime
    $running = @($script:Jobs | Where-Object { -not $_.Quiet }).Count
    $lblStatus.Text = '{0}   |   {1} {2}   |   IP {3}   |   Signed in: {4}   |   Uptime {5}d {6}h   |   Running: {7}' -f `
        $env:COMPUTERNAME, $OsInfo.Caption, $OsVersion, $MainIP, $ConsoleUser, $up.Days, $up.Hours, $running
}

function Set-Theme([string]$Name) {
    $script:ThemeName = $Name
    $form.SuspendLayout(); Update-Theme $form; $form.ResumeLayout()
    Update-Console
    $Settings.Theme = $Name; Save-ToolkitSettings $Settings
}

# ---- Tool cards ----
$script:CardEnter = {
    $c = if ((Get-Role $this) -eq 'card') { $this } else { $this.Parent }
    $c.BackColor = TC 'CardHover'
}
$script:CardLeave = {
    $c = if ((Get-Role $this) -eq 'card') { $this } else { $this.Parent }
    if (-not $c.ClientRectangle.Contains($c.PointToClient([Windows.Forms.Cursor]::Position))) { $c.BackColor = TC 'Card' }
}
$script:CardClick = { param($s, $e) if ($e.Button -eq 'Left') { Invoke-Tool $this.Tag.Tool } }
$cardPaint = { param($s, $e) $pen = New-Object Drawing.Pen((TC 'Border')); $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1); $pen.Dispose() }

$cardMenu = New-Object Windows.Forms.ContextMenuStrip
$menuFav = $cardMenu.Items.Add('Add to favourites')
$cardMenu.Add_Opening({
    $tool = $cardMenu.SourceControl.Tag.Tool
    $menuFav.Text = if ($Settings.Favorites -contains $tool.Name) { 'Remove from favourites' } else { 'Add to favourites' }
    $cardMenu.BackColor = TC 'Surface'; $cardMenu.ForeColor = TC 'Text'
})
$menuFav.Add_Click({
    $tool = $cardMenu.SourceControl.Tag.Tool
    if ($Settings.Favorites -contains $tool.Name) { $Settings.Favorites = @($Settings.Favorites | Where-Object { $_ -ne $tool.Name }) }
    else { $Settings.Favorites = @($Settings.Favorites) + $tool.Name }
    Save-ToolkitSettings $Settings
    Build-Nav
    if ($script:CurrentCategory[$script:CurrentTab] -eq 'Favourites') { Show-Content -KeepScroll }
})

function New-ToolCard($tool) {
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size(262, 78); $card.Margin = New-Object Windows.Forms.Padding(0, 0, 10, 10)
    $card.Cursor = [Windows.Forms.Cursors]::Hand; $card.Tag = @{ Role = 'card'; Tool = $tool }
    $card.Add_Paint($cardPaint)
    $title = New-Object Windows.Forms.Label
    $title.Text = $tool.Name; $title.Font = $FontBold; $title.Location = New-Object Drawing.Point(12, 10); $title.Size = New-Object Drawing.Size(178, 20)
    $title.AutoEllipsis = $true; $title.UseMnemonic = $false; $title.BackColor = [Drawing.Color]::Transparent; $title.Tag = @{ Role = 'text'; Tool = $tool }
    $desc = New-Object Windows.Forms.Label
    $desc.Text = $tool.Description; $desc.Font = $FontSmall; $desc.Location = New-Object Drawing.Point(12, 32); $desc.Size = New-Object Drawing.Size(240, 38)
    $desc.AutoEllipsis = $true; $desc.UseMnemonic = $false; $desc.BackColor = [Drawing.Color]::Transparent; $desc.Tag = @{ Role = 'muted'; Tool = $tool }
    $parts = @($title, $desc)
    $kind = if ($tool.Launch) { 'launch' } elseif ($tool.Confirm) { 'confirm' } elseif ($tool.Inputs.Count) { 'input' } else { '' }
    $fav = $Settings.Favorites -contains $tool.Name
    if ($kind -or $fav) {
        $badge = New-Object Windows.Forms.Label
        $badge.Text = (@($(if ($fav) { 'FAV' }), $kind.ToUpper()) | Where-Object { $_ }) -join ' / '
        $badge.Font = $FontBadge; $badge.Location = New-Object Drawing.Point(180, 12); $badge.Size = New-Object Drawing.Size(72, 16)
        $badge.TextAlign = 'MiddleRight'; $badge.BackColor = [Drawing.Color]::Transparent
        $badge.Tag = @{ Role = $(if ($kind) { "badge-$kind" } else { 'badge-rec' }); Tool = $tool }
        $parts += $badge
    }
    $card.Controls.AddRange($parts)
    foreach ($ctl in @($card) + $parts) {
        $ctl.Add_MouseUp($script:CardClick); $ctl.Add_MouseEnter($script:CardEnter); $ctl.Add_MouseLeave($script:CardLeave)
        $ctl.ContextMenuStrip = $cardMenu
        $ToolTip.SetToolTip($ctl, "$($tool.Category): $($tool.Description)`nRight-click to add to favourites")
    }
    $card
}

# ---- App items ----
$script:AppCheckChanged = {
    if ($script:Rendering) { return }
    if ($this.Checked) { [void]$script:SelectedApps.Add($this.Tag.Id) } else { [void]$script:SelectedApps.Remove($this.Tag.Id) }
    Update-CountText
}
$script:AppItemClick = { $cb = $this.Tag.Check; $cb.Checked = -not $cb.Checked }
function New-AppItem($app) {
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size(262, 54); $card.Margin = New-Object Windows.Forms.Padding(0, 0, 10, 10)
    $card.Cursor = [Windows.Forms.Cursors]::Hand; $card.Add_Paint($cardPaint)
    $cb = New-Object Windows.Forms.CheckBox
    $cb.Text = $app.name; $cb.Font = $FontBold; $cb.Location = New-Object Drawing.Point(10, 7); $cb.Size = New-Object Drawing.Size(180, 22)
    $cb.UseMnemonic = $false; $cb.AutoEllipsis = $true; $cb.Checked = $script:SelectedApps.Contains($app.id); $cb.Tag = @{ Role = 'check'; Id = $app.id }
    $cb.Add_CheckedChanged($script:AppCheckChanged)
    $card.Tag = @{ Role = 'card'; Check = $cb }
    $idl = New-Object Windows.Forms.Label
    $idl.Text = $app.id; $idl.Font = $FontSmall; $idl.Location = New-Object Drawing.Point(28, 30); $idl.Size = New-Object Drawing.Size(226, 18)
    $idl.AutoEllipsis = $true; $idl.UseMnemonic = $false; $idl.BackColor = [Drawing.Color]::Transparent; $idl.Tag = @{ Role = 'muted'; Check = $cb }
    $parts = @($cb, $idl)
    if ($script:InstalledApps.Contains($app.id)) {
        $b = New-Object Windows.Forms.Label; $b.Text = 'INSTALLED'; $b.Font = $FontBadge; $b.Location = New-Object Drawing.Point(188, 11); $b.Size = New-Object Drawing.Size(66, 16)
        $b.TextAlign = 'MiddleRight'; $b.BackColor = [Drawing.Color]::Transparent; $b.Tag = @{ Role = 'badge-ok'; Check = $cb }
        $parts += $b
    }
    $card.Controls.AddRange($parts)
    foreach ($ctl in @($card) + @($parts | Where-Object { $_ -ne $cb })) { $ctl.Add_Click($script:AppItemClick) }
    foreach ($ctl in @($card) + $parts) { $ToolTip.SetToolTip($ctl, "$($app.category): $($app.description)") }
    $card
}

# ---- Tweak items ----
$script:TweakCheckChanged = {
    if ($script:Rendering) { return }
    if ($this.Checked) { [void]$script:SelectedTweaks.Add($this.Tag.Name) } else { [void]$script:SelectedTweaks.Remove($this.Tag.Name) }
    Update-CountText
}
$script:TweakItemClick = { $cb = $this.Tag.Check; $cb.Checked = -not $cb.Checked }
function New-TweakItem($tw) {
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size(420, 64); $card.Margin = New-Object Windows.Forms.Padding(0, 0, 10, 10)
    $card.Cursor = [Windows.Forms.Cursors]::Hand; $card.Add_Paint($cardPaint)
    $cb = New-Object Windows.Forms.CheckBox
    $cb.Text = $tw.Name; $cb.Font = $FontBold; $cb.Location = New-Object Drawing.Point(10, 7); $cb.Size = New-Object Drawing.Size(290, 22)
    $cb.UseMnemonic = $false; $cb.AutoEllipsis = $true; $cb.Checked = $script:SelectedTweaks.Contains($tw.Name); $cb.Tag = @{ Role = 'check'; Name = $tw.Name }
    $cb.Add_CheckedChanged($script:TweakCheckChanged)
    $card.Tag = @{ Role = 'card'; Check = $cb }
    $desc = New-Object Windows.Forms.Label
    $desc.Text = $tw.Description; $desc.Font = $FontSmall; $desc.Location = New-Object Drawing.Point(28, 31); $desc.Size = New-Object Drawing.Size(384, 30)
    $desc.AutoEllipsis = $true; $desc.UseMnemonic = $false; $desc.BackColor = [Drawing.Color]::Transparent; $desc.Tag = @{ Role = 'muted'; Check = $cb }
    $parts = @($cb, $desc)
    $state = $script:TweakStatus[$tw.Name]
    $tags = @()
    if ($state -eq $true) { $tags += @{ T = 'APPLIED'; R = 'badge-ok' } } elseif ($state -eq $false) { $tags += @{ T = 'NOT APPLIED'; R = 'badge-muted' } }
    if ($tw.Warning) { $tags += @{ T = 'CAUTION'; R = 'badge-confirm' } } elseif ($tw.Recommended) { $tags += @{ T = 'RECOMMENDED'; R = 'badge-rec' } }
    $y = 6
    foreach ($tg in $tags) {
        $b = New-Object Windows.Forms.Label; $b.Text = $tg.T; $b.Font = $FontBadge; $b.Location = New-Object Drawing.Point(300, $y); $b.Size = New-Object Drawing.Size(110, 13)
        $b.TextAlign = 'MiddleRight'; $b.BackColor = [Drawing.Color]::Transparent; $b.Tag = @{ Role = $tg.R; Check = $cb }
        $parts += $b; $y += 13
    }
    $card.Controls.AddRange($parts)
    foreach ($ctl in @($card) + @($parts | Where-Object { $_ -ne $cb })) { $ctl.Add_Click($script:TweakItemClick) }
    $tip = $tw.Description; if ($tw.Warning) { $tip += "`nCAUTION: $($tw.Warning)" }; if ($tw.NoUndo) { $tip += "`nCannot be undone automatically." }
    foreach ($ctl in @($card) + $parts) { $ToolTip.SetToolTip($ctl, $tip) }
    $card
}

# ---- Sidebar per tab ----
function Get-NavItems {
    switch ($script:CurrentTab) {
        'Tools' {
            $tools = @($script:Tools | Where-Object Tab -eq 'Tools')
            $favs = @($tools | Where-Object { $Settings.Favorites -contains $_.Name }).Count
            $rec = @($tools | Where-Object { $Settings.Recent -contains $_.Name }).Count
            @{ Name = 'Favourites'; Count = $favs }, @{ Name = 'Recent'; Count = $rec }, @{ Name = 'All tools'; Count = $tools.Count }
            $tools | Group-Object Category | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
        }
        'Updates' {
            $tools = @($script:Tools | Where-Object Tab -eq 'Updates')
            @{ Name = 'All'; Count = $tools.Count }
            $tools | Group-Object Category | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
        }
        'Install' {
            @{ Name = 'All apps'; Count = $script:Apps.Count }, @{ Name = 'Selected'; Count = $script:SelectedApps.Count }, @{ Name = 'Installed'; Count = @($script:Apps | Where-Object { $script:InstalledApps.Contains($_.id) }).Count }
            $script:Apps | Group-Object category | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
        }
        'Tweaks' {
            @{ Name = 'All tweaks'; Count = $script:Tweaks.Count }, @{ Name = 'Recommended'; Count = @($script:Tweaks | Where-Object Recommended).Count }
            $script:Tweaks | Group-Object Category | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
        }
    }
}
function Build-Nav {
    $navFlow.SuspendLayout()
    $old = @($navFlow.Controls); $navFlow.Controls.Clear(); $old | ForEach-Object { $_.Dispose() }
    $navFlow.Controls.Add((New-Label $script:CurrentTab.ToUpper() 4 0 $FontBadge 'muted'))
    foreach ($item in (Get-NavItems)) {
        $b = New-Object Windows.Forms.Button
        $b.Text = "$($item.Name)  ($($item.Count))"; $b.Size = New-Object Drawing.Size(192, 34); $b.TextAlign = 'MiddleLeft'; $b.FlatStyle = 'Flat'
        $b.Padding = New-Object Windows.Forms.Padding(8, 0, 0, 0); $b.Margin = New-Object Windows.Forms.Padding(0, 2, 0, 2)
        $b.Cursor = [Windows.Forms.Cursors]::Hand; $b.UseMnemonic = $false; $b.Tag = @{ Role = 'nav'; Category = $item.Name }
        $b.Add_Click({
            $script:CurrentCategory[$script:CurrentTab] = $this.Tag.Category
            if ($txtSearch.Text) { $txtSearch.Text = '' } else { Show-Content }
            Update-Theme $navFlow
        })
        $navFlow.Controls.Add($b)
    }
    Update-Theme $navFlow
    $navFlow.ResumeLayout()
}

# ---- Action bar per tab ----
function Build-ActionBar {
    $actionBar.SuspendLayout()
    $old = @($actionBar.Controls); $actionBar.Controls.Clear(); $old | ForEach-Object { $_.Dispose() }
    switch ($script:CurrentTab) {
        'Install' {
            $b1 = New-Button 'Install / upgrade selected' 0 'primary'; $b1.Add_Click({ Invoke-AppAction Install })
            $b2 = New-Button 'Uninstall selected' 0 'danger'; $b2.Add_Click({ Invoke-AppAction Uninstall })
            $b3 = New-Button 'Upgrade all apps' 0; $b3.Add_Click({ Invoke-AppAction UpgradeAll })
            $b4 = New-Button 'Check installed' 0; $b4.Add_Click({ Invoke-AppAction Check })
            $b5 = New-Button 'Clear selection' 0; $b5.Add_Click({ $script:SelectedApps.Clear(); Build-Nav; Show-Content })
            $combo = New-Object Windows.Forms.ComboBox
            $combo.DropDownStyle = 'DropDownList'; $combo.Width = 190; $combo.Margin = New-Object Windows.Forms.Padding(8, 7, 8, 4); $combo.Tag = 'input'; $combo.FlatStyle = 'Flat'
            [void]$combo.Items.Add('Add a preset...')
            foreach ($k in $script:Presets.Keys) { [void]$combo.Items.Add($k) }
            if ($Settings.SavedPreset.Count) { [void]$combo.Items.Add('My saved preset') }
            $combo.SelectedIndex = 0
            $script:PresetCombo = $combo
            $combo.Add_SelectedIndexChanged({
                if ($this.SelectedIndex -le 0) { return }
                $name = [string]$this.SelectedItem
                $ids = if ($name -eq 'My saved preset') { $Settings.SavedPreset } else { $script:Presets[$name] }
                foreach ($id in $ids) { [void]$script:SelectedApps.Add($id) }
                Add-LogLine 'INFO' "Preset '$name' added to the selection ($(@($ids).Count) apps)."
                $script:CurrentCategory['Install'] = 'Selected'
                Build-Nav; Show-Content
                $this.SelectedIndex = 0
            })
            $b6 = New-Button 'Save selection as my preset' 0; $b6.Add_Click({
                $Settings.SavedPreset = @($script:SelectedApps); Save-ToolkitSettings $Settings
                Add-LogLine 'OK' "Saved $($Settings.SavedPreset.Count) apps as 'My saved preset'."
                if (-not $script:PresetCombo.Items.Contains('My saved preset')) { [void]$script:PresetCombo.Items.Add('My saved preset') }
            })
            $actionBar.Controls.AddRange(@($b1, $b2, $b3, $b4, $b5, $combo, $b6))
            $actionBar.Visible = $true
        }
        'Tweaks' {
            $b1 = New-Button 'Apply selected' 0 'primary'; $b1.Add_Click({ Invoke-Tweaks -Mode Apply -Names @($script:SelectedTweaks) })
            $b2 = New-Button 'Undo selected' 0; $b2.Add_Click({ Invoke-Tweaks -Mode Revert -Names @($script:SelectedTweaks) })
            $b3 = New-Button 'Check status' 0; $b3.Add_Click({ Invoke-Tweaks -Mode Test -Names @($script:Tweaks.Name) })
            $b4 = New-Button 'Select recommended' 0; $b4.Add_Click({ foreach ($t in ($script:Tweaks | Where-Object Recommended)) { [void]$script:SelectedTweaks.Add($t.Name) }; Show-Content })
            $b5 = New-Button 'Clear selection' 0; $b5.Add_Click({ $script:SelectedTweaks.Clear(); Show-Content })
            $b6 = New-Button 'Create restore point' 0; $b6.Add_Click({ Start-UiTask -Name 'Create restore point' -Code "[void](New-ToolkitRestorePoint 'IT Toolkit - manual')" })
            $actionBar.Controls.AddRange(@($b1, $b2, $b3, $b4, $b5, $b6))
            $actionBar.Visible = $true
        }
        default { $actionBar.Visible = $false }
    }
    Update-Theme $actionBar
    $actionBar.ResumeLayout()
}

# ---- Content ----
$script:LastCount = 0
function Update-CountText {
    $lblCount.Text = switch ($script:CurrentTab) {
        'Install' { '{0} apps shown  -  {1} selected  -  {2} installed (winget)' -f $script:LastCount, $script:SelectedApps.Count, $(if ($script:InstalledChecked) { $script:InstalledApps.Count } else { 'not checked' }) }
        'Tweaks'  { '{0} tweaks shown  -  {1} selected  -  a restore point is made before applying' -f $script:LastCount, $script:SelectedTweaks.Count }
        default   { '{0} tool{1}  -  click a card to run it, right-click to favourite' -f $script:LastCount, $(if ($script:LastCount -eq 1) { '' } else { 's' }) }
    }
}
function Show-Content([switch]$KeepScroll) {
    $q = $txtSearch.Text.Trim()
    $cat = $script:CurrentCategory[$script:CurrentTab]
    $items = switch ($script:CurrentTab) {
        { $_ -in 'Tools', 'Updates' } {
            $pool = @($script:Tools | Where-Object Tab -eq $script:CurrentTab)
            if ($q) { $pool | Where-Object { "$($_.Name) $($_.Description) $($_.Category)" -like "*$q*" } }
            elseif ($cat -eq 'Favourites') { $pool | Where-Object { $Settings.Favorites -contains $_.Name } }
            elseif ($cat -eq 'Recent') { foreach ($n in $Settings.Recent) { $pool | Where-Object Name -eq $n | Select-Object -First 1 } }
            elseif ($cat -in 'All tools', 'All') { $pool }
            else { $pool | Where-Object Category -eq $cat }
        }
        'Install' {
            if ($q) { $script:Apps | Where-Object { "$($_.name) $($_.id) $($_.category) $($_.description)" -like "*$q*" } }
            elseif ($cat -eq 'Selected') { $script:Apps | Where-Object { $script:SelectedApps.Contains($_.id) } }
            elseif ($cat -eq 'Installed') { $script:Apps | Where-Object { $script:InstalledApps.Contains($_.id) } }
            elseif ($cat -eq 'All apps') { $script:Apps }
            else { $script:Apps | Where-Object category -eq $cat }
        }
        'Tweaks' {
            if ($q) { $script:Tweaks | Where-Object { "$($_.Name) $($_.Description) $($_.Category)" -like "*$q*" } }
            elseif ($cat -eq 'Recommended') { $script:Tweaks | Where-Object Recommended }
            elseif ($cat -eq 'All tweaks') { $script:Tweaks }
            else { $script:Tweaks | Where-Object Category -eq $cat }
        }
    }
    $items = @($items | Where-Object { $_ })
    $lblCat.Text = if ($q) { "Search: $q" } else { "$($script:CurrentTab) - $cat" }
    $script:LastCount = $items.Count
    $script:Rendering = $true
    $scroll = -$flow.AutoScrollPosition.Y
    $flow.SuspendLayout()
    $old = @($flow.Controls); $flow.Controls.Clear(); $old | ForEach-Object { $_.Dispose() }
    foreach ($it in $items) {
        $ctl = switch ($script:CurrentTab) { 'Install' { New-AppItem $it } 'Tweaks' { New-TweakItem $it } default { New-ToolCard $it } }
        $flow.Controls.Add($ctl)
    }
    if (-not $items.Count) {
        $msg = if ($script:CurrentTab -eq 'Tools' -and $cat -eq 'Favourites') { 'No favourites yet - right-click any tool card and choose "Add to favourites".' }
               elseif ($script:CurrentTab -eq 'Install' -and $cat -eq 'Installed' -and -not $script:InstalledChecked) { 'Click "Check installed" to see which apps are on this PC.' }
               else { 'Nothing to show here.' }
        $flow.Controls.Add((New-Label $msg 4 4 $FontUI 'muted'))
    }
    Update-Theme $flow
    $flow.ResumeLayout()
    if ($KeepScroll -and $scroll -gt 0) { try { $flow.AutoScrollPosition = New-Object Drawing.Point(0, $scroll) } catch {} }
    $script:Rendering = $false
    Update-CountText
}

function Select-Tab([string]$Tab) {
    $script:CurrentTab = $Tab
    $script:Rendering = $true; $txtSearch.Text = ''; $script:Rendering = $false
    Build-Nav; Build-ActionBar; Show-Content
    Update-Theme $tabFlow
    if ($Tab -eq 'Install' -and -not $script:InstalledChecked) { $script:InstalledChecked = $true; Invoke-AppAction Check }
    if ($Tab -eq 'Tweaks' -and -not $script:TweakChecked) { $script:TweakChecked = $true; Invoke-Tweaks -Mode Test -Names @($script:Tweaks.Name) -Quiet }
}

# =====================================================================
#  EVENTS
# =====================================================================
$txtSearch.Add_TextChanged({ if (-not $script:Rendering) { Show-Content } })
$btnClear.Add_Click({ $script:LogLines.Clear(); $rtb.Clear() })
$btnCopy.Add_Click({ if ($rtb.TextLength) { [Windows.Forms.Clipboard]::SetText($rtb.Text); Add-LogLine 'OK' 'Output copied to clipboard.' } })
$btnSave.Add_Click({ $f = Save-Log; Add-LogLine 'OK' "Log saved: $f" })
$btnNotes.Add_Click({ Show-TicketNotes })
$btnStop.Add_Click({
    $active = @($script:Jobs | Where-Object { -not $_.Quiet })
    if (-not $active) { Add-LogLine 'INFO' 'Nothing is running.'; return }
    foreach ($j in $active) { $j.Stopped = $true; [void]$j.PS.BeginStop($null, $null) }
    Add-LogLine 'WARN' 'Stop requested for all running tasks.'
})
$runCmd = {
    $cmd = $txtCmd.Text.Trim(); if (-not $cmd) { return }
    $txtCmd.Clear()
    Start-UiTask -Name "PS> $cmd" -Code $cmd
}
$btnRun.Add_Click($runCmd)
$txtCmd.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true; & $runCmd } })
$form.Add_KeyDown({
    param($s, $e)
    if ($e.Control -and $e.KeyCode -eq 'F') { $txtSearch.Focus(); $txtSearch.SelectAll(); $e.SuppressKeyPress = $true }
    elseif ($e.Control -and $e.KeyCode -ge 'D1' -and $e.KeyCode -le 'D4') { Select-Tab $script:Tabs[[int]$e.KeyCode - [int][Windows.Forms.Keys]::D1]; $e.SuppressKeyPress = $true }
})

$timer = New-Object Windows.Forms.Timer; $timer.Interval = 150
$timer.Add_Tick({
    $item = $null; $n = 0; $refreshTweaks = $false; $refreshApps = $false
    while ($n -lt 300 -and $Queue.TryDequeue([ref]$item)) {
        $n++
        $job = $script:JobIndex[$item.JobId]
        if ($item.Level -eq 'EVENT') {
            switch ($item.Type) {
                'TweakStatus'     { $script:TweakStatus[$item.Data.Name] = $item.Data.Applied; $refreshTweaks = $true }
                'AppsInstalled'   { $script:InstalledApps.Clear(); foreach ($id in @($item.Data)) { [void]$script:InstalledApps.Add([string]$id) }; $script:InstalledChecked = $true; $refreshApps = $true }
                'UpdateAvailable' { $lblBanner.Text = "IT Toolkit $($item.Data) is available (you have $($Config.Version))."; $banner.Visible = $true }
            }
            continue
        }
        if ($job) {
            if ($item.Level -eq 'WARN' -and $job.Warnings.Count -lt 3) { $job.Warnings.Add($item.Text) }
            if ($item.Level -eq 'ERROR' -and $job.Errors.Count -lt 3) { $job.Errors.Add($item.Text) }
            if ($item.Level -eq 'OK') { $job.LastOk = $item.Text }
            if ($job.Quiet -and $item.Level -in 'INFO', 'OK') { continue }   # quiet background checks only surface problems
        }
        Add-LogLine $item.Level $item.Text $item.Time
    }
    foreach ($j in @($script:Jobs)) {
        if ($j.Handle.IsCompleted) {
            if ($Queue.Count) { break }     # finish printing its output first
            try { [void]$j.PS.EndInvoke($j.Handle) } catch {}
            $j.End = Get-Date
            $secs = [math]::Round(($j.End - $j.Start).TotalSeconds, 1)
            $j.Status = if ($j.Stopped) { 'Stopped' } elseif ($j.Errors.Count) { 'Errors' } else { 'Done' }
            if (-not $j.Quiet) {
                if ($j.Stopped) { Add-LogLine 'WARN' "Stopped: $($j.Name) after $secs s" } else { Add-LogLine 'OK' "Done: $($j.Name) ($secs s)" }
            }
            $j.PS.Dispose(); $script:Jobs.Remove($j); $script:JobIndex.Remove($j.Id); Update-Status
        }
    }
    if ($refreshTweaks -and $script:CurrentTab -eq 'Tweaks') { Show-Content -KeepScroll }
    if ($refreshApps) { if ($script:CurrentTab -eq 'Install') { Build-Nav; Show-Content -KeepScroll } }
})

$form.Add_Shown({
    Set-CueBanner $txtSearch 'Search this tab...  (Ctrl+F)'
    Set-CueBanner $txtCmd 'Type any PowerShell command and press Enter'
    $split.Panel1MinSize = 140; $split.Panel2MinSize = 160
    $split.SplitterDistance = [int]($split.Height * 0.58)
    $timer.Start()
    if ($Settings.CheckUpdates) {
        $code = {
            param($P)
            try {
                $latest = (Invoke-RestMethod -Uri ($P.Url + '?t=' + [DateTime]::UtcNow.Ticks) -TimeoutSec 8 -UseBasicParsing).ToString().Trim()
                if ([version]$latest -gt [version]$P.Current) { Send-ToolkitEvent 'UpdateAvailable' $latest }
            } catch {}
        }.ToString()
        Start-UiTask -Name 'Update check' -Code $code -Params @{ Url = $Config.VersionUrl; Current = $Config.Version } -Quiet
    }
})
$form.Add_FormClosing({
    $timer.Stop()
    foreach ($j in @($script:Jobs)) { try { $j.PS.Stop(); $j.PS.Dispose() } catch {} }
    if ($script:LogLines.Count -gt 2) { try { [void](Save-Log 'session') } catch {} }
    if ($Settings.WebhookUrl -and $Settings.SendNotesOnClose -and $script:History.Count) { try { Send-Webhook $Settings.WebhookUrl (Get-TicketNotes) } catch {} }
    Save-ToolkitSettings $Settings
})

# =====================================================================
#  GO
# =====================================================================
Update-Theme $form
Select-Tab 'Tools'
Update-Status
Add-LogLine 'HEAD' ("{0} {1} ready - {2} tools, {3} apps, {4} tweaks ({5} tools from the Tools folder)." -f $Config.AppName, $Config.Version, $script:Tools.Count, $script:Apps.Count, $script:Tweaks.Count, $PluginToolCount)
Add-LogLine 'INFO' "Logs, reports and settings: $($Config.DataDir)    Shortcuts: Ctrl+1-4 switch tabs, Ctrl+F search."
if (-not $IsAdmin) { Add-LogLine 'WARN' 'Not running elevated - many tools need admin rights.' }
foreach ($err in $script:LoadErrors) { Add-LogLine 'ERROR' "Failed to load $err" }

[void]$form.ShowDialog()
$form.Dispose()
