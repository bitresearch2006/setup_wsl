
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

$STATE_KEY = "HKCU:\Software\BitResearch\WSLSetup"

function Get-PhaseDone {
    param([string]$Phase)
    (Get-ItemProperty -Path $STATE_KEY -Name $Phase -ErrorAction SilentlyContinue) -ne $null
}

function Set-PhaseDone {
    param([string]$Phase)
    New-Item -Path $STATE_KEY -Force | Out-Null
    New-ItemProperty -Path $STATE_KEY -Name $Phase -Value 1 -Force | Out-Null
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

function Phase1-Enable-WSLFeatures {
# =========================================================
# PHASE-1: SYSTEM FEATURE CHECK / ENABLE (ADMIN ONLY)
# =========================================================
    if (Test-IsAdmin -and -not (Test-WSLFeaturesEnabled)) {

        Write-Log "PHASE-1: WSL system features NOT enabled"

        # -----------------------------------------------------
        # This admin process is allowed to do ONLY:
        #   - Enable WSL features
        #   - Reboot
        # -----------------------------------------------------
        
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

    }elseif (-not (Test-IsAdmin))
    {
        Write-Log "PHASE-1: Required admin privilege"
    }
    else
    {

        Write-Log "PHASE-1: WSL system features already enabled"
    }

}

function Phase2-WSL-Setup
{
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
}

function Phase3-Register-WSLAutoStart{
# =========================================================
# PHASE-3: SYSTEM FEATURE CHECK / ENABLE (ADMIN ONLY)
# =========================================================
    if (Test-IsAdmin) {    
        # Cleanup
        Remove-PostBootTask
        Write-Log "PHASE-2: Post-boot task removed"

        Register-WSLAutoStart
        Write-Log "PHASE-3: WSL auto-start task registered"
    }
    else
    {
        Write-Log "PHASE-3: Required admin privilege"
    }    
}

function Invoke-AsAdmin {
    param(
        [Parameter(Mandatory)]
        [string]$AdminAction
    )

    if (Test-IsAdmin) {
        Write-Log "Already admin, executing '$AdminAction'"
        & $AdminAction
        return
    }

    Write-Log "Requesting admin privileges for '$AdminAction'"

    Start-Process powershell `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -AdminAction $AdminAction"

    exit
}
 

Write-Log "SCRIPT STARTED"

# -------------------------------
# AdminAction DISPATCH MODE
# -------------------------------
# -------------------------------
# AdminAction DISPATCH MODE
# -------------------------------

if (-not (Get-PhaseDone)) {
    # Phase 1 – Admin only
    Invoke-AsAdmin Phase1-Enable-WSLFeatures

    & powershell.exe -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit
}else{
    Set-PhaseDone "Phase1"
}

if ((Get-PhaseDone) -eq "Phase1") {


    # Phase 2 – Standard user
    Phase2-WSL-Setup
    Set-PhaseDone "Phase2"

}

if ((Get-PhaseDone) -eq "Phase2") {
    # Phase 3 – Admin only
    Invoke-AsAdmin Phase3-Register-WSLAutoStart

    Remove-Item -Recurse -Force $STATE_KEY
    Read-Host "Press ENTER to close this window"
}


