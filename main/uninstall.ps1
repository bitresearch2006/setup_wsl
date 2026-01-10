# =========================================================
# WSL Uninstaller – Safe, Symmetric with install.ps1
#
# DESIGN PRINCIPLES:
# 1. User-owned resources removed as STANDARD USER
# 2. System-wide features removed ONLY with admin approval
# 3. No reboot unless features are disabled
# =========================================================

$DISTRO     = "Ubuntu"
$TASKS      = @("WSL-PostBoot", "WSL-AutoStart")

# ------------------------------
# Helpers
# ------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Remove-Task {
    param($Name)
    schtasks /delete /tn $Name /f 2>$null | Out-Null
}

function Get-DismFeatureState($FeatureName) {
    $stateLine = dism /online /get-featureinfo /featurename:$FeatureName |
                 Select-String "State :"
    return ($stateLine -split ':')[1].Trim()
}

function Test-WSLFeaturesEnabled {

    $wslState = Get-DismFeatureState "Microsoft-Windows-Subsystem-Linux"
    $vmState  = Get-DismFeatureState "VirtualMachinePlatform"

    $validStates = @("Enabled", "Enable Pending")

    return ($validStates -contains $wslState) -and
           ($validStates -contains $vmState)
}

# =========================================================
# PHASE-1: USER OWNED CLEANUP (STANDARD USER)
# =========================================================
Write-Host "Removing user-owned WSL resources..."

foreach ($task in $TASKS) {
    Remove-Task $task
    Write-Host "Removed task: $task"
}

$distros = wsl -l -q 2>$null
if ($distros -contains $DISTRO) {
    Write-Host "Unregistering WSL distro '$DISTRO'..."
    wsl --unregister $DISTRO
} else {
    Write-Host "WSL distro '$DISTRO' not found (skipping)"
}


# =========================================================
# ASK BEFORE SYSTEM-WIDE REMOVAL
# =========================================================
if (-not (Test-WSLFeaturesEnabled)) {
    Write-Host "WSL system features already disabled."
    exit
}

$choice = Read-Host "Do you want to remove WSL system-wide features? (yes/no)"
if ($choice -ne "yes") {
    Write-Host "System-wide features retained. Uninstall completed."
    exit
}

# =========================================================
# PHASE-2: SYSTEM FEATURE REMOVAL (ADMIN ONLY)
# =========================================================
if (-not (Test-IsAdmin)) {

    Write-Host "Requesting admin approval to remove WSL system features..."

    Start-Process powershell `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""

    exit
}

Write-Host "Disabling WSL system features..."

dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart

Write-Host "System reboot required to complete uninstall."
Restart-Computer -Force
