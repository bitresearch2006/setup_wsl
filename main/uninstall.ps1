# =========================================
# WSL Uninstall / Cleanup Script
# =========================================

$STATE_FILE = "C:\ProgramData\wsl_setup_state.txt"
$SETUP_TASK = "WSL-PostReboot-Setup"
$AUTOSTART_TASK = "WSL-AutoStart"
$DISTRO = "Ubuntu"

Write-Host "=== WSL Cleanup Started ===" -ForegroundColor Yellow

# Ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal]
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Re-launching uninstall script as Administrator..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 1. Remove WSL auto-start task
Write-Host "Removing WSL auto-start task..."
schtasks /delete /tn $AUTOSTART_TASK /f 2>$null

# 2. Remove post-reboot setup task (if exists)
Write-Host "Removing post-reboot setup task..."
schtasks /delete /tn $SETUP_TASK /f 2>$null

# 3. Remove state file
if (Test-Path $STATE_FILE) {
    Write-Host "Removing state file..."
    Remove-Item $STATE_FILE -Force
}

# 4. Shutdown WSL safely
Write-Host "Shutting down WSL..."
wsl --shutdown 2>$null

# 5. Optional: unregister distro
$choice = Read-Host "Do you want to UNREGISTER the Ubuntu distro? (Y/N)"

if ($choice -match '^[Yy]$') {
    Write-Host "Unregistering Ubuntu distro..."
    wsl --unregister $DISTRO
    Write-Host "Ubuntu distro removed."
} else {
    Write-Host "Ubuntu distro preserved."
}

Write-Host ""
Write-Host "WSL cleanup completed successfully." -ForegroundColor Green
Read-Host "Press ENTER to close this window"
