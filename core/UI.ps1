# =====================================================================
#  IT Toolkit - main window (WinForms)
#  Dot-sourced by ITToolkit.ps1, which provides $Config, $Settings,
#  $script:Tools / Tweaks / Apps / Presets, $Queue and Start-ToolkitTask.
#
#  Look: Windows-native (Segoe Fluent / MDL2 icons that ship with Windows),
#  each category has its own colour, shown as a tinted icon tile.
#  Cards, sidebar items, tabs and buttons are owner-drawn panels: they paint
#  themselves, so the whole window re-themes instantly and stays light.
# =====================================================================

if ($UiTest) { $ErrorActionPreference = 'Stop' }   # any error while building the window fails the UI test
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
if (-not ('ITK.Native' -as [type])) {
    Add-Type -Namespace ITK -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
'@
}
if (-not ('ITK.Chrome' -as [type])) {
    Add-Type -Namespace ITK -Name Chrome -MemberDefinition @'
[DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
public static extern int SetWindowTheme(IntPtr hWnd, string appName, string idList);
'@
}

# =====================================================================
#  THEME
# =====================================================================
$Themes = @{
    Dark  = @{
        Bg = '#15171c'; Sidebar = '#1a1d23'; Surface = '#1e2128'; Card = '#23272f'; CardHover = '#2b303a'
        Border = '#323844'; Text = '#e8eaef'; Muted = '#9aa3b2'; Accent = '#2563eb'; AccentHover = '#1d4fc4'; Link = '#7cb4ff'
        AccentText = '#ffffff'; Console = '#101217'; ConsoleText = '#d6dae1'; Input = '#23272f'
        Ok = '#4ade80'; Warn = '#fbbf24'; Err = '#f87171'; Track = '#4b5361'
    }
    Light = @{
        Bg = '#f3f4f7'; Sidebar = '#fbfbfd'; Surface = '#ffffff'; Card = '#ffffff'; CardHover = '#f2f5fb'
        Border = '#dfe3ea'; Text = '#1b2130'; Muted = '#5c6778'; Accent = '#2563eb'; AccentHover = '#1d4fc4'; Link = '#1d4fc4'
        AccentText = '#ffffff'; Console = '#fafbfc'; ConsoleText = '#1b2130'; Input = '#ffffff'
        Ok = '#15803d'; Warn = '#a16207'; Err = '#b91c1c'; Track = '#9aa3b2'
    }
}
$script:ThemeName = if ($Themes.ContainsKey([string]$Settings.Theme)) { [string]$Settings.Theme } else { 'Dark' }

# Category colours (hue of the icon tile)
$Hues = @{
    blue = '#3b82f6'; sky = '#0ea5e9'; cyan = '#06b6d4'; teal = '#14b8a6'; green = '#22c55e'; lime = '#84cc16'
    amber = '#f59e0b'; orange = '#f97316'; red = '#ef4444'; rose = '#f43f5e'; pink = '#ec4899'; purple = '#a855f7'
    violet = '#8b5cf6'; indigo = '#6366f1'; slate = '#64748b'; stone = '#78716c'
}
$CatHue = @{
    'Favourites' = 'amber'; 'Recent' = 'sky'; 'All tools' = 'blue'; 'All' = 'blue'; 'All apps' = 'blue'; 'All tweaks' = 'blue'
    'Selected' = 'blue'; 'Installed' = 'green'; 'Recommended' = 'green'; 'Search' = 'slate'
    'Quick Launch' = 'indigo'; 'System' = 'blue'; 'Drivers' = 'violet'; 'Blue screens' = 'red'; 'Network' = 'cyan'
    'Disk & Cleanup' = 'amber'; 'Repair' = 'orange'; 'Software' = 'teal'; 'Services & Processes' = 'slate'; 'User Session' = 'pink'
    'Domain & Entra' = 'sky'; 'Office & Teams' = 'rose'; 'Security & Users' = 'green'; 'Printers' = 'stone'; 'Power' = 'lime'
    'Reports' = 'purple'; 'Toolkit' = 'blue'; 'Custom' = 'violet'
    'Update policy' = 'indigo'; 'Update actions' = 'cyan'
    'Browsers' = 'sky'; 'Communication' = 'pink'; 'Remote support' = 'teal'; 'Office & PDF' = 'rose'; 'Utilities' = 'amber'
    'Hardware & diagnostics' = 'violet'; 'Pro tools' = 'slate'; 'Media' = 'purple'; 'Development' = 'indigo'; 'Runtimes' = 'stone'
    'Microsoft tools' = 'blue'; 'Security' = 'green'; 'Cloud storage' = 'sky'; 'Gaming' = 'lime'; 'Self-hosted' = 'orange'
    'Essential' = 'blue'; 'Privacy' = 'violet'; 'Performance' = 'amber'; 'Explorer & Taskbar' = 'indigo'; 'Preferences' = 'teal'
    'Drivers & vendor apps' = 'slate'; 'Cleanup' = 'orange'; 'Remove apps' = 'red'; 'Windows features' = 'green'
}
# Segoe Fluent Icons / Segoe MDL2 Assets code points
$CatGlyph = @{
    'Favourites' = 'E734'; 'Recent' = 'E81C'; 'All tools' = 'E71D'; 'All' = 'E71D'; 'All apps' = 'E71D'; 'All tweaks' = 'E71D'
    'Selected' = 'E73E'; 'Installed' = 'E930'; 'Recommended' = 'E8E1'; 'Search' = 'E721'
    'Quick Launch' = 'E8A7'; 'System' = 'E770'; 'Drivers' = 'E950'; 'Blue screens' = 'E783'; 'Network' = 'E968'
    'Disk & Cleanup' = 'EDA2'; 'Repair' = 'E90F'; 'Software' = 'E719'; 'Services & Processes' = 'E9D9'; 'User Session' = 'E77B'
    'Domain & Entra' = 'E716'; 'Office & Teams' = 'E8A5'; 'Security & Users' = 'EA18'; 'Printers' = 'E749'; 'Power' = 'E7E8'
    'Reports' = 'E9F9'; 'Toolkit' = 'E713'; 'Custom' = 'E70F'
    'Update policy' = 'E8D7'; 'Update actions' = 'E895'
    'Browsers' = 'E774'; 'Communication' = 'E8BD'; 'Remote support' = 'E703'; 'Office & PDF' = 'E8A5'; 'Utilities' = 'E90F'
    'Hardware & diagnostics' = 'E950'; 'Pro tools' = 'EC7A'; 'Media' = 'E714'; 'Development' = 'E943'; 'Runtimes' = 'E74C'
    'Microsoft tools' = 'E770'; 'Security' = 'EA18'; 'Cloud storage' = 'E753'; 'Gaming' = 'E7FC'; 'Self-hosted' = 'E80F'
    'Essential' = 'E734'; 'Privacy' = 'E72E'; 'Performance' = 'EC4A'; 'Explorer & Taskbar' = 'E8B7'; 'Preferences' = 'E713'
    'Drivers & vendor apps' = 'E950'; 'Cleanup' = 'E74D'; 'Remove apps' = 'E711'; 'Windows features' = 'E8F1'
}
$TabGlyph = @{ Tools = 'E90F'; Install = 'E896'; Tweaks = 'E9E9'; Updates = 'E895' }

function C([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
function TC([string]$key) { C $Themes[$script:ThemeName][$key] }
function Get-Role($c) { if ($c.Tag -is [hashtable]) { $c.Tag.Role } else { [string]$c.Tag } }
function Mix-Color($A, $B, [double]$T) {
    [Drawing.Color]::FromArgb(255, [int]($A.R + ($B.R - $A.R) * $T), [int]($A.G + ($B.G - $A.G) * $T), [int]($A.B + ($B.B - $A.B) * $T))
}
function G([string]$code) { [string][char][Convert]::ToInt32($code, 16) }
$script:ColorCache = @{}
function Get-CatColors([string]$Cat) {
    $key = "$script:ThemeName|$Cat"
    if ($script:ColorCache.ContainsKey($key)) { return $script:ColorCache[$key] }
    $name = $CatHue[$Cat]
    if (-not $name) { $names = @($Hues.Keys | Sort-Object); $name = $names[[math]::Abs($Cat.GetHashCode()) % $names.Count] }
    $hue = C $Hues[$name]
    $dark = $script:ThemeName -eq 'Dark'
    $r = @{
        Hue   = $hue
        Tile  = Mix-Color (TC 'Card') $hue $(if ($dark) { 0.2 } else { 0.13 })
        Glyph = if ($dark) { Mix-Color $hue ([Drawing.Color]::White) 0.3 } else { Mix-Color $hue ([Drawing.Color]::Black) 0.22 }
    }
    $script:ColorCache[$key] = $r
    $r
}
function Get-CatGlyph([string]$Cat) { $g = $CatGlyph[$Cat]; if ($g) { G $g } else { G 'E7C3' } }

# ---------------- Fonts ----------------
$installedFonts = @((New-Object Drawing.Text.InstalledFontCollection).Families | ForEach-Object Name)
$IconFamily = if ($installedFonts -contains 'Segoe Fluent Icons') { 'Segoe Fluent Icons' } elseif ($installedFonts -contains 'Segoe MDL2 Assets') { 'Segoe MDL2 Assets' } else { $null }
$MonoFamily = if ($installedFonts -contains 'Cascadia Mono') { 'Cascadia Mono' } else { 'Consolas' }
$FontUI    = New-Object Drawing.Font('Segoe UI', 9.5)
$FontBold  = New-Object Drawing.Font('Segoe UI Semibold', 10)
$FontNavSel = New-Object Drawing.Font('Segoe UI Semibold', 9.5)
$FontTitle = New-Object Drawing.Font('Segoe UI Semibold', 13)
$FontH2    = New-Object Drawing.Font('Segoe UI Semibold', 15)
$FontSmall = New-Object Drawing.Font('Segoe UI', 8.75)
$FontPill  = New-Object Drawing.Font('Segoe UI Semibold', 7.75)
$FontMono  = New-Object Drawing.Font($MonoFamily, 9.5)
if ($IconFamily) {
    $IconSm = New-Object Drawing.Font($IconFamily, 9)
    $IconMd = New-Object Drawing.Font($IconFamily, 11)
    $IconLg = New-Object Drawing.Font($IconFamily, 14)
}
$ToolTip = New-Object Windows.Forms.ToolTip
$ToolTip.InitialDelay = 600

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
$script:TweakState    = @{}
$script:InstalledChecked = $false
$script:TweakChecked = $false
$script:Jobs     = New-Object System.Collections.ArrayList
$script:JobIndex = @{}
$script:History  = New-Object System.Collections.Generic.List[object]
$script:LogLines = New-Object System.Collections.Generic.List[object]
$script:PaintErrors = New-Object System.Collections.Generic.List[string]
$script:Rendering = $false
$script:AnimPos = 0
$script:InWidthUpdate = $false

$RunAs     = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$IsAdmin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$OsInfo    = Get-CimInstance Win32_OperatingSystem
$OsVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
$ConsoleUser = Get-ConsoleUser; if (-not $ConsoleUser) { $ConsoleUser = 'nobody signed in' }
$MainIP = ''
try { $MainIP = (Get-IPConfig | Where-Object IPv4DefaultGateway | Select-Object -First 1).IPv4Address.IPAddress | Select-Object -First 1 } catch {}
if (-not $MainIP) { $MainIP = 'no network' }

# =====================================================================
#  DRAWING PRIMITIVES
# =====================================================================
$script:BindNP = [Reflection.BindingFlags]'NonPublic,Instance'
$script:DoubleBufferedProp = [Windows.Forms.Control].GetProperty('DoubleBuffered', $script:BindNP)
$script:ResizeRedrawProp = [Windows.Forms.Control].GetProperty('ResizeRedraw', $script:BindNP)
function Set-Smooth($ctl) { try { $script:DoubleBufferedProp.SetValue($ctl, $true, $null) } catch {} }

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    if ($r -le 0) { $p.AddRectangle((New-Object Drawing.RectangleF($x, $y, $w, $h))); return $p }
    $d = [math]::Min($r * 2, [math]::Min($w, $h))
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); $p
}
function Fill-Round($g, $Color, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-RoundRect $x $y $w $h $r; $b = New-Object Drawing.SolidBrush($Color); $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
}
function Stroke-Round($g, $Color, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r, [float]$Width = 1) {
    $p = New-RoundRect $x $y $w $h $r; $pen = New-Object Drawing.Pen($Color, $Width); $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
}
$FlagsLine  = [Windows.Forms.TextFormatFlags]'Left, VerticalCenter, EndEllipsis, SingleLine, NoPrefix, NoPadding'
$FlagsWrap  = [Windows.Forms.TextFormatFlags]'Left, Top, WordBreak, EndEllipsis, NoPrefix, NoPadding, TextBoxControl'
$FlagsRight = [Windows.Forms.TextFormatFlags]'Right, VerticalCenter, SingleLine, NoPrefix, NoPadding'
$FlagsCenter = [Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPrefix, NoPadding'
function Draw-Text($g, [string]$Text, $Font, $Color, [int]$x, [int]$y, [int]$w, [int]$h, $Flags = $FlagsLine) {
    if ($w -le 0 -or $h -le 0) { return }
    [Windows.Forms.TextRenderer]::DrawText($g, $Text, $Font, (New-Object Drawing.Rectangle($x, $y, $w, $h)), $Color, $Flags)
}
function Draw-Glyph($g, [string]$Glyph, $Font, $Color, [int]$x, [int]$y, [int]$w, [int]$h) {
    if (-not $IconFamily -or -not $Glyph) { return }
    Draw-Text $g $Glyph $Font $Color $x $y $w $h $FlagsCenter
}
function Draw-Tile($g, [string]$Cat, [int]$x, [int]$y, [int]$Size) {
    $c = Get-CatColors $Cat
    Fill-Round $g $c.Tile $x $y $Size $Size ([math]::Round($Size * 0.26))
    if ($IconFamily) { Draw-Glyph $g (Get-CatGlyph $Cat) $(if ($Size -ge 34) { $IconLg } elseif ($Size -ge 26) { $IconMd } else { $IconSm }) $c.Glyph $x $y $Size $Size }
    else { Draw-Text $g ($Cat.Substring(0, 1)) $FontBold $c.Glyph $x $y $Size $Size $FlagsCenter }
}
function Get-PillWidth([string]$Text) { [Windows.Forms.TextRenderer]::MeasureText($Text, $FontPill).Width + 10 }
function Draw-Pill($g, [string]$Text, $Color, [int]$Right, [int]$y, $Base) {
    $w = Get-PillWidth $Text; $x = $Right - $w
    Fill-Round $g (Mix-Color $Base $Color 0.16) $x $y $w 18 9
    Draw-Text $g $Text $FontPill $Color $x $y $w 18 $FlagsCenter
    $x
}
function Draw-Check($g, [bool]$On, [int]$x, [int]$y) {
    if ($On) {
        Fill-Round $g (TC 'Accent') $x $y 20 20 6
        if ($IconFamily) { Draw-Glyph $g (G 'E73E') $IconSm ([Drawing.Color]::White) $x $y 20 20 }
        else { Draw-Text $g 'v' $FontBold ([Drawing.Color]::White) $x $y 20 20 $FlagsCenter }
    } else {
        Fill-Round $g (TC 'Input') $x $y 20 20 6
        Stroke-Round $g (TC 'Muted') ($x + 0.5) ($y + 0.5) 19 19 6 1.25
    }
}

# =====================================================================
#  OWNER-DRAWN PAINTERS
# =====================================================================
function Draw-ToolCard($s, $g) {
    $t = $s.Tag.Data; $w = $s.Width; $h = $s.Height; $hover = $s.Tag.Hover
    $c = Get-CatColors $t.Category
    $base = if ($hover) { TC 'CardHover' } else { TC 'Card' }
    Fill-Round $g $base 0 0 ($w - 1) ($h - 1) 10
    Stroke-Round $g $(if ($hover) { Mix-Color (TC 'Border') $c.Hue 0.55 } else { TC 'Border' }) 0.5 0.5 ($w - 2) ($h - 2) 10
    Draw-Tile $g $t.Category 14 14 38
    $right = $w - 12
    $kind = if ($t.Launch) { @('Opens app', 'Link') } elseif ($t.Confirm) { @('Asks first', 'Warn') } elseif ($t.Inputs.Count) { @('Needs input', 'Muted') } else { $null }
    if ($kind) { $right = (Draw-Pill $g $kind[0] (TC $kind[1]) $right 13 $base) - 6 }
    if ($Settings.Favorites -contains $t.Name) {
        if ($IconFamily) { Draw-Glyph $g (G 'E735') $IconSm (TC 'Warn') ($right - 16) 13 16 18 } else { Draw-Text $g '*' $FontBold (TC 'Warn') ($right - 12) 13 12 18 $FlagsCenter }
        $right -= 20
    }
    Draw-Text $g $t.Name $FontBold (TC 'Text') 64 12 ($right - 64 - 4) 22
    Draw-Text $g $t.Description $FontSmall (TC 'Muted') 64 35 ($w - 64 - 14) ($h - 35 - 8) $FlagsWrap
}
function Draw-AppCard($s, $g) {
    $a = $s.Tag.Data; $w = $s.Width; $h = $s.Height; $hover = $s.Tag.Hover
    $sel = $script:SelectedApps.Contains($a.id)
    $base = if ($hover) { TC 'CardHover' } else { TC 'Card' }
    Fill-Round $g $base 0 0 ($w - 1) ($h - 1) 10
    Stroke-Round $g $(if ($sel) { TC 'Accent' } elseif ($hover) { Mix-Color (TC 'Border') (TC 'Muted') 0.4 } else { TC 'Border' }) 0.5 0.5 ($w - 2) ($h - 2) 10 $(if ($sel) { 1.5 } else { 1 })
    Draw-Check $g $sel 14 ([int](($h - 20) / 2))
    $right = $w - 12
    if ($script:InstalledApps.Contains($a.id)) { $right = (Draw-Pill $g 'Installed' (TC 'Ok') $right 11 $base) - 6 }
    Draw-Text $g $a.name $FontBold (TC 'Text') 46 9 ($right - 46 - 4) 22
    Draw-Text $g $a.id $FontSmall (TC 'Muted') 46 32 ($w - 46 - 12) 18
}
function Draw-TweakCard($s, $g) {
    $t = $s.Tag.Data; $w = $s.Width; $h = $s.Height; $hover = $s.Tag.Hover
    $sel = $script:SelectedTweaks.Contains($t.Name)
    $base = if ($hover) { TC 'CardHover' } else { TC 'Card' }
    Fill-Round $g $base 0 0 ($w - 1) ($h - 1) 10
    Stroke-Round $g $(if ($sel) { TC 'Accent' } elseif ($hover) { Mix-Color (TC 'Border') (TC 'Muted') 0.4 } else { TC 'Border' }) 0.5 0.5 ($w - 2) ($h - 2) 10 $(if ($sel) { 1.5 } else { 1 })
    Draw-Check $g $sel 14 13
    $right = $w - 12
    $state = $script:TweakState[$t.Name]
    if ($t.Warning) { $right = (Draw-Pill $g 'Caution' (TC 'Warn') $right 11 $base) - 6 }
    elseif ($t.Recommended) { $right = (Draw-Pill $g 'Recommended' (TC 'Link') $right 11 $base) - 6 }
    if ($state -eq $true) { $right = (Draw-Pill $g 'Applied' (TC 'Ok') $right 11 $base) - 6 }
    elseif ($state -eq $false) { $right = (Draw-Pill $g 'Not applied' (TC 'Muted') $right 11 $base) - 6 }
    Draw-Text $g $t.Name $FontBold (TC 'Text') 46 9 ($right - 46 - 4) 22
    Draw-Text $g $t.Description $FontSmall (TC 'Muted') 46 33 ($w - 46 - 14) ($h - 33 - 6) $FlagsWrap
}
function Draw-Nav($s, $g) {
    $w = $s.Width; $h = $s.Height; $name = $s.Tag.Name
    $sel = ($name -eq $script:CurrentCategory[$script:CurrentTab]) -and -not $txtSearch.Text
    $c = Get-CatColors $name
    if ($sel) { Fill-Round $g (Mix-Color (TC 'Sidebar') $c.Hue $(if ($script:ThemeName -eq 'Dark') { 0.16 } else { 0.1 })) 0 0 ($w - 1) ($h - 1) 8 }
    elseif ($s.Tag.Hover) { Fill-Round $g (TC 'CardHover') 0 0 ($w - 1) ($h - 1) 8 }
    Draw-Tile $g $name 8 (($h - 24) / 2) 24
    $countW = 34
    Draw-Text $g $name $(if ($sel) { $FontNavSel } else { $FontUI }) (TC 'Text') 42 0 ($w - 42 - $countW - 6) $h
    Draw-Text $g ([string]$s.Tag.Count) $FontSmall $(if ($sel) { $c.Glyph } else { TC 'Muted' }) ($w - $countW - 10) 0 $countW $h $FlagsRight
}
function Draw-Tab($s, $g) {
    $w = $s.Width; $h = $s.Height; $sel = $s.Tag.Tab -eq $script:CurrentTab
    if ($sel) { Fill-Round $g (TC 'Accent') 0 0 ($w - 1) ($h - 1) ([math]::Floor($h / 2)) }
    elseif ($s.Tag.Hover) { Fill-Round $g (TC 'CardHover') 0 0 ($w - 1) ($h - 1) ([math]::Floor($h / 2)) }
    $fg = if ($sel) { TC 'AccentText' } else { TC 'Text' }
    $x = 14
    if ($IconFamily) { Draw-Glyph $g (G $TabGlyph[$s.Tag.Tab]) $IconSm $fg $x 0 16 $h; $x += 22 }
    Draw-Text $g $s.Tag.Tab $(if ($sel) { $FontNavSel } else { $FontUI }) $fg $x 0 ($w - $x - 12) $h
}
function Draw-Button($s, $g) {
    $w = $s.Width; $h = $s.Height; $hv = $s.Tag.Hover; $st = $s.Tag.Style
    $parentBg = TC $s.Tag.Bg
    switch ($st) {
        'primary' { $fill = if ($hv) { TC 'AccentHover' } else { TC 'Accent' }; $fg = TC 'AccentText'; $line = $null }
        'danger'  { $fill = if ($hv) { Mix-Color (TC 'Card') (TC 'Err') 0.12 } else { TC 'Card' }; $fg = TC 'Err'; $line = TC 'Border' }
        'ghost'   { $fill = if ($hv) { TC 'CardHover' } else { $null }; $fg = TC 'Text'; $line = $null }
        'banner'  { $fill = if ($hv) { Mix-Color (TC 'Accent') ([Drawing.Color]::White) 0.18 } else { TC 'Accent' }; $fg = TC 'AccentText'; $line = Mix-Color (TC 'Accent') ([Drawing.Color]::White) 0.55 }
        default   { $fill = if ($hv) { TC 'CardHover' } else { TC 'Card' }; $fg = TC 'Text'; $line = TC 'Border' }
    }
    if ($fill) { Fill-Round $g $fill 0 0 ($w - 1) ($h - 1) 8 }
    if ($line) { Stroke-Round $g $line 0.5 0.5 ($w - 2) ($h - 2) 8 }
    $glyph = $s.Tag.Glyph; $text = $s.Tag.Text
    if ($glyph -and -not $text) { Draw-Glyph $g (G $glyph) $IconMd $fg 0 0 $w $h; return }
    $x = 12
    if ($glyph -and $IconFamily) { Draw-Glyph $g (G $glyph) $IconSm $(if ($st -eq 'default' -or $st -eq 'ghost') { TC 'Muted' } else { $fg }) $x 0 16 $h; $x += 22 }
    Draw-Text $g $text $FontUI $fg $x 0 ($w - $x - 10) $h
}
function Draw-Toggle($s, $g) {
    $dark = $script:ThemeName -eq 'Dark'
    $tw = 48; $th = 26; $x0 = $s.Width - $tw - 2; $y0 = [int](($s.Height - $th) / 2)
    Fill-Round $g $(if ($dark) { TC 'Accent' } else { TC 'Track' }) $x0 $y0 $tw $th ($th / 2)
    $d = $th - 6; $kx = if ($dark) { $x0 + $tw - $d - 3 } else { $x0 + 3 }
    $kb = New-Object Drawing.SolidBrush([Drawing.Color]::White); $g.FillEllipse($kb, $kx, $y0 + 3, $d, $d); $kb.Dispose()
    if ($IconFamily) { Draw-Glyph $g $(if ($dark) { G 'E708' } else { G 'E706' }) $IconSm $(if ($dark) { TC 'Accent' } else { C '#d97706' }) $kx ($y0 + 3) $d $d }
    Draw-Text $g $(if ($dark) { 'Dark' } else { 'Light' }) $FontUI (TC 'Muted') 0 0 ($x0 - 8) $s.Height $FlagsRight
}
function Draw-Logo($s, $g) {
    Fill-Round $g (TC 'Accent') 0 0 ($s.Width - 1) ($s.Height - 1) 9
    if ($IconFamily) { Draw-Glyph $g (G 'E756') $IconLg ([Drawing.Color]::White) 0 0 $s.Width $s.Height }
    else { Draw-Text $g '>_' $FontBold ([Drawing.Color]::White) 0 0 $s.Width $s.Height $FlagsCenter }
}
function Draw-Heading($s, $g) {
    $cat = $s.Tag.Cat
    Draw-Tile $g $cat 0 4 38
    Draw-Text $g $s.Tag.Title $FontH2 (TC 'Text') 52 0 ($s.Width - 52) 28
    Draw-Text $g $s.Tag.Sub $FontSmall (TC 'Muted') 53 28 ($s.Width - 53) 20
}
function Draw-InputBox($s, $g) {
    $focus = $s.Tag.Box -and $s.Tag.Box.Focused
    Fill-Round $g (TC 'Input') 0 0 ($s.Width - 1) ($s.Height - 1) 8
    Stroke-Round $g $(if ($focus) { TC 'Accent' } else { TC 'Border' }) 0.5 0.5 ($s.Width - 2) ($s.Height - 2) 8 $(if ($focus) { 1.5 } else { 1 })
    Draw-Glyph $g (G $s.Tag.Glyph) $IconSm (TC 'Muted') 8 0 20 $s.Height
}
function Draw-Frame($s, $g) {
    Fill-Round $g (TC 'Surface') 0 0 ($s.Width - 1) ($s.Height - 1) 12
    Stroke-Round $g (TC 'Border') 0.5 0.5 ($s.Width - 2) ($s.Height - 2) 12
}
function Draw-Progress($s, $g) {
    $running = @($script:Jobs | Where-Object { -not $_.Quiet }).Count -gt 0
    if (-not $running -and -not $script:ForceProgress) { return }
    $w = $s.Width; $seg = [math]::Max(60, [int]($w * 0.22))
    $x = ($script:AnimPos % ($w + $seg)) - $seg
    Fill-Round $g (TC 'Accent') $x 0 $seg $s.Height 1
}
function Draw-Status($s, $g) {
    $x = 14
    foreach ($it in @($s.Tag.Items)) {
        if ($IconFamily) { Draw-Glyph $g (G $it.G) $IconSm $(if ($it.Hot) { TC 'Accent' } else { TC 'Muted' }) $x 0 16 $s.Height; $x += 20 }
        $tw = [Windows.Forms.TextRenderer]::MeasureText($it.T, $FontSmall).Width
        Draw-Text $g $it.T $FontSmall $(if ($it.Hot) { TC 'Text' } else { TC 'Muted' }) $x 0 ($tw + 4) $s.Height
        $x += $tw + 22
        if ($x -gt $s.Width) { break }
    }
}

$script:DrawnPaint = {
    param($s, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        switch ($s.Tag.Kind) {
            'tool' { Draw-ToolCard $s $g } 'app' { Draw-AppCard $s $g } 'tweak' { Draw-TweakCard $s $g }
            'nav' { Draw-Nav $s $g } 'tab' { Draw-Tab $s $g } 'btn' { Draw-Button $s $g } 'toggle' { Draw-Toggle $s $g }
            'logo' { Draw-Logo $s $g } 'heading' { Draw-Heading $s $g } 'inputbox' { Draw-InputBox $s $g } 'frame' { Draw-Frame $s $g }
            'progress' { Draw-Progress $s $g } 'status' { Draw-Status $s $g }
        }
    } catch { $script:PaintErrors.Add("$($s.Tag.Kind): $($_.Exception.Message)") }
}
$script:DrawnEnter = { $this.Tag.Hover = $true; $this.Invalidate() }
$script:DrawnLeave = { $this.Tag.Hover = $false; $this.Invalidate() }
$script:DrawnUp = {
    param($s, $e)
    if ($e.Button -ne [Windows.Forms.MouseButtons]::Left) { return }
    switch ($s.Tag.Kind) {
        'tool' { Invoke-Tool $s.Tag.Data }
        'app' {
            $id = $s.Tag.Data.id
            if ($script:SelectedApps.Contains($id)) { [void]$script:SelectedApps.Remove($id) } else { [void]$script:SelectedApps.Add($id) }
            $s.Invalidate(); Update-CountText; Update-NavCounts
        }
        'tweak' {
            $n = $s.Tag.Data.Name
            if ($script:SelectedTweaks.Contains($n)) { [void]$script:SelectedTweaks.Remove($n) } else { [void]$script:SelectedTweaks.Add($n) }
            $s.Invalidate(); Update-CountText
        }
        'nav' {
            $script:CurrentCategory[$script:CurrentTab] = $s.Tag.Name
            if ($txtSearch.Text) { $txtSearch.Text = '' } else { Show-Content }
            foreach ($c in $navFlow.Controls) { $c.Invalidate() }
        }
        'tab' { Select-Tab $s.Tag.Tab }
        'btn' { if ($s.Tag.OnClick) { & $s.Tag.OnClick $s } }
        'toggle' { Set-Theme $(if ($script:ThemeName -eq 'Dark') { 'Light' } else { 'Dark' }) }
    }
}
$ClickableKinds = 'tool', 'app', 'tweak', 'nav', 'tab', 'btn', 'toggle'
function New-Drawn([string]$Kind, [int]$W, [int]$H, [hashtable]$Extra = @{}, [string]$Bg = 'Bg') {
    $p = New-Object Windows.Forms.Panel
    $p.Size = New-Object Drawing.Size($W, $H); $p.Margin = New-Object Windows.Forms.Padding(0)
    $tag = @{ Role = 'drawn'; Kind = $Kind; Bg = $Bg; Hover = $false }
    foreach ($k in $Extra.Keys) { $tag[$k] = $Extra[$k] }
    $p.Tag = $tag
    Set-Smooth $p
    try { $script:ResizeRedrawProp.SetValue($p, $true, $null) } catch {}
    $p.BackColor = TC $Bg
    $p.Add_Paint($script:DrawnPaint)
    if ($ClickableKinds -contains $Kind) {
        $p.Cursor = [Windows.Forms.Cursors]::Hand
        $p.Add_MouseEnter($script:DrawnEnter); $p.Add_MouseLeave($script:DrawnLeave); $p.Add_MouseUp($script:DrawnUp)
    }
    $p
}
function New-IconButton([string]$Text, [string]$Glyph, [string]$Style = 'default', [scriptblock]$OnClick, [string]$Bg = 'Bg', [int]$H = 32) {
    $w = if ($Text) { [Windows.Forms.TextRenderer]::MeasureText($Text, $FontUI).Width + 24 + $(if ($Glyph -and $IconFamily) { 22 } else { 0 }) } else { $H }
    $b = New-Drawn 'btn' $w $H @{ Text = $Text; Glyph = $Glyph; Style = $Style; OnClick = $OnClick } $Bg
    $b.Margin = New-Object Windows.Forms.Padding(0, 0, 8, 8)
    $b
}

# Classic controls (dialogs)
function New-Label([string]$Text, [int]$X, [int]$Y, $Font, $Role) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $Text; $l.Location = New-Object Drawing.Point($X, $Y); $l.AutoSize = $true; $l.Font = $Font; $l.Tag = $Role
    $l.BackColor = [Drawing.Color]::Transparent; $l.UseMnemonic = $false
    $l
}
function New-Button([string]$Text, [int]$W = 0, $Role = 'btn') {
    $b = New-Object Windows.Forms.Button
    if ($W -le 0) { $W = [Windows.Forms.TextRenderer]::MeasureText($Text, $FontUI).Width + 26 }
    $b.Text = $Text; $b.Size = New-Object Drawing.Size($W, 32); $b.FlatStyle = 'Flat'; $b.Tag = $Role; $b.UseMnemonic = $false
    $b.Cursor = [Windows.Forms.Cursors]::Hand; $b.Margin = New-Object Windows.Forms.Padding(0, 4, 8, 4); $b.Font = $FontUI
    $b
}
function Set-CueBanner($tb, [string]$text) { try { [void][ITK.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, $text) } catch {} }

function Set-CtlTheme($c) {
    switch (Get-Role $c) {
        'drawn'   { $c.BackColor = TC $c.Tag.Bg; $c.Invalidate() }
        'bg'      { $c.BackColor = TC 'Bg'; $c.ForeColor = TC 'Text' }
        'header'  { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text' }
        'surface' { $c.BackColor = TC 'Surface'; $c.ForeColor = TC 'Text' }
        'sidebar' { $c.BackColor = TC 'Sidebar'; $c.ForeColor = TC 'Text' }
        'border'  { $c.BackColor = TC 'Border' }
        'text'    { $c.ForeColor = TC 'Text' }
        'muted'   { $c.ForeColor = TC 'Muted' }
        'check'   { $c.ForeColor = TC 'Text'; $c.BackColor = [Drawing.Color]::Transparent }
        'console' { $c.BackColor = TC 'Console'; $c.ForeColor = TC 'ConsoleText' }
        'input'   { $c.BackColor = TC 'Input'; $c.ForeColor = TC 'Text' }
        'btn'     { $c.BackColor = TC 'Card'; $c.ForeColor = TC 'Text'; $c.FlatAppearance.BorderColor = TC 'Border'; $c.FlatAppearance.MouseOverBackColor = TC 'CardHover' }
        'primary' { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText'; $c.FlatAppearance.BorderColor = TC 'Accent'; $c.FlatAppearance.MouseOverBackColor = TC 'AccentHover' }
        'banner'  { $c.BackColor = TC 'Accent'; $c.ForeColor = TC 'AccentText' }
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
        if ($i -eq 0) { [void]$sb.Append($entry.Time.ToString('HH:mm:ss') + '  ') } else { [void]$sb.Append('          ') }
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
    $d.Add_Shown({ Set-WindowChrome $this })
    $d
}
function Show-InputDialog([string]$Title, [string]$Prompt, [string]$Default) {
    $dlg = New-Dialog $Title 480 190
    $dlg.Controls.Add((New-Label $Prompt 18 16 $FontUI 'text'))
    $tb = New-Object Windows.Forms.TextBox
    $tb.Location = New-Object Drawing.Point(20, 46); $tb.Width = 424; $tb.Text = $Default; $tb.BorderStyle = 'FixedSingle'; $tb.Tag = 'input'
    $tb.Font = New-Object Drawing.Font('Segoe UI', 10.5)
    $dlg.Controls.Add($tb)
    $ok = New-Button 'Run' 88 'primary'; $ok.Location = New-Object Drawing.Point(262, 98); $ok.DialogResult = 'OK'
    $cancel = New-Button 'Cancel' 88 'btn'; $cancel.Location = New-Object Drawing.Point(356, 98); $cancel.DialogResult = 'Cancel'
    $dlg.Controls.AddRange(@($ok, $cancel)); $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    Update-Theme $dlg
    $result = $dlg.ShowDialog($form); $value = $tb.Text.Trim(); $dlg.Dispose()
    if ($result -eq 'OK') { return $value } else { return $null }
}
function Show-TextDialog([string]$Title, [string]$Text) {
    $dlg = New-Dialog $Title 700 540
    $tb = New-Object Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars = 'Vertical'; $tb.Font = $FontMono; $tb.Text = $Text
    $tb.Location = New-Object Drawing.Point(16, 16); $tb.Size = New-Object Drawing.Size(652, 410); $tb.BorderStyle = 'FixedSingle'; $tb.Tag = 'input'
    $copy = New-Button 'Copy to clipboard' 0 'primary'; $copy.Location = New-Object Drawing.Point(16, 442)
    $close = New-Button 'Close' 88 'btn'; $close.Location = New-Object Drawing.Point(580, 442); $close.DialogResult = 'Cancel'
    $copy.Add_Click({ [Windows.Forms.Clipboard]::SetText($tb.Text); $this.Text = 'Copied' })
    $dlg.Controls.AddRange(@($tb, $copy, $close)); $dlg.CancelButton = $close
    Update-Theme $dlg
    [void]$dlg.ShowDialog($form); $dlg.Dispose()
}
function Show-SettingsDialog {
    $dlg = New-Dialog 'Settings' 540 352
    $dlg.Controls.Add((New-Label 'Report title (optional - your company or client name on reports)' 18 16 $FontUI 'text'))
    $tbTitle = New-Object Windows.Forms.TextBox; $tbTitle.Location = New-Object Drawing.Point(20, 40); $tbTitle.Width = 484; $tbTitle.Text = [string]$Settings.ReportTitle; $tbTitle.BorderStyle = 'FixedSingle'; $tbTitle.Tag = 'input'
    $dlg.Controls.Add((New-Label 'Webhook URL (optional - Discord, Slack or Teams incoming webhook)' 18 80 $FontUI 'text'))
    $tbHook = New-Object Windows.Forms.TextBox; $tbHook.Location = New-Object Drawing.Point(20, 104); $tbHook.Width = 484; $tbHook.Text = [string]$Settings.WebhookUrl; $tbHook.BorderStyle = 'FixedSingle'; $tbHook.Tag = 'input'
    $cbSend = New-Object Windows.Forms.CheckBox; $cbSend.Text = 'Send ticket notes to the webhook when I close the toolkit'; $cbSend.Location = New-Object Drawing.Point(20, 140); $cbSend.AutoSize = $true; $cbSend.Checked = [bool]$Settings.SendNotesOnClose; $cbSend.Tag = 'check'
    $cbUpd = New-Object Windows.Forms.CheckBox; $cbUpd.Text = 'Check GitHub for a newer version when the toolkit starts'; $cbUpd.Location = New-Object Drawing.Point(20, 168); $cbUpd.AutoSize = $true; $cbUpd.Checked = [bool]$Settings.CheckUpdates; $cbUpd.Tag = 'check'
    $test = New-Button 'Send test message' 0 'btn'; $test.Location = New-Object Drawing.Point(20, 204)
    $test.Add_Click({ try { Send-Webhook $tbHook.Text "IT Toolkit test message from $env:COMPUTERNAME"; $this.Text = 'Sent' } catch { [void][Windows.Forms.MessageBox]::Show($dlg, $_.Exception.Message, 'Webhook failed') } })
    $dlg.Controls.Add((New-Label "Settings file: $ITK_Settings" 18 248 $FontSmall 'muted'))
    $ok = New-Button 'Save' 88 'primary'; $ok.Location = New-Object Drawing.Point(322, 268); $ok.DialogResult = 'OK'
    $cancel = New-Button 'Cancel' 88 'btn'; $cancel.Location = New-Object Drawing.Point(416, 268); $cancel.DialogResult = 'Cancel'
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
    if (-not $Quiet) { Add-LogLine 'HEAD' "> $Name" }
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
    if ($tool.SaveSessionLog -and $script:LogLines.Count) { try { [void](Save-Log 'session') } catch {} }
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
    $results = @{}
    foreach ($t in $P.Tweaks) {
        if ($P.Mode -ne 'Test') {
            try { Invoke-Tweak -Tweak $t -Mode $P.Mode; Log ('{0}: {1}' -f $(if ($P.Mode -eq 'Apply') { 'Applied' } else { 'Undone' }), $t.Name) 'OK' }
            catch { Log "$($t.Name): $($_.Exception.Message)" 'ERROR' }
        }
        $state = $null
        try { $state = Invoke-Tweak -Tweak $t -Mode Test } catch {}
        $results[$t.Name] = $state
    }
    # One event with every result, so the list redraws once instead of after every few checks
    Send-ToolkitEvent 'TweakStatusBatch' $results
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
        $msg = "Apply $($list.Count) tweak(s)?`n`nA restore point is created first.`nEvery tweak except those marked Caution can be undone from this tab."
        if ($warnings) { $msg += "`n`nCaution:`n" + (($warnings | ForEach-Object { "- $($_.Name): $($_.Warning)" }) -join "`n") }
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

# ---------------- Saved setups (apps + tweaks) ----------------
function Get-SetupDir { $d = Join-Path $Config.DataDir 'Setups'; New-Item -ItemType Directory -Path $d -Force | Out-Null; $d }
function Export-Setup {
    if (-not $script:SelectedApps.Count -and -not $script:SelectedTweaks.Count) { Add-LogLine 'WARN' 'Tick some apps (Install tab) and / or tweaks (Tweaks tab) first, then export.'; return }
    $path = $null
    try {
        $dlg = New-Object Windows.Forms.SaveFileDialog
        $dlg.Filter = 'IT Toolkit setup (*.json)|*.json'; $dlg.InitialDirectory = Get-SetupDir; $dlg.FileName = 'my-setup.json'
        if ($dlg.ShowDialog($form) -eq 'OK') { $path = $dlg.FileName } else { return }
    } catch {
        $name = Show-InputDialog 'Export setup' 'Setup name (saved in C:\ProgramData\ITToolkit\Setups)' 'my-setup'
        if (-not $name) { return }
        $path = Join-Path (Get-SetupDir) (($name -replace '[^\w\- ]', '') + '.json')
    }
    $obj = [ordered]@{
        name = [IO.Path]::GetFileNameWithoutExtension($path); created = (Get-Date -Format 's'); createdOn = $env:COMPUTERNAME
        apps = @($script:SelectedApps); tweaks = @($script:SelectedTweaks)
    }
    $obj | ConvertTo-Json -Depth 3 | Set-Content -Path $path -Encoding UTF8
    Add-LogLine 'OK' "Setup saved: $path ($($obj.apps.Count) apps, $($obj.tweaks.Count) tweaks). Use it on another PC with Import setup, or headless: -Setup '<file or URL>'."
}
function Import-Setup {
    $path = $null
    try {
        $dlg = New-Object Windows.Forms.OpenFileDialog
        $dlg.Filter = 'IT Toolkit setup (*.json)|*.json|All files (*.*)|*.*'; $dlg.InitialDirectory = Get-SetupDir
        if ($dlg.ShowDialog($form) -eq 'OK') { $path = $dlg.FileName } else { return }
    } catch {
        $path = Show-InputDialog 'Import setup' 'Path or URL of a setup .json file' (Get-SetupDir)
        if (-not $path) { return }
    }
    try {
        $data = if ($path -match '^https?://') { Invoke-RestMethod -Uri $path -TimeoutSec 20 } else { Get-Content -Path $path -Raw | ConvertFrom-Json }
        if ($data -is [string]) { $data = $data | ConvertFrom-Json }
    } catch { Add-LogLine 'ERROR' "Could not read setup: $($_.Exception.Message)"; return }
    $apps = @($data.apps | Where-Object { $_ }); $tweaks = @($data.tweaks | Where-Object { $_ })
    foreach ($a in $apps) { [void]$script:SelectedApps.Add([string]$a) }
    $unknown = @()
    foreach ($t in $tweaks) { if ($script:Tweaks.Name -contains $t) { [void]$script:SelectedTweaks.Add([string]$t) } else { $unknown += $t } }
    Add-LogLine 'OK' "Setup '$($data.name)' loaded: $($apps.Count) apps ticked on the Install tab, $($tweaks.Count - $unknown.Count) tweaks ticked on the Tweaks tab. Review them, then click Install / Apply."
    if ($unknown) { Add-LogLine 'WARN' ("Tweaks not found in this version: " + ($unknown -join ', ')) }
    $script:CurrentCategory['Install'] = 'Selected'
    Build-Nav; Show-Content
}

# =====================================================================
#  WINDOW CHROME (dark title bar, dark scrollbars, app icon)
# =====================================================================
function Set-WindowChrome($Window) {
    if (-not $Window -or -not $Window.IsHandleCreated) { return }
    try {
        $dark = [int]($script:ThemeName -eq 'Dark')
        [void][ITK.Chrome]::DwmSetWindowAttribute($Window.Handle, 20, [ref]$dark, 4)                # immersive dark title bar
        $col = TC 'Surface'; $cr = [int]$col.R -bor ([int]$col.G -shl 8) -bor ([int]$col.B -shl 16)
        [void][ITK.Chrome]::DwmSetWindowAttribute($Window.Handle, 35, [ref]$cr, 4)                  # caption colour (Windows 11)
    } catch {}
}
function Set-ScrollbarTheme {
    $themeName = if ($script:ThemeName -eq 'Dark') { 'DarkMode_Explorer' } else { 'Explorer' }
    foreach ($c in @($flow, $navFlow, $rtb)) { try { if ($c.IsHandleCreated) { [void][ITK.Chrome]::SetWindowTheme($c.Handle, $themeName, $null) } } catch {} }
}
function New-AppIcon {
    try {
        $bmp = New-Object Drawing.Bitmap(64, 64)
        $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
        Fill-Round $g (C '#2563eb') 0 0 63 63 15
        $f = if ($IconFamily) { New-Object Drawing.Font($IconFamily, 26) } else { New-Object Drawing.Font('Consolas', 22, [Drawing.FontStyle]::Bold) }
        $txt = if ($IconFamily) { G 'E756' } else { '>_' }
        $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString($txt, $f, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF(0, 2, 64, 64)), $sf)
        $g.Dispose(); $f.Dispose()
        [Drawing.Icon]::FromHandle($bmp.GetHicon())
    } catch { $null }
}

# =====================================================================
#  BUILD THE WINDOW
# =====================================================================
$form = New-Object Windows.Forms.Form
$form.Text = "$($Config.AppName) $($Config.Version) - $env:COMPUTERNAME"
$form.Size = New-Object Drawing.Size(1320, 860); $form.MinimumSize = New-Object Drawing.Size(1100, 680)
$form.StartPosition = 'CenterScreen'; $form.Font = $FontUI; $form.Tag = 'bg'; $form.KeyPreview = $true
$appIcon = New-AppIcon; if ($appIcon) { $form.Icon = $appIcon }
Set-Smooth $form

# ---- Header ----
$header = New-Object Windows.Forms.Panel; $header.Dock = 'Top'; $header.Height = 66; $header.Tag = 'header'
$logo = New-Drawn 'logo' 36 36 @{} 'Surface'; $logo.Location = New-Object Drawing.Point(18, 15)
$lblApp = New-Label $Config.AppName 64 11 $FontTitle 'text'
$subText = if ($RunAs -match 'SYSTEM$') { "$env:COMPUTERNAME  -  running as SYSTEM" } else { "Running as $RunAs" }
if (-not $IsAdmin) { $subText += '  -  not elevated' }
$lblSub = New-Label $subText 65 37 $FontSmall 'muted'
$header.Controls.AddRange(@($logo, $lblApp, $lblSub))

$titleW = [math]::Max([Windows.Forms.TextRenderer]::MeasureText($Config.AppName, $FontTitle).Width, [Windows.Forms.TextRenderer]::MeasureText($subText, $FontSmall).Width)
$tabFlow = New-Object Windows.Forms.FlowLayoutPanel
$tabFlow.Location = New-Object Drawing.Point([math]::Max(300, 64 + $titleW + 36), 15); $tabFlow.AutoSize = $true; $tabFlow.WrapContents = $false; $tabFlow.Tag = 'header'
foreach ($t in $script:Tabs) {
    $tw = [Windows.Forms.TextRenderer]::MeasureText($t, $FontNavSel).Width + 28 + $(if ($IconFamily) { 22 } else { 0 })
    $b = New-Drawn 'tab' $tw 36 @{ Tab = $t } 'Surface'
    $b.Margin = New-Object Windows.Forms.Padding(0, 0, 4, 0)
    $ToolTip.SetToolTip($b, "$t  (Ctrl+$([array]::IndexOf($script:Tabs, $t) + 1))")
    $tabFlow.Controls.Add($b)
}
$header.Controls.Add($tabFlow)

$rightArea = New-Object Windows.Forms.FlowLayoutPanel; $rightArea.Dock = 'Right'; $rightArea.Width = 170; $rightArea.Tag = 'header'
$rightArea.FlowDirection = 'RightToLeft'; $rightArea.Padding = New-Object Windows.Forms.Padding(0, 15, 14, 0); $rightArea.WrapContents = $false
$toggle = New-Drawn 'toggle' 104 36 @{} 'Surface'; $toggle.Margin = New-Object Windows.Forms.Padding(6, 0, 0, 0)
$btnSettings = New-IconButton '' 'E713' 'ghost' { Show-SettingsDialog } 'Surface' 36
$ToolTip.SetToolTip($toggle, 'Switch between dark and light')
$ToolTip.SetToolTip($btnSettings, 'Settings')
$rightArea.Controls.AddRange(@($toggle, $btnSettings))
$header.Controls.Add($rightArea)
$headerLine = New-Object Windows.Forms.Panel; $headerLine.Dock = 'Bottom'; $headerLine.Height = 1; $headerLine.Tag = 'border'
$header.Controls.Add($headerLine)

# ---- Update banner (hidden until a newer version is found) ----
$banner = New-Object Windows.Forms.Panel; $banner.Dock = 'Top'; $banner.Height = 44; $banner.Tag = 'banner'; $banner.Visible = $false
$banner.Padding = New-Object Windows.Forms.Padding(20, 6, 14, 6)
$lblBanner = New-Object Windows.Forms.Label; $lblBanner.Dock = 'Fill'; $lblBanner.TextAlign = 'MiddleLeft'; $lblBanner.Tag = 'banner'; $lblBanner.Font = $FontBold; $lblBanner.UseMnemonic = $false
$bannerBtns = New-Object Windows.Forms.FlowLayoutPanel; $bannerBtns.Dock = 'Right'; $bannerBtns.Width = 230; $bannerBtns.FlowDirection = 'RightToLeft'; $bannerBtns.Tag = 'banner'; $bannerBtns.WrapContents = $false
$btnBannerLater = New-IconButton 'Later' '' 'banner' { $banner.Visible = $false } 'Accent' 32
$btnBannerUpdate = New-IconButton 'Update now' 'E896' 'banner' {
    $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm '$($Config.InstallUrl)' | iex"
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd
    $form.Close()
} 'Accent' 32
$bannerBtns.Controls.AddRange(@($btnBannerLater, $btnBannerUpdate))
$banner.Controls.AddRange(@($bannerBtns, $lblBanner)); $lblBanner.BringToFront()

# ---- Sidebar ----
$sidebar = New-Object Windows.Forms.Panel; $sidebar.Dock = 'Left'; $sidebar.Width = 236; $sidebar.Tag = 'sidebar'
$sidebar.Padding = New-Object Windows.Forms.Padding(12, 16, 8, 12)
$navFlow = New-Object Windows.Forms.FlowLayoutPanel; $navFlow.Dock = 'Fill'; $navFlow.FlowDirection = 'TopDown'
$navFlow.WrapContents = $false; $navFlow.AutoScroll = $true; $navFlow.Tag = 'sidebar'
Set-Smooth $navFlow
$sideLine = New-Object Windows.Forms.Panel; $sideLine.Dock = 'Right'; $sideLine.Width = 1; $sideLine.Tag = 'border'
$sidebar.Controls.Add($navFlow); $sidebar.Controls.Add($sideLine); $navFlow.BringToFront()

# ---- Main area ----
$main = New-Object Windows.Forms.Panel; $main.Dock = 'Fill'; $main.Tag = 'bg'; $main.Padding = New-Object Windows.Forms.Padding(22, 16, 22, 14)

$topBar = New-Object Windows.Forms.Panel; $topBar.Dock = 'Top'; $topBar.Height = 62; $topBar.Tag = 'bg'
$heading = New-Drawn 'heading' 600 52 @{ Title = ''; Sub = ''; Cat = 'All tools' } 'Bg'; $heading.Dock = 'Fill'
$searchWrap = New-Object Windows.Forms.Panel; $searchWrap.Dock = 'Right'; $searchWrap.Width = 330; $searchWrap.Tag = 'bg'; $searchWrap.Padding = New-Object Windows.Forms.Padding(0, 8, 0, 14)
$searchBox = New-Drawn 'inputbox' 330 38 @{ Glyph = 'E721' } 'Bg'; $searchBox.Dock = 'Fill'
$searchBox.Padding = New-Object Windows.Forms.Padding($(if ($IconFamily) { 34 } else { 12 }), 9, 12, 6)
$txtSearch = New-Object Windows.Forms.TextBox
$txtSearch.Dock = 'Fill'; $txtSearch.BorderStyle = 'None'; $txtSearch.Tag = 'input'; $txtSearch.Font = New-Object Drawing.Font('Segoe UI', 10.5)
$searchBox.Tag.Box = $txtSearch
$searchBox.Controls.Add($txtSearch)
$searchWrap.Controls.Add($searchBox)
$topBar.Controls.AddRange(@($searchWrap, $heading)); $heading.BringToFront()

$actionBar = New-Object Windows.Forms.FlowLayoutPanel
$actionBar.Dock = 'Top'; $actionBar.AutoSize = $true; $actionBar.AutoSizeMode = 'GrowAndShrink'; $actionBar.Tag = 'bg'
$actionBar.Padding = New-Object Windows.Forms.Padding(0, 0, 0, 6); $actionBar.Visible = $false

$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'; $split.Orientation = 'Horizontal'; $split.SplitterWidth = 10; $split.Tag = 'bg'
$split.Panel1.Tag = 'bg'; $split.Panel2.Tag = 'bg'

$flow = New-Object Windows.Forms.FlowLayoutPanel; $flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.Tag = 'bg'
$flow.Padding = New-Object Windows.Forms.Padding(0, 2, 0, 0)
Set-Smooth $flow
$split.Panel1.Controls.Add($flow)

# Console (rounded frame)
$conFrame = New-Drawn 'frame' 400 200 @{} 'Bg'; $conFrame.Dock = 'Fill'; $conFrame.Padding = New-Object Windows.Forms.Padding(8, 4, 8, 8)
$conBar = New-Object Windows.Forms.Panel; $conBar.Dock = 'Top'; $conBar.Height = 44; $conBar.Tag = 'surface'
$conTitle = New-Label 'Output' 6 13 $FontBold 'text'
$conBar.Controls.Add($conTitle)
$conButtons = New-Object Windows.Forms.FlowLayoutPanel; $conButtons.Dock = 'Right'; $conButtons.Width = 540; $conButtons.FlowDirection = 'RightToLeft'; $conButtons.Tag = 'surface'
$conButtons.Padding = New-Object Windows.Forms.Padding(0, 6, 0, 0); $conButtons.WrapContents = $false
$btnStop  = New-IconButton 'Stop' 'E71A' 'danger' {
    $active = @($script:Jobs | Where-Object { -not $_.Quiet })
    if (-not $active) { Add-LogLine 'INFO' 'Nothing is running.'; return }
    foreach ($j in $active) { $j.Stopped = $true; [void]$j.PS.BeginStop($null, $null) }
    Add-LogLine 'WARN' 'Stop requested for all running tasks.'
} 'Surface' 30
$btnClear = New-IconButton 'Clear' 'E894' 'default' { $script:LogLines.Clear(); $rtb.Clear() } 'Surface' 30
$btnSave  = New-IconButton 'Save log' 'E74E' 'default' { $f = Save-Log; Add-LogLine 'OK' "Log saved: $f" } 'Surface' 30
$btnCopy  = New-IconButton 'Copy' 'E8C8' 'default' { if ($rtb.TextLength) { [Windows.Forms.Clipboard]::SetText($rtb.Text); Add-LogLine 'OK' 'Output copied to clipboard.' } } 'Surface' 30
$btnNotes = New-IconButton 'Ticket notes' 'E70B' 'default' { Show-TicketNotes } 'Surface' 30
foreach ($b in $btnStop, $btnClear, $btnSave, $btnCopy, $btnNotes) { $b.Margin = New-Object Windows.Forms.Padding(6, 0, 0, 0) }
$conButtons.Controls.AddRange(@($btnStop, $btnClear, $btnSave, $btnCopy, $btnNotes))
$conBar.Controls.Add($conButtons)
$progress = New-Drawn 'progress' 400 2 @{} 'Surface'; $progress.Dock = 'Top'

$rtb = New-Object Windows.Forms.RichTextBox
$rtb.Dock = 'Fill'; $rtb.ReadOnly = $true; $rtb.BorderStyle = 'None'; $rtb.Font = $FontMono; $rtb.WordWrap = $false
$rtb.DetectUrls = $false; $rtb.Tag = 'console'
$rtbWrap = New-Object Windows.Forms.Panel; $rtbWrap.Dock = 'Fill'; $rtbWrap.Tag = 'console'; $rtbWrap.Padding = New-Object Windows.Forms.Padding(10, 8, 4, 4)
$rtbWrap.Controls.Add($rtb)

$cmdBar = New-Object Windows.Forms.Panel; $cmdBar.Dock = 'Bottom'; $cmdBar.Height = 50; $cmdBar.Tag = 'surface'
$cmdBar.Padding = New-Object Windows.Forms.Padding(0, 10, 0, 2)
$cmdBox = New-Drawn 'inputbox' 400 38 @{ Glyph = 'E76C' } 'Surface'; $cmdBox.Dock = 'Fill'
$cmdBox.Padding = New-Object Windows.Forms.Padding($(if ($IconFamily) { 32 } else { 12 }), 9, 10, 6)
$txtCmd = New-Object Windows.Forms.TextBox; $txtCmd.Dock = 'Fill'; $txtCmd.Font = $FontMono; $txtCmd.BorderStyle = 'None'; $txtCmd.Tag = 'input'
$cmdBox.Tag.Box = $txtCmd
$cmdBox.Controls.Add($txtCmd)
$runCmd = {
    $cmd = $txtCmd.Text.Trim(); if (-not $cmd) { return }
    $txtCmd.Clear()
    Start-UiTask -Name "PS> $cmd" -Code $cmd
}
$btnRun = New-IconButton 'Run' 'E768' 'primary' $runCmd 'Surface' 38; $btnRun.Dock = 'Right'; $btnRun.Margin = New-Object Windows.Forms.Padding(0)
$cmdGap = New-Object Windows.Forms.Panel; $cmdGap.Dock = 'Right'; $cmdGap.Width = 8; $cmdGap.Tag = 'surface'
$cmdBar.Controls.AddRange(@($btnRun, $cmdGap, $cmdBox)); $cmdBox.BringToFront()

$conFrame.Controls.AddRange(@($conBar, $progress, $cmdBar, $rtbWrap)); $rtbWrap.BringToFront()
$split.Panel2.Controls.Add($conFrame)

$main.Controls.AddRange(@($actionBar, $topBar, $split)); $split.BringToFront()

# ---- Status bar ----
$status = New-Object Windows.Forms.Panel; $status.Dock = 'Bottom'; $status.Height = 28; $status.Tag = 'sidebar'
$statusBar = New-Drawn 'status' 600 27 @{ Items = @() } 'Sidebar'; $statusBar.Dock = 'Fill'
$statusLine = New-Object Windows.Forms.Panel; $statusLine.Dock = 'Top'; $statusLine.Height = 1; $statusLine.Tag = 'border'
$status.Controls.Add($statusBar); $status.Controls.Add($statusLine); $statusBar.BringToFront()

$form.Controls.AddRange(@($main, $sidebar, $banner, $header, $status)); $main.BringToFront()

# =====================================================================
#  VIEWS
# =====================================================================
$animTimer = New-Object Windows.Forms.Timer; $animTimer.Interval = 30
$animTimer.Add_Tick({ $script:AnimPos += 9; $progress.Invalidate() })

function Update-Status {
    $up = (Get-Date) - $OsInfo.LastBootUpTime
    $running = @($script:Jobs | Where-Object { -not $_.Quiet }).Count
    $statusBar.Tag.Items = @(
        @{ G = 'E7F8'; T = $env:COMPUTERNAME }
        @{ G = 'E770'; T = "$($OsInfo.Caption -replace '^Microsoft ', '') $OsVersion" }
        @{ G = 'E968'; T = $MainIP }
        @{ G = 'E77B'; T = $ConsoleUser }
        @{ G = 'E823'; T = ('Up {0}d {1}h' -f $up.Days, $up.Hours) }
        @{ G = 'E9F5'; T = $(if ($running) { "$running running" } else { 'Idle' }); Hot = [bool]$running }
    )
    $statusBar.Invalidate()
    if ($running) { if (-not $animTimer.Enabled) { $animTimer.Start() } } else { $animTimer.Stop(); $progress.Invalidate() }
}

function Set-Theme([string]$Name) {
    $script:ThemeName = $Name
    $script:ColorCache = @{}
    $form.SuspendLayout(); Update-Theme $form; $form.ResumeLayout()
    Set-WindowChrome $form
    Set-ScrollbarTheme
    Update-Console
    $Settings.Theme = $Name; Save-ToolkitSettings $Settings
}

# ---- Cards ----
$cardMenu = New-Object Windows.Forms.ContextMenuStrip
$menuFav = $cardMenu.Items.Add('Add to favourites')
$menuRun = $cardMenu.Items.Add('Run')
$cardMenu.Add_Opening({
    $tool = $cardMenu.SourceControl.Tag.Data
    $menuFav.Text = if ($Settings.Favorites -contains $tool.Name) { 'Remove from favourites' } else { 'Add to favourites' }
    $cardMenu.BackColor = TC 'Surface'; $cardMenu.ForeColor = TC 'Text'
})
$menuRun.Add_Click({ Invoke-Tool $cardMenu.SourceControl.Tag.Data })
$menuFav.Add_Click({
    $card = $cardMenu.SourceControl; $tool = $card.Tag.Data
    if ($Settings.Favorites -contains $tool.Name) { $Settings.Favorites = @($Settings.Favorites | Where-Object { $_ -ne $tool.Name }) }
    else { $Settings.Favorites = @($Settings.Favorites) + $tool.Name }
    Save-ToolkitSettings $Settings
    $card.Invalidate(); Update-NavCounts
    if ($script:CurrentCategory[$script:CurrentTab] -eq 'Favourites') { Show-Content -KeepScroll }
})

function New-ToolCard($tool) {
    $c = New-Drawn 'tool' 280 80 @{ Data = $tool } 'Bg'
    $c.Margin = New-Object Windows.Forms.Padding(0, 0, 12, 12)
    $c.ContextMenuStrip = $cardMenu
    $tip = "$($tool.Description)`n`n$($tool.Category)"; if ($tool.Confirm) { $tip += " - asks before running" }; $tip += "`nRight-click to add to favourites"
    $ToolTip.SetToolTip($c, $tip)
    $c
}
function New-AppItem($app) {
    $c = New-Drawn 'app' 260 62 @{ Data = $app } 'Bg'
    $c.Margin = New-Object Windows.Forms.Padding(0, 0, 12, 12)
    $ToolTip.SetToolTip($c, "$($app.description)`n`n$($app.category) - winget ID $($app.id)")
    $c
}
function New-TweakItem($tw) {
    $c = New-Drawn 'tweak' 420 72 @{ Data = $tw } 'Bg'
    $c.Margin = New-Object Windows.Forms.Padding(0, 0, 12, 12)
    $tip = "$($tw.Description)`n`n$($tw.Category)"; if ($tw.Warning) { $tip += "`nCaution: $($tw.Warning)" }; if ($tw.NoUndo) { $tip += "`nCannot be undone automatically." }
    $ToolTip.SetToolTip($c, $tip)
    $c
}

# Cards stretch to fill each row, so the grid flows with the window width
function Update-CardWidths {
    if ($script:InWidthUpdate) { return }
    $cards = @($flow.Controls | Where-Object { $_.Tag -is [hashtable] -and $_.Tag.Kind -in 'tool', 'app', 'tweak' })
    if (-not $cards) { return }
    $script:InWidthUpdate = $true
    try {
        $min = switch ($cards[0].Tag.Kind) { 'tweak' { 400 } 'app' { 250 } default { 270 } }
        $gap = 12
        $avail = $flow.ClientSize.Width - $flow.Padding.Horizontal - 2
        $n = [math]::Max(1, [math]::Floor(($avail + $gap) / ($min + $gap)))
        $w = [int][math]::Floor(($avail - $gap * $n) / $n)
        if ($w -lt 200) { $w = 200 }
        if ($cards[0].Width -ne $w) {
            $flow.SuspendLayout()
            foreach ($c in $cards) { $c.Width = $w }
            $flow.ResumeLayout()
        }
    } finally { $script:InWidthUpdate = $false }
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
    $navW = $navFlow.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth - 2
    $hdr = New-Label 'Categories' 6 0 $FontSmall 'muted'; $hdr.Margin = New-Object Windows.Forms.Padding(8, 0, 0, 8)
    $navFlow.Controls.Add($hdr)
    foreach ($item in (Get-NavItems)) {
        $b = New-Drawn 'nav' $navW 38 @{ Name = $item.Name; Count = $item.Count } 'Sidebar'
        $b.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 2)
        $navFlow.Controls.Add($b)
    }
    Update-Theme $navFlow
    $navFlow.ResumeLayout()
}
function Update-NavCounts {
    $counts = @{}; foreach ($i in (Get-NavItems)) { $counts[$i.Name] = $i.Count }
    foreach ($c in $navFlow.Controls) { if ($c.Tag -is [hashtable] -and $c.Tag.Kind -eq 'nav' -and $counts.ContainsKey($c.Tag.Name) -and $c.Tag.Count -ne $counts[$c.Tag.Name]) { $c.Tag.Count = $counts[$c.Tag.Name]; $c.Invalidate() } }
}

# ---- Presets menu (Install tab) ----
$presetMenu = New-Object Windows.Forms.ContextMenuStrip
$presetMenu.ShowImageMargin = $false
$presetMenu.Font = $FontUI
$presetMenu.Add_Opening({
    $presetMenu.Items.Clear()
    $presetMenu.BackColor = TC 'Surface'; $presetMenu.ForeColor = TC 'Text'
    $names = @($script:Presets.Keys)
    if ($Settings.SavedPreset.Count) { $names += 'My saved preset' }
    foreach ($n in $names) {
        $ids = if ($n -eq 'My saved preset') { @($Settings.SavedPreset) } else { @($script:Presets[$n]) }
        $mi = $presetMenu.Items.Add("$n  ($($ids.Count) apps)")
        $mi.Tag = $n; $mi.ForeColor = TC 'Text'
        $mi.Add_Click({
            $name = [string]$this.Tag
            $ids = if ($name -eq 'My saved preset') { $Settings.SavedPreset } else { $script:Presets[$name] }
            foreach ($id in $ids) { [void]$script:SelectedApps.Add($id) }
            Add-LogLine 'INFO' "Preset '$name' added to the selection ($(@($ids).Count) apps)."
            $script:CurrentCategory['Install'] = 'Selected'
            Build-Nav; Show-Content
        })
    }
})

# ---- Action bar per tab ----
function Build-ActionBar {
    $actionBar.SuspendLayout()
    $old = @($actionBar.Controls); $actionBar.Controls.Clear(); $old | ForEach-Object { $_.Dispose() }
    switch ($script:CurrentTab) {
        'Install' {
            $presetBtn = New-IconButton 'Add a preset' 'E710' 'default' { param($b) $presetMenu.Show($b, 0, $b.Height + 2) }
            $actionBar.Controls.AddRange(@(
                (New-IconButton 'Install / upgrade selected' 'E896' 'primary' { Invoke-AppAction Install })
                (New-IconButton 'Uninstall selected' 'E74D' 'danger' { Invoke-AppAction Uninstall })
                (New-IconButton 'Upgrade all apps' 'E898' 'default' { Invoke-AppAction UpgradeAll })
                (New-IconButton 'Check installed' 'E930' 'default' { Invoke-AppAction Check })
                (New-IconButton 'Clear selection' 'E894' 'default' { $script:SelectedApps.Clear(); Build-Nav; Show-Content })
                $presetBtn
                (New-IconButton 'Save as my preset' 'E74E' 'default' {
                    $Settings.SavedPreset = @($script:SelectedApps); Save-ToolkitSettings $Settings
                    Add-LogLine 'OK' "Saved $($Settings.SavedPreset.Count) apps as 'My saved preset'."
                })
                (New-IconButton 'Export setup' 'E72D' 'default' { Export-Setup })
                (New-IconButton 'Import setup' 'E8B5' 'default' { Import-Setup })
            ))
            $actionBar.Visible = $true
        }
        'Tweaks' {
            $actionBar.Controls.AddRange(@(
                (New-IconButton 'Apply selected' 'E73E' 'primary' { Invoke-Tweaks -Mode Apply -Names @($script:SelectedTweaks) })
                (New-IconButton 'Undo selected' 'E7A7' 'default' { Invoke-Tweaks -Mode Revert -Names @($script:SelectedTweaks) })
                (New-IconButton 'Check status' 'E9D9' 'default' { Invoke-Tweaks -Mode Test -Names @($script:Tweaks.Name) })
                (New-IconButton 'Select recommended' 'E8E1' 'default' { foreach ($t in ($script:Tweaks | Where-Object Recommended)) { [void]$script:SelectedTweaks.Add($t.Name) }; Show-Content -KeepScroll })
                (New-IconButton 'Clear selection' 'E894' 'default' { $script:SelectedTweaks.Clear(); Show-Content -KeepScroll })
                (New-IconButton 'Create restore point' 'E777' 'default' { Start-UiTask -Name 'Create restore point' -Code "[void](New-ToolkitRestorePoint 'IT Toolkit - manual')" })
                (New-IconButton 'Export setup' 'E72D' 'default' { Export-Setup })
                (New-IconButton 'Import setup' 'E8B5' 'default' { Import-Setup })
            ))
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
    $heading.Tag.Sub = switch ($script:CurrentTab) {
        'Install' { '{0} apps  -  {1} selected  -  {2} installed' -f $script:LastCount, $script:SelectedApps.Count, $(if ($script:InstalledChecked) { $script:InstalledApps.Count } else { 'not checked yet' }) }
        'Tweaks'  { '{0} tweaks  -  {1} selected  -  a restore point is made before applying' -f $script:LastCount, $script:SelectedTweaks.Count }
        default   { '{0} tool{1}  -  click to run, right-click to favourite' -f $script:LastCount, $(if ($script:LastCount -eq 1) { '' } else { 's' }) }
    }
    $heading.Invalidate()
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
    $heading.Tag.Title = if ($q) { "Results for '$q'" } else { $cat }
    $heading.Tag.Cat = if ($q) { 'Search' } else { $cat }
    $script:LastCount = $items.Count
    $script:Rendering = $true
    $scroll = -$flow.AutoScrollPosition.Y
    $flow.SuspendLayout()
    $old = @($flow.Controls); $flow.Controls.Clear(); $old | ForEach-Object { $ToolTip.SetToolTip($_, $null); $_.Dispose() }
    foreach ($it in $items) {
        $ctl = switch ($script:CurrentTab) { 'Install' { New-AppItem $it } 'Tweaks' { New-TweakItem $it } default { New-ToolCard $it } }
        $flow.Controls.Add($ctl)
    }
    if (-not $items.Count) {
        $msg = if ($q) { "Nothing matches '$q'. Try a shorter word, or clear the search to see everything." }
               elseif ($script:CurrentTab -eq 'Tools' -and $cat -eq 'Favourites') { 'No favourites yet. Right-click any tool and choose "Add to favourites".' }
               elseif ($script:CurrentTab -eq 'Tools' -and $cat -eq 'Recent') { 'Tools you run will show up here.' }
               elseif ($script:CurrentTab -eq 'Install' -and $cat -eq 'Selected') { 'Tick apps in any category, or add a preset, and they collect here.' }
               elseif ($script:CurrentTab -eq 'Install' -and $cat -eq 'Installed' -and -not $script:InstalledChecked) { 'Click "Check installed" to see which apps are on this PC.' }
               else { 'Nothing here yet.' }
        $l = New-Label $msg 4 4 $FontUI 'muted'; $l.Margin = New-Object Windows.Forms.Padding(4, 8, 0, 0)
        $flow.Controls.Add($l)
    }
    Update-Theme $flow
    $flow.ResumeLayout()
    Update-CardWidths
    if ($KeepScroll -and $scroll -gt 0) { try { $flow.AutoScrollPosition = New-Object Drawing.Point(0, $scroll) } catch {} }
    $script:Rendering = $false
    Update-CountText
}

function Select-Tab([string]$Tab) {
    $script:CurrentTab = $Tab
    $script:Rendering = $true; $txtSearch.Text = ''; $script:Rendering = $false
    $form.SuspendLayout()
    Build-Nav; Build-ActionBar; Show-Content
    $form.ResumeLayout()
    foreach ($c in $tabFlow.Controls) { $c.Invalidate() }
    if ($Tab -eq 'Install' -and -not $script:InstalledChecked) { $script:InstalledChecked = $true; Invoke-AppAction Check }
    if ($Tab -eq 'Tweaks' -and -not $script:TweakChecked) { $script:TweakChecked = $true; Invoke-Tweaks -Mode Test -Names @($script:Tweaks.Name) -Quiet }
}

# =====================================================================
#  EVENTS
# =====================================================================
$txtSearch.Add_TextChanged({ if (-not $script:Rendering) { Show-Content; foreach ($c in $navFlow.Controls) { $c.Invalidate() } } })
foreach ($tb in $txtSearch, $txtCmd) {
    $tb.Add_GotFocus({ $this.Parent.Invalidate() }); $tb.Add_LostFocus({ $this.Parent.Invalidate() })
}
$flow.Add_Resize({ Update-CardWidths })
$txtCmd.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true; & $runCmd } })
$form.Add_KeyDown({
    param($s, $e)
    if ($e.Control -and $e.KeyCode -eq 'F') { $txtSearch.Focus(); $txtSearch.SelectAll(); $e.SuppressKeyPress = $true }
    elseif ($e.Control -and $e.KeyCode -ge 'D1' -and $e.KeyCode -le 'D4') { Select-Tab $script:Tabs[[int]$e.KeyCode - [int][Windows.Forms.Keys]::D1]; $e.SuppressKeyPress = $true }
    elseif ($e.KeyCode -eq 'Escape' -and $txtSearch.Focused -and $txtSearch.Text) { $txtSearch.Text = ''; $e.SuppressKeyPress = $true }
})

$timer = New-Object Windows.Forms.Timer; $timer.Interval = 150
$script:TickHandler = {
    $item = $null; $n = 0; $refreshTweaks = $false; $refreshApps = $false
    while ($n -lt 300 -and $Queue.TryDequeue([ref]$item)) {
        $n++
        $job = $script:JobIndex[$item.JobId]
        if ($item.Level -eq 'EVENT') {
            switch ($item.Type) {
                'TweakStatus'      { $script:TweakState[$item.Data.Name] = $item.Data.Applied; $refreshTweaks = $true }
                'TweakStatusBatch' { foreach ($k in $item.Data.Keys) { $script:TweakState[$k] = $item.Data[$k] }; $refreshTweaks = $true }
                'AppsInstalled'    { $script:InstalledApps.Clear(); foreach ($id in @($item.Data)) { [void]$script:InstalledApps.Add([string]$id) }; $script:InstalledChecked = $true; $refreshApps = $true }
                'UpdateAvailable'  { $lblBanner.Text = "IT Toolkit $($item.Data) is available - you have $($Config.Version)."; $banner.Visible = $true }
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
    if ($refreshTweaks -and $script:CurrentTab -eq 'Tweaks') { foreach ($c in $flow.Controls) { $c.Invalidate() } }
    if ($refreshApps) { Update-NavCounts; if ($script:CurrentTab -eq 'Install') { Show-Content -KeepScroll } }
}
$timer.Add_Tick($script:TickHandler)

$form.Add_HandleCreated({ Set-WindowChrome $form })
$form.Add_Shown({
    Set-WindowChrome $form
    Set-ScrollbarTheme
    Set-CueBanner $txtSearch 'Search this tab  (Ctrl+F)'
    Set-CueBanner $txtCmd 'Run any PowerShell command'
    $split.Panel1MinSize = 140; $split.Panel2MinSize = 170
    $split.SplitterDistance = [int]($split.Height * 0.6)
    Update-CardWidths
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
    $timer.Stop(); $animTimer.Stop()
    foreach ($j in @($script:Jobs)) { try { $j.PS.Stop(); $j.PS.Dispose() } catch {} }
    if ($script:LogLines.Count -gt 2) { try { [void](Save-Log 'session') } catch {} }
    if ($Settings.WebhookUrl -and $Settings.SendNotesOnClose -and $script:History.Count) { try { Send-Webhook $Settings.WebhookUrl (Get-TicketNotes) } catch {} }
    Save-ToolkitSettings $Settings
})

# =====================================================================
#  GO
# =====================================================================
Update-Theme $form
if ($UiTest) { $script:InstalledChecked = $true; $script:TweakChecked = $true }   # no background checks in the self-test
Select-Tab 'Tools'
Update-Status
Add-LogLine 'HEAD' ("{0} {1} ready - {2} tools, {3} apps, {4} tweaks{5}." -f $Config.AppName, $Config.Version, $script:Tools.Count, $script:Apps.Count, $script:Tweaks.Count, $(if ($PluginToolCount) { " ($PluginToolCount from the Tools folder)" } else { '' }))
Add-LogLine 'INFO' "Logs, reports and settings: $($Config.DataDir)    Ctrl+1-4 switch tabs, Ctrl+F search."
if (-not $IsAdmin) { Add-LogLine 'WARN' 'Not running elevated - many tools need admin rights.' }
foreach ($err in $script:LoadErrors) { Add-LogLine 'ERROR' "Failed to load $err" }

# ---------------------------------------------------------------------
#  UI self-test (-UiTest): builds every view in both themes off-screen,
#  paints it to a bitmap and fails on any error. Used by CI on Windows.
# ---------------------------------------------------------------------
if ($UiTest) {
    $script:UiFailures = New-Object System.Collections.Generic.List[string]
    $ErrorActionPreference = 'Stop'
    function Test-UiStep([string]$Name, [scriptblock]$Do) {
        try { & $Do; Write-Host "  ok    $Name" -ForegroundColor Green }
        catch { $script:UiFailures.Add("$Name - $($_.Exception.Message)"); Write-Host "  FAIL  $Name - $($_.Exception.Message)" -ForegroundColor Red }
    }
    $saved = @{ Theme = $Settings.Theme; Favorites = @($Settings.Favorites); Recent = @($Settings.Recent); CheckUpdates = $Settings.CheckUpdates }
    $Settings.CheckUpdates = $false
    # Show the window fully transparent and off-screen so every control gets a real handle and paints
    $form.StartPosition = 'Manual'; $form.Location = New-Object Drawing.Point(-30000, -30000); $form.ShowInTaskbar = $false; $form.Opacity = 0
    $form.Show(); [Windows.Forms.Application]::DoEvents()
    $form.PerformLayout()
    $script:TestBmp = New-Object Drawing.Bitmap(1900, 1200)
    $render = {
        [Windows.Forms.Application]::DoEvents()
        $form.DrawToBitmap($script:TestBmp, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
        if ($script:PaintErrors.Count) { $m = ($script:PaintErrors | Select-Object -Unique) -join '; '; $script:PaintErrors.Clear(); throw "paint error: $m" }
    }
    Write-Host "UI test: icon font = $(if ($IconFamily) { $IconFamily } else { 'none (letters used instead)' })"
    foreach ($theme in 'Dark', 'Light') {
        Test-UiStep "$theme theme" { Set-Theme $theme; & $render }
        foreach ($tab in $script:Tabs) {
            Test-UiStep "$theme / $tab" { Select-Tab $tab; & $render }
            foreach ($navItem in @(Get-NavItems)) {
                Test-UiStep "$theme / $tab / $($navItem.Name)" { $script:CurrentCategory[$tab] = $navItem.Name; Show-Content; & $render }
            }
        }
    }
    Test-UiStep 'Search and empty state' { Select-Tab 'Tools'; $txtSearch.Text = 'disk'; & $render; $txtSearch.Text = 'zzzz-no-match'; & $render; $txtSearch.Text = '' }
    Test-UiStep 'Select apps and tweaks' {
        [void]$script:SelectedApps.Add('7zip.7zip'); [void]$script:SelectedTweaks.Add('Show file extensions')
        Select-Tab 'Install'; & $render; Select-Tab 'Tweaks'; & $render
    }
    Test-UiStep 'Presets menu' {
        Select-Tab 'Install'; $presetMenu.Show($form, 10, 10); [Windows.Forms.Application]::DoEvents()
        if ($presetMenu.Items.Count -lt 1) { throw 'no presets listed' }
        $presetMenu.Items[0].PerformClick(); $presetMenu.Close()
        if ($script:SelectedApps.Count -lt 2) { throw 'preset did not tick any apps' }
        & $render
    }
    Test-UiStep 'Favourite and recent' { $Settings.Favorites = @('Disk space'); $Settings.Recent = @('System summary'); Select-Tab 'Tools'; $script:CurrentCategory['Tools'] = 'Favourites'; Show-Content; & $render }
    Test-UiStep 'Resize (cards flow)' { foreach ($w in 1100, 1400, 1900) { $form.Width = $w; $form.PerformLayout(); Update-CardWidths; & $render } }
    Test-UiStep 'Background events' {
        $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = 'EVENT'; Text = ''; JobId = 0; Type = 'TweakStatusBatch'; Data = @{ 'Show file extensions' = $true; 'Dark mode' = $false } })
        $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = 'EVENT'; Text = ''; JobId = 0; Type = 'AppsInstalled'; Data = @('7zip.7zip') })
        $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = 'EVENT'; Text = ''; JobId = 0; Type = 'UpdateAvailable'; Data = '99.0.0' })
        $Queue.Enqueue([pscustomobject]@{ Time = (Get-Date); Level = 'WARN'; Text = 'test warning'; JobId = 0; Type = $null; Data = $null })
        & $script:TickHandler; Select-Tab 'Tweaks'; & $render; Select-Tab 'Install'; & $render
    }
    Test-UiStep 'Running indicator and status' { $script:ForceProgress = $true; $script:AnimPos = 120; Update-Status; & $render; $script:ForceProgress = $false }
    Test-UiStep 'Console and ticket notes' { Add-LogLine 'OK' 'ui test'; Update-Console; [void](Get-TicketNotes) }
    # Optional screenshots for review (CI sets ITK_UITEST_SHOTS)
    if ($env:ITK_UITEST_SHOTS) {
        Test-UiStep 'Screenshots' {
            New-Item -ItemType Directory -Path $env:ITK_UITEST_SHOTS -Force | Out-Null
            $form.Width = 1400; $form.Height = 880; $form.PerformLayout(); $banner.Visible = $false
            $txtSearch.Text = ''
            $shots = @(
                @{ Theme = 'Dark'; Tab = 'Tools'; Cat = 'Disk & Cleanup' }, @{ Theme = 'Light'; Tab = 'Tools'; Cat = 'All tools' }
                @{ Theme = 'Dark'; Tab = 'Install'; Cat = 'Browsers' }, @{ Theme = 'Light'; Tab = 'Tweaks'; Cat = 'Essential' }
                @{ Theme = 'Dark'; Tab = 'Tweaks'; Cat = 'Recommended' }, @{ Theme = 'Light'; Tab = 'Updates'; Cat = 'All' }
            )
            foreach ($sh in $shots) {
                Set-Theme $sh.Theme; Select-Tab $sh.Tab; $script:CurrentCategory[$sh.Tab] = $sh.Cat; Show-Content
                foreach ($c in $navFlow.Controls) { $c.Invalidate() }
                [Windows.Forms.Application]::DoEvents()
                $bmp = New-Object Drawing.Bitmap($form.Width, $form.Height)
                $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
                $bmp.Save((Join-Path $env:ITK_UITEST_SHOTS ('{0}-{1}.png' -f $sh.Theme, $sh.Tab)), [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
            }
        }
    }
    $script:TestBmp.Dispose()
    $script:UiTestExitCode = [int]($script:UiFailures.Count -gt 0)
    if ($script:UiFailures.Count) { Write-Host "UI test failed: $($script:UiFailures.Count) step(s)." -ForegroundColor Red } else { Write-Host 'UI test passed.' -ForegroundColor Green }
    $ErrorActionPreference = 'Continue'
    $Settings.Theme = $saved.Theme; $Settings.Favorites = $saved.Favorites; $Settings.Recent = $saved.Recent; $Settings.CheckUpdates = $saved.CheckUpdates
    $script:LogLines.Clear()          # don't save a session log for the test
    $form.Close(); $form.Dispose()
    $timer.Dispose(); $animTimer.Dispose()
    return
}

[void]$form.ShowDialog()
$form.Dispose()
