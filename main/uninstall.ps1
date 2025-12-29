# =========================================
# WSL Uninstall & Rollback Script
# =========================================

$TASK_NAME = "AutoStartWSL"
$DISTRO    = "Ubuntu"

Write-Host "=== WSL Uninstall Started ===" -ForegroundColor Yellow

# ------------------------------
# 1. Stop all WSL instances
# ------------------------------
Write-Host "Stopping WSL..."
wsl --shutdown 2>$null

# ------------------------------
# 2. Remove Windows startup task
# ------------------------------
Write-Host "Removing Windows startup task..."
schtasks /query /tn $TASK_NAME >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    schtasks /delete /tn $TASK_NAME /f
    Write-Host "Startup task removed"
} else {
    Write-Host "Startup task not found (skipping)"
}

# ------------------------------
# 3. Unregister Ubuntu distro
# ------------------------------
Write-Host "Checking installed WSL distros..."
$distros = wsl -l -q 2>$null

if ($distros -contains $DISTRO) {
    Write-Host "Unregistering Ubuntu (this deletes Linux data)..."
    wsl --unregister $DISTRO
} else {
    Write-Host "Ubuntu not installed (skipping)"
}

# ------------------------------
# 4. Optional: Disable WSL features
# ------------------------------
$answer = Read-Host "Disable WSL Windows features as well? (y/N)"

if ($answer -match '^[Yy]$') {
    Write-Host "Disabling WSL features..."
    dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
    dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart

    Write-Host "WSL features disabled. Reboot required."
} else {
    Write-Host "WSL features left enabled."
}

# ------------------------------
# 5. Final status
# ------------------------------
Write-Host "=== Uninstall Completed ===" -ForegroundColor Green
Write-Host "If features were disabled, please reboot Windows."
