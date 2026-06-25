**English** · [Русский](README.md)

# StretchBreak ⟳

A lightweight Windows app that reminds you to take stretch breaks — and **stays out of your way while gaming**.

It lives in the system tray and, at a set interval, reminds you it's time to stretch. While a fullscreen game is running, the screen is **never covered** — you get regular notifications instead.

## Features

- ⏰ Break reminders at a configurable interval (default: every 60 minutes)
- 🔔 **Soft mode (default):** silent Windows notification; you must click it to dismiss, otherwise it repeats every 10 seconds
- 🟣 **Hard mode (optional):** abrupt fullscreen overlay with a countdown on every monitor
- 🎮 **Game-friendly:** during a fullscreen game (including borderless windowed) the screen won't be covered — notifications only. Games are detected automatically by window size + a process list
- 🖥️ Proper multi-monitor support
- ⚙️ Settings window: interval, duration, game list, start with Windows, sound, pause
- 🪟 Minimizes to tray on close, like a real app

## Installation

1. Download `StretchBreak.exe` from [**Releases**](../../releases).
2. Put it in any folder and double-click to run.
3. The settings window opens and a tray icon appears. No install or dependencies needed.

> **SmartScreen / antivirus.** The app isn't code-signed, so Windows may warn you: "More info" → "Run anyway". If the file arrives blocked: right-click → Properties → "Unblock".

## Usage

- **Double-click the tray icon** — open settings.
- **Window close button** — minimize to tray (the app keeps running).
- **Exit** — via the tray menu (right-click the icon → Exit).
- **"Check now"** — trigger a break immediately to test.

## Settings

| Option | Description |
|---|---|
| Break interval | How often to remind you (minutes) |
| Break duration | Length of the overlay in hard mode (seconds) |
| Notification repeat | How often to repeat the notification if not dismissed (seconds) |
| Hard mode | Abrupt fullscreen overlay instead of a notification (not recommended while gaming) |
| Games | Processes during which only notifications are shown |
| Start with Windows | Launch automatically at sign-in |

Settings are stored in `settings.json` next to the program.

## Run from source

No dependencies needed — uses the built-in Windows PowerShell.

```powershell
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File StretchBreak.ps1
```

Or run silently without a console window — double-click `StretchBreak.vbs`.

> `StretchBreak.ps1` must be saved as **UTF-8 with BOM**, otherwise Cyrillic text breaks under Windows PowerShell 5.1.

## Build the .exe

```powershell
Install-Module ps2exe -Scope CurrentUser
Invoke-ps2exe -inputFile StretchBreak.ps1 -outputFile StretchBreak.exe -noConsole -STA -iconFile StretchBreak.ico -title StretchBreak
```

## License

[MIT](LICENSE)
