# =========================================
# Fully Automated WSL Setup (Two-Phase)
# =========================================

$STATE_FILE = "C:\ProgramData\wsl_setup_state.txt"
$TASK_NAME  = "WSL-PostReboot-Setup"
$SCRIPT     = $MyInvocation.MyCommand.Path
$DISTRO     = "Ubuntu"

function Register-PostBootTask {
    schtasks /create /tn $TASK_NAME /tr "powershell.exe -ExecutionPolicy Bypass -File `"$SCRIPT`"" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f
}

function Remove-PostBootTask {
    schtasks /delete /tn $TASK_NAME /f 2>$null
}

function Register-WSLAutoStart {
    schtasks /create /tn "WSL-AutoStart" /tr "wsl -d Ubuntu -e true" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f

}

# -----------------------------------------
# Ensure script is running as Administrator
# -----------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Re-launching script as Administrator..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ------------------------------
# Phase Detection
# ------------------------------
if (!(Test-Path $STATE_FILE)) {

    Write-Host "=== Phase 1: WSL Installation ===" -ForegroundColor Yellow

    # Enable WSL features
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    # Set WSL 2 default
    wsl --set-default-version 2

    # Install Ubuntu
    $distros = wsl -l -q 2>$null
    if ($distros -notcontains $DISTRO) {
        wsl --install -d $DISTRO
    }

    # Mark phase 1 complete
    "PHASE1_DONE" | Out-File $STATE_FILE -Force

    # Register auto-resume task (ONLOGON + USER)
    Register-PostBootTask

    # Ask user permission before reboot
    $choice = Read-Host "WSL installation requires a reboot. Reboot now? (Y/N)"

    if ($choice -match '^[Yy]$') {
        Write-Host "Rebooting system to continue setup..."
        Restart-Computer -Force
    } else {
        Write-Host "Reboot skipped. Please reboot manually to complete setup by rerun this script after restart."
    }
    exit 0

}

# ------------------------------
# Phase 2 (Post-Reboot)
# ------------------------------

Write-Host "=== Phase 2: User Setup ===" -ForegroundColor Green

# Ask user credentials
$LINUX_USER = Read-Host "Enter Linux username"
$PASSWORD_SECURE = Read-Host "Enter Linux password" -AsSecureString
if ([string]::IsNullOrWhiteSpace($LINUX_USER)) {
    Write-Host "Linux username cannot be empty." -ForegroundColor Red
    exit 1
}
$PASSWORD_PLAIN = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PASSWORD_SECURE)
)

# Create Linux user
$USER_LINE = "$LINUX_USER`:$PASSWORD_PLAIN"

wsl -d Ubuntu -- bash -c "id $LINUX_USER >/dev/null 2>&1 || useradd -m -s /bin/bash $LINUX_USER && echo '$USER_LINE' | chpasswd && usermod -aG sudo $LINUX_USER"

# Set default WSL user
wsl -d Ubuntu -- bash -c "printf '[user]\ndefault=%s\n' '$LINUX_USER' > /etc/wsl.conf"

# Cleanup
Remove-PostBootTask
Remove-Item $STATE_FILE -Force

wsl --shutdown
# Enable persistent WSL auto-start at every login
Register-WSLAutoStart

# ------------------------------
# Phase 3 (Post-Verification)
# ------------------------------

function Verify-WSLSetup {
    Write-Host ""
    Write-Host "=== Verifying WSL Setup Completion ===" -ForegroundColor Cyan

    $DISTRO = "Ubuntu"
    $EXPECTED_USER = $LINUX_USER
    $success = $true

    $distros = wsl -l -q
    if ($distros -notcontains $DISTRO) {
        Write-Host "❌ Ubuntu distro not found" -ForegroundColor Red
        $success = $false
    } else {
        Write-Host "✔ Ubuntu distro found"
    }

    wsl -d $DISTRO -- bash -c "id $EXPECTED_USER" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Linux user '$EXPECTED_USER' does not exist" -ForegroundColor Red
        $success = $false
    } else {
        Write-Host "✔ Linux user '$EXPECTED_USER' exists"
    }

    $defaultUser = (wsl -d $DISTRO -- bash -c "whoami").Trim()
    if ($defaultUser -ne $EXPECTED_USER) {
        Write-Host "❌ Default WSL user is '$defaultUser' (expected '$EXPECTED_USER')" -ForegroundColor Red
        $success = $false
    } else {
        Write-Host "✔ Default WSL user is '$EXPECTED_USER'"
    }

    $wslConf = wsl -d $DISTRO -- bash -c "grep -E '^default=' /etc/wsl.conf"
    if ($wslConf -notmatch "default=$EXPECTED_USER") {
        Write-Host "❌ /etc/wsl.conf not configured correctly" -ForegroundColor Red
        $success = $false
    } else {
        Write-Host "✔ /etc/wsl.conf configured"
    }

    Write-Host ""
    if ($success) {
        Write-Host "WSL installation COMPLETED SUCCESSFULLY WSL strted in automatically from next boot" -ForegroundColor Green
    } else {
        Write-Host "WSL installation INCOMPLETE - please re-run install.ps1" -ForegroundColor Yellow
    }

    Read-Host "Press ENTER to close this window"
}

Verify-WSLSetup
