# ===============================================
# Windows Update Policy & Annual Scheduled Task Script with Version Check
# ===============================================
# This script:
# 1. Detects the OS version (Windows 10 vs. Windows 11) and feature release version using three methods:
#       - METHOD 1: Using System.Environment (for Windows 10 vs. Windows 11)
#       - METHOD 2: Using Get-ComputerInfo (for feature release, e.g. "22H2")
#       - METHOD 3: Falling back to parsing systeminfo
#    If detection fails, the release version defaults to "24H2".
#
# 2. Applies Windows Update policy settings via registry entries under:
#       HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
#    These settings include:
#       - "Select Target Feature Update Version":
#           • TargetReleaseVersion = 1 (enabled)
#           • TargetReleaseVersionInfo = (detected feature release, e.g. "22H2")
#           • ProductVersion = "Windows 10" or "Windows 11"
#       - "Select When Quality Updates are received":
#           • DeferQualityUpdates = 1
#           • DeferQualityUpdatesPeriodInDays = 4
#
# 3. If the script is run with the "-Scheduled" argument (i.e. when run by the scheduled task),
#    it first checks the registry. If the current OS version and feature release already match the
#    registry settings, the script exits without making changes.
#
# 4. Forces a gpupdate.
#
# 5. Copies itself to a fixed location and creates a scheduled task that runs the saved copy annually
#    (every 365 days) with the "-Scheduled" parameter.
# ===============================================

# ----- Part 1: Detect OS Version and Feature Release Version -----

# Initialize variables.
$ProductVersion = $null
$TargetReleaseVersionInfo = $null

# 🟢 METHOD 1: Get OS version from System.Environment
$OSVersion = [System.Environment]::OSVersion.Version
$Major = $OSVersion.Major
$Build = $OSVersion.Build

if ($Major -eq 10 -and $Build -ge 22000) {
    $ProductVersion = "Windows 11"
} elseif ($Major -eq 10) {
    $ProductVersion = "Windows 10"
}

# 🟢 METHOD 2: Get feature release version using Get-ComputerInfo
try {
    $ReleaseVersion = (Get-ComputerInfo -ErrorAction Stop).WindowsVersion
    if ($ReleaseVersion -match "\d{2}H\d") {
        $TargetReleaseVersionInfo = $ReleaseVersion
    }
} catch {
    Write-Host "Get-ComputerInfo failed, attempting fallback..." -ForegroundColor Yellow
}

# 🔴 METHOD 3 (Fallback): Use systeminfo if Get-ComputerInfo fails
if (-not $TargetReleaseVersionInfo) {
    $OSInfo = systeminfo | Select-String "OS Version"
    if ($OSInfo -match "(\d{2}H\d)") {
        $TargetReleaseVersionInfo = $matches[1]
    }
}

# Default if detection fails.
if (-not $TargetReleaseVersionInfo) {
    $TargetReleaseVersionInfo = "24H2"
}

Write-Host "Detected OS: $ProductVersion"
Write-Host "Detected Release Version: $TargetReleaseVersionInfo"

# Define the registry path.
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# ----- Part 1.5: (Scheduled Run Check) -----
# If the script is run with "-Scheduled", check if the registry already matches the detected values.
if ($args -contains "-Scheduled") {
    try {
        $ExistingRegSettings = Get-ItemProperty -Path $RegPath -ErrorAction Stop
    } catch {
        $ExistingRegSettings = $null
    }
    if ($ExistingRegSettings) {
        if ( ($ExistingRegSettings.ProductVersion -eq $ProductVersion) -and `
             ($ExistingRegSettings.TargetReleaseVersionInfo -eq $TargetReleaseVersionInfo) ) {
            Write-Host "Registry settings are already up-to-date. Exiting scheduled run." -ForegroundColor Green
            exit
        }
    }
}

# ----- Part 2: Apply Registry Settings for Windows Update Policies -----

$RegistrySettings = @{
    "ProductVersion"                  = $ProductVersion
    "TargetReleaseVersion"            = 1
    "TargetReleaseVersionInfo"        = $TargetReleaseVersionInfo
    "DeferQualityUpdates"             = 1
    "DeferQualityUpdatesPeriodInDays" = 4
}

# Ensure the registry path exists.
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

foreach ($Name in $RegistrySettings.Keys) {
    $Value = $RegistrySettings[$Name]
    # Determine type: "DWord" for integers, "String" otherwise.
    $Type = if ($Value -is [int]) { "DWord" } else { "String" }
    try {
        # Check if the registry value exists.
        $existingValue = Get-ItemProperty -Path $RegPath -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $existingValue) {
            # Create the registry value with the specified type.
            New-ItemProperty -Path $RegPath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        }
        else {
            # Update the registry value.
            Set-ItemProperty -Path $RegPath -Name $Name -Value $Value -Force
        }
        Write-Host "Set $Name to $Value ($Type)"
    }
    catch {
        Write-Host "Failed to set $($Name): $($_)" -ForegroundColor Red
    }
}

# Force a Group Policy update.
gpupdate /force
Write-Host "Registry settings applied successfully." -ForegroundColor Green

# ----- Part 3: Copy Script and Create Scheduled Task -----

# Define the folder to store the scheduled task copy.
$ScheduledFolder = "C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually"
if (-not (Test-Path $ScheduledFolder)) {
    New-Item -Path $ScheduledFolder -ItemType Directory -Force | Out-Null
}

# Define the path for the scheduled script copy.
$ScheduledScriptPath = Join-Path -Path $ScheduledFolder -ChildPath "SecurityOnly_Update.ps1"

# Copy the current script to the scheduled folder.
try {
    Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $ScheduledScriptPath -Force
    Write-Host "Script copied to $ScheduledScriptPath"
} catch {
    Write-Host "Failed to copy script: $($_)" -ForegroundColor Red
}

# Define the scheduled task name.
$TaskName = "UpdateWindowsUpdatePoliciesAnnually"

# Check if the scheduled task already exists.
$taskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $taskExists) {
    Write-Host "Creating scheduled task '$TaskName' to run the script annually..." -ForegroundColor Cyan
    # Scheduled task action: run the saved copy with the "-Scheduled" argument.
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScheduledScriptPath`" -Scheduled"
    # Trigger: once every 365 days at 03:00 AM.
    $Trigger = New-ScheduledTaskTrigger -Daily -At "03:00AM" -DaysInterval 365
    # Principal: run as SYSTEM.
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Description "Re-applies Windows Update registry settings annually if needed." -Force
        Write-Host "Scheduled task '$TaskName' created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create scheduled task: $($_)" -ForegroundColor Red
    }
} else {
    Write-Host "Scheduled task '$TaskName' already exists."
}
