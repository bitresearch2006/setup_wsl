# =========================================================
# WSL Installer – Phase-split, Parameter-free
#
# DESIGN PRINCIPLES:
# 1. Script is always started by STANDARD USER
# 2. Admin rights are used ONLY to enable system-wide WSL features
# 3. WSL distro + tasks are ALWAYS created as STANDARD USER
# 4. Phase-2 must NEVER run in admin context (hard enforced)
#
# DO NOT move Phase-2 code above the admin guard.
# =========================================================

# ------------------------------
# Globals
# ------------------------------
$DISTRO     = "Ubuntu"
$TASK_NAME  = "WSL-PostBoot"
$SCRIPT     = $PSCommandPath

# ------------------------------
# Logging
# ------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $color = switch ($Level) {
        "INFO"  { "Gray" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
    }

    Write-Host "$ts [$env:USERNAME] [$Level] $Message" -ForegroundColor $color
}



# ------------------------------
# Helpers
# ------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WSLFeaturesEnabled {
    $wsl = dism /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux |
           Select-String "State : Enabled"
    $vm  = dism /online /get-featureinfo /featurename:VirtualMachinePlatform |
           Select-String "State : Enabled"
    return ($wsl -and $vm)
}

function Enable-WSLFeatures {
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
}

function Register-PostBootTask {
    schtasks /create /tn $TASK_NAME /tr "powershell.exe -ExecutionPolicy Bypass -File `"$SCRIPT`"" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f
}

function Remove-PostBootTask {
    schtasks /delete /tn $TASK_NAME /f 2>$null
}

function Register-WSLAutoStart {
    schtasks /create /tn "WSL-AutoStart" /tr "wsl -d Ubuntu -e true" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f

}

function Verify-WSLSetup {
    Write-Log ""
    Write-Log "=== Verifying WSL Setup Completion ===" -ForegroundColor Cyan

    $DISTRO = "Ubuntu"
    $EXPECTED_USER = $LINUX_USER
    $success = $true

    $distros = wsl -l -q
    if ($distros -notcontains $DISTRO) {
        Write-Log "❌ Ubuntu distro not found" -ForegroundColor Red
        $success = $false
    } else {
        Write-Log "✔ Ubuntu distro found"
    }

    wsl -d $DISTRO -- bash -c "id $EXPECTED_USER" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ Linux user '$EXPECTED_USER' does not exist" -ForegroundColor Red
        $success = $false
    } else {
        Write-Log "✔ Linux user '$EXPECTED_USER' exists"
    }

    $defaultUser = (wsl -d $DISTRO -- bash -c "whoami").Trim()
    if ($defaultUser -ne $EXPECTED_USER) {
        Write-Log "❌ Default WSL user is '$defaultUser' (expected '$EXPECTED_USER')" -ForegroundColor Red
        $success = $false
    } else {
        Write-Log "✔ Default WSL user is '$EXPECTED_USER'"
    }

    $wslConf = wsl -d $DISTRO -- bash -c "grep -E '^default=' /etc/wsl.conf"
    if ($wslConf -notmatch "default=$EXPECTED_USER") {
        Write-Log "❌ /etc/wsl.conf not configured correctly" -ForegroundColor Red
        $success = $false
    } else {
        Write-Log "✔ /etc/wsl.conf configured"
    }

    Write-Log ""
    if ($success) {
        Write-Log "WSL installation COMPLETED SUCCESSFULLY WSL strted in automatically from next boot" -ForegroundColor Green
    } else {
        Write-Log "WSL installation INCOMPLETE - please re-run install.ps1" -ForegroundColor Yellow
    }

    Read-Host "Press ENTER to close this window"
}


# =========================================================
# SCRIPT START
# =========================================================
Write-Log "SCRIPT STARTED"

# =========================================================
# PHASE-1: SYSTEM FEATURE CHECK / ENABLE (ADMIN ONLY)
# =========================================================
if (-not (Test-WSLFeaturesEnabled)) {

    Write-Log "PHASE-1: WSL system features NOT enabled"

    # -----------------------------------------------------
    # If NOT admin → relaunch entire script as admin
    # This admin process is allowed to do ONLY:
    #   - Enable WSL features
    #   - Reboot
    # -----------------------------------------------------
    if (-not (Test-IsAdmin)) {

        Write-Log "PHASE-1: Requesting admin approval"

        Write-Log "PHASE-1: Post-boot task registered"

        Write-Host "Restarting script with administrator privileges..."
        Start-Process powershell `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs

        exit   #  CRITICAL
    }
    
    Register-PostBootTask
    # -----------------------------------------------------
    # ADMIN CONTEXT (HARD-LIMITED SECTION)
    # -----------------------------------------------------
    Write-Log "ADMIN: Enabling WSL system features"
    Enable-WSLFeatures

    Write-Log "ADMIN: Rebooting system (required)"
    if ($choice -match '^[Yy]$') {
        Write-Log "Rebooting system to continue setup..."
        Restart-Computer -Force
    } else {
        Write-Log "Reboot skipped. Please reboot manually to complete setup by rerun this script after restart."
    }

    # HARD ADMIN-CONTEXT ASSERTION
    # Admin execution must NEVER continue beyond this point.
    exit
}

Write-Log "PHASE-1: WSL system features already enabled"

# =========================================================
# HARD SAFETY CHECK (ADMIN HELPER ONLY)
# =========================================================
if (Test-IsAdmin -and -not (Test-WSLFeaturesEnabled)) {
    Write-Log "ADMIN-HELPER: Phase-2 blocked (expected behavior)"
    exit
}


# =========================================================
# PHASE-2: USER-OWNED WSL SETUP (STANDARD USER ONLY)
# =========================================================
Write-Log "PHASE-2: Starting user WSL setup"

$distros = wsl -l -q 2>$null

if ($distros -notcontains $DISTRO) {
    Write-Log "PHASE-2: Installing WSL distro '$DISTRO' for user"
    wsl --install -d $DISTRO
} else {
    Write-Log "PHASE-2: WSL distro '$DISTRO' already installed"
}
Write-Log "=== Phase 2: User Setup ===" -ForegroundColor Green

# Ask user credentials
$LINUX_USER = Read-Host "Enter Linux username"
$PASSWORD_SECURE = Read-Host "Enter Linux password" -AsSecureString
if ([string]::IsNullOrWhiteSpace($LINUX_USER)) {
    Write-Log "Linux username cannot be empty." -ForegroundColor Red
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
Write-Log "PHASE-2: Post-boot task removed"

Register-WSLAutoStart
Write-Log "PHASE-2: WSL auto-start task registered"

# ------------------------------
# Phase 3 (Post-Verification)
# ------------------------------
Verify-WSLSetup

Write-Log "SUCCESS: WSL setup completed successfully"
Write-Log "WSL setup completed successfully."
