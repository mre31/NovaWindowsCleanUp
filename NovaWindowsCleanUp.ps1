# Windows 10/11 Bloatware Temizleme Script'i

# Yönetici hakları kontrolü
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run with administrator privileges!"
    Break
}

# Kaldırılacak uygulamalar listesi (tekrar edenleri temizledim)
$uygulamalar = @(
    "Microsoft.3DBuilder"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal"
    "Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.YourPhone"
    "Microsoft.WindowsNews"
    "Microsoft.ClipChamp"
    "Microsoft.BingSearch"
    "Microsoft.BingNews"
    "Microsoft.ScreenSketch"
    "Clipchamp.Clipchamp"
    "Microsoft.Todos"
    "Microsoft.PowerAutomateDesktop"
    "MicrosoftTeams"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.BingSearch"
    "Microsoft.BingNews"
    "Microsoft.ScreenSketch"
    "Microsoft.BingWeather"
    "Clipchamp.Clipchamp"
    "Microsoft.YourPhone"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Todos"
    "Microsoft.PowerAutomateDesktop"
    "MicrosoftTeams"
    "MSTeams"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.Copilot"
    "Microsoft.Windows.Gallery"
    "Microsoft.OutlookForWindows"
)

Write-Host "Windows Cleanup Process Starting..." -ForegroundColor Green

# Uygulama kaldırma fonksiyonu
function Remove-AppWithTimeout {
    param (
        [string]$AppName,
        [int]$MaxAttempts = 3,
        [int]$TimeoutSeconds = 30
    )
    
    # Uygulamanın yüklü olup olmadığını kontrol et
    $appInstalled = Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue
    if ($null -eq $appInstalled) {
        Write-Host "Skipping $AppName - Not installed" -ForegroundColor Gray
        return $true
    }
    
    Write-Host "Found installed app: $AppName" -ForegroundColor Yellow
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-Host "Removing: $AppName (Attempt $attempt of $MaxAttempts)..." -ForegroundColor Yellow
        
        $job = Start-Job -ScriptBlock {
            param($app)
            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        } -ArgumentList $AppName

        if (Wait-Job $job -Timeout $TimeoutSeconds) {
            Receive-Job $job
            Remove-Job $job
            Write-Host "Successfully removed $AppName" -ForegroundColor Green
            return $true
        } else {
            Stop-Job $job
            Remove-Job $job
            Write-Host "Timeout while removing $AppName, retrying..." -ForegroundColor Red
        }

        if ($attempt -eq $MaxAttempts) {
            Write-Host "Failed to remove $AppName after $MaxAttempts attempts" -ForegroundColor Red
        }
    }
    return $false
}

# Uygulamaları kaldır
foreach ($uygulama in $uygulamalar) {
    Remove-AppWithTimeout -AppName $uygulama
}

Write-Host "`nOneDrive is being removed..." -ForegroundColor Yellow

# OneDrive işlemlerini durdur
Get-Process | Where-Object { $_.ProcessName -like "*onedrive*" } | Stop-Process -Force

# OneDrive'ı kaldır
if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    & "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall
} elseif (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
    & "$env:SystemRoot\System32\OneDriveSetup.exe" /uninstall
}

# OneDrive ile ilgili dosya ve klasörleri temizle
@(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
    "$env:PUBLIC\Desktop\OneDrive.lnk"
    "$env:USERPROFILE\Desktop\OneDrive.lnk"
    "$env:USERPROFILE\OneDrive"
    "$env:LOCALAPPDATA\Microsoft\OneDrive"
    "$env:ProgramData\Microsoft\OneDrive"
    "$env:SystemDrive\OneDriveTemp"
) | ForEach-Object { 
    if (Test-Path $_) {
        Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Registry kayıtlarını temizle
@(
    "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
) | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nSistem teması karanlık temaya ayarlanıyor..." -ForegroundColor Cyan

# Uygulama temasını karanlık yap
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -PropertyType Dword -Force

# Windows temasını karanlık yap
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -PropertyType Dword -Force

# Transparency'yi aç
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -PropertyType DWord -Force

Write-Host "System theme set to dark." -ForegroundColor Green

Write-Host "`nTaskbar is being cleaned..." -ForegroundColor Cyan

# Taskbar ayarları için registry yolu
$TaskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$ChatPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Search box'ı kaldır
New-ItemProperty -Path $TaskbarPath -Name "SearchboxTaskbarMode" -Value 0 -PropertyType DWord -Force

# Search ikonu ve fonksiyonunu tamamen kaldır
New-ItemProperty -Path $TaskbarPath -Name "ShowTaskViewButton" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path $TaskbarPath -Name "ShowSearch" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -PropertyType DWord -Force

# Widgets (Hava durumu) butonunu kaldır
New-ItemProperty -Path $TaskbarPath -Name "TaskbarDa" -Value 0 -PropertyType DWord -Force

# Widgets'ı tamamen kaldır
Write-Host "Widgets are being removed..." -ForegroundColor Yellow

# Tüm Widget ayarlarını devre dışı bırak
$WidgetSettings = @(
    @{Path="$TaskbarPath"; Name="TaskbarDa"; Value=0}
    @{Path="$TaskbarPath"; Name="TaskbarWidgets"; Value=0}
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="ShowWidgets"; Value=0}
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Dsh"; Name="IsPrelaunchEnabled"; Value=0}
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; Name="AllowNewsAndInterests"; Value=0}
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name="EnableFeeds"; Value=0}
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"; Name="ShellFeedsTaskbarViewMode"; Value=2}
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name="TaskbarNoNotification"; Value=1}
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name="EnableFeeds"; Value=0}
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name="ShellFeedsTaskbarViewMode"; Value=2}
)

foreach ($setting in $WidgetSettings) {
    if (!(Test-Path $setting.Path)) {
        New-Item -Path $setting.Path -Force | Out-Null
    }
    New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force -ErrorAction SilentlyContinue
}

# Widget servislerini devre dışı bırak
$services = @(
    "WpnUserService"
    "TabletInputService"
    "PushToInstall"
    "WpnService"
)

foreach ($service in $services) {
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
}

# Windows özelliklerinden Widget'ı kaldır
Disable-WindowsOptionalFeature -Online -FeatureName "Windows-Widgets" -NoRestart -ErrorAction SilentlyContinue

# Haberler ve ilgi alanlarını kaldır
New-ItemProperty -Path $TaskbarPath -Name "TaskbarMn" -Value 0 -PropertyType DWord -Force

# Chat/Teams butonunu kaldır
New-ItemProperty -Path $ChatPath -Name "TaskbarMn" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path $TaskbarPath -Name "TaskbarChat" -Value 0 -PropertyType DWord -Force

# Cortana butonunu kaldır
New-ItemProperty -Path $TaskbarPath -Name "ShowCortanaButton" -Value 0 -PropertyType DWord -Force

# People butonunu kaldır
New-ItemProperty -Path $TaskbarPath -Name "PeopleBand" -Value 0 -PropertyType DWord -Force

# Tüm pinlenmiş uygulamaları kaldır
Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Force -Recurse -ErrorAction SilentlyContinue -Confirm:$false

Write-Host "Taskbar cleaned." -ForegroundColor Green

Write-Host "`nGallery feature is being removed..." -ForegroundColor Cyan

# Galeri ve Home özelliklerini kaldır
$GalleryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
)

foreach ($path in $GalleryPaths) {
    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
}

# Eski ayarları da uygula
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "NavPaneShowLibraries" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowGallery" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -PropertyType DWord -Force


Write-Host "Gallery feature removed." -ForegroundColor Green


Write-Host "`nAdding This PC icon to desktop..." -ForegroundColor Cyan

# Bu Bilgisayar simgesini masaüstüne ekle
$DesktopIcons = @{
    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    Name = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
    Value = 0
}

if (!(Test-Path $DesktopIcons.Path)) {
    New-Item -Path $DesktopIcons.Path -Force | Out-Null
}
New-ItemProperty -Path $DesktopIcons.Path -Name $DesktopIcons.Name -Value $DesktopIcons.Value -PropertyType DWord -Force

Write-Host "This PC icon added to desktop." -ForegroundColor Green

Write-Host "`nChanging desktop wallpaper..." -ForegroundColor Cyan

# Arkaplan değiştirme fonksiyonu
function Set-WallpaperFromGithub {
    param (
        [string]$ImageUrl,
        [string]$WallpaperStyle = "Fill"  # Fill, Fit, Stretch, Tile, Center, Span
    )
    
    try {
        # Resmi geçici klasöre indir
        $wallpaperPath = "$env:TEMP\wallpaper.jpg"
        Invoke-WebRequest -Uri $ImageUrl -OutFile $wallpaperPath
        
        # Arkaplan stilini ayarla
        $styleValue = switch ($WallpaperStyle) {
            "Fill" {10}
            "Fit" {6}
            "Stretch" {2}
            "Tile" {1}
            "Center" {1}
            "Span" {22}
        }
        
        # Registry ayarlarını güncelle
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value $styleValue -Force
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -PropertyType String -Value 0 -Force
        
        # Arkaplanı ayarla
        Add-Type -TypeDefinition @"
        using System.Runtime.InteropServices;
        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
        [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperPath, 3)
        
        Write-Host "Wallpaper changed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to change wallpaper: $_" -ForegroundColor Red
    }
}

# GitHub'dan arkaplanı değiştir
$wallpaperUrl = "https://raw.githubusercontent.com/mre31/NovaWindowsCleanUp/main/wallpaper.png"
Set-WallpaperFromGithub -ImageUrl $wallpaperUrl -WallpaperStyle "Fill"


# Explorer'ı yeniden başlat
Write-Host "Restarting Explorer..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 5
Start-Process explorer
Write-Host "Explorer restarted." -ForegroundColor Green

Write-Host "`nCleanup process completed!" -ForegroundColor Green

Write-Host "`nInstalling applications with Winget..." -ForegroundColor Cyan

# Yüklenecek uygulamalar listesi
$wingetApps = @(
    @{name = "Brave.Brave"; display = "Brave Browser"}
    @{name = "Microsoft.DirectX"; display = "DirectX"}
    @{name = "Spotify.Spotify"; display = "Spotify"}
    @{name = "Valve.Steam"; display = "Steam"}
    @{name = "Nvidia.GeForceExperience"; display = "NVIDIA GeForce Experience"}
    @{name = "WhatsApp.WhatsApp"; display = "WhatsApp"}
    @{name = "RARLab.WinRAR"; display = "WinRAR"}
    @{name = "VideoLAN.VLC"; display = "VLC Media Player"}
    @{name = "EpicGames.EpicGamesLauncher"; display = "Epic Games"}
    @{name = "REALiX.HWiNFO"; display = "HWiNFO"}
    @{name = "Discord.Discord"; display = "Discord"}
)

# Winget'in yüklü olduğunu kontrol et
$wingetPath = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $wingetPath) {
    Write-Host "Winget not found. Installing App Installer..." -ForegroundColor Yellow
    
    # Microsoft Store'dan App Installer'ı indir
    $releases_url = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $download_url = (Invoke-RestMethod -Uri $releases_url).assets.browser_download_url | Where-Object { $_ -match 'msixbundle' }
    $download_path = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    
    Invoke-WebRequest -Uri $download_url -OutFile $download_path
    Add-AppxPackage -Path $download_path
    Remove-Item $download_path
    
    Write-Host "Winget installed successfully." -ForegroundColor Green
}

# Uygulamaları yüklemeye devam et
foreach ($app in $wingetApps) {
    Write-Host "Installing $($app.display)..." -ForegroundColor Yellow
    
    # Spotify için özel durum
    if ($app.name -eq "Spotify.Spotify") {
        Write-Host "Installing Spotify as non-admin..." -ForegroundColor Yellow
        # Yönetici olmadan çalıştır
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $arguments = "winget install --id Spotify.Spotify -e --accept-source-agreements --accept-package-agreements --silent"
            Start-Process powershell -ArgumentList $arguments -Wait -Verb RunAs -LoadUserProfile
        }
    } else {
        # Diğer uygulamalar için normal kurulum
        winget install --id $app.name -e --accept-source-agreements --accept-package-agreements --silent
    }
    
    # Discord yüklendikten sonra işlemi kapat
    if ($app.name -eq "Discord.Discord") {
        Write-Host "Closing Discord process..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        Stop-Process -Name "Discord" -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Application installation completed!" -ForegroundColor Green

Write-Host "Restarting Explorer..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 5
Start-Process explorer
Write-Host "Explorer restarted." -ForegroundColor Green
