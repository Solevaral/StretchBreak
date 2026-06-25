param([switch]$TestNow)   # -TestNow: показать заглушку сразу один раз и выйти

# ============================================================
#  StretchBreak — напоминание о разминке (трей-приложение)
#  Тёмный современный UI на WinForms. Без установок.
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- WinAPI: активное окно / процесс ----------
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern IntPtr GetDesktopWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetShellWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
'@

# ---------- Пути и настройки ----------
# Надёжное определение папки и для .ps1, и для скомпилированного .exe (ps2exe)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot }
    elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
    else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$SettingsPath = Join-Path $ScriptDir 'settings.json'

$DefaultSettings = [ordered]@{
    IntervalMinutes = 60
    BreakSeconds    = 35
    ToastEverySec   = 10
    GameProcesses   = @('GTA5','GTA6','RDR2','cs2','Dota2','VALORANT-Win64-Shipping')
    HardMode        = $false
    Autostart       = $false
    Sound           = $false
    Paused          = $false
}

function Copy-Defaults {
    $c = [ordered]@{}
    foreach ($k in $DefaultSettings.Keys) { $c[$k] = $DefaultSettings[$k] }
    return $c
}

function Load-Settings {
    if (Test-Path $SettingsPath) {
        try {
            $j = Get-Content $SettingsPath -Raw | ConvertFrom-Json
            $s = [ordered]@{}
            foreach ($k in $DefaultSettings.Keys) {
                if ($null -ne $j.$k) { $s[$k] = $j.$k } else { $s[$k] = $DefaultSettings[$k] }
            }
            # массив игр приводим к [string[]]
            $s.GameProcesses = @($s.GameProcesses)
            return $s
        } catch { return Copy-Defaults }
    }
    return Copy-Defaults
}

function Save-Settings {
    $script:Settings | ConvertTo-Json | Set-Content $SettingsPath -Encoding UTF8
}

$script:Settings = Load-Settings

# ---------- Палитра ----------
$clrBg      = [System.Drawing.Color]::FromArgb(24, 24, 37)
$clrPanel   = [System.Drawing.Color]::FromArgb(34, 34, 52)
$clrPanel2  = [System.Drawing.Color]::FromArgb(44, 44, 66)
$clrAccent  = [System.Drawing.Color]::FromArgb(124, 92, 255)
$clrAccent2 = [System.Drawing.Color]::FromArgb(96, 200, 255)
$clrText    = [System.Drawing.Color]::FromArgb(232, 232, 245)
$clrMuted   = [System.Drawing.Color]::FromArgb(150, 150, 175)
$clrDanger  = [System.Drawing.Color]::FromArgb(230, 90, 110)

function Font([single]$size, [string]$style = 'Regular') {
    New-Object System.Drawing.Font('Segoe UI', $size, [System.Drawing.FontStyle]::$style)
}

# ---------- Хелперы UI ----------
function New-FlatButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H,
          [System.Drawing.Color]$Back, [System.Drawing.Color]$Fore, [single]$FontSize = 10)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.SetBounds($X, $Y, $W, $H)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $Back
    $b.ForeColor = $Fore
    $b.Font = Font $FontSize 'Bold'
    $b.Cursor = 'Hand'
    $hover = [System.Drawing.Color]::FromArgb(
        [Math]::Min(255, $Back.R + 28), [Math]::Min(255, $Back.G + 28), [Math]::Min(255, $Back.B + 28))
    $b.Add_MouseEnter({ $this.BackColor = $hover }.GetNewClosure())
    $b.Add_MouseLeave({ $this.BackColor = $Back }.GetNewClosure())
    return $b
}

function Set-RoundedRegion {
    param($Control, [int]$Radius)
    $d = $Radius * 2
    $w = $Control.Width; $h = $Control.Height
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc(0, 0, $d, $d, 180, 90)
    $p.AddArc($w - $d, 0, $d, $d, 270, 90)
    $p.AddArc($w - $d, $h - $d, $d, $d, 0, 90)
    $p.AddArc(0, $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $Control.Region = New-Object System.Drawing.Region($p)
}

# Общий обработчик степперов: всё берёт из $this.Tag, пишет в реальный $script:Settings
$script:StepHandler = {
    $d = $this.Tag
    $new = [int]$script:Settings[$d.Key] + ($d.Dir * $d.Step)
    $new = [Math]::Max($d.Min, [Math]::Min($d.Max, $new))
    $script:Settings[$d.Key] = $new
    $d.Val.Text = "$new $($d.Suffix)"
}

# Кастомный степпер: − [значение] +  ; пишет прямо в $Settings[$Key]
function New-Stepper {
    param($Parent, [int]$X, [int]$Y, [string]$Title, [string]$Key,
          [int]$Min, [int]$Max, [int]$Step, [string]$Suffix)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Title
    $lbl.ForeColor = $clrText
    $lbl.Font = Font 11
    $lbl.SetBounds($X, $Y + 6, 280, 24)
    $Parent.Controls.Add($lbl)

    $bx = $X + 360
    $minus = New-FlatButton '−' $bx $Y 38 38 $clrPanel2 $clrText 14
    $plus  = New-FlatButton '+' ($bx + 168) $Y 38 38 $clrPanel2 $clrText 14

    $val = New-Object System.Windows.Forms.Label
    $val.TextAlign = 'MiddleCenter'
    $val.ForeColor = $clrAccent2
    $val.Font = Font 12 'Bold'
    $val.BackColor = $clrPanel
    $val.SetBounds($bx + 42, $Y, 122, 38)
    $val.Text = "$([int]$script:Settings[$Key]) $Suffix"

    $minus.Tag = @{ Key=$Key; Min=$Min; Max=$Max; Step=$Step; Suffix=$Suffix; Val=$val; Dir=-1 }
    $plus.Tag  = @{ Key=$Key; Min=$Min; Max=$Max; Step=$Step; Suffix=$Suffix; Val=$val; Dir= 1 }
    $minus.Add_Click($script:StepHandler)
    $plus.Add_Click($script:StepHandler)

    $Parent.Controls.AddRange(@($minus, $val, $plus))
}

# ---------- Иконка приложения ----------
function New-AppIcon {
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush($clrAccent)), 1, 1, 30, 30)
    $f = Font 16 'Bold'
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString('S', $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0,0,32,32)), $sf)
    $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$AppIcon = New-AppIcon

# ---------- Определение игры ----------
function Test-GameActive {
    $hwnd = [Win32]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) { return $false }
    if ($hwnd -eq [Win32]::GetDesktopWindow()) { return $false }
    if ($hwnd -eq [Win32]::GetShellWindow())   { return $false }

    $procId = [uint32]0
    [void][Win32]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    if ($procId -ne 0) {
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($p -and ($script:Settings.GameProcesses -contains $p.ProcessName)) { return $true }
    }

    $rect = New-Object Win32+RECT
    [void][Win32]::GetWindowRect($hwnd, [ref]$rect)
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {
        $b = $scr.Bounds
        if ($w -ge $b.Width -and $h -ge $b.Height -and $rect.Left -le $b.X -and $rect.Top -le $b.Y) {
            return $true
        }
    }
    return $false
}

# ---------- Заглушка на всех мониторах ----------
function Show-BreakOverlay {
    param([int]$Seconds)
    if ($script:Settings.Sound) { try { [System.Media.SystemSounds]::Asterisk.Play() } catch {} }

    $forms = @(); $counts = @()
    $screens = [System.Windows.Forms.Screen]::AllScreens |
               Sort-Object -Property @{ Expression = { -not $_.Primary } }

    foreach ($scr in $screens) {
        $b = $scr.Bounds
        $f = New-Object System.Windows.Forms.Form
        $f.FormBorderStyle = 'None'; $f.TopMost = $true
        $f.BackColor = [System.Drawing.Color]::FromArgb(15, 16, 28)
        $f.ShowInTaskbar = $false; $f.Cursor = 'Hand'
        $f.StartPosition = 'Manual'; $f.Bounds = $b

        $title = New-Object System.Windows.Forms.Label
        $title.Text = "ПЕРЕРЫВ — РАЗОМНИСЬ!"; $title.ForeColor = $clrText
        $title.Font = Font 42 'Bold'; $title.AutoSize = $true
        $f.Controls.Add($title)

        $count = New-Object System.Windows.Forms.Label
        $count.ForeColor = $clrAccent2; $count.Font = Font 90 'Bold'
        $count.AutoSize = $true; $count.Text = "$Seconds"
        $f.Controls.Add($count)

        $hint = New-Object System.Windows.Forms.Label
        $hint.Text = "Встань, потянись, посмотри вдаль. Окно закроется само."
        $hint.ForeColor = $clrMuted; $hint.Font = Font 16; $hint.AutoSize = $true
        $f.Controls.Add($hint)

        $w = $b.Width; $h = $b.Height
        $title.Left = [int]($w/2 - $title.Width/2); $title.Top = [int]($h*0.30)
        $count.Left = [int]($w/2 - $count.Width/2); $count.Top = [int]($h*0.42)
        $hint.Left  = [int]($w/2 - $hint.Width/2);  $hint.Top  = [int]($h*0.66)

        $forms += $f; $counts += $count
    }

    $script:remaining = $Seconds
    $main = $forms[0]
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 1000
    $t.Add_Tick({
        $script:remaining--
        foreach ($c in $counts) {
            $c.Text = "$script:remaining"
            $c.Left = [int]($c.Parent.ClientSize.Width/2 - $c.Width/2)
        }
        if ($script:remaining -le 0) { $t.Stop(); foreach ($x in $forms) { $x.Close() } }
    }.GetNewClosure())

    for ($i = 1; $i -lt $forms.Count; $i++) { $forms[$i].Show() }
    $main.Add_Shown({ $main.Activate(); $t.Start() })
    [void]$main.ShowDialog()
    $t.Dispose(); foreach ($x in $forms) { $x.Dispose() }
}

# ---------- Уведомление ----------
function Show-Toast {
    param([string]$Text, [string]$Title = "Пора отдохнуть")
    $script:Tray.BalloonTipTitle = $Title
    $script:Tray.BalloonTipText  = $Text
    # без звука у всплывающего уведомления
    $script:Tray.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::None
    $script:Tray.ShowBalloonTip(8000)
}

# Мягкий режим: уведомление повторяется каждые N сек, пока его не закроют кликом
$script:NagActive = $false
function Start-Nag {
    $script:NagActive = $true
    Show-Toast "Пора размяться! Нажми на это уведомление, чтобы закрыть."
    $script:NagTimer.Interval = [Math]::Max(3000, [int]$script:Settings.ToastEverySec * 1000)
    $script:NagTimer.Start()
}
function Stop-Nag {
    $script:NagActive = $false
    if ($script:NagTimer) { $script:NagTimer.Stop() }
}

# ---------- Сам перерыв ----------
function Invoke-Break {
    if ($script:Settings.HardMode -and -not (Test-GameActive)) {
        # Жёсткий режим: резкое перекрытие экрана (но не во время игры)
        Show-BreakOverlay -Seconds ([int]$script:Settings.BreakSeconds)
    } else {
        # Мягкий режим (по умолчанию): назойливое уведомление до клика
        Start-Nag
    }
}

# ---------- Автозапуск ----------
function Set-Autostart {
    param([bool]$Enable)
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $name = 'StretchBreak'
    $vbs = Join-Path $ScriptDir 'StretchBreak.vbs'
    if ($Enable) {
        Set-ItemProperty -Path $runKey -Name $name -Value ("wscript.exe `"$vbs`"")
    } else {
        Remove-ItemProperty -Path $runKey -Name $name -ErrorAction SilentlyContinue
    }
}

# ============================================================
#  Тестовый режим
# ============================================================
if ($TestNow) {
    $script:Tray = New-Object System.Windows.Forms.NotifyIcon
    $script:Tray.Icon = $AppIcon; $script:Tray.Visible = $true
    if (Test-GameActive) { Show-Toast "ТЕСТ: обнаружена игра — идут уведомления вместо блокировки." }
    else { Show-BreakOverlay -Seconds 10 }
    $script:Tray.Visible = $false; $script:Tray.Dispose()
    exit
}

# --- Один экземпляр ---
$mutex = New-Object System.Threading.Mutex($false, 'Global\StretchBreakSingleInstance')
if (-not $mutex.WaitOne(0)) { exit }

# ============================================================
#  Окно настроек
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'StretchBreak'
$form.FormBorderStyle = 'None'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(680, 660)
$form.BackColor = $clrBg
$form.ShowInTaskbar = $true
$form.Icon = $AppIcon
$form.Add_Shown({ Set-RoundedRegion $form 16 })

# Кастомный заголовок
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.SetBounds(0, 0, 680, 48); $titleBar.BackColor = $clrPanel
$form.Controls.Add($titleBar)

$appTitle = New-Object System.Windows.Forms.Label
$appTitle.Text = "  ⟳  StretchBreak"
$appTitle.ForeColor = $clrText; $appTitle.Font = Font 13 'Bold'
$appTitle.SetBounds(14, 10, 320, 28); $appTitle.BackColor = $clrPanel
$titleBar.Controls.Add($appTitle)

$btnClose = New-FlatButton '✕' 632 8 36 32 $clrPanel $clrMuted 11
$btnClose.Add_MouseEnter({ $this.BackColor = $clrDanger; $this.ForeColor = 'White' })
$btnClose.Add_MouseLeave({ $this.BackColor = $clrPanel; $this.ForeColor = $clrMuted })
$btnClose.Add_Click({ $form.Hide() })   # крестик = свернуть в трей
$titleBar.Controls.Add($btnClose)

$btnMin = New-FlatButton '—' 592 8 36 32 $clrPanel $clrMuted 11
$btnMin.Add_Click({ $form.WindowState = 'Minimized' })
$titleBar.Controls.Add($btnMin)

# Перетаскивание окна за заголовок
$script:drag = $false; $script:dragPt = New-Object System.Drawing.Point
$onDown = { $script:drag = $true; $script:dragPt = [System.Windows.Forms.Cursor]::Position;
            $script:formPt = $form.Location }
$onMove = {
    if ($script:drag) {
        $cur = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(
            ($script:formPt.X + $cur.X - $script:dragPt.X),
            ($script:formPt.Y + $cur.Y - $script:dragPt.Y))
    }
}
$onUp = { $script:drag = $false }
$titleBar.Add_MouseDown($onDown); $titleBar.Add_MouseMove($onMove); $titleBar.Add_MouseUp($onUp)
$appTitle.Add_MouseDown($onDown); $appTitle.Add_MouseMove($onMove); $appTitle.Add_MouseUp($onUp)

# Подзаголовок
$sub = New-Object System.Windows.Forms.Label
$sub.Text = "Напоминание о разминке — не мешает во время игры"
$sub.ForeColor = $clrMuted; $sub.Font = Font 9.5
$sub.SetBounds(24, 60, 500, 22); $form.Controls.Add($sub)

# Степперы
New-Stepper $form 24 100 "Интервал между перерывами"  'IntervalMinutes' 1 240 5 "мин"
New-Stepper $form 24 150 "Длительность перерыва (жёсткий режим)" 'BreakSeconds' 5 300 5 "сек"
New-Stepper $form 24 200 "Повтор уведомления, если не закрыто"   'ToastEverySec' 5 120 5 "сек"

# Секция игр
$gLbl = New-Object System.Windows.Forms.Label
$gLbl.Text = "Игры (процессы, при которых только уведомления):"
$gLbl.ForeColor = $clrText; $gLbl.Font = Font 11
$gLbl.SetBounds(24, 262, 460, 24); $form.Controls.Add($gLbl)

$gList = New-Object System.Windows.Forms.ListBox
$gList.SetBounds(24, 292, 380, 150)
$gList.BackColor = $clrPanel; $gList.ForeColor = $clrText
$gList.BorderStyle = 'None'; $gList.Font = Font 10
$gList.Items.AddRange([object[]]$script:Settings.GameProcesses)
$form.Controls.Add($gList)

$gBox = New-Object System.Windows.Forms.TextBox
$gBox.SetBounds(420, 292, 232, 28)
$gBox.BackColor = $clrPanel; $gBox.ForeColor = $clrText
$gBox.BorderStyle = 'FixedSingle'; $gBox.Font = Font 10
$form.Controls.Add($gBox)

$gAdd = New-FlatButton 'Добавить' 420 328 232 34 $clrAccent 'White' 10
$gAdd.Add_Click({
    $v = $gBox.Text.Trim() -replace '\.exe$',''
    if ($v -and -not $gList.Items.Contains($v)) { [void]$gList.Items.Add($v); $gBox.Clear() }
})
$form.Controls.Add($gAdd)

$gDel = New-FlatButton 'Удалить выбранное' 420 368 232 34 $clrPanel2 $clrText 10
$gDel.Add_Click({ if ($gList.SelectedIndex -ge 0) { $gList.Items.RemoveAt($gList.SelectedIndex) } })
$form.Controls.Add($gDel)

$gHint = New-Object System.Windows.Forms.Label
$gHint.Text = "Игры в «окне без рамки» определяются автоматически по размеру окна."
$gHint.ForeColor = $clrMuted; $gHint.Font = Font 8.5
$gHint.SetBounds(420, 406, 232, 36); $form.Controls.Add($gHint)

# Чекбоксы
function New-Check {
    param($Text, $X, $Y, [bool]$Checked, [int]$W = 200)
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $Text; $c.Checked = $Checked
    $c.ForeColor = $clrText; $c.Font = Font 10
    $c.SetBounds($X, $Y, $W, 26); $c.FlatStyle = 'Flat'
    $form.Controls.Add($c); return $c
}

# Жёсткий режим + кружок "?" с подсказкой
$chkHard = New-Check "Жёсткий режим (перекрытие экрана)" 24 452 ([bool]$script:Settings.HardMode) 300

$help = New-Object System.Windows.Forms.Label
$help.Text = "?"; $help.TextAlign = 'MiddleCenter'
$help.Font = Font 9 'Bold'; $help.ForeColor = 'White'; $help.BackColor = $clrAccent
$help.SetBounds(326, 454, 22, 22); $help.Cursor = 'Help'
$form.Controls.Add($help)
Set-RoundedRegion $help 11

$tip = New-Object System.Windows.Forms.ToolTip
$tip.InitialDelay = 150; $tip.AutoPopDelay = 12000; $tip.ReshowDelay = 100
$tip.SetToolTip($help, "Экран будет резко перекрываться уведомлением на весь экран." + [Environment]::NewLine + "Не рекомендуется при играх. По умолчанию выключено — приходит обычное уведомление Windows.")

$chkAuto  = New-Check "Запуск с Windows" 24 486 ([bool]$script:Settings.Autostart)
$chkSound = New-Check "Звук в жёстком режиме" 230 486 ([bool]$script:Settings.Sound)
$chkPause = New-Check "Пауза"            450 486 ([bool]$script:Settings.Paused)

# Кнопки снизу
$status = New-Object System.Windows.Forms.Label
$status.ForeColor = $clrAccent2; $status.Font = Font 9.5
$status.SetBounds(24, 610, 360, 24); $form.Controls.Add($status)

$btnSave = New-FlatButton 'Сохранить' 420 540 232 40 $clrAccent 'White' 11
$btnTest = New-FlatButton 'Проверить сейчас' 24 540 180 40 $clrPanel2 $clrText 11
$btnHide = New-FlatButton 'Свернуть в трей' 215 540 190 40 $clrPanel2 $clrText 11
$form.Controls.AddRange(@($btnSave, $btnTest, $btnHide))

$btnHide.Add_Click({ $form.Hide() })
$btnTest.Add_Click({ Invoke-Break })

$btnSave.Add_Click({
    $script:Settings.GameProcesses = @($gList.Items)
    $script:Settings.HardMode  = [bool]$chkHard.Checked
    $script:Settings.Autostart = [bool]$chkAuto.Checked
    $script:Settings.Sound     = [bool]$chkSound.Checked
    $script:Settings.Paused    = [bool]$chkPause.Checked
    Save-Settings
    Set-Autostart -Enable ([bool]$chkAuto.Checked)
    Restart-IntervalTimer
    $status.Text = "✓ Сохранено в $(Get-Date -Format 'HH:mm:ss')"
})

# Закрытие окна -> в трей
$form.Add_FormClosing({
    if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $_.Cancel = $true; $form.Hide()
    }
})

# ============================================================
#  Трей
# ============================================================
$script:Tray = New-Object System.Windows.Forms.NotifyIcon
$script:Tray.Icon = $AppIcon
$script:Tray.Text = "StretchBreak"
$script:Tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen  = $menu.Items.Add("Настройки")
$miPause = $menu.Items.Add("Пауза")
$miTest  = $menu.Items.Add("Проверить сейчас")
$menu.Items.Add("-") | Out-Null
$miExit  = $menu.Items.Add("Выход")
$script:Tray.ContextMenuStrip = $menu

function Show-Window {
    $form.Show(); $form.WindowState = 'Normal'; $form.Activate(); $form.BringToFront()
}
$miOpen.Add_Click({ Show-Window })
$script:Tray.Add_DoubleClick({ Show-Window })
$miTest.Add_Click({ Invoke-Break })
$miPause.Add_Click({
    $script:Settings.Paused = -not $script:Settings.Paused
    $chkPause.Checked = $script:Settings.Paused
    Save-Settings; Restart-IntervalTimer
})
$miExit.Add_Click({
    $script:IntervalTimer.Stop()
    $script:Tray.Visible = $false; $script:Tray.Dispose()
    $form.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

# Обновлять текст пункта "Пауза" при открытии меню
$menu.Add_Opening({ $miPause.Text = if ($script:Settings.Paused) { "Возобновить" } else { "Пауза" } })

# ============================================================
#  Таймер интервалов
# ============================================================
$script:IntervalTimer = New-Object System.Windows.Forms.Timer
$script:IntervalTimer.Add_Tick({ if (-not $script:Settings.Paused) { Invoke-Break } })

# Таймер назойливого уведомления: повторяет показ, пока не закроют кликом
$script:NagTimer = New-Object System.Windows.Forms.Timer
$script:NagTimer.Add_Tick({
    if ($script:NagActive) { Show-Toast "Пора размяться! Нажми на это уведомление, чтобы закрыть." }
    else { $script:NagTimer.Stop() }
})
# Клик по уведомлению — прекратить повторы
$script:Tray.Add_BalloonTipClicked({ Stop-Nag })

function Restart-IntervalTimer {
    $script:IntervalTimer.Stop()
    $ms = [int]$script:Settings.IntervalMinutes * 60000
    if ($ms -lt 1000) { $ms = 1000 }
    $script:IntervalTimer.Interval = $ms
    if (-not $script:Settings.Paused) { $script:IntervalTimer.Start() }
}
Restart-IntervalTimer

# Приветственное уведомление
Show-Toast "StretchBreak запущен. Крестик сворачивает в трей, выход — через меню трея."

# Запуск: показываем окно настроек сразу (в трей уходит по крестику).
# Цикл сообщений живёт, пока форма не уничтожена (Выход из меню трея).
[System.Windows.Forms.Application]::Run($form)
