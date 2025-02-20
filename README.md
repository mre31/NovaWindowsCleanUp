# NovaWindowsCleanUp

```irm https://raw.githubusercontent.com/mre31/NovaWindowsCleanUp/refs/heads/main/NovaWindowsCleanUp.ps1  | iex```

A PowerShell script that automates the process of removing bloatware, customizing Windows settings, and installing essential applications on Windows 10/11 systems.

## Features

### Bloatware Removal
- Removes pre-installed Microsoft applications and bloatware
- Includes commonly unwanted apps like:
  - Microsoft 3D Builder
  - Microsoft Office Hub
  - Skype
  - Mixed Reality Portal
  - Windows Feedback Hub
  - Microsoft Teams
  - Clipchamp
  - And many more

### OneDrive Removal
- Completely uninstalls OneDrive
- Removes OneDrive from startup
- Cleans up OneDrive-related files and registry entries

### System Customization
- Sets system-wide dark theme
- Enables transparency effects
- Customizes taskbar:
  - Removes search box
  - Disables widgets
  - Removes chat/Teams button
  - Removes news and interests
  - Removes Cortana button
  - Removes People button
  - Unpins all pinned applications
- Adds "This PC" icon to desktop
- Changes desktop wallpaper (downloads from specified URL)
- Removes Windows 11 Gallery feature

### Automatic Application Installation
Uses Winget to automatically install popular applications:
- Brave Browser
- DirectX
- Spotify
- Steam
- NVIDIA GeForce Experience
- WhatsApp
- WinRAR
- VLC Media Player
- Epic Games Launcher
- HWiNFO
- Discord

## Requirements
- Windows 10 or Windows 11
- PowerShell
- Administrator privileges
- Internet connection for downloading applications

## Usage
1. Run ```irm https://raw.githubusercontent.com/mre31/NovaWindowsCleanUp/refs/heads/main/NovaWindowsCleanUp.ps1  | iex``` with admin powershell.

## Disclaimer
This script makes significant changes to your Windows installation. While it's designed to be safe, it's recommended to:
- Review the script before running
- Backup important data
- Create a system restore point before execution
